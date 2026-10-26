# BAAD board results and acceptance matrix

This continues the existing hardware-tested BAAD architecture. Earlier ILA evidence in `ILA_Data/RUN1` remains historical evidence; it is not replaced or relabelled as a run of this release. Fill observed results only after programming the matched package. No board result below is pre-filled.

## Run-level information (record once per session)

Record board model/revision/serial (ZCU102), operator, date/time, Vivado/Vitis version, BIT/LTX/XSA/ELF/UI SHA-256 values, hardware/firmware HELLO IDs, UART port/115200/8N1, power source, ambient conditions and result folder. Keep nominal 62 MHz and any independently measured clock frequency separate. Record requested six tone frequencies/PINCs, acknowledged DDS configuration, threshold, summary interval/count, burst source/count and any ILA trigger setup. Session files preserve requests and acknowledgements separately; a click is not proof a command took effect.

## Board cases

| ID | Test and existing stimulus | Procedure / repetitions | Record in results | Acceptance / interpretation |
|---|---|---|---|---|
| B00 | Identity and safe startup | Power-cycle; JTAG program matched files; connect; repeat 3 times | HELLO, startup status, logs, hashes | IDs `26091301`, protocol 2; no reset/DMA failure. M1 at startup is expected. |
| B02 | 2 MHz total six-tone bandwidth | Apply DDS; summaries 200 ms/3 records, threshold 5000; wait stable; 10 input and 10 output bursts, N4096 | Measured bins/edge/span, commanded/active M, gain, CRC/cadence, spectra | Nominal prediction M16, shift12; verify measured spectrum meets guard. Do not force a pass if spectrum differs. |
| B04 | 4 MHz total bandwidth | As B02 | Same fields | Nominal prediction M8, shift9. |
| B08 | 8 MHz total bandwidth | As B02 | Same fields | Nominal prediction M4, shift6. |
| B16 | 16 MHz total bandwidth | As B02 | Same fields | Nominal prediction M2, shift3. |
| B20 | Supported stimulus upper limit, 20 MHz | As B02; 5 paired stationary sets | Same fields; FIR-edge attenuation | M2 is nominal; fixed FIR is near its passband edge. No >20 MHz board-stimulus claim. |
| BTH | Threshold sensitivity | Each bandwidth, thresholds 500/1000/2500/5000/10000/25000/100000; at least 20 summaries per point | Active bins, estimated edge, M, no-active/error flags, peak/min power | Compare with idealized offline sweep. A threshold that hides tones can cause fallback or over-decimation; document rather than suppress. Restore 5000. |
| BFB | No-active fallback | At 2 MHz raise threshold to 33-bit maximum `8589934591`; then restore5000 | Flag/candidate/active-M timeline and recovery | No-active drives M1; recovery uses inward margin/two valid frames. Host snapshots do not resolve frame-level latency. |
| BDYN | Widen/narrow transitions | 2→4→8→16→8→4→2 MHz, 10 cycles; dwell 2 s; save ILA decision/CIC signals for detailed timing | Decision frame ID, edge, candidate/current M, rate_changed, settling, output-valid gaps | Widening drops M at strict guard; increasing M requires inward margin and 2 frames. Use ILA/simulation for clock-accurate transition latency. |
| BHYS | Guard/hysteresis boundary | Tune bandwidth near measured edge bins41/51,92/102,194/204,399/409; small up/down steps,10 cycles | Actual edge bins and transitions, not only requested width | Do not chatter within deadband. DDS/leakage/threshold make requested-frequency-to-bin mapping approximate. |
| BCAP | Capture size/source integrity | Both sources, N256/4096/8192,10 each | Header/trailer/full CRC, exact N, sample offsets, M/shift, capture ID, flags | PSD stride1; CIC strideM; no missing/duplicate samples in an unflagged steady capture. Flags or gaps exclude steady-state metrics. |
| BABT | Abort and retrieve again | Abort while waiting/acquiring and during chunk transfer,10 repeats; then capture again | Partial `.bin`, failure JSON, next capture ID, DMA status | Partial data preserved, next acquisition completes. Aborted data is not a valid spectrum. |
| BLINK | Disconnect/reconnect | Disconnect during transfer; reconnect; Status/Abort held capture;10 repeats | UART/event logs, retry/failure evidence | No silently accepted partial capture. Firmware may hold completed buffer until Abort; reconnect does not manufacture a new capture. |
| BSCH | Summary cadence | Intervals50/200/1000 ms; count1 and4;60 s each | Device uptime, record/emitted/dropped counters, host arrival distribution | Firmware deadlines use real device time. UART batching means host arrival intervals need not equal requested capture interval. |
| BSOAK | Recorded soak | 30 min summaries200 ms, repeated N8192 bursts; keep result directory writable | Memory/CPU, file growth, counter deltas, timeout/errors/CRC, elapsed duration | No unexplained data loss/invalid nominal bursts. Retain any failed run and state reproduction steps. |
| BDISK | Recording failure | Use a dedicated test destination that becomes unavailable/full; do not endanger existing files | Visible error, preserved files, status after reconnect | Host attempts STOP and closes link. Verify actual device status; OS/power-loss durability is not guaranteed by QFile flush. |

