%% ============================================================
% Step 4: Decimation Decision Controller
%
% Input:
%   step3_occupied_bandwidth_output.mat
%
% Output:
%   M_selected_blocks
%
% Controller:
%   edge-bin index -> decimation factor M
%
% Modes:
%   M = 8, 4, 2, 1
%
% Features:
%   - FPGA-friendly integer-bin thresholds
%   - Hysteresis
%   - Minimum dwell time
% ============================================================

clear; close all; clc;

%% ------------------------------------------------------------
% 1. Load occupied-bandwidth output
% ------------------------------------------------------------

load('step3_occupied_bandwidth_output.mat');

if ~exist('B_ddc_max', 'var')
    B_ddc_max = max(true_B_blocks);
end

fprintf('Loaded occupied bandwidth output.\n');
fprintf('Fs = %.2f MSps\n', Fs/1e6);
fprintf('Nfft = %d\n', Nfft);
fprintf('df = %.2f kHz\n', df/1e3);

num_blocks = length(B_est_blocks);

%% ------------------------------------------------------------
% 2. Use radial edge-bin index
% ------------------------------------------------------------
% If your previous file has k_edge_radius_blocks, use it.
% If not, derive it from B_est_blocks.

if exist('k_edge_radius_blocks', 'var')
    k_edge = k_edge_radius_blocks;
else
    k_edge = round(B_est_blocks / df);
end

k_edge = double(k_edge);

%% ------------------------------------------------------------
% 3. Basic FPGA-friendly thresholds
% ------------------------------------------------------------

safety_factor = 0.8;

k_thr_M8 = floor(safety_factor * Nfft / (2*8));
k_thr_M4 = floor(safety_factor * Nfft / (2*4));
k_thr_M2 = floor(safety_factor * Nfft / (2*2));

fprintf('\nNominal threshold bins:\n');
fprintf('M=8 threshold: k <= %d\n', k_thr_M8);
fprintf('M=4 threshold: k <= %d\n', k_thr_M4);
fprintf('M=2 threshold: k <= %d\n', k_thr_M2);
fprintf('M=1 otherwise (fallback outside current +/-10 MHz target)\n');

%% ------------------------------------------------------------
% 4. Hysteresis settings
% ------------------------------------------------------------
% Hysteresis is applied in bins.
%
% Larger value = more stable, slower to return to higher decimation.
% Smaller value = more responsive, more switching.

hyst_bins = 40;

% Thresholds for moving to more conservative mode
% Example: M=8 -> M=4 when edge exceeds k_thr_M8 + hyst
up_M8_to_M4 = k_thr_M8 + hyst_bins;
up_M4_to_M2 = k_thr_M4 + hyst_bins;
up_M2_to_M1 = k_thr_M2 + hyst_bins;

% Thresholds for moving to more aggressive decimation
% Example: M=4 -> M=8 when edge falls below k_thr_M8 - hyst
down_M4_to_M8 = k_thr_M8 - hyst_bins;
down_M2_to_M4 = k_thr_M4 - hyst_bins;
down_M1_to_M2 = k_thr_M2 - hyst_bins;

fprintf('\nHysteresis thresholds:\n');
fprintf('M8 -> M4 if k > %d\n', up_M8_to_M4);
fprintf('M4 -> M8 if k < %d\n', down_M4_to_M8);
fprintf('M4 -> M2 if k > %d\n', up_M4_to_M2);
fprintf('M2 -> M4 if k < %d\n', down_M2_to_M4);
fprintf('M2 -> M1 if k > %d\n', up_M2_to_M1);
fprintf('M1 -> M2 if k < %d\n', down_M1_to_M2);

%% ------------------------------------------------------------
% 5. Minimum dwell time
% ------------------------------------------------------------
% Number of PSD blocks to remain in a mode before allowing
% a non-urgent switch.
%
% Urgent switch means moving to a safer lower decimation factor
% when bandwidth expands.

min_dwell_blocks = 2;

fprintf('\nMinimum dwell time = %d PSD blocks\n', min_dwell_blocks);

%% ------------------------------------------------------------
% 6. Initialize controller
% ------------------------------------------------------------

M_selected_blocks = zeros(1, num_blocks);
mode_state = 1;  % Start conservative: M = 1
dwell_counter = 0;

switch_events = zeros(1, num_blocks);

%% ------------------------------------------------------------
% 7. Controller loop
% ------------------------------------------------------------

for b = 1:num_blocks

    k = k_edge(b);
    previous_mode = mode_state;

    dwell_counter = dwell_counter + 1;

    switch_allowed = dwell_counter >= min_dwell_blocks;

    % ---------------------------------------------------------
    % State machine
    % ---------------------------------------------------------
    % More conservative switching is allowed immediately.
    % More aggressive switching requires dwell time.
    %
    % Conservative means:
    %   M=8 -> M=4 -> M=2 -> M=1
    %
    % Aggressive means:
    %   M=1 -> M=2 -> M=4 -> M=8
    % ---------------------------------------------------------

    if mode_state == 8

        % Urgent/protective switch if bandwidth has expanded
        if k > up_M8_to_M4
            mode_state = 4;
        end

    elseif mode_state == 4

        % Protective switch
        if k > up_M4_to_M2
            mode_state = 2;

        % Aggressive switch only after dwell
        elseif switch_allowed && k < down_M4_to_M8
            mode_state = 8;
        end

    elseif mode_state == 2

        % Protective switch
        if k > up_M2_to_M1
            mode_state = 1;

        % Aggressive switch only after dwell
        elseif switch_allowed && k < down_M2_to_M4
            mode_state = 4;
        end

    elseif mode_state == 1

        % Aggressive switch only after dwell
        if switch_allowed && k < down_M1_to_M2
            mode_state = 2;
        end
    end

    % If mode changed, reset dwell counter
    if mode_state ~= previous_mode
        dwell_counter = 0;
        switch_events(b) = 1;
    end

    M_selected_blocks(b) = mode_state;
