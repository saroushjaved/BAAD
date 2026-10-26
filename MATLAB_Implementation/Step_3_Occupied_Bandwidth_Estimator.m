%% ============================================================
% Step 3: Occupied Bandwidth Estimation from PSD
%
% Input:
%   step2_psd_output_fixed_input.mat
%
% Output:
%   Estimated occupied bandwidth per block
%   Estimated edge bin per block
%
% This stage converts:
%
%   PSD_blocks(:, b)
%       -> B_est_blocks(b)
%       -> k_edge_blocks(b)
%
% The edge-bin output is important for FPGA implementation.
% ============================================================

clear; close all; clc;

%% ------------------------------------------------------------
% 1. Load PSD output
% ------------------------------------------------------------

load('step2_psd_output_fixed_input.mat');

if ~exist('B_ddc_max', 'var')
    B_ddc_max = max(B_states);
end

fprintf('Loaded PSD output.\n');
fprintf('Fs = %.2f MSps\n', Fs/1e6);
fprintf('Nfft = %d\n', Nfft);
fprintf('Frequency resolution df = %.2f kHz\n', df/1e3);
fprintf('Number of PSD blocks = %d\n', size(PSD_blocks,2));

num_blocks = size(PSD_blocks, 2);

%% ------------------------------------------------------------
% 2. Occupied-bandwidth estimator parameters
% ------------------------------------------------------------

rho = 0.99;                  % 99 percent occupied power bandwidth

% The useful Vivado DDC band is currently +/-10 MHz. The outer region
% close to +/-Fs/2 is still used for a simple noise-floor estimate.
noise_edge_start = 0.45 * Fs;    % |f| > 0.45 Fs is treated as noise-only

% Safety clamp: ignore bins outside the current DDC passband.
B_max_allowed = B_ddc_max;

fprintf('\nOccupied bandwidth estimator parameters:\n');
fprintf('Occupied power percentage rho = %.2f\n', rho);
fprintf('Noise floor estimated from |f| > %.2f MHz\n', noise_edge_start/1e6);
fprintf('Maximum expected one-sided bandwidth = %.2f MHz\n', B_max_allowed/1e6);

%% ------------------------------------------------------------
% 3. Prepare frequency-bin ordering around DC
% ------------------------------------------------------------

abs_f = abs(fBB);

% Sort bins from DC outward
[abs_f_sorted, sort_idx] = sort(abs_f, 'ascend');

% Noise-estimation bins
noise_bins = abs_f > noise_edge_start;

if sum(noise_bins) < 10
    error('Not enough noise-only bins. Reduce noise_edge_start.');
end

%% ------------------------------------------------------------
% 4. Allocate outputs
% ------------------------------------------------------------

B_est_blocks = zeros(1, num_blocks);        % estimated one-sided bandwidth in Hz
k_edge_blocks = zeros(1, num_blocks);       % edge bin index in fftshifted PSD
edge_freq_blocks = zeros(1, num_blocks);    % same as B_est, for clarity

total_power_blocks = zeros(1, num_blocks);
signal_power_blocks = zeros(1, num_blocks);
noise_floor_blocks = zeros(1, num_blocks);

%% ------------------------------------------------------------
% 5. Estimate occupied bandwidth for each PSD block
% ------------------------------------------------------------

for b = 1:num_blocks

    % Current PSD block, units approximately power/Hz
    Pxx = PSD_blocks(:, b);

    % Convert PSD density to power per FFT bin
    Pbin = Pxx * df;

    % Estimate noise floor from outer bins.
    % This is intentionally simple and FPGA-concept friendly.
    noise_floor_density = median(Pxx(noise_bins));
    noise_floor_power_per_bin = noise_floor_density * df;

    noise_floor_blocks(b) = noise_floor_density;

    % Remove estimated noise contribution
    Psig_bin = Pbin - noise_floor_power_per_bin;
    Psig_bin(Psig_bin < 0) = 0;

    % Optional clamp: ignore anything beyond expected maximum signal range
    Psig_bin(abs_f > B_max_allowed) = 0;

    % Total useful signal power estimate
    total_sig_power = sum(Psig_bin);
    signal_power_blocks(b) = total_sig_power;
    total_power_blocks(b) = sum(Pbin);

    % If signal power is extremely small, default to lowest bandwidth.
    if total_sig_power <= eps
        B_est_blocks(b) = 0;
        k_edge_blocks(b) = find(fBB == 0, 1);
        edge_freq_blocks(b) = 0;
        continue;
    end

    % Sort power from DC outward
    Psig_sorted = Psig_bin(sort_idx);

    % Cumulative power around DC
    cumulative_power = cumsum(Psig_sorted);

    % Find bin where rho percent of signal power is contained
    target_power = rho * total_sig_power;

    edge_sorted_pos = find(cumulative_power >= target_power, 1, 'first');

    % Convert sorted position back to original PSD bin index
    k_edge = sort_idx(edge_sorted_pos);

    % Estimated one-sided occupied bandwidth
    B_est = abs_f(k_edge);

    B_est_blocks(b) = B_est;
    k_edge_blocks(b) = k_edge;
    edge_freq_blocks(b) = B_est;
end

fprintf('\nOccupied bandwidth estimation complete.\n');

%% ------------------------------------------------------------
% 6. Print representative results
% ------------------------------------------------------------

fprintf('\nRepresentative block results:\n');

