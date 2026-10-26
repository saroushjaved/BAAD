# Fresh-clone setup

Run commands from the repository root. Supply paths matching your tool installation. Build dependencies are not vendored.

## Software checks

```powershell
./BAAD/scripts/test_firmware.ps1 -Compiler 'C:/Qt/Tools/llvm-mingw1706_64/bin/clang.exe'
./BAAD/scripts/build_host.ps1 -Qt 'C:/Qt/6.11.1/llvm-mingw_64' -Compiler 'C:/Qt/Tools/llvm-mingw1706_64' -CMake 'C:/Qt/Tools/CMake_64/bin/cmake.exe' -Ninja 'C:/Qt/Tools/Ninja/ninja.exe'
```

The host build compiles the app, executes tests, deploys dependencies, and checks startup with an offscreen smoke test. The firmware host tests use mocks; they do not exercise physical DMA or UART hardware.

## Hardware and firmware

```powershell
$vivado = 'D:/Xilinx_2025.2/2025.2/Vivado/bin/vivado.bat'
& $vivado -mode batch -notrace -source BAAD/scripts/run_unit_tests.tcl -tclargs fresh_clone
& $vivado -mode batch -notrace -source BAAD/scripts/build_release_hw.tcl
./BAAD/scripts/review_release_reports.ps1
./BAAD/scripts/build_firmware.ps1 -Vitis 'D:/Xilinx_2025.2/2025.2/Vitis/bin/vitis.bat'
```

The hardware flow generates the block design from `main_bd.tcl`, applies `integrate_release.tcl`, and builds under `BAAD/build/hardware_release`. Firmware must be built against that output XSA. Never pair an old BSP/ELF with new hardware. Inspect all completion markers and timing/CDC/DRC reports; a zero process exit code alone is insufficient.

For source inspection only, append `-tclargs project_only` to the hardware build command. This creates the project in the same output directory; inspect and use the resume flow for subsequent implementation rather than repeating initial creation.

## MATLAB

From MATLAB with the repository root as the current directory:

```matlab
addpath(fullfile(pwd, 'BAAD', 'analysis'));
results = run_baad_analysis();
tests = run_analysis_tests();
```

Generated analysis outputs remain local. See `BAAD/analysis/README.md` for raw burst analysis.

## Release artifacts

Workstation-only packaging helpers and private provenance records are excluded. Distribute independently reviewed release artifacts with a manifest containing file hashes, tool versions, source revision, and validation status. Do not include personal paths, internal notes, or raw sessions without reviewing them first.

JTAG programming and board acceptance follow `BAAD/docs/BOARD_TEST_RUNBOOK.md`; its package paths describe the expected release layout. Keep measurement sessions and release binaries outside source commits.