end

fprintf('\nController complete.\n');
fprintf('Number of switches = %d\n', sum(switch_events));

%% ------------------------------------------------------------
% 8. Ideal no-hysteresis controller for comparison
% ------------------------------------------------------------

M_ideal_blocks = zeros(1, num_blocks);

for b = 1:num_blocks

    k = k_edge(b);

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

%% ------------------------------------------------------------
% 9. Plot edge-bin index and thresholds
% ------------------------------------------------------------

figure;
stairs(time_blocks*1e3, k_edge, 'LineWidth', 1.5); hold on;
yline(k_thr_M8, '--', 'M8 threshold');
yline(k_thr_M4, '--', 'M4 threshold');
yline(k_thr_M2, '--', 'M2 threshold');
grid on;

xlabel('Time (ms)');
ylabel('Occupied edge-bin index');
title('PSD-Derived Edge-Bin Index with Decision Thresholds');

%% ------------------------------------------------------------
% 10. Plot selected decimation factor over time
% ------------------------------------------------------------

figure;
stairs(time_blocks*1e3, true_M_blocks, 'LineWidth', 1.8); hold on;
stairs(time_blocks*1e3, M_ideal_blocks, '--', 'LineWidth', 1.4);
stairs(time_blocks*1e3, M_selected_blocks, 'LineWidth', 1.4);
grid on;

xlabel('Time (ms)');
ylabel('Decimation factor M');
title('Decimation Mode Decision Over Time');
legend('True expected M', 'No-hysteresis decision', ...
       'Hysteresis controller decision', ...
       'Location', 'best');

yticks([1 2 4 8]);

%% ------------------------------------------------------------
% 11. Plot bandwidth and selected mode together
% ------------------------------------------------------------

figure;

yyaxis left;
plot(time_blocks*1e3, B_est_blocks/1e6, 'LineWidth', 1.4);
ylabel('Estimated bandwidth (MHz)');

yyaxis right;
stairs(time_blocks*1e3, M_selected_blocks, 'LineWidth', 1.5);
ylabel('Selected decimation factor M');
yticks([1 2 4 8]);

grid on;
xlabel('Time (ms)');
title('Estimated Bandwidth and Selected Decimation Mode');

%% ------------------------------------------------------------
% 12. Basic controller metrics
% ------------------------------------------------------------

mode_accuracy = mean(M_selected_blocks == true_M_blocks) * 100;
ideal_accuracy = mean(M_ideal_blocks == true_M_blocks) * 100;

fprintf('\nMode decision accuracy:\n');
fprintf('No-hysteresis controller: %.2f %%\n', ideal_accuracy);
fprintf('Hysteresis controller:    %.2f %%\n', mode_accuracy);

% Count unsafe decisions.
% Unsafe means selected M is larger than true expected M.
% Example: true M = 2, selected M = 4 or 8.
unsafe_decisions = M_selected_blocks > true_M_blocks;
num_unsafe = sum(unsafe_decisions);

% Conservative means selected M is smaller than true expected M.
% Example: true M = 8, selected M = 4, 2, or 1.
conservative_decisions = M_selected_blocks < true_M_blocks;
num_conservative = sum(conservative_decisions);

fprintf('\nDecision safety:\n');
fprintf('Unsafe decisions = %d blocks\n', num_unsafe);
fprintf('Conservative decisions = %d blocks\n', num_conservative);

%% ------------------------------------------------------------
% 13. Data-rate reduction estimate
% ------------------------------------------------------------

average_output_rate_fraction = mean(1 ./ M_selected_blocks);

data_rate_reduction = 1 - average_output_rate_fraction;

fprintf('\nData-rate estimate:\n');
fprintf('Average output-rate fraction = %.4f of input rate\n', ...
    average_output_rate_fraction);
fprintf('Estimated data-rate reduction = %.2f %%\n', ...
    data_rate_reduction * 100);

%% ------------------------------------------------------------
% 14. Save controller output
% ------------------------------------------------------------

save('step4_decimation_controller_output.mat', ...
    'M_selected_blocks', 'M_ideal_blocks', ...
    'k_edge', ...
    'k_thr_M8', 'k_thr_M4', 'k_thr_M2', ...
    'hyst_bins', ...
    'up_M8_to_M4', 'up_M4_to_M2', 'up_M2_to_M1', ...
    'down_M4_to_M8', 'down_M2_to_M4', 'down_M1_to_M2', ...
    'min_dwell_blocks', ...
    'switch_events', ...
    'mode_accuracy', 'ideal_accuracy', ...
    'num_unsafe', 'num_conservative', ...
    'average_output_rate_fraction', 'data_rate_reduction', ...
    'B_est_blocks', 'true_B_blocks', 'true_M_blocks', ...
    'time_blocks', 'Fs', 'B_ddc_max', 'Nfft', 'df', ...
    'safety_factor');

fprintf('\nSaved controller output:\n');
fprintf('step4_decimation_controller_output.mat\n');
