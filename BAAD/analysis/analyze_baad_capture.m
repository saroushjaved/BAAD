function result=analyze_baad_capture(burst_file,output_dir)
% Plot a verified, contiguous raw burst saved by the BAAD test application.
% Hann-windowed amplitude spectrum in dBFS relative to 32768 complex amplitude.
% Separate captures are NOT phase-aligned or simultaneous input/output pairs.
c=read_baad_burst(burst_file);
assert(c.valid_for_spectrum,'BAAD:NotNominal','Refusing FFT of flagged/gapped capture; raw data is preserved.');
if nargin<2, output_dir=fileparts(burst_file); end
if ~exist(output_dir,'dir'), mkdir(output_dir); end
n=c.sample_count; window=.5-.5*cos(2*pi*(0:n-1).'/(n-1));
rate=c.sample_rate_hz/c.expected_stride;
spectrum=fftshift(fft(c.iq.*window)); amplitude=abs(spectrum)/sum(window)/32768;
frequency=(-floor(n/2):ceil(n/2)-1).'*rate/n;
[peak,index]=max(amplitude);
result=struct('evidence_class','derived from user-provided capture, uncalibrated digital full scale', ...
    'capture_id',c.capture_id,'source',c.source,'m',c.m,'sample_count',n,'sample_rate_hz',rate, ...
    'resolution_hz',rate/n,'duration_s',(n-1)/rate,'peak_frequency_hz',frequency(index), ...
    'peak_amplitude_dbfs',20*log10(max(peak,realmin)),'rms_complex_lsb',sqrt(mean(abs(c.iq).^2)), ...
    'full_crc32',c.full_crc32,'start_cycle',c.start_cycle,'frame_id',c.frame_id, ...
    'note','No physical voltage/power calibration. PSD input and CIC output captures are sequential, not paired sample streams.');
[~,name]=fileparts(burst_file);
save(fullfile(output_dir,[name '_analysis.mat']),'result','frequency','amplitude');
fid=fopen(fullfile(output_dir,[name '_analysis.json']),'w'); assert(fid>=0); cleanup=onCleanup(@() fclose(fid)); %#ok<NASGU>
fprintf(fid,'%s\n',jsonencode(result));
fig=figure('Visible','off','Color','w','Position',[100 100 1100 480]);
plot(frequency/1e6,20*log10(max(amplitude,1e-8))); grid on;
xlabel('Signed baseband frequency (MHz)'); ylabel('Amplitude (dBFS, digital)');
title(sprintf('Capture %u, source %d, M=%d, N=%d, resolution %.1f Hz',c.capture_id,c.source,c.m,n,rate/n));
print(fig,fullfile(output_dir,[name '_spectrum.png']),'-dpng','-r120'); close(fig);
end
