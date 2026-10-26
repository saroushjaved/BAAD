%% DDC low-pass FIR design for Xilinx FIR Compiler
% Target: cleanup LPF after 10 MHz DDC mixer.
% Designed with MATLAB Signal Processing Toolbox routines equivalent to
% Filter Designer / FDATool fixed-order equiripple FIR setup.

clear; clc;

Fs = 62e6;
Fpass = 10e6;
Fstop = 12e6;
Apass = 0.1;
Astop = 60;
N = 128;              % Filter order; 129 taps
WL = 16;
FL = 15;
scale = 2^FL;

outDir = fileparts(mfilename('fullpath'));
coeFile = fullfile(outDir, 'ddc_lpf_order128_q15.coe');
csvFile = fullfile(outDir, 'ddc_lpf_order128_q15_coefficients.csv');
reportFile = fullfile(outDir, 'ddc_lpf_order128_report.txt');

% Convert dB ripple/attenuation specs into equiripple weights.
deltaPass = (10^(Apass/20) - 1) / (10^(Apass/20) + 1);
deltaStop = 10^(-Astop/20);
weights = [1/deltaPass, 1/deltaStop];

freq = [0 Fpass Fstop Fs/2] / (Fs/2);
amp = [1 1 0 0];

b = firpm(N, freq, amp, weights);
b = b / sum(b);       % exact unity DC gain before quantization

q = round(b * scale);
q(q > 2^(WL-1)-1) = 2^(WL-1)-1;
q(q < -2^(WL-1)) = -2^(WL-1);
q = int16(q);

bq = double(q) / scale;
[H, f] = freqz(bq, 1, 65536, Fs);
magDb = 20*log10(abs(H) + eps);

passIdx = f <= Fpass;
stopIdx = f >= Fstop;
passRippleDb = max(magDb(passIdx)) - min(magDb(passIdx));
passMinDb = min(magDb(passIdx));
passMaxDb = max(magDb(passIdx));
stopMaxDb = max(magDb(stopIdx));

fid = fopen(coeFile, 'w');
fprintf(fid, '; DDC low-pass FIR coefficients for Xilinx FIR Compiler\n');
fprintf(fid, '; Fs = %.0f Hz, Fpass = %.0f Hz, Fstop = %.0f Hz\n', Fs, Fpass, Fstop);
fprintf(fid, '; FIR equiripple order = %d, taps = %d\n', N, N+1);
fprintf(fid, '; Quantized signed Q%d.%d coefficients\n', WL-FL, FL);
fprintf(fid, 'radix = 10;\n');
fprintf(fid, 'coefdata =\n');
for k = 1:length(q)
    if k < length(q)
        fprintf(fid, '%d,\n', q(k));
    else
        fprintf(fid, '%d;\n', q(k));
    end
end
fclose(fid);

fid = fopen(csvFile, 'w');
fprintf(fid, 'index,coefficient_q15,coefficient_float\n');
for k = 1:length(q)
    fprintf(fid, '%d,%d,%.18g\n', k-1, q(k), bq(k));
end
fclose(fid);

fid = fopen(reportFile, 'w');
fprintf(fid, 'DDC low-pass FIR report\n');
fprintf(fid, '=======================\n');
fprintf(fid, 'Response type        : Lowpass\n');
fprintf(fid, 'Design method        : FIR equiripple (firpm)\n');
fprintf(fid, 'Filter order         : %d\n', N);
fprintf(fid, 'Number of taps       : %d\n', N+1);
fprintf(fid, 'Fs                   : %.0f Hz\n', Fs);
fprintf(fid, 'Fpass                : %.0f Hz\n', Fpass);
fprintf(fid, 'Fstop                : %.0f Hz\n', Fstop);
fprintf(fid, 'Apass target         : %.3f dB\n', Apass);
fprintf(fid, 'Astop target         : %.3f dB\n', Astop);
fprintf(fid, 'Coefficient format   : signed Q%d.%d\n', WL-FL, FL);
fprintf(fid, 'Quantized pass min   : %.4f dB\n', passMinDb);
fprintf(fid, 'Quantized pass max   : %.4f dB\n', passMaxDb);
fprintf(fid, 'Quantized pass ripple: %.4f dB\n', passRippleDb);
fprintf(fid, 'Quantized stop max   : %.4f dB\n', stopMaxDb);
fprintf(fid, 'COE file             : %s\n', coeFile);
fclose(fid);

fprintf('Wrote %s\n', coeFile);
fprintf('Quantized pass ripple = %.4f dB\n', passRippleDb);
fprintf('Quantized stop max = %.4f dB\n', stopMaxDb);
