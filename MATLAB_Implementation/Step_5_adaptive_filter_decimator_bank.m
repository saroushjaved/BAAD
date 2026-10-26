%% ============================================================
% Step 5: Adaptive Filter/Decimator Bank
%
% Input files:
%   test_signal_fixed_Q15_Fs62Msps.mat
%   step3_occupied_bandwidth_output.mat
%   step4_decimation_controller_output.mat
%
% Output:
%   adaptive reduced-rate output stream
%
% Flow:
%   selected M
%       -> choose anti-alias filter h_M[n]
%       -> fixed-point FIR filtering
%       -> downsample by M
%       -> adaptive reduced-rate output
%
% Fixed-point modeling:
%   Input samples:      Q1.15 int16 I/Q
%   FIR coefficients:   Q1.15 int16
%   FIR accumulator:    modeled as Q2.30 using double exact integer math
%   FIR output:         Q1.15 int16
%
% ============================================================

clear; close all; clc;

%% ------------------------------------------------------------
% 1. Load required data
% ------------------------------------------------------------

sig  = load('test_signal_fixed_Q15_Fs62Msps.mat');
obw  = load('step3_occupied_bandwidth_output.mat');
ctrl = load('step4_decimation_controller_output.mat');

Fs = sig.Fs;

I_int = sig.I_int(:);
Q_int = sig.Q_int(:);

num_samples = length(I_int);

M_selected_blocks = ctrl.M_selected_blocks(:).';
time_blocks = ctrl.time_blocks(:).';

% Get hop and Nwin from Step 3 if available
if isfield(obw, 'hop')
    hop = obw.hop;
else
    hop = round(median(diff(time_blocks)) * Fs);
end

if isfield(obw, 'Nwin')
    Nwin = obw.Nwin;
else
    Nwin = 8192;
end

fprintf('Loaded input and controller data.\n');
fprintf('Fs = %.2f MSps\n', Fs/1e6);
fprintf('Total input samples = %d\n', num_samples);
fprintf('Number of control blocks = %d\n', length(M_selected_blocks));
fprintf('Control hop = %d samples\n', hop);
fprintf('PSD window length = %d samples\n', Nwin);

%% ------------------------------------------------------------
% 2. Generate per-sample decimation command M[n]
% ------------------------------------------------------------
% The controller gives one M decision per PSD block.
%
% For FPGA-faithful behavior, we model causal control:
%   decision from PSD block b is available only after that PSD window ends.
%
% Therefore:
%   Before first decision is available, use conservative M = 1.
%   Then apply decision b to the following hop interval.
%
% If you want ideal zero-delay control for debugging, set:
%   causal_control = false;

causal_control = true;

M_per_sample = ones(num_samples, 1);   % default conservative mode M=1

num_blocks = length(M_selected_blocks);

for b = 1:num_blocks

    if causal_control
        % PSD block b covers:
        %   start = (b-1)*hop + 1
        %   end   = start + Nwin - 1
        %
        % Decision becomes available after idx_psd_end.
        idx_psd_end = (b-1)*hop + Nwin;

        interval_start = idx_psd_end + 1;
        interval_end   = idx_psd_end + hop;
    else
        % Ideal noncausal alignment:
        interval_start = (b-1)*hop + 1;
        interval_end   = interval_start + hop - 1;
    end

    if interval_start > num_samples
        continue;
    end

    interval_end = min(interval_end, num_samples);

    M_per_sample(interval_start:interval_end) = M_selected_blocks(b);
end

fprintf('\nControl scheduling:\n');
if causal_control
    fprintf('Causal control enabled. Initial samples use M=1 until first PSD decision is available.\n');
else
    fprintf('Ideal zero-delay control enabled.\n');
end

%% ------------------------------------------------------------
% 3. Design anti-aliasing FIR filters
% ------------------------------------------------------------
% For decimation by M:
%
%   output Nyquist = Fs/(2M)
%
% We design the cutoff at:
%
%   Fc = 0.9 * Fs/(2M)
%
% while the controller only allows useful signal bandwidth up to:
%
%   0.8 * Fs/(2M)
%
% So there is guard room between the signal bandwidth limit and filter cutoff.
%
% M=1 is bypass.

modes = [1 2 4 8];

