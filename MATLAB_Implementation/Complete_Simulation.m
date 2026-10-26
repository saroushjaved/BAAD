%% ============================================================
% Single Experiment:
% Real-Time Bandwidth-Aware Adaptive Decimation
% for Embedded Signal Acquisition on Zynq SoC
%
% Complete MATLAB model:
%   1. Generate 4-bandwidth test signal
%   2. Quantize input to Q1.15
%   3. Estimate PSD block-by-block
%   4. Estimate occupied edge-bin index
%   5. Select decimation factor M = 1/2/4/8
%   6. Filter + downsample using adaptive decimator bank
%   7. Evaluate rate reduction, SNR, leakage, mode usage
%
% ============================================================

clear; close all; clc;

%% ============================================================
% 0. Experiment configuration
% ============================================================

resultsDir = 'single_experiment_results';
if ~exist(resultsDir, 'dir')
    mkdir(resultsDir);
end

% Sampling and frequency interpretation
Fs = 62e6;                    % 62 MSps
Ts = 1/Fs;

% Current Vivado DDC target:
% real 0-20 MHz IF mixed at 10 MHz -> complex baseband -10 to +10 MHz.
B_ddc_max = 10e6;
fc = 1550e6;                  % RF center label for plots only
fRF_min = fc - B_ddc_max;
fRF_max = fc + B_ddc_max;

% Test signal bandwidth states
B_states = [2.5 5.0 7.5 10.0] * 1e6;     % one-sided complex-baseband bandwidths
expected_M = [8 4 2 2];                   % M=1 remains a fallback outside this target

state_names = ["Very narrowband", ...
               "Narrowband", ...
               "Medium bandwidth", ...
               "Full DDC bandwidth"];

segment_duration = 1e-3;      % 1 ms per state
Nseg = round(segment_duration * Fs);
num_states = length(B_states);
Ntotal = Nseg * num_states;

% Input noise
SNR_dB = 35;

% Fixed-point input format
WL = 16;
FL = 15;
Q_SCALE = 2^FL;
target_peak = 0.75;

% PSD parameters
Nwin = 8192;
Nfft = 8192;
hop = Nwin/2;
df = Fs/Nfft;

% Occupied bandwidth estimator
rho = 0.99;                   % 99% occupied-power bandwidth
B_max_allowed = B_ddc_max;    % ignore bins outside current DDC passband

% Controller parameters
safety_factor = 0.8;
hyst_bins = 40;
min_dwell_blocks = 2;
causal_control = true;

% FIR filter settings
Ntaps_M2 = 129;               % improved from 65
Ntaps_M4 = 129;
Ntaps_M8 = 257;

fprintf('============================================================\n');
fprintf('Single adaptive decimation experiment\n');
fprintf('============================================================\n');
fprintf('Fs = %.2f MSps\n', Fs/1e6);
fprintf('RF label range = %.1f to %.1f MHz\n', fRF_min/1e6, fRF_max/1e6);
fprintf('Center frequency label = %.1f MHz\n', fc/1e6);
fprintf('DDC complex baseband span = %.1f to %.1f MHz\n', ...
    -B_ddc_max/1e6, B_ddc_max/1e6);
fprintf('Total samples = %d\n', Ntotal);
fprintf('Total duration = %.3f ms\n', 1e3*Ntotal/Fs);

%% ============================================================
% 1. Generate bandwidth-variable complex baseband signal
% ============================================================

fprintf('\n[1] Generating bandwidth-variable test signal...\n');

x = complex(zeros(Ntotal,1));
true_B = zeros(Ntotal,1);
true_M = zeros(Ntotal,1);

rng(1);

for s = 1:num_states
    idx_start = (s-1)*Nseg + 1;
    idx_end = s*Nseg;
    idx = idx_start:idx_end;

    B = B_states(s);

    x_seg = generate_bandlimited_complex_noise(Nseg, Fs, B);
    x_seg = x_seg / sqrt(mean(abs(x_seg).^2));

    x(idx) = x_seg;
    true_B(idx) = B;
    true_M(idx) = expected_M(s);

    fprintf('State %d: %-18s | B = %.2f MHz | expected M = %d\n', ...
        s, state_names(s), B/1e6, expected_M(s));
