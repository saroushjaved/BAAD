%% ============================================================
% Step 2: PSD Estimation Block for Adaptive Decimation
%
% Input:
%   test_signal_fixed_Q15_Fs62Msps.mat
%
% Output:
%   Block-wise PSD estimates from Q1.15 quantized signal
%
% This script models the first main implementation block:
%
%   Q1.15 input samples
%       -> block buffer
%       -> Q1.15 window multiplication
%       -> PSD estimate
%
% ============================================================

clear; close all; clc;

%% ------------------------------------------------------------
% 1. Load fixed-point generated signal
% ------------------------------------------------------------

load('test_signal_fixed_Q15_Fs62Msps.mat');

if ~exist('B_ddc_max', 'var')
    B_ddc_max = max(B_states);
end

if ~exist('fRF_min', 'var')
    fRF_min = fc - B_ddc_max;
    fRF_max = fc + B_ddc_max;
end

fprintf('Loaded fixed-point test signal.\n');
fprintf('Fs = %.2f MSps\n', Fs/1e6);
fprintf('Number of samples = %d\n', length(I_int));

%% ------------------------------------------------------------
% 2. PSD block parameters
% ------------------------------------------------------------

Nwin = 8192;                 % PSD analysis window length
Nfft = 8192;                 % FFT length for PSD
hop  = Nwin/2;               % 50 percent overlap

df = Fs / Nfft;              % Frequency-bin spacing

fprintf('\nPSD parameters:\n');
fprintf('Nwin = %d samples\n', Nwin);
fprintf('Nfft = %d points\n', Nfft);
fprintf('Hop  = %d samples\n', hop);
fprintf('Frequency resolution = %.2f kHz\n', df/1e3);

num_samples = length(I_int);
num_blocks = floor((num_samples - Nwin)/hop) + 1;

fprintf('Number of PSD blocks = %d\n', num_blocks);

%% ------------------------------------------------------------
% 3. Frequency axis
% ------------------------------------------------------------

% Complex baseband, centered PSD:
% frequency range = -Fs/2 to +Fs/2
fBB = (-Nfft/2:Nfft/2-1).' * (Fs/Nfft);

% RF-labeled frequency axis for interpretation only
fRF = fc + fBB;

%% ------------------------------------------------------------
% 4. Create Q1.15 Hann window
% ------------------------------------------------------------
% Avoid toolbox dependency by defining Hann manually.

n = (0:Nwin-1).';
win_float = 0.5 - 0.5*cos(2*pi*n/(Nwin-1));

% Quantize window to Q1.15.
% Maximum positive Q1.15 value is 32767.
win_q15 = int16(round(win_float * 32767));

% Reconstructed quantized window for PSD normalization
win_q = double(win_q15) / 2^15;

% Window energy used for PSD normalization
U = sum(win_q.^2);

fprintf('\nWindow:\n');
fprintf('Window type = Hann\n');
fprintf('Window format = Q1.15\n');
fprintf('Window energy U = %.2f\n', U);

%% ------------------------------------------------------------
% 5. Allocate PSD storage
% ------------------------------------------------------------

PSD_blocks = zeros(Nfft, num_blocks);
time_blocks = zeros(1, num_blocks);
true_B_blocks = zeros(1, num_blocks);
true_M_blocks = zeros(1, num_blocks);

%% ------------------------------------------------------------
% 6. Block-wise PSD estimation
% ------------------------------------------------------------

