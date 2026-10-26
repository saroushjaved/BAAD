# Same-module fixed-rate synthesis comparison

Verified 2026-09-14 using Vivado2025.2, `xczu9eg-ffvb1156-2-e`, existing `rate_controlled_cic_decimator.v` inside `tests/cic_compare_top.v`. Command: `vivado -mode batch -source scripts/compare_fixed_cic.tcl -notrace -log fixed_cic.log -journal fixed_cic.jou` from BAAD. All six synthesis runs completed.

| Configuration | Synthesized LUTs | FF |
|---|---:|---:|
| Runtime-controlled M1/2/4/8/16 | 1068 | 472 |
| Constant M1 (bypass) | 8 | 41 |
| Constant M2 | 915 | 459 |
| Constant M4 | 916 | 459 |
| Constant M8 | 917 | 459 |
| Constant M16 | 862 | 459 |

Scope: CIC only,16-bit complex input/output,32-bit3-stage integrators, same reset, ports and observable status. Constant variants send the existing configuration interface one startup request; synthesis can propagate the fixed M. No new filter or alternate datapath is introduced. M1 logically bypasses filtering, so its much lower count is not a fair filtered-bandwidth comparison by itself.

These are post-synthesis, out-of-context counts, not placed/routed main-board or chain-only numbers. The wrapper excludes DDS/DDC FIR/FFT/controller/AXI/DMA/BRAM capture/ILA and PS. No physical clock-buffer location is supplied; synthesis timing reports warn that clock skew cannot be estimated. Do not use them as Fmax or final timing signoff. The16.129032ns requested period is rounded to16.129ns by Vivado.

Reports/checkpoints: `BAAD/build/fixed_cic_comparison/M{0,1,2,4,8,16}_{utilization,synthesis_timing}.rpt` and `.dcp`; M0 denotes runtime-controlled. Main-board resources must come from the release post-route hierarchical utilization report, with chain-only reference figures kept separate. No measured-power or full-system resource-saving claim follows from this small-core comparison.