end

% Add AWGN
signal_power = mean(abs(x).^2);
noise_power = signal_power / (10^(SNR_dB/10));

noise = sqrt(noise_power/2) * ...
    (randn(size(x)) + 1j*randn(size(x)));

x_noisy = x + noise;

%% ============================================================
% 2. Q1.15 input quantization
% ============================================================

fprintf('\n[2] Quantizing input to Q1.15...\n');

max_IQ_peak = max([abs(real(x_noisy)); abs(imag(x_noisy))]);
x_scaled = x_noisy * (target_peak / max_IQ_peak);

I_int = quantize_to_int16(real(x_scaled), Q_SCALE);
Q_int = quantize_to_int16(imag(x_scaled), Q_SCALE);

x_fixed = double(I_int)/Q_SCALE + 1j*double(Q_int)/Q_SCALE;

q_error = x_scaled - x_fixed;
input_quant_snr_dB = 10*log10(sum(abs(x_scaled).^2) / sum(abs(q_error).^2));

fprintf('Scaled max I/Q peak = %.4f\n', ...
    max([abs(real(x_scaled)); abs(imag(x_scaled))]));
fprintf('Input quantization SNR = %.2f dB\n', input_quant_snr_dB);

%% ============================================================
% 3. PSD estimation from Q1.15 input
% ============================================================

fprintf('\n[3] Estimating PSD blocks...\n');

num_blocks = floor((Ntotal - Nwin)/hop) + 1;

fBB = (-Nfft/2:Nfft/2-1).' * df;
fRF = fc + fBB;

n = (0:Nwin-1).';
win_float = 0.5 - 0.5*cos(2*pi*n/(Nwin-1));
win_q15 = int16(round(win_float * 32767));
win_q = double(win_q15)/2^15;
U = sum(win_q.^2);

PSD_blocks = zeros(Nfft, num_blocks);
time_blocks = zeros(1, num_blocks);
true_B_blocks = zeros(1, num_blocks);
true_M_blocks = zeros(1, num_blocks);

for b = 1:num_blocks
    idx_start = (b-1)*hop + 1;
    idx_end = idx_start + Nwin - 1;
    idx = idx_start:idx_end;

    I_blk = I_int(idx);
    Q_blk = Q_int(idx);

    I_win_int = q15_multiply(I_blk, win_q15);
    Q_win_int = q15_multiply(Q_blk, win_q15);

    x_win = double(I_win_int)/2^15 + 1j*double(Q_win_int)/2^15;

    X = fftshift(fft(x_win, Nfft));
    Pxx = (abs(X).^2) / (Fs * U);

    PSD_blocks(:, b) = Pxx;

    time_blocks(b) = ((idx_start + idx_end)/2 - 1) / Fs;
    true_B_blocks(b) = median(true_B(idx));
    true_M_blocks(b) = mode(true_M(idx));
end

fprintf('PSD blocks = %d\n', num_blocks);
fprintf('Frequency resolution = %.2f kHz\n', df/1e3);

%% ============================================================
% 4. Occupied edge-bin estimation
% ============================================================

fprintf('\n[4] Estimating occupied edge-bin index...\n');

bin_axis = (-Nfft/2:Nfft/2-1).';
bin_radius = abs(bin_axis);

[bin_radius_sorted, sort_idx] = sort(bin_radius, 'ascend');

noise_bins = bin_radius > floor(0.45*Nfft);
Bmax_bin = floor(B_max_allowed / df);

k_edge_blocks = zeros(1, num_blocks);
B_est_blocks = zeros(1, num_blocks);