% FIR lengths.
% M=8 needs the narrowest transition, so it uses the longest filter.
Ntaps_M2 = 65;
Ntaps_M4 = 129;
Ntaps_M8 = 257;

h_q15 = cell(9,1);
h_float = cell(9,1);

% M=1 bypass
h_float{1} = 1;
h_q15{1} = int16(32767);

% M=2 filter
Fc_M2 = 0.9 * (1/(2*2));     % normalized to Fs, cycles/sample
[h_float{2}, h_q15{2}] = design_lowpass_fir_q15(Ntaps_M2, Fc_M2);

% M=4 filter
Fc_M4 = 0.9 * (1/(2*4));
[h_float{4}, h_q15{4}] = design_lowpass_fir_q15(Ntaps_M4, Fc_M4);

% M=8 filter
Fc_M8 = 0.9 * (1/(2*8));
[h_float{8}, h_q15{8}] = design_lowpass_fir_q15(Ntaps_M8, Fc_M8);

fprintf('\nDesigned anti-aliasing filters:\n');
fprintf('M=1: bypass\n');
fprintf('M=2: Ntaps = %d, cutoff = %.3f * Fs = %.2f MHz\n', ...
    Ntaps_M2, Fc_M2, Fc_M2*Fs/1e6);
fprintf('M=4: Ntaps = %d, cutoff = %.3f * Fs = %.2f MHz\n', ...
    Ntaps_M4, Fc_M4, Fc_M4*Fs/1e6);
fprintf('M=8: Ntaps = %d, cutoff = %.3f * Fs = %.2f MHz\n', ...
    Ntaps_M8, Fc_M8, Fc_M8*Fs/1e6);

%% ------------------------------------------------------------
% 4. Plot filter responses
% ------------------------------------------------------------

Nresp = 16384;
f_resp = (-Nresp/2:Nresp/2-1).' * (Fs/Nresp);

figure;
hold on; grid on;

for m = [2 4 8]
    H = fftshift(fft(double(h_q15{m})/2^15, Nresp));
    plot(f_resp/1e6, 20*log10(abs(H) + eps), 'LineWidth', 1.2);
end

xlabel('Baseband frequency (MHz)');
ylabel('Magnitude response (dB)');
title('Quantized Q1.15 Anti-Alias FIR Filter Responses');
legend('M=2', 'M=4', 'M=8', 'Location', 'best');
xlim([-31 31]);
ylim([-100 5]);

%% ------------------------------------------------------------
% 5. Run all filter paths continuously
% ------------------------------------------------------------
% This models a parallel filter bank:
%
%   input x[n]
%       -> h_1[n] path
%       -> h_2[n] path
%       -> h_4[n] path
%       -> h_8[n] path
%
% All paths run continuously.
% The selected mode chooses which path contributes output samples.
%
% This avoids filter-state discontinuity at mode switches.

fprintf('\nRunning fixed-point FIR paths...\n');

I_filt = cell(9,1);
Q_filt = cell(9,1);

% M=1 bypass
I_filt{1} = I_int;
Q_filt{1} = Q_int;

% Fixed-point FIR for M=2,4,8
for m = [2 4 8]
    fprintf('Filtering M=%d path...\n', m);

    [I_filt{m}, Q_filt{m}] = q15_complex_fir_fullstream( ...
        I_int, Q_int, h_q15{m});
end

fprintf('All filter paths complete.\n');

%% ------------------------------------------------------------
% 6. Adaptive downsampling
% ------------------------------------------------------------
% At each input sample n:
%   1. Read current selected mode M[n]
%   2. Select filtered path for M[n]
%   3. Output sample only if global phase satisfies mod(n-1, M) == 0
%
% The output is variable-rate.
% Therefore, we also store:
%   - original input sample index
%   - time stamp
%   - selected M for each output sample

fprintf('\nGenerating adaptive reduced-rate output...\n');

out_I = zeros(num_samples,1,'int16');
out_Q = zeros(num_samples,1,'int16');
out_input_index = zeros(num_samples,1);
out_M = zeros(num_samples,1);

out_count = 0;

for n = 1:num_samples

    M = M_per_sample(n);

    if mod(n-1, M) == 0

        out_count = out_count + 1;

        out_M(out_count) = M;
        out_input_index(out_count) = n;

        out_I(out_count) = I_filt{M}(n);
        out_Q(out_count) = Q_filt{M}(n);
    end
