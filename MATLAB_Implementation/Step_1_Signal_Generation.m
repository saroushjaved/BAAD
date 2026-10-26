%% Test Signal Generation for Adaptive Decimation Paper
% Signal type:
% Bandwidth-variable complex baseband signal representing activity
% inside the current Vivado DDC +/-10 MHz observation band.

clear; close all; clc;

%% -------------------------
% 1. System parameters
% --------------------------

Fs = 62e6;                    % Sampling rate = 62 MSps
Ts = 1/Fs;

% Current Vivado DDC target:
% real 0-20 MHz IF mixed at 10 MHz -> complex baseband -10 to +10 MHz.
B_ddc_max = 10e6;
fc = 1550e6;                  % RF center label for plots only
fRF_min = fc - B_ddc_max;
fRF_max = fc + B_ddc_max;

fprintf('Sampling rate Fs = %.2f MSps\n', Fs/1e6);
fprintf('RF interpretation range = %.1f to %.1f MHz\n', ...
    fRF_min/1e6, fRF_max/1e6);
fprintf('Chosen center frequency fc = %.1f MHz\n\n', fc/1e6);
fprintf('DDC complex baseband span = %.1f to %.1f MHz\n\n', ...
    -B_ddc_max/1e6, B_ddc_max/1e6);

%% -------------------------
% 2. Define bandwidth states
% --------------------------
% These are one-sided baseband bandwidths.
% The complex baseband signal occupies approximately -B to +B.

B_states = [2.5 5.0 7.5 10.0] * 1e6;

state_names = ["Very narrowband", ...
               "Narrowband", ...
               "Medium bandwidth", ...
               "Full DDC bandwidth"];

expected_M = [8 4 2 2];       % M=1 remains a fallback outside this target

fprintf('Bandwidth states:\n');
for i = 1:length(B_states)
    B = B_states(i);

    fprintf('State %d: %-18s | B = %.2f MHz | RF span %.2f to %.2f MHz | Expected M = %d\n', ...
        i, state_names(i), B/1e6, ...
        (fc-B)/1e6, (fc+B)/1e6, expected_M(i));
end

%% -------------------------
% 3. Signal duration settings
% --------------------------

segment_duration = 1e-3;        % 1 ms per bandwidth state
Nseg = round(segment_duration * Fs);

num_states = length(B_states);
Ntotal = Nseg * num_states;

t = (0:Ntotal-1).' / Fs;

fprintf('\nSamples per segment = %d\n', Nseg);
fprintf('Total samples = %d\n', Ntotal);
fprintf('Total duration = %.2f ms\n\n', 1e3*Ntotal/Fs);

%% -------------------------
% 4. Generate each bandwidth segment
% --------------------------
% Each segment is complex bandlimited noise with a known occupied bandwidth.

x = complex(zeros(Ntotal,1));
true_B = zeros(Ntotal,1);
true_M = zeros(Ntotal,1);

rng(1);  % Repeatable result

for i = 1:num_states
    idx_start = (i-1)*Nseg + 1;
    idx_end   = i*Nseg;
    idx = idx_start:idx_end;

    B = B_states(i);

    x_seg = generate_bandlimited_complex_noise(Nseg, Fs, B);

    % Normalize each segment to unit RMS
    x_seg = x_seg / rms(x_seg);

    x(idx) = x_seg;
    true_B(idx) = B;
    true_M(idx) = expected_M(i);
end

%% -------------------------
% 5. Optional: add noise
% --------------------------
% Keep this high for first test so PSD bands are clear.

SNR_dB = 35;

signal_power = mean(abs(x).^2);
noise_power = signal_power / (10^(SNR_dB/10));

noise = sqrt(noise_power/2) * ...
    (randn(size(x)) + 1j*randn(size(x)));

x_noisy = x + noise;

%% -------------------------
% 6. Plot time-domain magnitude
% --------------------------

figure;
plot(t*1e3, abs(x_noisy));
grid on;
xlabel('Time (ms)');
ylabel('|x[n]|');
title('Generated Bandwidth-Variable Complex Baseband Signal');

%% -------------------------
% 7. Plot true bandwidth over time
% --------------------------

figure;
plot(t*1e3, true_B/1e6, 'LineWidth', 1.5);
grid on;
xlabel('Time (ms)');
ylabel('One-sided occupied bandwidth (MHz)');
title('True Bandwidth State Over Time');
ylim([0 max(B_states)/1e6*1.2]);

%% -------------------------
% 8. PSD verification using Welch method
% --------------------------

nfft = 8192;
win = hann(4096, 'periodic');
noverlap = 2048;

figure;
hold on; grid on;

for i = 1:num_states
    idx_start = (i-1)*Nseg + 1;
    idx_end   = i*Nseg;
    x_seg = x_noisy(idx_start:idx_end);

    [Pxx, fBB] = pwelch(x_seg, win, noverlap, nfft, Fs, ...
                        'centered', 'power');

    fRF = fc + fBB;

    plot(fRF/1e6, 10*log10(Pxx), 'LineWidth', 1.2);
end

xlabel('Frequency (MHz)');
ylabel('PSD (dB)');
title('PSD of Four Bandwidth States Mapped to RF Frequency Axis');
legend(state_names, 'Location', 'best');
xlim([fRF_min fRF_max]/1e6);

%% -------------------------
% 9. Save generated signal
% --------------------------

save('test_signal_4_bandwidth_states_Fs62Msps.mat', ...
    'x_noisy', 'x', 'Fs', 'fc', 'fRF_min', 'fRF_max', ...
    'B_ddc_max', 'B_states', 'true_B', 'true_M', 'expected_M', ...
    'state_names', 'SNR_dB');

fprintf('Saved test signal to test_signal_4_bandwidth_states_Fs62Msps.mat\n');

%% ============================================================
% Local function
% ============================================================

function x = generate_bandlimited_complex_noise(N, Fs, B)
% Generates complex baseband noise limited approximately to -B to +B.
%
% Inputs:
%   N  = number of samples
%   Fs = sampling rate
%   B  = one-sided bandwidth in Hz
%
% Output:
%   x  = complex baseband time-domain signal

    % Frequency axis centered at zero
    f = (-N/2:N/2-1).' * (Fs/N);

    % Frequency-domain mask
    mask = abs(f) <= B;

    % Random complex spectrum
    X = zeros(N,1);
    X(mask) = randn(sum(mask),1) + 1j*randn(sum(mask),1);

    % Smooth band edge slightly to reduce ringing
    transition_width = 0.05 * B;
    edge_region = abs(abs(f) - B) <= transition_width;

    taper = ones(N,1);
    taper(edge_region) = 0.5 * ...
        (1 + cos(pi * (abs(f(edge_region)) - B + transition_width) ...
        / transition_width));

    X = X .* taper;

    % Convert to time domain
    x = ifft(ifftshift(X));

    % Normalize
    x = x / rms(x);
end
