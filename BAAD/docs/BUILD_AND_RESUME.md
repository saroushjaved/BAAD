# Build and resume

Run from the repository root. Set the Vivado executable path for your installation; the examples require Vivado/Vitis 2025.2.

```powershell
$vivado = 'D:/Xilinx_2025.2/2025.2/Vivado/bin/vivado.bat'
./BAAD/scripts/test_firmware.ps1
./BAAD/scripts/build_host.ps1
& $vivado -mode batch -notrace -source BAAD/scripts/run_unit_tests.tcl -tclargs release

# Initial full build; refuses to overwrite an existing release project.
& $vivado -mode batch -notrace -source BAAD/scripts/build_release_hw.tcl

# Inspect an interrupted build before resuming it.
& $vivado -mode batch -notrace -source BAAD/scripts/inspect_release_hw.tcl
& $vivado -mode batch -notrace -source BAAD/scripts/resume_release_hw.tcl

# Review reports, then build firmware against the fresh XSA.
./BAAD/scripts/review_release_reports.ps1
./BAAD/scripts/build_firmware.ps1
```

The generated project is `BAAD/build/hardware_release/project/baad_release.xpr`. Authored RTL remains under `BAAD/BAAD_V1.srcs/sources_1/new`. To create the source project without implementation, use `build_release_hw.tcl -tclargs project_only`; subsequent implementation uses the inspect/resume flow.

Hardware outputs are `BAAD/build/hardware_release/BAAD_BD_wrapper.{bit,ltx,xsa}`. Review timing, DRC, methodology, CDC, and clock reports under `reports`. Do not mix bitstreams, probes, hardware exports, or firmware from different builds.

Firmware builds a matching-XSA platform, FSBL, PMU firmware, and application in a separate workspace and verifies DMA placement. `-Resume` requires the same XSA hash. Host output is `BAAD/build/host_release`; the build executes tests and an offscreen startup check after deploying runtime dependencies.

Inspect active tool processes and existing logs before resuming. Source changes after synthesis require refreshing affected runs. Tool exit status alone does not establish acceptance: review explicit test completion markers and implementation reports. Physical board validation is separate; see [the board runbook](BOARD_TEST_RUNBOOK.md).