Sequential PSD/CIC bursts are not simultaneous or phase-aligned. Use stationary-tone amplitude ratios averaged over repeats; do not compute sample-wise input/output RMSE, phase transfer, or latency from independently triggered bursts. Those require aligned simulation/ILA evidence.

## Simulation / analysis-only cases

| ID | Case | Evidence to include |
|---|---|---|
| SCTL | Exact guard, inward hysteresis, malformed/absent frames, stale estimates | `tb_control_guard`, `tb_estimator_recovery`, legacy controller logs; cycles/frames and expected/observed M. |
| SCIC | Invalid rate, full-scale/DC/impulse/random I-Q, modular overflow, valid gaps, switching | `tb_cic_safety`, `tb_cic_numeric` independent convolution (60,010 comparisons), legacy CIC logs. Numerical model is separate from vendor DDS/FFT fidelity. |
| SAXI | Independent AW/W, byte strobes, stalled responses/DDS words | `tb_axi_config`; firmware busy/timeout tests. |
| SDMA | Backpressure, packet bounds/TLAST, flush, abort, CRC, DMA watchdog/reset/length faults | Burst/snapshot RTL and firmware mock logs. Fault injection is not claimed as performed on board. |
| SALIAS | Equal-amplitude desired/blocker and exact folded frequency at each M | Offline actual-FIR/CIC transfer calculations; M8/M16 blockers inside fixed FIR passband demonstrate finite alias attenuation. Not an adaptive retained-M guarantee. |
| SFID | Quantization/droop and real-input image | Actual coefficient hash, response curves, fixed-CIC vs convolution/floating errors, real1MHz→-9/-11MHz image calculation. Idealized FFT `/4096` is not vendor bit-exact. |
| SFIX | Fixed-rate versus adaptive resource comparison | Synthesize existing CIC with runtime M and constant M1/2/4/8/16 under the same part/clock; report scope explicitly. Never substitute core-only figures for whole-board or chain-only figures. |

## Tables and figures for the paper

1. Full-design resources (LUT/FF/DSP/BRAM), clock constraints, WNS/TNS/WHS/THS; separate chain-only and fixed-rate-core rows, tool/version/commit or manifest hashes.
2. Bandwidth→measured edge→M→output sample rate→measured bytes/record, with threshold and repeats. Compression of sample rate is M; UART throughput is a separate bounded retrieval metric.
3. Response/droop at each desired tone: input/output amplitudes, mean/standard deviation, FFT/window/coherent-gain method and predicted CIC attenuation.
4. Alias figure with input blocker frequency, folded output frequency, blocker/desired ratio and detection threshold. Label offline versus hardware.
5. Switching timeline showing estimate, decision, applied M, settling and m_valid; report ILA clocks rather than serial receipt time.
6. Reliability table: attempts/completed/flagged/aborted, CRC/sequence/DMA/protocol errors, dropped summaries, timeout/reset counts and duration.
7. Power: label Vivado vectorless estimates explicitly; only add measured board rails/input power if actually measured, with instrument and workload. No energy-per-sample measurement from estimated power alone.

For each case add: run folder, artifact hashes, expected behavior, observed value, units, repetitions, mean/std or min/max where meaningful, pass/fail/inconclusive, reason, and linked raw evidence. Failed/inconclusive runs remain part of the record.