for b = 1:num_blocks
    Pxx = PSD_blocks(:, b);
    Pbin = Pxx * df;

    noise_floor = median(Pbin(noise_bins));

    Psig = Pbin - noise_floor;
    Psig(Psig < 0) = 0;

    Psig(bin_radius > Bmax_bin) = 0;

    Psig_sorted = Psig(sort_idx);
    cumulative_power = cumsum(Psig_sorted);
    total_power = cumulative_power(end);

    if total_power <= eps
        k_edge = 0;
    else
        target_power = rho * total_power;
        edge_pos = find(cumulative_power >= target_power, 1, 'first');
        k_edge = bin_radius_sorted(edge_pos);
    end

    k_edge_blocks(b) = k_edge;
    B_est_blocks(b) = k_edge * df;
end

B_error = B_est_blocks - true_B_blocks;

fprintf('Mean absolute bandwidth error = %.3f MHz\n', mean(abs(B_error))/1e6);
fprintf('Max absolute bandwidth error  = %.3f MHz\n', max(abs(B_error))/1e6);

%% ============================================================
% 5. Decimation decision controller
% ============================================================

fprintf('\n[5] Running decimation decision controller...\n');

k_thr_M8 = floor(safety_factor * Nfft / (2*8));
k_thr_M4 = floor(safety_factor * Nfft / (2*4));
k_thr_M2 = floor(safety_factor * Nfft / (2*2));

fprintf('Thresholds:\n');
fprintf('M=8 if k_edge <= %d\n', k_thr_M8);
fprintf('M=4 if k_edge <= %d\n', k_thr_M4);
fprintf('M=2 if k_edge <= %d\n', k_thr_M2);
fprintf('M=1 otherwise (fallback outside current +/-10 MHz target)\n');

up_M8_to_M4 = k_thr_M8 + hyst_bins;
up_M4_to_M2 = k_thr_M4 + hyst_bins;
up_M2_to_M1 = k_thr_M2 + hyst_bins;

down_M4_to_M8 = k_thr_M8 - hyst_bins;
down_M2_to_M4 = k_thr_M4 - hyst_bins;
down_M1_to_M2 = k_thr_M2 - hyst_bins;

M_selected_blocks = zeros(1, num_blocks);
M_ideal_blocks = zeros(1, num_blocks);

mode_state = 1;        % conservative start
dwell_counter = 0;
switch_events = zeros(1, num_blocks);

for b = 1:num_blocks
    k = k_edge_blocks(b);

    previous_mode = mode_state;
    dwell_counter = dwell_counter + 1;
    switch_allowed = dwell_counter >= min_dwell_blocks;

    if mode_state == 8
        if k > up_M8_to_M4
            mode_state = 4;
        end

    elseif mode_state == 4
        if k > up_M4_to_M2
            mode_state = 2;
        elseif switch_allowed && k < down_M4_to_M8
            mode_state = 8;
        end

    elseif mode_state == 2
        if k > up_M2_to_M1
            mode_state = 1;
        elseif switch_allowed && k < down_M2_to_M4
            mode_state = 4;
        end

    elseif mode_state == 1
        if switch_allowed && k < down_M1_to_M2
            mode_state = 2;
        end
    end

    if mode_state ~= previous_mode
        dwell_counter = 0;
        switch_events(b) = 1;
    end

    M_selected_blocks(b) = mode_state;

    % Ideal no-hysteresis decision
    if k <= k_thr_M8
        M_ideal_blocks(b) = 8;
    elseif k <= k_thr_M4
        M_ideal_blocks(b) = 4;
    elseif k <= k_thr_M2
        M_ideal_blocks(b) = 2;
    else
        M_ideal_blocks(b) = 1;
    end
end

fprintf('Controller switches = %d\n', sum(switch_events));
fprintf('Controller accuracy = %.2f %%\n', ...
    100*mean(M_selected_blocks == true_M_blocks));

%% ============================================================
% 6. Build per-sample M schedule
% ============================================================

fprintf('\n[6] Building per-sample decimation schedule...\n');

M_per_sample = ones(Ntotal, 1);

for b = 1:num_blocks
    if causal_control
        idx_psd_end = (b-1)*hop + Nwin;
        interval_start = idx_psd_end + 1;
        interval_end = idx_psd_end + hop;
    else
        interval_start = (b-1)*hop + 1;
        interval_end = interval_start + hop - 1;
    end

    if interval_start > Ntotal
        continue;
    end

    interval_end = min(interval_end, Ntotal);
    M_per_sample(interval_start:interval_end) = M_selected_blocks(b);
