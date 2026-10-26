param(
    [string]$Xsa='',
    [string]$OutputDirectory='',
    [string]$Vitis='D:/Xilinx_2025.2/2025.2/Vitis/bin/vitis.bat',
    [switch]$Resume
)
$ErrorActionPreference='Stop'
$baadRoot=Split-Path $PSScriptRoot -Parent
if(!$Xsa){$Xsa=Join-Path $baadRoot 'build/hardware_release/BAAD_BD_wrapper.xsa'}
if(!$OutputDirectory){$OutputDirectory=Join-Path $baadRoot 'build/firmware_release'}
$Xsa=(Resolve-Path -LiteralPath $Xsa).Path
$OutputDirectory=[System.IO.Path]::GetFullPath($OutputDirectory)
$workspace=Join-Path $OutputDirectory 'workspace'
$manifestPath=Join-Path $OutputDirectory 'build_manifest.json'
$xsaHash=(Get-FileHash -LiteralPath $Xsa -Algorithm SHA256).Hash
if(Test-Path -LiteralPath $manifestPath){
    $oldManifest=Get-Content -Raw -LiteralPath $manifestPath | ConvertFrom-Json
    if(!$Resume){throw 'Release directory already has a build. Use -Resume for the same XSA, or select a new output directory.'}
    if($oldManifest.xsa_sha256 -ne $xsaHash){throw 'XSA changed. Select a new output directory; never reuse a mismatched platform.'}
} elseif(Test-Path -LiteralPath $workspace){throw 'Existing workspace has no identity manifest; select a new output directory.'}
New-Item -ItemType Directory -Force -Path $OutputDirectory | Out-Null
$inputs=@('baad_serial_firmware/src/firmware.c','common/baad_serial_protocol.h','baad_software_v2/src/lscript.ld','scripts/build_firmware_vitis.py')
$manifest=[ordered]@{
    status='building';started_utc=[DateTime]::UtcNow.ToString('o');xsa=$Xsa;xsa_sha256=$xsaHash
    workspace=$workspace;vitis=$Vitis;build_id='26091301';protocol_version=2
    sources=@($inputs | ForEach-Object { $p=Join-Path $baadRoot $_; @{path=$_;sha256=(Get-FileHash -LiteralPath $p -Algorithm SHA256).Hash} })
    next_action='Inspect vitis_build.log and workspace logs. Resume only with this same XSA identity.'
}
$manifest | ConvertTo-Json -Depth 8 | Set-Content -LiteralPath $manifestPath
$env:BAAD_FW_ROOT=$baadRoot
$env:BAAD_FW_WORKSPACE=$workspace
$env:BAAD_FW_XSA=$Xsa
$env:BAAD_FW_RESUME=if($Resume){'1'}else{'0'}
$log=Join-Path $OutputDirectory ('vitis_build_'+[DateTime]::UtcNow.ToString('yyyyMMdd_HHmmss')+'.log')
$manifest.log=$log
$manifest | ConvertTo-Json -Depth 8 | Set-Content -LiteralPath $manifestPath
try {
    & $Vitis -s (Join-Path $PSScriptRoot 'build_firmware_vitis.py') 2>&1 | Tee-Object -FilePath $log
    if($LASTEXITCODE -ne 0 -or !(Select-String -LiteralPath $log -Pattern '^BAAD_FIRMWARE_BUILD_SUCCESS' -Quiet)) {
        throw "Vitis build failed or did not reach completion marker. Inspect $log"
    }
    $appElf=Join-Path $workspace 'baad_release_firmware/build/baad_release_firmware.elf'
    if(!(Test-Path -LiteralPath $appElf)){throw "Application ELF missing: $appElf"}
    $readelf=Join-Path (Split-Path (Split-Path $Vitis -Parent) -Parent) 'gnu/aarch64/nt/aarch64-none/bin/aarch64-none-elf-readelf.exe'
    $symbols=& $readelf -sW $appElf
    if($LASTEXITCODE -ne 0){throw 'Could not inspect firmware ELF symbols.'}
    $symbols | Set-Content -LiteralPath (Join-Path $OutputDirectory 'firmware_symbols.log')
    $dmaSymbol=@($symbols | Where-Object {$_ -match '^\s*\d+:\s+([0-9a-fA-F]+)\s+(\d+)\s+OBJECT\s+LOCAL\s+DEFAULT\s+\d+\s+dma_buffer$'})
    if($dmaSymbol.Count -ne 1){throw 'Cannot uniquely identify DMA buffer in linked ELF.'}
    $null=$dmaSymbol[0] -match '^\s*\d+:\s+([0-9a-fA-F]+)\s+(\d+)'
    $dmaAddress=[Convert]::ToUInt64($Matches[1],16);$dmaSize=[UInt64]$Matches[2]
    if(($dmaAddress % 64) -ne 0 -or ($dmaAddress+$dmaSize) -gt 0x100000000L -or $dmaSize -ne 65664){
        throw "DMA placement invalid: address $dmaAddress size $dmaSize"
    }
    & $readelf -lW $appElf | Set-Content -LiteralPath (Join-Path $OutputDirectory 'firmware_segments.log')
    if($LASTEXITCODE -ne 0){throw 'Could not inspect firmware segments.'}
    $platformPath=Join-Path $workspace 'baad_release_platform'
    $bootElfs=@(Get-ChildItem -LiteralPath $platformPath -Recurse -File -Filter '*.elf')
    $fsbl=@($bootElfs | Where-Object {$_.Name -match 'fsbl' } | Sort-Object @{Expression={$_.FullName -notmatch 'export'}})
    $pmu=@($bootElfs | Where-Object {$_.Name -match 'pmu' } | Sort-Object @{Expression={$_.FullName -notmatch 'export'}})
    if(!$fsbl.Count -or !$pmu.Count){throw 'Fresh FSBL or PMU firmware ELF missing.'}
    Copy-Item -LiteralPath $appElf -Destination (Join-Path $OutputDirectory 'baad_serial_firmware.elf') -Force
    Copy-Item -LiteralPath $fsbl[0].FullName -Destination (Join-Path $OutputDirectory 'zynqmp_fsbl.elf') -Force
    Copy-Item -LiteralPath $pmu[0].FullName -Destination (Join-Path $OutputDirectory 'pmufw.elf') -Force
    $manifest.status='built_and_placement_verified';$manifest.completed_utc=[DateTime]::UtcNow.ToString('o')
    $manifest.dma_address=('0x{0:x}' -f $dmaAddress);$manifest.dma_bytes=$dmaSize
    $manifest.artifacts=@(Get-ChildItem -LiteralPath $OutputDirectory -File -Filter '*.elf' | ForEach-Object {@{name=$_.Name;sha256=(Get-FileHash -LiteralPath $_.FullName -Algorithm SHA256).Hash}})
    $manifest.next_action='Root release signoff and JTAG instructions; board acceptance remains user-run.'
} catch {
    $manifest.status='failed';$manifest.error=$_.Exception.Message
    throw
} finally {
    $manifest | ConvertTo-Json -Depth 8 | Set-Content -LiteralPath $manifestPath
    Remove-Item Env:BAAD_FW_ROOT,Env:BAAD_FW_WORKSPACE,Env:BAAD_FW_XSA,Env:BAAD_FW_RESUME -ErrorAction SilentlyContinue
}