for b = 1:num_blocks

    idx_start = (b-1)*hop + 1;
    idx_end   = idx_start + Nwin - 1;
    idx = idx_start:idx_end;

    % Extract Q1.15 input block as int16
    I_blk = I_int(idx);
    Q_blk = Q_int(idx);

    % Q1.15 window multiplication
    % Q1.15 * Q1.15 -> Q2.30
    % Shift back to Q1.15
    I_win_int = q15_multiply(I_blk, win_q15);
    Q_win_int = q15_multiply(Q_blk, win_q15);

    % Convert windowed fixed-point samples back to numerical values
    % This represents the value entering the PSD/FFT block.
    x_win = double(I_win_int)/2^15 + 1j*double(Q_win_int)/2^15;

    % PSD estimate
    %
    % Periodogram-style PSD:
    %   Sxx[k] = |FFT{x_win}|^2 / (Fs * U)
    %
    % fftshift is used because this is a complex baseband signal.
    X = fftshift(fft(x_win, Nfft));
    Pxx = (abs(X).^2) / (Fs * U);

    PSD_blocks(:, b) = Pxx;

    % Block center time
    time_blocks(b) = ((idx_start + idx_end)/2 - 1) / Fs;

    % Ground-truth labels for later validation
    true_B_blocks(b) = mode(round(true_B(idx)));
    true_M_blocks(b) = mode(true_M(idx));
end

fprintf('\nPSD estimation complete.\n');

%% ------------------------------------------------------------
% 7. Plot PSD of selected blocks
% ------------------------------------------------------------

figure;
hold on; grid on;

selected_blocks = round(linspace(1, num_blocks, 4));

for ii = 1:length(selected_blocks)
    b = selected_blocks(ii);
    plot(fRF/1e6, 10*log10(PSD_blocks(:,b) + eps), 'LineWidth', 1.2);
end

xlabel('Frequency (MHz)');
ylabel('PSD (dB/Hz)');
title('PSD Estimates from Q1.15 Input Signal');
legend("Block " + string(selected_blocks), 'Location', 'best');
xlim([fRF_min fRF_max]/1e6);

%% ------------------------------------------------------------
% 8. PSD time-frequency visualization
% ------------------------------------------------------------

figure;

imagesc(time_blocks*1e3, fRF/1e6, 10*log10(PSD_blocks + eps));
axis xy;
colorbar;

xlabel('Time (ms)');
ylabel('Frequency (MHz)');
title('Block-wise PSD of Bandwidth-Variable Signal');
ylim([fRF_min fRF_max]/1e6);

%% ------------------------------------------------------------
% 9. Plot true bandwidth per PSD block
% ------------------------------------------------------------

figure;
stairs(time_blocks*1e3, true_B_blocks/1e6, 'LineWidth', 1.5);
grid on;

xlabel('Time (ms)');
ylabel('True one-sided bandwidth (MHz)');
title('True Bandwidth Label per PSD Block');

%% ------------------------------------------------------------
% 10. Save PSD output for next stage
% ------------------------------------------------------------

save('step2_psd_output_fixed_input.mat', ...
    'PSD_blocks', 'fBB', 'fRF', 'time_blocks', ...
    'true_B_blocks', 'true_M_blocks', ...
    'Fs', 'fc', 'fRF_min', 'fRF_max', 'B_ddc_max', ...
    'Nwin', 'Nfft', 'hop', 'df', ...
    'win_q15', 'win_q', 'U', ...
    'B_states', 'expected_M', 'state_names');

fprintf('\nSaved PSD output:\n');
fprintf('step2_psd_output_fixed_input.mat\n');

%% ============================================================
% Local function: Q1.15 multiplier
% ============================================================

function y = q15_multiply(a, b)
% q15_multiply
%
% Multiplies two signed Q1.15 int16 vectors:
%
%   a: Q1.15 int16
%   b: Q1.15 int16
%
% Product:
%   Q1.15 * Q1.15 = Q2.30
%
% Output:
%   y: Q1.15 int16 after rounding and saturation

    product_q30 = int64(a) .* int64(b);

    % Round before shifting back by 15 bits
    product_q30 = product_q30 + int64(2^14);

    y_temp = floor(double(product_q30) / 2^15);

    % Saturate to int16 range
    y_temp(y_temp > 32767)  = 32767;
    y_temp(y_temp < -32768) = -32768;

    y = int16(y_temp);
end
