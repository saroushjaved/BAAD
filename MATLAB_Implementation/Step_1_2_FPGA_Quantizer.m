%% ============================================================
% 10. Fixed-point quantization for FPGA-faithful modeling
% ============================================================

% Fixed-point format:
% Signed Q1.15 for I and Q
% int16 range: -32768 to +32767
% real value = integer / 2^15

WL = 16;                 % Word length
FL = 15;                 % Fractional length
Q_SCALE = 2^FL;

% Keep some headroom to avoid clipping.
% Bandlimited noise has random peaks, so do not use full scale.
target_peak = 0.75;

max_IQ_peak = max([abs(real(x_noisy)); abs(imag(x_noisy))]);

x_scaled = x_noisy * (target_peak / max_IQ_peak);

% Check scaling
fprintf('\nFixed-point scaling:\n');
fprintf('Original max I/Q peak = %.4f\n', max_IQ_peak);
fprintf('Scaled max I/Q peak   = %.4f\n', ...
    max([abs(real(x_scaled)); abs(imag(x_scaled))]));

% Quantize to signed Q1.15
I_int = quantize_to_int16(real(x_scaled), Q_SCALE);
Q_int = quantize_to_int16(imag(x_scaled), Q_SCALE);

% Reconstruct quantized signal back to MATLAB numeric form
I_q = double(I_int) / Q_SCALE;
Q_q = double(Q_int) / Q_SCALE;

x_fixed_model = I_q + 1j*Q_q;

% Quantization error
q_error = x_scaled - x_fixed_model;

quant_snr_dB = 10*log10( ...
    sum(abs(x_scaled).^2) / sum(abs(q_error).^2) );

fprintf('Input quantization SNR = %.2f dB\n', quant_snr_dB);

% Clipping check
num_clip_I = sum(I_int == int16(32767) | I_int == int16(-32768));
num_clip_Q = sum(Q_int == int16(32767) | Q_int == int16(-32768));

fprintf('Clipped I samples = %d\n', num_clip_I);
fprintf('Clipped Q samples = %d\n', num_clip_Q);

%% ============================================================
% 11. Plot floating vs fixed-point signal
% ============================================================

Ns_plot = 1000;

figure;
plot(real(x_scaled(1:Ns_plot)), 'LineWidth', 1.2); hold on;
plot(real(x_fixed_model(1:Ns_plot)), '--', 'LineWidth', 1.1);
grid on;
xlabel('Sample index');
ylabel('Amplitude');
title('Floating-Point vs Q1.15 Fixed-Point Model: Real Part');
legend('Scaled floating-point', 'Q1.15 fixed-point');

figure;
plot(abs(q_error(1:Ns_plot)), 'LineWidth', 1.2);
grid on;
xlabel('Sample index');
ylabel('|Quantization error|');
title('Input Quantization Error');

%% ============================================================
% 12. Export fixed-point samples for FPGA/testbench use
% ============================================================

% Convert signed int16 to unsigned two's complement representation
I_u16 = uint16(mod(int32(I_int), 2^16));
Q_u16 = uint16(mod(int32(Q_int), 2^16));

% Pack into 32-bit word:
% bits [31:16] = I
% bits [15:0]  = Q
IQ_u32 = bitor(bitshift(uint32(I_u16), 16), uint32(Q_u16));

% Save MATLAB file
if ~exist('B_ddc_max', 'var')
    B_ddc_max = max(B_states);
end

save('test_signal_fixed_Q15_Fs62Msps.mat', ...
    'x_noisy', 'x_scaled', 'x_fixed_model', ...
    'I_int', 'Q_int', 'I_u16', 'Q_u16', 'IQ_u32', ...
    'Fs', 'fc', 'fRF_min', 'fRF_max', 'B_ddc_max', ...
    'B_states', 'true_B', 'true_M', 'expected_M', ...
    'state_names', 'SNR_dB', ...
    'WL', 'FL', 'Q_SCALE', 'quant_snr_dB');

fprintf('\nSaved fixed-point MATLAB model:\n');
fprintf('test_signal_fixed_Q15_Fs62Msps.mat\n');

% Export decimal CSV: useful for MATLAB/Python/C test models
csv_data = [double(I_int), double(Q_int)];
writematrix(csv_data, 'test_signal_IQ_int16_decimal.csv');

fprintf('Saved decimal I/Q samples:\n');
fprintf('test_signal_IQ_int16_decimal.csv\n');

% Export 32-bit hexadecimal packed samples: useful for RTL testbench/BRAM
fid = fopen('test_signal_IQ_packed_hex.txt', 'w');

for n = 1:length(IQ_u32)
    fprintf(fid, '%08X\n', IQ_u32(n));
end

fclose(fid);

fprintf('Saved packed 32-bit hex samples:\n');
fprintf('test_signal_IQ_packed_hex.txt\n');

%% ============================================================
% Local helper function
% ============================================================

function x_int16 = quantize_to_int16(x, scale)
% Quantizes real-valued input x to signed int16 using Q1.15 scaling.

    x_scaled_int = round(x * scale);

    % Saturate
    x_scaled_int(x_scaled_int > 32767)  = 32767;
    x_scaled_int(x_scaled_int < -32768) = -32768;

    x_int16 = int16(x_scaled_int);
end
