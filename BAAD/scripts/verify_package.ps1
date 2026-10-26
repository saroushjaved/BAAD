param([string]$PackageRoot=(Split-Path $PSScriptRoot -Parent))
$ErrorActionPreference='Stop'
$base=(Resolve-Path -LiteralPath $PackageRoot).Path.TrimEnd('\','/')
$manifest=Get-Content -Raw -LiteralPath (Join-Path $base 'release_manifest.json') | ConvertFrom-Json
if((Get-FileHash -LiteralPath "$base/release_manifest.json" -Algorithm SHA256).Hash -ne (Get-FileHash -LiteralPath "$base/host/release_manifest.json" -Algorithm SHA256).Hash){throw 'Host manifest copy differs'}
if($manifest.status -ne 'build_and_software_verified_board_test_pending'){throw 'Package is not marked verified for board testing'}
$failures=@()
foreach($item in $manifest.files){
 $path=[IO.Path]::GetFullPath((Join-Path $base $item.path))
 if(!$path.StartsWith($base+[IO.Path]::DirectorySeparatorChar,[StringComparison]::OrdinalIgnoreCase)){throw 'Unsafe manifest path'}
 if(!(Test-Path -LiteralPath $path -PathType Leaf)){ $failures += "Missing $($item.path)";continue }
 if((Get-FileHash -LiteralPath $path -Algorithm SHA256).Hash -ne $item.sha256){$failures += "Changed $($item.path)"}
}
if($failures.Count){$failures | Write-Output;throw 'Package hash verification failed'}
Write-Output "PASS: $($manifest.files.Count) packaged files match SHA-256; board acceptance still requires your tests."
