%% ============================================================
% Step 6: Evaluation of Adaptive Decimator
%
% Input files:
%   test_signal_fixed_Q15_Fs62Msps.mat
%   step4_decimation_controller_output.mat
%   step5_adaptive_decimator_output.mat
%
% This script evaluates:
%   1. Data-rate reduction
%   2. Mode usage
%   3. Switching behavior
%   4. Fixed-point output distortion
%   5. Per-mode NMSE/SNR
%   6. PSD before/after adaptive decimation
%   7. Alias/leakage ratio
%
% ============================================================

clear; close all; clc;

%% ------------------------------------------------------------
% 1. Load data
% ------------------------------------------------------------

sig  = load('test_signal_fixed_Q15_Fs62Msps.mat');
ctrl = load('step4_decimation_controller_output.mat');
dec  = load('step5_adaptive_decimator_output.mat');

Fs = sig.Fs;

x_scaled = sig.x_scaled(:);              % floating reference after scaling
x_fixed  = sig.x_fixed_model(:);         % Q1.15 reconstructed input

out_I = dec.out_I(:);
out_Q = dec.out_Q(:);
out_M = dec.out_M(:);
out_input_index = dec.out_input_index(:);
out_time = dec.out_time(:);

y_adaptive = double(out_I)/2^15 + 1j*double(out_Q)/2^15;

M_per_sample = dec.M_per_sample(:);
h_float = dec.h_float;
h_q15 = dec.h_q15;

num_input_samples = length(x_scaled);
num_output_samples = length(y_adaptive);

fprintf('Loaded evaluation data.\n');
fprintf('Input samples  = %d\n', num_input_samples);
fprintf('Output samples = %d\n', num_output_samples);
fprintf('Fs = %.2f MSps\n', Fs/1e6);

%% ------------------------------------------------------------
% 2. Data-rate reduction
% ------------------------------------------------------------

output_rate_fraction = num_output_samples / num_input_samples;
data_rate_reduction = 1 - output_rate_fraction;

fprintf('\nData-rate reduction:\n');
fprintf('Output/input sample fraction = %.5f\n', output_rate_fraction);
fprintf('Data-rate reduction = %.2f %%\n', 100*data_rate_reduction);

%% ------------------------------------------------------------
% 3. Mode usage statistics
% ------------------------------------------------------------

modes = [1 2 4 8];

input_mode_fraction = zeros(size(modes));
output_mode_fraction = zeros(size(modes));

fprintf('\nMode usage:\n');

for ii = 1:length(modes)

    M = modes(ii);

    input_mode_fraction(ii) = mean(M_per_sample == M);
    output_mode_fraction(ii) = mean(out_M == M);

    fprintf('M = %d | input-time usage = %.2f %% | output-sample usage = %.2f %%\n', ...
        M, 100*input_mode_fraction(ii), 100*output_mode_fraction(ii));
end

figure;
bar(modes, 100*input_mode_fraction);
grid on;
xlabel('Decimation factor M');
ylabel('Input-time usage (%)');
title('Input-Time Mode Usage');

figure;
bar(modes, 100*output_mode_fraction);
grid on;
xlabel('Decimation factor M');
ylabel('Output-sample usage (%)');
title('Output-Sample Mode Usage');

%% ------------------------------------------------------------
% 4. Switching behavior
% ------------------------------------------------------------

mode_changes = [0; diff(M_per_sample) ~= 0];
switch_indices = find(mode_changes);
num_switches = length(switch_indices);

fprintf('\nSwitching behavior:\n');
fprintf('Number of per-sample mode switches = %d\n', num_switches);

if num_switches > 1
    switch_intervals_samples = diff(switch_indices);
    switch_intervals_time = switch_intervals_samples / Fs;

    fprintf('Mean time between switches = %.3f us\n', ...
        mean(switch_intervals_time)*1e6);
else
    fprintf('Mean time between switches = N/A\n');
end

t_input = (0:num_input_samples-1).' / Fs;

figure;
stairs(t_input*1e3, M_per_sample, 'LineWidth', 1.2);
grid on;
xlabel('Time (ms)');
ylabel('Selected decimation factor M');
title('Selected Decimation Factor Over Input Time');
yticks([1 2 4 8]);

%% ------------------------------------------------------------
% 5. Build floating-point reference output
% ------------------------------------------------------------
% We compare the fixed-point adaptive output against a floating-point
% reference that uses:
%
%   same selected M
%   same output sample locations
%   floating-point input x_scaled
%   floating-point FIR coefficients h_float{M}
%
% This measures fixed-point implementation error:
%   input quantization + coefficient quantization + FIR output quantization

fprintf('\nBuilding floating-point reference filter paths...\n');

x_ref_filt = cell(9,1);

x_ref_filt{1} = x_scaled;

for M = [2 4 8]
    x_ref_filt{M} = filter(h_float{M}, 1, x_scaled);
end

y_ref = zeros(num_output_samples, 1);