end

%% ============================================================
% 7. Design Q1.15 anti-aliasing filters
% ============================================================

fprintf('\n[7] Designing anti-aliasing FIR filters...\n');

h_float = cell(9,1);
h_q15 = cell(9,1);

h_float{1} = 1;
h_q15{1} = int16(32767);

Fc_M2 = 0.9 * (1/(2*2));
Fc_M4 = 0.9 * (1/(2*4));
Fc_M8 = 0.9 * (1/(2*8));

[h_float{2}, h_q15{2}] = design_lowpass_fir_q15(Ntaps_M2, Fc_M2);
[h_float{4}, h_q15{4}] = design_lowpass_fir_q15(Ntaps_M4, Fc_M4);
[h_float{8}, h_q15{8}] = design_lowpass_fir_q15(Ntaps_M8, Fc_M8);

fprintf('M=2: taps=%d, cutoff=%.2f MHz\n', Ntaps_M2, Fc_M2*Fs/1e6);
fprintf('M=4: taps=%d, cutoff=%.2f MHz\n', Ntaps_M4, Fc_M4*Fs/1e6);
fprintf('M=8: taps=%d, cutoff=%.2f MHz\n', Ntaps_M8, Fc_M8*Fs/1e6);

%% ============================================================
% 8. Run continuous fixed-point filter bank
% ============================================================

fprintf('\n[8] Running continuous fixed-point filter bank...\n');

I_filt = cell(9,1);
Q_filt = cell(9,1);

I_filt{1} = I_int;
Q_filt{1} = Q_int;

for M = [2 4 8]
    fprintf('Filtering M=%d path...\n', M);
    [I_filt{M}, Q_filt{M}] = q15_complex_fir_fullstream(I_int, Q_int, h_q15{M});
end

%% ============================================================
% 9. Adaptive downsampling
% ============================================================

fprintf('\n[9] Performing adaptive downsampling...\n');

out_I = zeros(Ntotal,1,'int16');
out_Q = zeros(Ntotal,1,'int16');
out_M = zeros(Ntotal,1);
out_input_index = zeros(Ntotal,1);

out_count = 0;

for nSamp = 1:Ntotal
    M = M_per_sample(nSamp);

    if mod(nSamp-1, M) == 0
        out_count = out_count + 1;

        out_I(out_count) = I_filt{M}(nSamp);
        out_Q(out_count) = Q_filt{M}(nSamp);
        out_M(out_count) = M;
        out_input_index(out_count) = nSamp;
    end
end

out_I = out_I(1:out_count);
out_Q = out_Q(1:out_count);
out_M = out_M(1:out_count);
out_input_index = out_input_index(1:out_count);

out_time = (double(out_input_index)-1)/Fs;
y_adaptive = double(out_I)/2^15 + 1j*double(out_Q)/2^15;

fprintf('Adaptive output samples = %d\n', out_count);

%% ============================================================
% 10. Evaluation
% ============================================================

fprintf('\n[10] Evaluating adaptive decimator...\n');

input_count = Ntotal;
output_count = out_count;

output_rate_fraction = output_count / input_count;
data_rate_reduction = 1 - output_rate_fraction;

fprintf('\nData-rate reduction:\n');
fprintf('Output/input sample fraction = %.5f\n', output_rate_fraction);
fprintf('Data-rate reduction = %.2f %%\n', 100*data_rate_reduction);

modes = [1 2 4 8];

input_mode_fraction = zeros(size(modes));
output_mode_fraction = zeros(size(modes));

fprintf('\nMode usage:\n');
for ii = 1:length(modes)
    M = modes(ii);
    input_mode_fraction(ii) = mean(M_per_sample == M);
    output_mode_fraction(ii) = mean(out_M == M);

    fprintf('M=%d | input-time usage = %.2f %% | output-sample usage = %.2f %%\n', ...
        M, 100*input_mode_fraction(ii), 100*output_mode_fraction(ii));
