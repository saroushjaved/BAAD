function results = run_baad_analysis(output_dir)
% Reproducible, base-MATLAB R2021a analysis of the EXISTING BAAD DSP.
% No generated result is a board measurement or a vendor-IP bit-accurate test.
here=fileparts(mfilename('fullpath')); baad=fileparts(here);
if nargin==0, output_dir=fullfile(here,'generated'); end
if ~exist(output_dir,'dir'), mkdir(output_dir); end
rng(9132026,'twister'); fs=62000000; factors=[1 2 4 8 16];
coef_file=fullfile(baad,'BAAD_V1.ip_user_files','mem_init_files','ddc_lpf_order128_q15.coe');
text=fileread(coef_file); part=regexp(text,'coefdata\s*=([^;]+);','tokens','once');
coeff=sscanf(strrep(part{1},',',' '),'%f'); assert(numel(coeff)==129 && isequal(coeff,flipud(coeff)));
h=coeff/32768; dc=sum(h);
hann_file=fullfile(baad,'BAAD_V1.ip_user_files','mem_init_files','hann_2048_q15.mem');
hann_q15=hex2dec(strsplit(strtrim(fileread(hann_file)))); assert(numel(hann_q15)==2048);
results=struct('evidence_class','offline arithmetic and floating simulation, NOT board measurement', ...
    'matlab_version',version,'sample_rate_hz',fs,'fft_size',2048,'fft_nominal_shift_bits',12, ...
    'coefficient_file',coef_file,'coefficient_sha256',sha256(coef_file),'coefficient_count',numel(h), ...
    'coefficient_dc_gain',dc,'seed',9132026,'rounding','CIC positive half-LSB then arithmetic right shift; ties toward +Inf');
freq=linspace(0,fs/2,32769).'; fir=abs(fft(h,65536)); fir=fir(1:32769);
pass=freq<=10e6; stop=freq>=12e6;
results.fir=struct('passband_ripple_db',20*log10(max(fir(pass))/min(fir(pass))), ...
    'stopband_max_relative_dc_db',20*log10(max(fir(stop))/abs(dc)), ...
    'nominal_linear_phase_delay_input_samples',64);
guards=zeros(5,8); response=zeros(numel(freq),5);
for k=1:5
    m=factors(k); edge=.8*fs/(2*m); bound=floor(.8*2048/(2*m));
    guards(k,:)=[m fs/m m^3 3*log2(m) 16+3*log2(m) bound max(bound-10,0) 20*log10(cic_response(edge,fs,m))];
    response(:,k)=cic_response(freq,fs,m);
end
results.guard_columns={'M','output_rate_hz','gain','gain_shift','required_dc_width_bits','strict_edge_bins','inward_edge_bins','cic_at_continuous_guard_db'};
results.guards=guards;
% Alias experiment: 0.8*Fout is OUTSIDE new Nyquist, and folds to -0.2*Fout.
% Include DDC FIR attenuation separately. This demonstrates finite suppression,
% not universal alias rejection or a guaranteed controller response to a blocker.
aliases=zeros(4,8);
for k=1:4
    m=factors(k+1); fout=fs/m; blocker=.8*fout; alias=mod(blocker+fout/2,fout)-fout/2;
    desired=.1*fout;
    aliases(k,:)=[m blocker alias desired db(cic_response(blocker,fs,m)) db(abs(fir_at(h,blocker,fs))/abs(dc)) ...
        db(abs(fir_at(h,blocker,fs))*cic_response(blocker,fs,m)/(abs(fir_at(h,desired,fs))*cic_response(desired,fs,m))) fout/2];