for n = 1:num_output_samples
    M = out_M(n);
    idx = out_input_index(n);

    y_ref(n) = x_ref_filt{M}(idx);
end

fprintf('Floating-point reference output built.\n');

%% ------------------------------------------------------------
% 6. Overall fixed-point distortion
% ------------------------------------------------------------

err = y_ref - y_adaptive;

NMSE = sum(abs(err).^2) / sum(abs(y_ref).^2);
NMSE_dB = 10*log10(NMSE + eps);

SNR_out_dB = 10*log10(sum(abs(y_ref).^2) / sum(abs(err).^2));

fprintf('\nOverall fixed-point output distortion:\n');
fprintf('NMSE = %.6e\n', NMSE);
fprintf('NMSE = %.2f dB\n', NMSE_dB);
fprintf('SNR  = %.2f dB\n', SNR_out_dB);

figure;
plot(out_time*1e3, abs(err), 'LineWidth', 1.0);
grid on;
xlabel('Time (ms)');
ylabel('|error|');
title('Adaptive Output Error Magnitude vs Floating-Point Reference');

%% ------------------------------------------------------------
% 7. Per-mode distortion
% ------------------------------------------------------------

NMSE_mode = zeros(size(modes));
NMSE_mode_dB = zeros(size(modes));
SNR_mode_dB = zeros(size(modes));

fprintf('\nPer-mode output distortion:\n');

for ii = 1:length(modes)

    M = modes(ii);
    idx = out_M == M;

    if sum(idx) < 10
        NMSE_mode(ii) = NaN;
        NMSE_mode_dB(ii) = NaN;
        SNR_mode_dB(ii) = NaN;

        fprintf('M = %d | insufficient samples\n', M);
        continue;
    end

    eM = y_ref(idx) - y_adaptive(idx);
    rM = y_ref(idx);

    NMSE_mode(ii) = sum(abs(eM).^2) / sum(abs(rM).^2);
    NMSE_mode_dB(ii) = 10*log10(NMSE_mode(ii) + eps);
    SNR_mode_dB(ii) = 10*log10(sum(abs(rM).^2) / sum(abs(eM).^2));

    fprintf('M = %d | NMSE = %.2f dB | SNR = %.2f dB\n', ...
        M, NMSE_mode_dB(ii), SNR_mode_dB(ii));
end

figure;
bar(modes, SNR_mode_dB);
grid on;
xlabel('Decimation factor M');
ylabel('SNR vs floating reference (dB)');
title('Per-Mode Fixed-Point Output SNR');

%% ------------------------------------------------------------
% 8. PSD before decimation
% ------------------------------------------------------------

fprintf('\nComputing PSD of input signal...\n');

Nfft_psd = 8192;
win_len = 4096;
noverlap = 2048;

win = hann(win_len, 'periodic');

[Pxx_in, f_in] = pwelch(x_fixed, win, noverlap, Nfft_psd, Fs, ...
                        'centered', 'power');

figure;
plot(f_in/1e6, 10*log10(Pxx_in + eps), 'LineWidth', 1.2);
grid on;
xlabel('Baseband frequency (MHz)');
ylabel('PSD (dB)');
title('Input PSD Before Adaptive Decimation');
xlim([-Fs/2 Fs/2]/1e6);

%% ------------------------------------------------------------
% 9. PSD after decimation for longest contiguous run of each mode
% ------------------------------------------------------------
% Since the adaptive output is variable-rate, we analyze each mode using
% its longest contiguous output run.

alias_leakage_dB = NaN(size(modes));
run_lengths = zeros(size(modes));

figure;
hold on; grid on;

for ii = 1:length(modes)

    M = modes(ii);

    [idx_run, run_len] = longest_contiguous_output_run(out_M, out_input_index, M);

    run_lengths(ii) = run_len;

    if run_len < 512
        fprintf('M = %d | insufficient contiguous output run for PSD\n', M);
        continue;
    end

    y_run = y_adaptive(idx_run);

    Fs_out = Fs / M;

    % PSD of decimated output segment
    local_win_len = min(4096, 2^floor(log2(length(y_run))));
    local_win_len = max(local_win_len, 256);

    local_noverlap = floor(local_win_len/2);
    local_nfft = max(2048, 2^nextpow2(local_win_len));

    local_win = hann(local_win_len, 'periodic');

    [Pyy, f_out] = pwelch(y_run, local_win, local_noverlap, ...
                          local_nfft, Fs_out, ...
                          'centered', 'power');

    plot(f_out/1e6, 10*log10(Pyy + eps), 'LineWidth', 1.1);

    % Alias/leakage metric:
    % in-band region is the safe useful region:
    %   |f| <= 0.8 * Fs/(2M)
    %
    % leakage region:
    %   0.8 * Fs/(2M) < |f| <= Fs/(2M)

    B_safe = 0.8 * Fs/(2*M);

    inband = abs(f_out) <= B_safe;
    leakage_band = abs(f_out) > B_safe;

    P_inband = sum(Pyy(inband));
    P_leak = sum(Pyy(leakage_band));

    alias_leakage_dB(ii) = 10*log10((P_leak + eps) / (P_inband + eps));

    fprintf('M = %d | longest run = %d output samples | leakage ratio = %.2f dB\n', ...
        M, run_len, alias_leakage_dB(ii));
