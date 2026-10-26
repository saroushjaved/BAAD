param([string]$Compiler='C:/Qt/Tools/llvm-mingw1706_64/bin/clang.exe')
$ErrorActionPreference='Stop'
$baadRoot=Split-Path $PSScriptRoot -Parent
$testRoot=Join-Path $baadRoot 'baad_serial_firmware/tests'
$outputRoot=Join-Path $baadRoot 'baad_serial_firmware/build_host_tests'
New-Item -ItemType Directory -Force -Path $outputRoot | Out-Null
$exe=Join-Path $outputRoot 'test_firmware.exe'
$compileLog=Join-Path $outputRoot 'compile.log'
$testLog=Join-Path $outputRoot 'tests.log'
& $Compiler -std=c11 -O2 -g -Wall -Wextra -Werror -I "$testRoot" -I "$baadRoot/common" "$testRoot/test_firmware.c" -o $exe 2>&1 | Tee-Object -FilePath $compileLog
if($LASTEXITCODE -ne 0){throw "Firmware host compile failed; see $compileLog"}
& $exe 2>&1 | Tee-Object -FilePath $testLog
if($LASTEXITCODE -ne 0){throw "Firmware host tests failed; see $testLog"}