end

% Switching behavior
mode_changes = [0; diff(M_per_sample) ~= 0];
switch_indices = find(mode_changes);
num_switches = length(switch_indices);

if num_switches > 1
    mean_time_between_switches = mean(diff(switch_indices))/Fs;
else
    mean_time_between_switches = NaN;
end

fprintf('\nSwitching:\n');
fprintf('Number of switches = %d\n', num_switches);
fprintf('Mean time between switches = %.3f us\n', mean_time_between_switches*1e6);

% Floating-point reference with same modes/sample locations
fprintf('\nBuilding floating-point mode-matched reference...\n');

x_ref_filt = cell(9,1);
x_ref_filt{1} = x_scaled;

for M = [2 4 8]
    x_ref_filt{M} = filter(h_float{M}, 1, x_scaled);
end

y_ref = zeros(output_count,1);

for nOut = 1:output_count
    M = out_M(nOut);
    idx = out_input_index(nOut);
    y_ref(nOut) = x_ref_filt{M}(idx);
end

err = y_ref - y_adaptive;

NMSE = sum(abs(err).^2) / sum(abs(y_ref).^2);
NMSE_dB = 10*log10(NMSE + eps);
SNR_out_dB = 10*log10(sum(abs(y_ref).^2) / sum(abs(err).^2));

fprintf('\nFixed-point output quality:\n');
fprintf('NMSE = %.6e\n', NMSE);
fprintf('NMSE = %.2f dB\n', NMSE_dB);
fprintf('SNR  = %.2f dB\n', SNR_out_dB);

% Per-mode distortion
NMSE_mode_dB = NaN(size(modes));
SNR_mode_dB = NaN(size(modes));

fprintf('\nPer-mode output quality:\n');
for ii = 1:length(modes)
    M = modes(ii);
    idx = out_M == M;

    if sum(idx) < 10
        fprintf('M=%d | insufficient samples\n', M);
        continue;
    end

    eM = y_ref(idx) - y_adaptive(idx);
    rM = y_ref(idx);

    NMSE_M = sum(abs(eM).^2) / sum(abs(rM).^2);
    NMSE_mode_dB(ii) = 10*log10(NMSE_M + eps);
    SNR_mode_dB(ii) = 10*log10(sum(abs(rM).^2) / sum(abs(eM).^2));

    fprintf('M=%d | NMSE = %.2f dB | SNR = %.2f dB\n', ...
        M, NMSE_mode_dB(ii), SNR_mode_dB(ii));
end

% Alias/leakage per mode
alias_leakage_dB = NaN(size(modes));
run_lengths = zeros(size(modes));

fprintf('\nAlias/leakage evaluation:\n');

for ii = 1:length(modes)
    M = modes(ii);

    [idx_run, run_len] = longest_contiguous_output_run(out_M, out_input_index, M);
    run_lengths(ii) = run_len;

    if run_len < 512
        fprintf('M=%d | insufficient contiguous run\n', M);
        continue;
    end

    y_run = y_adaptive(idx_run);
    Fs_out = Fs/M;

    local_win_len = min(4096, 2^floor(log2(length(y_run))));
    local_win_len = max(local_win_len, 256);
    local_nfft = max(2048, 2^nextpow2(local_win_len));
    local_overlap = floor(local_win_len/2);

    [Pyy, f_out] = local_welch_psd(y_run, Fs_out, local_win_len, local_overlap, local_nfft);

    B_safe = safety_factor * Fs/(2*M);

    inband = abs(f_out) <= B_safe;
    leakage_band = abs(f_out) > B_safe;

    P_inband = sum(Pyy(inband));
    P_leak = sum(Pyy(leakage_band));

    alias_leakage_dB(ii) = 10*log10((P_leak + eps)/(P_inband + eps));

    fprintf('M=%d | longest run=%d samples | leakage=%.2f dB\n', ...
        M, run_len, alias_leakage_dB(ii));
end

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

%% ============================================================
% 11. Plots
% ============================================================

fprintf('\n[11] Generating plots...\n');

