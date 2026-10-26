# BAAD main-board testing runbook

Target: the existing ZCU102 / Zynq UltraScale+ design, nominal62MHz DSP,10MHz LO, <=20MHz total generated six-tone bandwidth. This is a continuation of the previously tested architecture, not a new board/stimulus design. The chain-only reference and older ILA captures are preserved. Board execution and measurements are yours; software tests and implementation reports do not imply the new release has been exercised on your board.

## Before programming

Use a package only when its `release_manifest.json` states software/build verification complete and `board_acceptance` pending user testing. Do not select old BIT/ELF files from the historical project by matching filenames alone. Keep the whole package, its source checkpoint and hashes together. Verify package hashes with the supplied verification script.

Use the board's already-tested power/JTAG/UART setup and JTAG boot selection; do not change board switches based on guesses. Connect JTAG and the PS UART USB cable. Close other serial terminals on that COM port. No ADC input, SD card, Linux image or new waveform generator is required.

## JTAG launch through Vitis 2025.2

1. Open the fresh release Vitis workspace under `BAAD/build/firmware_release/workspace` (or the exact path recorded by its build manifest), application `baad_release_firmware`.
2. Create a Hardware / bare-metal Zynq UltraScale+ debug launch, local hardware server, A53 core `psu_cortexa53_0`.
3. Enable system reset and device programming. Select the packaged `hardware/BAAD_BD_wrapper.bit`.
4. Choose initialization with the packaged `firmware/zynqmp_fsbl.elf`, exit symbol `XFsbl_Exit`. This follows the previously used FSBL launch method. Do not also substitute an old `psu_init.tcl` or old platform. The fresh `pmufw.elf` is included if required by your established Vitis launch configuration; use the new platform's boot artifacts, not mixed versions.
5. Download packaged `firmware/baad_serial_firmware.elf` to A53_0 and run. Disable stop-at-entry, or explicitly Resume if the debugger stops at main.
6. For ILA capture, open Vivado Hardware Manager, select the programmed device and load packaged `hardware/BAAD_BD_wrapper.ltx`. Retain the BIT/LTX pair. Use the original ILA_IN/ILA_PSD/ILA_BW/ILA_DECE/ILA_DMA_F probes and record trigger settings and clock domains.

The old `_ide/launch.json` uses historical absolute paths. Do not launch it unchanged for this release. Initialization/board enumeration remain user-run checks; if FSBL stalls, stop and retain the Vitis console rather than repeatedly downloading unrelated ELFs.

## First recorded run

1. Start `host/BAAD_Software_Control_UI.exe` from its complete folder, not a copied standalone EXE. It needs the adjacent Qt/runtime DLLs and `platforms` folder; Qt need not be installed on the test PC.
2. Refresh/select PS UART COM port,115200. Connect and select a writable parent folder. A unique UTC/UUID session directory is created before opening UART. HELLO must report matching hardware and firmware IDs `26091301`, protocol2,62MHz,FFT2048,8192 maximum samples. Controls remain disabled on mismatch.
3. Select B02 (2MHz), click Apply DDS and wait for ACK. Existing six DDS tones are shown. Presets change requested settings, not observed results.
4. Threshold5000,3 summary records,200ms; click Summaries. Wait for measured bandwidth and stable active M. Expected nominal M16 is conditional on actual detected spectrum. Startup/no-active/error fallback M1 is legitimate, not proof nothing works.
5. Select PSD input,4096 samples; Capture burst. The PL waits for two stable decisions, captures to BRAM, drains through DMA, then the host pulls480-byte chunks. Repeat for CIC output. N8192 retrieval takes several seconds at115200; the short acquisition interval and UART retrieval duration are different quantities.
6. Use Status before and after case groups to record device uptime, DMA/protocol errors, emitted/dropped records, resets/timeouts. Press Result folder to inspect saved files.
7. Stop before changing experiments when an explicit discontinuity is useful. Apply the next DDS setting, wait for ACK, restart Summaries if necessary, and repeat the matrix. Summaries pause during burst ownership and resume after release when previously requested.

