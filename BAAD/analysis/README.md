# Reproducible BAAD analysis

These scripts extend the existing fixed-FIR/FFT/CIC design. They do not change the FPGA or introduce a waveform generator or compensation filter. Base MATLAB R2021a is sufficient; no Signal Processing or Fixed-Point Toolbox is required.

From PowerShell in `the repository root`:

```powershell
& 'C:\Program Files\Polyspace\R2021a\bin\matlab.exe' -batch "addpath('BAAD/analysis'); run_baad_analysis" -logfile 'the repository root\BAAD\analysis\matlab_analysis.log'
```

Generated outputs are `generated/ANALYSIS_REPORT.md`, `analysis_results.json`, `analysis_results.mat` and `filter_responses.png`. The source coefficient file is read in place and hashed. The chain-only reference is not edited.

The report separates actual-coefficient transfer functions, modular CIC arithmetic, idealized DDS/FFT simulation, and controller frame-level predictions. The modular fixed-rate CIC is checked against an independently constructed integer moving-average convolution. This is not a substitute for RTL simulation or board tests. Vendor DDS phase truncation, vendor FFT stage rounding, and pipeline alignment are not claimed bit-exact.

For a raw burst `.bin` saved by the test application:

```matlab
addpath('BAAD/analysis');
c = read_baad_burst('D:/my_run/burst_7.bin');
r = analyze_baad_capture('D:/my_run/burst_7.bin','D:/my_run/analysis');
```

The raw file must contain one complete burst record, not the UART transport packet or concatenated legacy snapshots. The loader checks magic/version/type, count, layout, trailer, CRC32, flags, M/gain, and exact cycle cadence. Malformed records raise errors. Flagged/gapped records remain readable for diagnosis but cannot produce nominal spectrum metrics. `analyze_baad_capture` explicitly refuses their FFT.

An unflagged PSD burst has sample cycle stride 1; an unflagged CIC burst has stride M. Both contain exact per-sample cycle offsets. Capture length 256..8192 is a bounded observation, not continuous UART-rate data acquisition. Default N=4096 gives 15.1367 kHz PSD-input FFT spacing and 15.1367/M kHz CIC-output spacing at nominal 62 MHz. The generated Clock Wizard nominal realization is approximately 62.000967 MHz; retain the reported nominal rate and measured/calibrated rate separately when precision matters.

Use `../docs/RESULTS_TEST_MATRIX.md` for board cases and `../docs/BOARD_TEST_RUNBOOK.md` for recording. Sequential input/output bursts can support stationary spectral amplitude comparisons with averaging; they cannot support sample-by-sample error, transient latency, or phase-coherent transfer measurements without a shared trigger and alignment evidence. Those comparisons remain simulation/ILA tasks in this architecture.