t_input = (0:Ntotal-1).'/Fs;

% True vs estimated bandwidth
figure;
stairs(time_blocks*1e3, true_B_blocks/1e6, 'LineWidth', 1.8); hold on;
plot(time_blocks*1e3, B_est_blocks/1e6, 'o-', 'LineWidth', 1.1);
grid on;
xlabel('Time (ms)');
ylabel('One-sided bandwidth (MHz)');
title('True vs PSD-Estimated Occupied Bandwidth');
legend('True bandwidth', 'Estimated bandwidth', 'Location', 'best');
saveas(gcf, fullfile(resultsDir, 'true_vs_estimated_bandwidth.png'));

% Edge-bin and thresholds
figure;
stairs(time_blocks*1e3, k_edge_blocks, 'LineWidth', 1.5); hold on;
yline(k_thr_M8, '--', 'M=8 threshold');
yline(k_thr_M4, '--', 'M=4 threshold');
yline(k_thr_M2, '--', 'M=2 threshold');
grid on;
xlabel('Time (ms)');
ylabel('Occupied edge-bin index');
title('Occupied Edge-Bin Index and Mode Thresholds');
saveas(gcf, fullfile(resultsDir, 'edge_bin_thresholds.png'));

% Mode decision
figure;
stairs(time_blocks*1e3, true_M_blocks, 'LineWidth', 1.8); hold on;
stairs(time_blocks*1e3, M_ideal_blocks, '--', 'LineWidth', 1.3);
stairs(time_blocks*1e3, M_selected_blocks, 'LineWidth', 1.3);
grid on;
xlabel('Time (ms)');
ylabel('Decimation factor M');
title('Decimation Mode Decision');
legend('Expected M', 'No-hysteresis decision', 'Hysteresis controller', ...
       'Location', 'best');
yticks([1 2 4 8]);
saveas(gcf, fullfile(resultsDir, 'mode_decision.png'));

% Per-sample M
figure;
stairs(t_input*1e3, M_per_sample, 'LineWidth', 1.1);
grid on;
xlabel('Time (ms)');
ylabel('Selected M');
title('Per-Sample Decimation Schedule');
yticks([1 2 4 8]);
saveas(gcf, fullfile(resultsDir, 'per_sample_decimation_schedule.png'));

% Mode usage
figure;
bar(modes, 100*input_mode_fraction);
grid on;
xlabel('Decimation factor M');
ylabel('Input-time usage (%)');
title('Input-Time Mode Usage');
xticks(modes);
saveas(gcf, fullfile(resultsDir, 'mode_usage.png'));

% Filter responses
Nresp = 16384;
f_resp = (-Nresp/2:Nresp/2-1).' * Fs/Nresp;

figure;
hold on; grid on;
for M = [2 4 8]
    H = fftshift(fft(double(h_q15{M})/2^15, Nresp));
    plot(f_resp/1e6, 20*log10(abs(H)+eps), 'LineWidth', 1.1);
end
xlabel('Baseband frequency (MHz)');
ylabel('Magnitude response (dB)');
title('Q1.15 Anti-Alias FIR Responses');
legend('M=2', 'M=4', 'M=8', 'Location', 'best');
xlim([-31 31]);
ylim([-100 5]);
saveas(gcf, fullfile(resultsDir, 'fir_responses.png'));

% PSD heatmap
figure;
imagesc(time_blocks*1e3, fRF/1e6, 10*log10(PSD_blocks + eps));
axis xy;
colorbar;
xlabel('Time (ms)');
ylabel('Frequency label (MHz)');
title('Block-wise PSD');
ylim([fRF_min fRF_max]/1e6);
saveas(gcf, fullfile(resultsDir, 'psd_heatmap.png'));

% Per-mode SNR
figure;
bar(modes, SNR_mode_dB);
grid on;
xlabel('Decimation factor M');
ylabel('SNR vs floating reference (dB)');
title('Per-Mode Fixed-Point Output SNR');
xticks(modes);
saveas(gcf, fullfile(resultsDir, 'per_mode_snr.png'));