The threshold field is applied by Summaries/START_STREAM, not by Capture burst. Burst uses the currently acknowledged device configuration. After editing threshold, click Summaries and wait for ACK before the next burst. Do not change DDS/threshold during capture; host controls prevent this. For deliberate transient invalidation use simulation/ILA, not mislabelled steady captures.

## Saved evidence

| File | Meaning |
|---|---|
| `manifest.json` | Session metadata, executable/release-manifest hashes, identity and last acknowledged requests, start/close UTC. An unclosed session is recoverable evidence, not automatically a pass. |
| `uart_rx.bin`, `uart_tx.bin` | Exact incoming bytes and attempted outgoing command frames; check command ACK/events to know successful operations. |
| `events.jsonl` | Host UTC, packets/sequence gaps, commands/ACKs, device STATUS counters, retries/errors and saved captures. |
| `summary.csv` | Streaming decoded summary records; host UTC is receipt time, not DSP acquisition time. Device cycle/frame metadata is retained. |
| `test_runs.jsonl` | Requested case/configuration; manually attach observed result/pass/fail in experiment notes. |
| `capture_NNNN_idX.bin/.json/.csv` | Complete or partial raw record, validation metadata, and I/Q rows when integrity validates. Flags/gaps invalidate nominal metrics even when CRC is good. |

Raw record layout:8 header64-bit words; N sample words `{cycle_offset32,Q16,I16}`; END/count/flags word; CRC32 word. Sample rate nominal62MHz, PSD stride1 or CIC strideM. Byte order is little-endian. Full transfer CRC and record CRC are independent checks. A header/build ID does not replace artifact hashes.

## Analyze captures

In MATLAB R2021a:

```matlab
addpath(fullfile(pwd, 'BAAD', 'analysis')); % Run from repository root
c = read_baad_burst('D:/results/session/capture_0001_id1.bin');
r = analyze_baad_capture('D:/results/session/capture_0001_id1.bin');
```

The analyzer refuses flagged/gapped nominal FFTs. Amplitude is digital dBFS, not calibrated volts or RF power. Capture N/window/coherent gain must be included with spectra. Compare stationary input/output tone magnitudes over repeated sequential captures; they are not phase-aligned streams for time-domain error or latency. Use `RESULTS_TEST_MATRIX.md` for paper charts and acceptance evidence.

Summary cycle counters are32-bit and wrap after approximately69.27s; burst cycle timestamps are64-bit. `analyze_baad_summary('.../summary.csv')` unwraps an uninterrupted session and rejects >=60s host gaps or decreasing frame IDs. Split recordings at resets/disconnections; never assume a single wrap across an arbitrarily long gap.

## Recovery and limits

- Lost chunk: host retries the same offset up to3 times; duplicate reads are safe. Capture timeout/rejection/abort preserves partial data. Use Abort burst to release a held buffer before reacquiring.
- Lost control ACK: after2s the UI records an unknown outcome and requests Status; commands are not blindly retried. Verify configuration before retrying Apply.
- Reconnect after interrupted retrieval: HELLO/Status may reveal held data. Abort releases it; previous partial files remain invalid. A new capture ID distinguishes the next acquisition.
- DMA error/watchdog: firmware disables producer, resets DMA with a bounded deadline and flushes capture FIFO. Summary retry is bounded; failed bursts do not silently recapture. Sticky reset failure requires investigating/restarting the board.
- Disk error: host attempts STOP and closes serial; files already written remain. Verify device state on reconnect. QFile flush covers normal process crashes, not all sudden-power-loss cases.
- This CIC has measurable passband droop and finite alias rejection. The bandwidth guard is not a flatness/alias-safety proof. No compensation filter was added. Wider/noisy/modulated/custom-blocker vectors remain offline unless supported by your existing board stimulus.

Record all unexpected behavior with the session directory, status, screenshot, ILA/Vitis logs and exact reproduction steps. Do not delete failed runs when calculating reliability statistics.

