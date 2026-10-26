param([string]$Qt='C:/Qt/6.11.1/llvm-mingw_64',[string]$Compiler='C:/Qt/Tools/llvm-mingw1706_64',
 [string]$CMake='C:/Qt/Tools/CMake_64/bin/cmake.exe',[string]$Ninja='C:/Qt/Tools/Ninja/ninja.exe')
$ErrorActionPreference='Stop'
$baadRoot=Split-Path $PSScriptRoot -Parent
$repoRoot=Split-Path $baadRoot -Parent
$source=Join-Path $repoRoot 'BAAD_Software_Control_UI'
$build=Join-Path $source 'build/release'
$output=Join-Path $baadRoot 'build/host_release'
New-Item -ItemType Directory -Force -Path $output | Out-Null
$savedPath=$env:PATH
try {
 $env:PATH="$Compiler/bin;$Qt/bin;$savedPath"
 & $CMake -S $source -B $build -G Ninja -DCMAKE_BUILD_TYPE=Release "-DCMAKE_PREFIX_PATH=$Qt" "-DCMAKE_CXX_COMPILER=$Compiler/bin/clang++.exe" "-DCMAKE_MAKE_PROGRAM=$Ninja" 2>&1 | Tee-Object "$output/configure.log"
 if($LASTEXITCODE){throw 'Host configure failed'}
 & $CMake --build $build -j 4 2>&1 | Tee-Object "$output/build.log"
 if($LASTEXITCODE){throw 'Host build failed'}
 & "$build/baad_host_tests.exe" 2>&1 | Tee-Object "$output/tests.log"
 if($LASTEXITCODE){throw 'Host tests failed'}
 Copy-Item -LiteralPath "$build/BAAD_Software_Control_UI.exe" -Destination $output -Force
 Copy-Item -LiteralPath "$build/baad_host_tests.exe" -Destination $output -Force
 # windeployqt misclassifies this installed LLVM distribution's plugins as
 # debug and fails even with --no-plugins. Explicit dependency deployment:
 # QtWidgets -> QtGui -> QtCore -> libc++/libunwind + Windows system DLLs.
 foreach($library in @('Qt6Core.dll','Qt6Gui.dll','Qt6Widgets.dll')) {
  Copy-Item -LiteralPath "$Qt/bin/$library" -Destination $output -Force
 }
 New-Item -ItemType Directory -Force -Path "$output/platforms" | Out-Null
 foreach($plugin in @('qwindows.dll','qoffscreen.dll')) {
  Copy-Item -LiteralPath "$Qt/plugins/platforms/$plugin" -Destination "$output/platforms" -Force
 }
 foreach($runtime in @('libc++.dll','libunwind.dll')) {
  Copy-Item -LiteralPath "$Compiler/bin/$runtime" -Destination $output -Force
 }
 Copy-Item -LiteralPath "$PSScriptRoot/host_qt.conf" -Destination "$output/qt.conf" -Force
 # Test the deployed bundle without Qt/compiler bin directories on PATH.
 $env:PATH="$env:SystemRoot/System32;$env:SystemRoot"
 $env:QT_QPA_PLATFORM='offscreen';$env:BAAD_SMOKE_IMAGE="$output/smoke.png"
 $p=Start-Process -FilePath "$output/BAAD_Software_Control_UI.exe" -ArgumentList '--smoke-test' -WindowStyle Hidden -Wait -PassThru -RedirectStandardError "$output/smoke.log"
 if($p.ExitCode -ne 0){throw "Deployed UI startup failed $($p.ExitCode)"}
 & "$output/baad_host_tests.exe" 2>&1 | Tee-Object "$output/deployed_tests.log"
 if($LASTEXITCODE){throw 'Deployed host tests failed'}
 Write-Output 'BAAD_HOST_BUILD_DEPLOY_TEST_SUCCESS'
} finally {
 $env:PATH=$savedPath
 Remove-Item Env:QT_QPA_PLATFORM,Env:BAAD_SMOKE_IMAGE -ErrorAction SilentlyContinue
}