selected_blocks = round(linspace(1, num_blocks, 8));

for ii = 1:length(selected_blocks)
    b = selected_blocks(ii);

    fprintf('Block %4d | Time = %.3f ms | True B = %.2f MHz | Est B = %.2f MHz | Edge bin = %d\n', ...
        b, time_blocks(b)*1e3, true_B_blocks(b)/1e6, ...
        B_est_blocks(b)/1e6, k_edge_blocks(b));
end

%% ------------------------------------------------------------
% 7. Plot true bandwidth vs estimated bandwidth
% ------------------------------------------------------------

figure;
stairs(time_blocks*1e3, true_B_blocks/1e6, 'LineWidth', 1.8); hold on;
plot(time_blocks*1e3, B_est_blocks/1e6, 'o-', 'LineWidth', 1.2);
grid on;

xlabel('Time (ms)');
ylabel('One-sided bandwidth (MHz)');
title('True vs PSD-Estimated Occupied Bandwidth');
legend('True bandwidth', 'Estimated occupied bandwidth', 'Location', 'best');

%% ------------------------------------------------------------
% 8. Plot estimation error
% ------------------------------------------------------------

B_error = B_est_blocks - true_B_blocks;

figure;
plot(time_blocks*1e3, B_error/1e6, 'LineWidth', 1.4);
grid on;

xlabel('Time (ms)');
ylabel('Bandwidth estimation error (MHz)');
title('Occupied Bandwidth Estimation Error');

fprintf('\nBandwidth estimation error:\n');
fprintf('Mean absolute error = %.3f MHz\n', mean(abs(B_error))/1e6);
fprintf('Max absolute error  = %.3f MHz\n', max(abs(B_error))/1e6);

%% ------------------------------------------------------------
% 9. Visualize one PSD block and estimated bandwidth
% ------------------------------------------------------------

% Pick one block from each segment/state if possible
figure;
hold on; grid on;

unique_B = unique(true_B_blocks);

for s = 1:length(unique_B)

    b = find(true_B_blocks == unique_B(s), 1, 'first');

    Pxx_dB = 10*log10(PSD_blocks(:,b) + eps);

    plot(fBB/1e6, Pxx_dB, 'LineWidth', 1.1);

    % Add estimated bandwidth markers
    xline(B_est_blocks(b)/1e6, '--');
    xline(-B_est_blocks(b)/1e6, '--');
end

xlabel('Baseband frequency (MHz)');
ylabel('PSD (dB/Hz)');
title('PSD Blocks with Estimated Occupied Bandwidth Edges');
legend(state_names, 'Location', 'best');
xlim(1.2 * [-B_ddc_max B_ddc_max]/1e6);

%% ------------------------------------------------------------
% 10. Convert bandwidth thresholds to FPGA-friendly bin thresholds
% ------------------------------------------------------------
% These thresholds correspond to your decimation modes.
%
% Using the same rule as before:
%
%   B_est <= 0.8 * Fs/(2M)
%
% M = 8 threshold: 0.8 * Fs/16
% M = 4 threshold: 0.8 * Fs/8
% M = 2 threshold: 0.8 * Fs/4

M_modes = [8 4 2 1];

B_threshold_M8 = 0.8 * Fs/(2*8);
B_threshold_M4 = 0.8 * Fs/(2*4);
B_threshold_M2 = 0.8 * Fs/(2*2);

B_thresholds = [B_threshold_M8, B_threshold_M4, B_threshold_M2];

% Convert Hz thresholds into nearest frequency-bin thresholds
bin_threshold_M8 = find(abs_f <= B_threshold_M8, 1, 'last');
bin_threshold_M4 = find(abs_f <= B_threshold_M4, 1, 'last');
bin_threshold_M2 = find(abs_f <= B_threshold_M2, 1, 'last');

fprintf('\nDecision thresholds:\n');
fprintf('M = 8 allowed if B_est <= %.2f MHz | bin threshold = %d\n', ...
    B_threshold_M8/1e6, bin_threshold_M8);
fprintf('M = 4 allowed if B_est <= %.2f MHz | bin threshold = %d\n', ...
    B_threshold_M4/1e6, bin_threshold_M4);
fprintf('M = 2 allowed if B_est <= %.2f MHz | bin threshold = %d\n', ...
    B_threshold_M2/1e6, bin_threshold_M2);

%% ------------------------------------------------------------
% 11. Save occupied bandwidth estimator output
% ------------------------------------------------------------

save('step3_occupied_bandwidth_output.mat', ...
    'B_est_blocks', 'k_edge_blocks', 'edge_freq_blocks', ...
    'B_error', ...
    'signal_power_blocks', 'total_power_blocks', 'noise_floor_blocks', ...
    'rho', 'B_max_allowed', 'noise_edge_start', ...
    'B_thresholds', ...
    'B_threshold_M8', 'B_threshold_M4', 'B_threshold_M2', ...
    'bin_threshold_M8', 'bin_threshold_M4', 'bin_threshold_M2', ...
    'time_blocks', 'true_B_blocks', 'true_M_blocks', ...
    'PSD_blocks', 'fBB', 'fRF', ...
    'Fs', 'fc', 'B_ddc_max', 'Nwin', 'Nfft', 'hop', 'df', ...
    'B_states', 'expected_M', 'state_names');

fprintf('\nSaved occupied bandwidth output:\n');
fprintf('step3_occupied_bandwidth_output.mat\n');