end

xlabel('Output baseband frequency (MHz)');
ylabel('PSD (dB)');
title('Output PSD for Longest Contiguous Run of Each Mode');
legend("M=" + string(modes), 'Location', 'best');

figure;
bar(modes, alias_leakage_dB);
grid on;
xlabel('Decimation factor M');
ylabel('Leakage / in-band power (dB)');
title('Per-Mode Alias/Leakage Energy Ratio');

%% ------------------------------------------------------------
% 10. Rate-reduction vs fidelity summary table
% ------------------------------------------------------------

summary_table = table( ...
    modes(:), ...
    input_mode_fraction(:), ...
    output_mode_fraction(:), ...
    NMSE_mode_dB(:), ...
    SNR_mode_dB(:), ...
    alias_leakage_dB(:), ...
    run_lengths(:), ...
    'VariableNames', { ...
        'M', ...
        'InputTimeFraction', ...
        'OutputSampleFraction', ...
        'NMSE_dB', ...
        'SNR_dB', ...
        'AliasLeakage_dB', ...
        'LongestRunSamples' ...
    });

disp(' ');
disp('Summary table:');
disp(summary_table);

%% ------------------------------------------------------------
% 11. Optional: rough rate-matched reconstruction check
% ------------------------------------------------------------
% This is not the main fidelity metric because the adaptive output is
% variable-rate. It is only a rough visualization of whether the output
% follows the original waveform envelope after interpolation.

fprintf('\nComputing rough rate-matched reconstruction for visualization...\n');

x_recon_real = interp1(out_time, real(y_adaptive), t_input, 'linear', 'extrap');
x_recon_imag = interp1(out_time, imag(y_adaptive), t_input, 'linear', 'extrap');

x_recon = x_recon_real + 1j*x_recon_imag;

rough_err = x_scaled - x_recon;

rough_NMSE = sum(abs(rough_err).^2) / sum(abs(x_scaled).^2);
rough_NMSE_dB = 10*log10(rough_NMSE + eps);

fprintf('Rough interpolated reconstruction NMSE = %.2f dB\n', rough_NMSE_dB);

figure;
Ns_plot = min(3000, num_input_samples);

plot(t_input(1:Ns_plot)*1e6, real(x_scaled(1:Ns_plot)), 'LineWidth', 1.0); hold on;
plot(t_input(1:Ns_plot)*1e6, real(x_recon(1:Ns_plot)), '--', 'LineWidth', 1.0);
grid on;
xlabel('Time (us)');
ylabel('Real amplitude');
title('Rough Rate-Matched Reconstruction');
legend('Original scaled input', 'Interpolated adaptive output');

%% ------------------------------------------------------------
% 12. Save results
% ------------------------------------------------------------

save('step6_evaluation_results.mat', ...
    'output_rate_fraction', 'data_rate_reduction', ...
    'input_mode_fraction', 'output_mode_fraction', ...
    'num_switches', 'switch_indices', ...
    'NMSE', 'NMSE_dB', 'SNR_out_dB', ...
    'NMSE_mode', 'NMSE_mode_dB', 'SNR_mode_dB', ...
    'alias_leakage_dB', 'run_lengths', ...
    'summary_table', ...
    'rough_NMSE', 'rough_NMSE_dB', ...
    'modes', 'Fs');

fprintf('\nSaved evaluation results:\n');
fprintf('step6_evaluation_results.mat\n');

fprintf('\nStep 6 evaluation complete.\n');

%% ============================================================
% Local function: longest contiguous output run
% ============================================================

function [idx_run, run_len] = longest_contiguous_output_run(out_M, out_input_index, M)
% Finds the longest contiguous output run for a given decimation mode.
%
% A run is considered contiguous if:
%   out_M == M
% and consecutive output samples are separated by M input samples.

    candidate = find(out_M == M);

    if isempty(candidate)
        idx_run = [];
        run_len = 0;
        return;
    end

    best_start = candidate(1);
    best_len = 1;

    current_start = candidate(1);
    current_len = 1;

    for i = 2:length(candidate)

        prev_idx = candidate(i-1);
        curr_idx = candidate(i);

        same_spacing = ...
            (out_input_index(curr_idx) - out_input_index(prev_idx)) == M;

        consecutive_output_indices = ...
            (curr_idx - prev_idx) == 1;

        if same_spacing && consecutive_output_indices
            current_len = current_len + 1;
        else
            if current_len > best_len
                best_len = current_len;
                best_start = current_start;
            end

            current_start = curr_idx;
            current_len = 1;
        end
    end

    if current_len > best_len
        best_len = current_len;
        best_start = current_start;
    end

    idx_run = best_start:(best_start + best_len - 1);
    run_len = best_len;
end