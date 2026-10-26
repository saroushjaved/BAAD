%% Plot DDC LPF responses from Xilinx COE coefficients
% Loads ddc_lpf_order128_q15.coe and plots common FIR filter responses.

clear; close all; clc;

Fs = 62e6;
Fpass = 10e6;
Fstop = 12e6;
FL = 15;

scriptDir = fileparts(mfilename('fullpath'));
coeFile = fullfile(scriptDir, 'ddc_lpf_order128_q15.coe');
plotDir = fullfile(scriptDir, 'response_plots');

if ~exist(plotDir, 'dir')
    mkdir(plotDir);
end

q15 = read_xilinx_coe(coeFile);
b = double(q15(:)) / 2^FL;
a = 1;

Nfft = 65536;
[H, f] = freqz(b, a, Nfft, Fs);
mag = abs(H);
magDb = 20*log10(mag + eps);
phaseRad = angle(H);
phaseUnwrapped = unwrap(phaseRad);
[gd, fgd] = grpdelay(b, a, Nfft, Fs);

fprintf('Loaded %d coefficients from:\n%s\n', length(b), coeFile);
fprintf('DC gain = %.8f (%.4f dB)\n', sum(b), 20*log10(abs(sum(b)) + eps));
fprintf('Passband edge = %.3f MHz, Stopband edge = %.3f MHz\n', Fpass/1e6, Fstop/1e6);

passIdx = f <= Fpass;
stopIdx = f >= Fstop;
fprintf('Passband ripple = %.4f dB\n', max(magDb(passIdx)) - min(magDb(passIdx)));
fprintf('Worst stopband  = %.4f dB\n', max(magDb(stopIdx)));

%% Magnitude response
figure('Name', 'Magnitude Response');
plot(f/1e6, magDb, 'LineWidth', 1.2);
grid on;
xlabel('Frequency (MHz)');
ylabel('Magnitude (dB)');
title('DDC LPF Magnitude Response');
xline(Fpass/1e6, '--', 'Fpass');
xline(Fstop/1e6, '--', 'Fstop');
ylim([-120 5]);
save_png(gcf, fullfile(plotDir, '01_magnitude_response_db.png'));

%% Passband zoom
figure('Name', 'Passband Zoom');
plot(f/1e6, magDb, 'LineWidth', 1.2);
grid on;
xlabel('Frequency (MHz)');
ylabel('Magnitude (dB)');
title('DDC LPF Passband Zoom');
xlim([0 Fpass/1e6]);
ylim([-0.1 0.1]);
save_png(gcf, fullfile(plotDir, '02_passband_zoom_db.png'));

%% Stopband zoom
figure('Name', 'Stopband Response');
plot(f/1e6, magDb, 'LineWidth', 1.2);
grid on;
xlabel('Frequency (MHz)');
ylabel('Magnitude (dB)');
title('DDC LPF Stopband Response');
xlim([Fstop/1e6 Fs/2/1e6]);
ylim([-120 -40]);
save_png(gcf, fullfile(plotDir, '03_stopband_response_db.png'));

%% Linear magnitude response
figure('Name', 'Linear Magnitude Response');
plot(f/1e6, mag, 'LineWidth', 1.2);
grid on;
xlabel('Frequency (MHz)');
ylabel('|H(f)|');
title('DDC LPF Linear Magnitude Response');
xline(Fpass/1e6, '--', 'Fpass');
xline(Fstop/1e6, '--', 'Fstop');
save_png(gcf, fullfile(plotDir, '04_linear_magnitude_response.png'));

%% Phase response
figure('Name', 'Phase Response');
plot(f/1e6, phaseUnwrapped, 'LineWidth', 1.2);
grid on;
xlabel('Frequency (MHz)');
ylabel('Phase (rad)');
title('DDC LPF Unwrapped Phase Response');
save_png(gcf, fullfile(plotDir, '05_phase_response.png'));

%% Group delay
figure('Name', 'Group Delay');
plot(fgd/1e6, gd, 'LineWidth', 1.2);
grid on;
xlabel('Frequency (MHz)');
ylabel('Group delay (samples)');
title('DDC LPF Group Delay');
xlim([0 Fs/2/1e6]);
save_png(gcf, fullfile(plotDir, '06_group_delay.png'));

%% Impulse response
figure('Name', 'Impulse Response');
stem(0:length(b)-1, b, 'filled');
grid on;
xlabel('Sample index');
ylabel('Amplitude');
title('DDC LPF Impulse Response');
save_png(gcf, fullfile(plotDir, '07_impulse_response.png'));

%% Step response
figure('Name', 'Step Response');
stairs(0:length(b)-1, cumsum(b), 'LineWidth', 1.2);
grid on;
xlabel('Sample index');
ylabel('Amplitude');
title('DDC LPF Step Response');
save_png(gcf, fullfile(plotDir, '08_step_response.png'));

%% Pole-zero plot
figure('Name', 'Pole-Zero Plot');
zplane(b, a);
title('DDC LPF Pole-Zero Plot');
save_png(gcf, fullfile(plotDir, '09_pole_zero_plot.png'));

%% Coefficient plot
figure('Name', 'Q1.15 Coefficients');
stem(0:length(q15)-1, double(q15), 'filled');
grid on;
xlabel('Tap index');
ylabel('Q1.15 integer coefficient');
title('DDC LPF Quantized Coefficients');
save_png(gcf, fullfile(plotDir, '10_q15_coefficients.png'));

fprintf('Saved response plots to:\n%s\n', plotDir);

function coeffs = read_xilinx_coe(filename)
    text = fileread(filename);
    tokens = regexp(text, 'coefdata\s*=\s*(.*?);', 'tokens', 'once');

    if isempty(tokens)
        error('Could not find coefdata section in %s', filename);
    end

    values = regexp(tokens{1}, '-?\d+', 'match');

    if isempty(values)
        error('No coefficients found in %s', filename);
    end

    coeffs = int16(str2double(values));
end

function save_png(fig, filename)
    set(fig, 'Color', 'w');
    print(fig, filename, '-dpng', '-r150');
end