end

% Trim preallocated arrays
out_I = out_I(1:out_count);
out_Q = out_Q(1:out_count);
out_input_index = out_input_index(1:out_count);
out_M = out_M(1:out_count);

out_time = (double(out_input_index)-1) / Fs;
y_adaptive_q15 = double(out_I)/2^15 + 1j*double(out_Q)/2^15;

fprintf('Adaptive output generated.\n');
fprintf('Output samples = %d\n', out_count);

%% ------------------------------------------------------------
% 7. Data-rate reduction
% ------------------------------------------------------------

input_count = num_samples;
output_count = out_count;

output_rate_fraction = output_count / input_count;
data_rate_reduction = 1 - output_rate_fraction;

fprintf('\nAdaptive output rate:\n');
fprintf('Input samples  = %d\n', input_count);
fprintf('Output samples = %d\n', output_count);
fprintf('Output/input sample fraction = %.4f\n', output_rate_fraction);
fprintf('Data-rate reduction = %.2f %%\n', 100*data_rate_reduction);

%% ------------------------------------------------------------
% 8. Plot selected M per input sample
% ------------------------------------------------------------

t = (0:num_samples-1).' / Fs;

figure;
stairs(t*1e3, M_per_sample, 'LineWidth', 1.2);
grid on;
xlabel('Time (ms)');
ylabel('Selected decimation factor M');
title('Per-Sample Scheduled Decimation Mode');
yticks([1 2 4 8]);

%% ------------------------------------------------------------
% 9. Plot adaptive output sample locations
% ------------------------------------------------------------

figure;
plot(t*1e3, real(double(I_int)/2^15), 'LineWidth', 0.8); hold on;
stem(out_time*1e3, real(y_adaptive_q15), '.', 'LineWidth', 0.8);
grid on;

xlabel('Time (ms)');
ylabel('Real amplitude');
title('Input Signal and Adaptive Output Sample Locations');
legend('Input real part', 'Adaptive output samples');

xlim([0 min(0.2, t(end))*1e3]);

%% ------------------------------------------------------------
% 10. Plot output mode histogram
% ------------------------------------------------------------

figure;
histogram(out_M, 'BinMethod', 'integers');
grid on;
xlabel('Selected M at output sample');
ylabel('Number of output samples');
title('Distribution of Output Samples by Decimation Mode');
xticks([1 2 4 8]);

%% ------------------------------------------------------------
% 11. Export adaptive output for later stages
% ------------------------------------------------------------

% Pack adaptive output as 32-bit words:
% bits [31:16] = I
% bits [15:0]  = Q

out_I_u16 = uint16(mod(int32(out_I), 2^16));
out_Q_u16 = uint16(mod(int32(out_Q), 2^16));
out_IQ_u32 = bitor(bitshift(uint32(out_I_u16), 16), uint32(out_Q_u16));

save('step5_adaptive_decimator_output.mat', ...
    'out_I', 'out_Q', 'out_IQ_u32', ...
    'out_input_index', 'out_time', 'out_M', ...
    'y_adaptive_q15', ...
    'M_per_sample', ...
    'I_filt', 'Q_filt', ...
    'h_q15', 'h_float', ...
    'Fs', 'Fc_M2', 'Fc_M4', 'Fc_M8', ...
    'Ntaps_M2', 'Ntaps_M4', 'Ntaps_M8', ...
    'input_count', 'output_count', ...
    'output_rate_fraction', 'data_rate_reduction', ...
    'causal_control');

fprintf('\nSaved adaptive decimator output:\n');
fprintf('step5_adaptive_decimator_output.mat\n');

%% ------------------------------------------------------------
% 12. Export output samples as files
% ------------------------------------------------------------

writematrix([double(out_I), double(out_Q), double(out_M), double(out_input_index)], ...
    'adaptive_output_IQ_int16_with_metadata.csv');

fid = fopen('adaptive_output_IQ_packed_hex.txt', 'w');
for n = 1:length(out_IQ_u32)
    fprintf(fid, '%08X\n', out_IQ_u32(n));
end
fclose(fid);

fprintf('\nExported:\n');
fprintf('adaptive_output_IQ_int16_with_metadata.csv\n');
fprintf('adaptive_output_IQ_packed_hex.txt\n');