% Alias leakage
figure;
bar(modes, alias_leakage_dB);
grid on;
xlabel('Decimation factor M');
ylabel('Leakage / in-band power (dB)');
title('Per-Mode Alias/Leakage Ratio');
xticks(modes);
saveas(gcf, fullfile(resultsDir, 'alias_leakage.png'));

%% ============================================================
% 12. Export outputs
% ============================================================

fprintf('\n[12] Saving experiment outputs...\n');

% Pack input and output samples
I_u16 = uint16(mod(int32(I_int), 2^16));
Q_u16 = uint16(mod(int32(Q_int), 2^16));
IQ_u32 = bitor(bitshift(uint32(I_u16), 16), uint32(Q_u16));

out_I_u16 = uint16(mod(int32(out_I), 2^16));
out_Q_u16 = uint16(mod(int32(out_Q), 2^16));
out_IQ_u32 = bitor(bitshift(uint32(out_I_u16), 16), uint32(out_Q_u16));

save(fullfile(resultsDir, 'single_experiment_output.mat'), ...
    'Fs', 'fc', 'fRF_min', 'fRF_max', 'B_ddc_max', ...
    'B_states', 'expected_M', 'state_names', ...
    'x_scaled', 'x_fixed', 'I_int', 'Q_int', 'IQ_u32', ...
    'true_B', 'true_M', ...
    'Nwin', 'Nfft', 'hop', 'df', ...
    'PSD_blocks', 'fBB', 'fRF', 'time_blocks', ...
    'B_est_blocks', 'k_edge_blocks', 'true_B_blocks', 'true_M_blocks', ...
    'M_selected_blocks', 'M_ideal_blocks', 'M_per_sample', ...
    'h_float', 'h_q15', ...
    'out_I', 'out_Q', 'out_IQ_u32', 'out_M', ...
    'out_input_index', 'out_time', 'y_adaptive', ...
    'summary_table', ...
    'output_rate_fraction', 'data_rate_reduction', ...
    'input_mode_fraction', 'output_mode_fraction', ...
    'NMSE', 'NMSE_dB', 'SNR_out_dB', ...
    'NMSE_mode_dB', 'SNR_mode_dB', 'alias_leakage_dB', ...
    'input_quant_snr_dB', ...
    'k_thr_M8', 'k_thr_M4', 'k_thr_M2', ...
    'hyst_bins', 'min_dwell_blocks', 'safety_factor');

writetable(summary_table, fullfile(resultsDir, 'summary_table.csv'));

writematrix([double(out_I), double(out_Q), double(out_M), double(out_input_index)], ...
    fullfile(resultsDir, 'adaptive_output_IQ_int16_with_metadata.csv'));

fid = fopen(fullfile(resultsDir, 'adaptive_output_IQ_packed_hex.txt'), 'w');
for nOut = 1:length(out_IQ_u32)
    fprintf(fid, '%08X\n', out_IQ_u32(nOut));
end
fclose(fid);

export_coefficients_q15(fullfile(resultsDir, 'fir_coeff_M2_q15.txt'), h_q15{2});
export_coefficients_q15(fullfile(resultsDir, 'fir_coeff_M4_q15.txt'), h_q15{4});
export_coefficients_q15(fullfile(resultsDir, 'fir_coeff_M8_q15.txt'), h_q15{8});

fprintf('\n============================================================\n');
fprintf('Experiment complete.\n');
fprintf('Results saved in folder: %s\n', resultsDir);
fprintf('Data-rate reduction = %.2f %%\n', 100*data_rate_reduction);
fprintf('Overall fixed-point SNR = %.2f dB\n', SNR_out_dB);
fprintf('============================================================\n');

%% ============================================================
% Local functions
% ============================================================

