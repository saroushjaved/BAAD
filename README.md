# BAAD — Bandwidth-Aware Adaptive Decimation

An FPGA and software research implementation of real-time bandwidth-aware adaptive decimation on the AMD Zynq UltraScale+ ZCU102. The system estimates occupied bandwidth and selects a CIC decimation rate, with firmware and a Qt desktop application for control, telemetry, and bounded sample capture.

## System

The processing chain combines generated multitone input, a fixed 129-tap DDC FIR, an FFT-based bandwidth estimator, adaptive rate control, and a three-stage CIC decimator. The board configuration supports decimation factors **1, 2, 4, 8, and 16**, nominal processing at **62 MHz**, a **10 MHz** LO, and **115200-baud UART** control. Capture supports 256–8192 complex samples from the PSD input or CIC output.

The controller applies a strict guard when reducing decimation, hysteresis when increasing it, and a fallback when estimates become stale. MATLAB tools characterize response, numerical behavior, and captured data.

## Repository layout

| Path | Contents |
| --- | --- |
| `BAAD/BAAD_V1.srcs/sources_1/new/` | Authored RTL |
| `BAAD/BAAD_V1.srcs/sim_1/new/`, `BAAD/tests/` | Legacy and focused RTL testbenches |
| `BAAD/BAAD_V1.ip_user_files/mem_init_files/` | Required FIR coefficients and Hann ROM |
| `BAAD/scripts/` | Vivado/Vitis builds, regression, report review, artifact verification |
| `BAAD/baad_serial_firmware/` | Board firmware and host-based firmware tests |
| `BAAD/baad_software_v2/src/lscript.ld` | Linker configuration used by the firmware build |
| `BAAD/common/` | Shared firmware/host protocol |
| `BAAD_Software_Control_UI/` | Qt C++ control app and protocol/decoder tests |
| `BAAD/analysis/` | MATLAB analysis and capture decoders |
| `Filter_Designs/Low_Pass_DDC/` | FIR design scripts and coefficients |
| `MATLAB_Implementation/`, `MATLAB_Artifiacts/` | Reference simulation and ROM generator |
| `BAAD/docs/`, `docs/` | Build, protocol usage, test, and repository documentation |

The established source paths are retained because the build scripts depend on them. Generated Vivado projects are recreated from Tcl; historical project copies, caches, binaries, local release bundles, drivers, research drafts, and recorded ILA/session data are excluded.

## Prerequisites

- Windows with PowerShell for the supplied orchestration scripts.
- AMD Vivado and Vitis **2025.2**, ZCU102 board definitions, and required vendor IP access.
- Qt **6.11.1**, LLVM-MinGW, CMake, and Ninja for the host app.
- MATLAB **R2021a** for the core analysis. Original filter-design/reference scripts may require additional MATLAB toolboxes.
- ZCU102 with JTAG and UART access for physical acceptance tests.

Tool defaults reflect the original workstation. Override script parameters for your installation; see [fresh-clone setup](docs/GETTING_STARTED.md).

## Build and test

From the repository root in PowerShell:

```powershell
# Host-based firmware regression and Qt application build/tests
./BAAD/scripts/test_firmware.ps1
./BAAD/scripts/build_host.ps1

# RTL regression (choose a fresh output tag)
& 'D:/Xilinx_2025.2/2025.2/Vivado/bin/vivado.bat' -mode batch -notrace -source BAAD/scripts/run_unit_tests.tcl -tclargs github

# Recreate the integrated Vivado project without implementation
& 'D:/Xilinx_2025.2/2025.2/Vivado/bin/vivado.bat' -mode batch -notrace -source BAAD/scripts/build_release_hw.tcl -tclargs project_only
```

For a full hardware/firmware build, use [GETTING_STARTED.md](docs/GETTING_STARTED.md) and [build/resume instructions](BAAD/docs/BUILD_AND_RESUME.md). The build refuses to overwrite an existing release project: inspect and resume it before rerunning. Outputs belong in ignored build directories.

## Validation status and limits

The local September 2026 checkpoint records passing RTL, firmware-host, Qt-host, and MATLAB checks, plus routed hardware signoff. Those historical results are not fresh-clone verification and their generated evidence is not committed here. **Physical board acceptance remains pending.** Estimated power, offline analysis, and simulation must not be presented as measured board results.

Start physical testing with the [board runbook](BAAD/docs/BOARD_TEST_RUNBOOK.md) and [results matrix](BAAD/docs/RESULTS_TEST_MATRIX.md). See [analysis documentation](BAAD/analysis/README.md) for capture integrity and interpretation limits and [IP validation review](BAAD/docs/IP_VALIDATION_REVIEW.md) for reviewed integration warnings.

## Contributing and licensing

See [CONTRIBUTING.md](CONTRIBUTING.md) for source and validation conventions and [third-party notices](docs/THIRD_PARTY_NOTICES.md) for the included AMD linker script. No open-source license has been selected for the original project code. Vendor tools, IP, and Qt retain their respective license terms.