%% ------------------------------------------------------------
% 13. Export FIR coefficients for FPGA
% ------------------------------------------------------------

export_coefficients_q15('fir_coeff_M2_q15.txt', h_q15{2});
export_coefficients_q15('fir_coeff_M4_q15.txt', h_q15{4});
export_coefficients_q15('fir_coeff_M8_q15.txt', h_q15{8});

fprintf('\nExported Q1.15 FIR coefficients:\n');
fprintf('fir_coeff_M2_q15.txt\n');
fprintf('fir_coeff_M4_q15.txt\n');
fprintf('fir_coeff_M8_q15.txt\n');

%% ============================================================
% Local function: design low-pass FIR and quantize to Q1.15
% ============================================================

function [h, h_q15] = design_lowpass_fir_q15(Ntaps, Fc)
% design_lowpass_fir_q15
%
% Designs a windowed-sinc low-pass FIR.
%
% Inputs:
%   Ntaps = number of FIR taps, preferably odd
%   Fc    = cutoff normalized to Fs, cycles/sample
%           Example: Fc = 0.1 means cutoff = 0.1*Fs
%
% Outputs:
%   h     = floating-point FIR coefficients
%   h_q15 = Q1.15 int16 FIR coefficients

    if mod(Ntaps, 2) == 0
        error('Ntaps should be odd for symmetric Type-I FIR.');
    end

    if Fc <= 0 || Fc >= 0.5
        error('Fc must satisfy 0 < Fc < 0.5.');
    end

    n = (0:Ntaps-1).';
    alpha = (Ntaps-1)/2;
    m = n - alpha;

    % Normalized sinc: sinc(x) = sin(pi*x)/(pi*x)
    x = 2*Fc*m;

    sinc_x = ones(size(x));
    nonzero = abs(x) > 1e-12;
    sinc_x(nonzero) = sin(pi*x(nonzero)) ./ (pi*x(nonzero));

    % Ideal low-pass impulse response
    h_ideal = 2*Fc * sinc_x;

    % Hamming window, manually defined
    w = 0.54 - 0.46*cos(2*pi*n/(Ntaps-1));

    h = h_ideal .* w;

    % Normalize DC gain to 1
    h = h / sum(h);

    % Quantize to Q1.15
    h_q = round(h * 2^15);

    % Saturate
    h_q(h_q > 32767)  = 32767;
    h_q(h_q < -32768) = -32768;

    h_q15 = int16(h_q);
end

%% ============================================================
% Local function: fixed-point complex FIR full stream
% ============================================================

function [I_out, Q_out] = q15_complex_fir_fullstream(I_in, Q_in, h_q15)
% q15_complex_fir_fullstream
%
% Models a fixed-point complex FIR:
%
%   input:       Q1.15 int16 I/Q
%   coeffs:      Q1.15 int16
%   multiply:    Q1.15 * Q1.15 = Q2.30
%   accumulate:  Q2.30
%   output:      Q1.15 int16 after rounding/saturation
%
% This uses double for speed, but all operands are integer-valued.
% Values are within exact-integer range for this model.

    I_in_d = double(I_in);
    Q_in_d = double(Q_in);
    h_d = double(h_q15(:));

    % Q2.30 accumulator stream
    I_acc_q30 = filter(h_d, 1, I_in_d);
    Q_acc_q30 = filter(h_d, 1, Q_in_d);

    % Round and shift from Q2.30 to Q1.15
    I_temp = round(I_acc_q30 / 2^15);
    Q_temp = round(Q_acc_q30 / 2^15);

    % Saturate to int16
    I_temp(I_temp > 32767)  = 32767;
    I_temp(I_temp < -32768) = -32768;

    Q_temp(Q_temp > 32767)  = 32767;
    Q_temp(Q_temp < -32768) = -32768;

    I_out = int16(I_temp);
    Q_out = int16(Q_temp);
end

%% ============================================================
% Local function: export coefficients
% ============================================================

function export_coefficients_q15(filename, coeffs)
% Exports Q1.15 int16 coefficients as decimal and hex comments.

    fid = fopen(filename, 'w');

    for i = 1:length(coeffs)
        c = coeffs(i);
        c_u16 = uint16(mod(int32(c), 2^16));
        fprintf(fid, '%6d    // 0x%04X\n', c, c_u16);
    end

    fclose(fid);
end