function x = generate_bandlimited_complex_noise(N, Fs, B)

    f = (-N/2:N/2-1).' * (Fs/N);

    mask = abs(f) <= B;

    X = zeros(N,1);
    X(mask) = randn(sum(mask),1) + 1j*randn(sum(mask),1);

    transition_width = 0.05 * B;
    edge_region = abs(abs(f) - B) <= transition_width;

    taper = ones(N,1);

    if transition_width > 0
        taper(edge_region) = 0.5 * ...
            (1 + cos(pi * (abs(f(edge_region)) - B + transition_width) ...
            / transition_width));
    end

    X = X .* taper;

    x = ifft(ifftshift(X));
    x = x / sqrt(mean(abs(x).^2));
end

function x_int16 = quantize_to_int16(x, scale)

    x_scaled_int = round(x * scale);

    x_scaled_int(x_scaled_int > 32767) = 32767;
    x_scaled_int(x_scaled_int < -32768) = -32768;

    x_int16 = int16(x_scaled_int);
end

function y = q15_multiply(a, b)

    product_q30 = int64(a) .* int64(b);
    product_q30 = product_q30 + int64(2^14);

    y_temp = floor(double(product_q30) / 2^15);

    y_temp(y_temp > 32767) = 32767;
    y_temp(y_temp < -32768) = -32768;

    y = int16(y_temp);
end

function [h, h_q15] = design_lowpass_fir_q15(Ntaps, Fc)

    if mod(Ntaps, 2) == 0
        error('Ntaps should be odd.');
    end

    n = (0:Ntaps-1).';
    alpha = (Ntaps-1)/2;
    m = n - alpha;

    x = 2*Fc*m;

    sinc_x = ones(size(x));
    nonzero = abs(x) > 1e-12;
    sinc_x(nonzero) = sin(pi*x(nonzero)) ./ (pi*x(nonzero));

    h_ideal = 2*Fc*sinc_x;

    w = 0.54 - 0.46*cos(2*pi*n/(Ntaps-1));

    h = h_ideal .* w;
    h = h / sum(h);

    h_q = round(h * 2^15);
    h_q(h_q > 32767) = 32767;
    h_q(h_q < -32768) = -32768;

    h_q15 = int16(h_q);
end

function [I_out, Q_out] = q15_complex_fir_fullstream(I_in, Q_in, h_q15)

    I_in_d = double(I_in);
    Q_in_d = double(Q_in);
    h_d = double(h_q15(:));

    I_acc_q30 = filter(h_d, 1, I_in_d);
    Q_acc_q30 = filter(h_d, 1, Q_in_d);

    I_temp = round(I_acc_q30 / 2^15);
    Q_temp = round(Q_acc_q30 / 2^15);

    I_temp(I_temp > 32767) = 32767;
    I_temp(I_temp < -32768) = -32768;

    Q_temp(Q_temp > 32767) = 32767;
    Q_temp(Q_temp < -32768) = -32768;

    I_out = int16(I_temp);
    Q_out = int16(Q_temp);
end

function [idx_run, run_len] = longest_contiguous_output_run(out_M, out_input_index, M)

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

function [Pxx, f] = local_welch_psd(x, Fs, win_len, overlap, nfft)

    x = x(:);

    step = win_len - overlap;
    num_segments = floor((length(x) - win_len)/step) + 1;

    if num_segments < 1
        error('Signal too short for requested Welch parameters.');
    end

    n = (0:win_len-1).';
    win = 0.5 - 0.5*cos(2*pi*n/(win_len-1));
    U = sum(win.^2);

    Pacc = zeros(nfft,1);

    for s = 1:num_segments
        idx_start = (s-1)*step + 1;
        idx_end = idx_start + win_len - 1;

        xw = x(idx_start:idx_end) .* win;

        X = fftshift(fft(xw, nfft));
        Pseg = abs(X).^2 / (Fs   * U);

        Pacc = Pacc + Pseg;
    end

    Pxx = Pacc / num_segments;
    f = (-nfft/2:nfft/2-1).' * (Fs/nfft);
end

function export_coefficients_q15(filename, coeffs)

    fid = fopen(filename, 'w');

    for i = 1:length(coeffs)
        c = coeffs(i);
        c_u16 = uint16(mod(int32(c), 2^16));
        fprintf(fid, '%6d    // 0x%04X\n', c, c_u16);
    end

    fclose(fid);
end