end
results.alias_columns={'M','blocker_hz','folded_hz','desired_hz','cic_blocker_db','fir_blocker_relative_dc_db','equal_input_blocker_to_desired_output_db','output_nyquist_hz'};
results.aliases=aliases;
% A real 1 MHz input is not a +1 MHz complex DDC-input tone. Mixing by a
% negative-sine 10 MHz complex LO produces -9 and -11 MHz components.
input_tone=1e6; mixed=[input_tone-10e6 -input_tone-10e6];
results.real_1mhz=struct('input_hz',input_tone,'mixed_components_hz',mixed, ...
    'fir_relative_dc_db',db(abs(fir_at(h,mixed,fs))/abs(dc)), ...
    'image_to_desired_after_fir_db',db(abs(fir_at(h,mixed(2),fs)/fir_at(h,mixed(1),fs))));
% Independent fixed-arithmetic equivalence and fidelity against a floating
% convolution of the SAME 3-stage CIC. No arbitrary spectral accuracy limit.
input=complex(randi([-32768 32767],16384,1),randi([-32768 32767],16384,1));
fidelity=zeros(5,6);
for k=1:5
    m=factors(k); [fixed,indices,stats]=baad_cic_fixed(input,m);
    kernel=conv(conv(ones(m,1),ones(m,1)),ones(m,1));
    numerator=complex(filter(kernel,1,real(input)),filter(kernel,1,imag(input)));
    floating=numerator(indices)/m^3;
    independent=complex(min(max(floor(real(floating)+.5),-32768),32767), ...
        min(max(floor(imag(floating)+.5),-32768),32767));
    mismatches=nnz(fixed~=independent); assert(mismatches==0,'Fixed CIC/convolution mismatch at M=%d',m);
    e=fixed-floating;
    fidelity(k,:)=[m numel(fixed) mismatches max(abs([real(e);imag(e)])) sqrt(mean(abs(e).^2)) stats.saturated_components];
end
results.fidelity_columns={'M','compared_samples','integer_reference_mismatches','max_component_error_lsb','complex_rmse_lsb','saturated_components'};
results.fidelity=fidelity;
% Controller boundary and dynamic timeline. Hold either side of all guards.
edges=[41 41 51 52 92 92 102 103 194 194 204 205 399 399 409 410 204 204 41 41 41 41];
active=true(size(edges)); errors=false(size(edges)); errors(end-1)=true; active(end)=false;
timeline=baad_controller_reference(edges,active,errors);
assert(isequal(timeline(1:4,3).',[1 16 16 8]));
assert(all(timeline(end-1:end,3)==1));
results.dynamic_columns={'edge_bins','candidate_M','active_M','stable_count','changed'};
results.dynamic=timeline; results.dynamic_errors=errors; results.dynamic_active=active;
% Idealized DDS/mixer/FIR + integer Hann front-end and floating FFT /4096.
% It models actual bit slices, but not vendor DDS phase truncation, FFT stage
% rounding, IP latency or frame alignment. Board threshold needs calibration.
thresholds=[500 1000 2500 5000 10000 25000 100000]; bands=[2 4 8 16 20]*1e6;
robustness=zeros(numel(bands)*numel(thresholds),7); row=0;
n=(0:8191).'; lo=complex(round(8191*cos(2*pi*10e6/fs*n)),-round(8191*sin(2*pi*10e6/fs*n)));
for bandwidth=bands
    tones=10e6+linspace(-bandwidth/2,bandwidth/2,6);
    dds=round(8191*sin(2*pi/fs*n*tones)); real_input=floor(sum(dds,2)/8);
    mixer=complex(wrap16(floor(real_input.*real(lo)/8192)),wrap16(floor(real_input.*imag(lo)/8192)));
    ddc=complex(wrap16(floor(filter(coeff,1,real(mixer))/32768)),wrap16(floor(filter(coeff,1,imag(mixer))/32768)));
    frame=ddc(end-2047:end);
    windowed=complex(floor(real(frame).*hann_q15/32768),floor(imag(frame).*hann_q15/32768));
    spec=fft(windowed)/4096; power=abs(spec).^2;
    signed_bins=[0:1023 -1024:-1].';
    for threshold=thresholds
        selected=power>threshold; edge=0; if any(selected), edge=max(abs(signed_bins(selected))); end
        tl=baad_controller_reference([edge edge],[any(selected) any(selected)],[false false]);
        row=row+1; robustness(row,:)=[bandwidth threshold nnz(selected) edge edge*fs/2048 tl(end,3) max(power)];
    end
end
results.threshold_columns={'requested_bandwidth_hz','absolute_power_threshold','active_bin_count','edge_bins','edge_hz','steady_M_from_startup','peak_power_idealized'};
results.threshold_sweep=robustness;
% Hardware resource comparison is deliberately absent: only separately built
% implementation reports can establish LUT/FF/DSP/BRAM/timing/power estimates.
results.tests=run_analysis_tests();
save(fullfile(output_dir,'analysis_results.mat'),'results','freq','fir','response');
write_text(fullfile(output_dir,'analysis_results.json'),jsonencode(results));
write_report(fullfile(output_dir,'ANALYSIS_REPORT.md'),results);
fig=figure('Visible','off','Color','w','Position',[100 100 1200 720]);
subplot(2,1,1); plot(freq/1e6,db(fir/abs(dc)),'LineWidth',1.2); grid on; ylim([-110 2]); xlim([0 31]);
xlabel('Input frequency (MHz)'); ylabel('DDC FIR relative to DC (dB)'); title('Actual 129-tap Q1.15 coefficient response (offline)');
subplot(2,1,2); hold on;
for k=1:5, plot(freq/1e6,db(response(:,k)),'LineWidth',1.1); end
grid on; ylim([-90 2]); xlim([0 15.5]); xlabel('CIC input frequency (MHz)'); ylabel('Normalized CIC gain (dB)');
legend('M=1','M=2','M=4','M=8','M=16','Location','southwest'); title('Existing 3-stage CIC; zeros and droop are not an ideal anti-alias filter');
print(fig,fullfile(output_dir,'filter_responses.png'),'-dpng','-r120'); close(fig);
fprintf('PASS BAAD analysis: actual coefficients, 5-rate arithmetic equivalence, controller, CRC/burst tests.\n');
fprintf('Output: %s\n',output_dir);
end
function y=cic_response(f,fs,m)
if m==1, y=ones(size(f)); return; end
y=abs(sin(pi*m*f/fs)./(m*sin(pi*f/fs))).^3; y(f==0)=1;
end
function y=fir_at(h,f,fs)
y=reshape(h.'*exp(-2i*pi/fs*(0:numel(h)-1).'*f(:).'),size(f));
end
function y=db(x), y=20*log10(max(abs(x),1e-15)); end
function y=wrap16(x), y=mod(x+32768,65536)-32768; end
function text=sha256(path)
fid=fopen(path,'rb'); cleanup=onCleanup(@() fclose(fid)); %#ok<NASGU>
bytes=fread(fid,Inf,'*uint8'); digest=java.security.MessageDigest.getInstance('SHA-256'); digest.update(bytes);
text=lower(reshape(dec2hex(typecast(digest.digest(),'uint8'),2).',1,[]));
end
function write_text(path,text)
fid=fopen(path,'w'); assert(fid>=0,'Cannot write %s',path); cleanup=onCleanup(@() fclose(fid)); %#ok<NASGU>
fprintf(fid,'%s\n',text);
end
function write_report(path,r)
fid=fopen(path,'w'); assert(fid>=0); cleanup=onCleanup(@() fclose(fid)); %#ok<NASGU>
fprintf(fid,'# BAAD offline analysis report\n\nGenerated from actual coefficients using %s. No board measurements are in this report.\n\n',r.matlab_version);
fprintf(fid,'Coefficient SHA-256: `%s`. DC gain %.9f. Passband ripple (0..10 MHz): %.5f dB. Maximum stopband relative to DC (12..31 MHz): %.3f dB.\n\n',r.coefficient_sha256,r.coefficient_dc_gain,r.fir.passband_ripple_db,r.fir.stopband_max_relative_dc_db);
fprintf(fid,'## Guard and droop\n\n| M | Fs/M (MHz) | Gain | Shift | DC width | Strict edge bin | Inward bin | CIC at 0.8 Nyquist (dB) |\n|---:|---:|---:|---:|---:|---:|---:|---:|\n');
for a=r.guards.', fprintf(fid,'| %d | %.6f | %d | %d | %d | %d | %d | %.4f |\n',a(1),a(2)/1e6,a(3:8)); end
fprintf(fid,'\nM=1 is bypass and safety fallback; its 24.8 MHz mathematical guard is outside the <=20 MHz full-bandwidth board stimulus scope. The guard protects bin occupancy, not flatness or arbitrary blocker suppression.\n\n');
fprintf(fid,'## Specific alias counterexamples\n\nEqual-amplitude desired tone at 0.1*Fs/M and blocker at 0.8*Fs/M, before the fixed DDC FIR. Negative folded frequency is complex-baseband signed frequency.\n\n| M | Blocker MHz | Fold MHz | Desired MHz | CIC blocker dB | FIR blocker dB | Output blocker/desired dB |\n|---:|---:|---:|---:|---:|---:|---:|\n');
for a=r.aliases.', fprintf(fid,'| %d | %.4f | %.4f | %.4f | %.3f | %.3f | %.3f |\n',a(1),a(2:4)/1e6,a(5:7)); end
fprintf(fid,'\nThese are fixed-rate transfer-function experiments, not assertions that the adaptive controller will retain that M with a visible blocker. They quantify finite anti-alias attenuation when a blocker is missed/below threshold.\n\n');
fprintf(fid,'## Real-input image\n\nA real 1 MHz tone mixed with the existing 10 MHz negative-sine LO produces -9 and -11 MHz. Actual FIR gains relative to DC: %.3f and %.3f dB. The -11 MHz image is %.3f dB relative to the -9 MHz component after FIR, so it is not valid to treat this as a clean +1 MHz complex-baseband test.\n\n',r.real_1mhz.fir_relative_dc_db,r.real_1mhz.image_to_desired_after_fir_db);
fprintf(fid,'## CIC arithmetic\n\n| M | Samples | Exact integer mismatches | Maximum component error LSB | Complex RMSE LSB | Saturated components |\n|---:|---:|---:|---:|---:|---:|\n');
for a=r.fidelity.', fprintf(fid,'| %d | %d | %d | %.4f | %.4f | %d |\n',a); end
fprintf(fid,'\nThe independent integer convolution matches the modular-integrator/comb model exactly. The floating comparison isolates CIC quantization, not DDS/FFT vendor behavior. Width values are DC growth requirements (16+3*log2(M)); integrators intentionally use modular arithmetic, not saturation.\n\n');
fprintf(fid,'## Idealized threshold sweep\n\nActual coefficient and Hann ROM values and existing bit slices are used; ideal sinusoids and floating FFT /4096 replace vendor DDS/FFT. These are predictions to calibrate against board captures, not exact RTL results.\n\n| Requested bandwidth MHz | Threshold | Active bins | Edge bin | Edge MHz | M after two frames from startup |\n|---:|---:|---:|---:|---:|---:|\n');
for a=r.threshold_sweep.', fprintf(fid,'| %.1f | %d | %d | %d | %.5f | %d |\n',a(1)/1e6,a(2:4),a(5)/1e6,a(6)); end
fprintf(fid,'\nSee analysis_results.json/.mat for dynamic controller timeline, all numerical inputs, and decoder test outcomes. Use the board test matrix to collect the corresponding measured results. Hardware resources and estimated power require matched full-design implementation reports; offline fixed-M processing cannot establish resource savings.\n');
end
