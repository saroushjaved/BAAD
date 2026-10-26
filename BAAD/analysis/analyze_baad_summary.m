function result=analyze_baad_summary(csv_file,output_dir)
% Recorded summary timeline; not a cycle-accurate transition measurement.
% The 32-bit packer clock wraps every ~69.27 s at 62 MHz. Only unwrap adjacent
% records in one uninterrupted session, and refuse ambiguous long gaps/reset.
if nargin<2, output_dir=fileparts(csv_file); end
t=readtable(csv_file,'TextType','string');
t=t(t.kind=="summary" & t.valid==1,:);
assert(height(t)>1,'BAAD:Summary','Need two valid summary records');
utc=datetime(t.host_utc,'InputFormat',"yyyy-MM-dd'T'HH:mm:ss.SSS'Z'",'TimeZone','UTC');
host_delta=seconds(diff(utc));
assert(all(host_delta>=0 & host_delta<60),'BAAD:AmbiguousTime','Host clock change or >=60s gap: split the session before unwrapping');
assert(all(diff(double(t.frame_id))>=0),'BAAD:PossibleReset','Frame ID decreased: split at reset/wrap before analysis');
elapsed=[0;cumsum(mod(diff(double(t.cycle)),2^32))]/62e6;
result=struct('evidence_class','derived user-recorded summary; host arrivals are not device latency', ...
 'records',height(t),'observed_duration_s',elapsed(end),'m_values',unique(t.active_m).', ...
 'mean_host_interval_s',mean(host_delta),'std_host_interval_s',std(host_delta), ...
 'flagged_records',sum(bitand(uint32(t.flags),uint32(hex2dec('0C44')))~=0), ...
 'note','Summary snapshots omit intervening FFT frames. Use ILA/RTL for switching latency; clock frequency is nominal.');
if ~exist(output_dir,'dir'),mkdir(output_dir);end
[~,stem]=fileparts(csv_file);
save(fullfile(output_dir,[stem '_timeline.mat']),'t','elapsed','result');
f=figure('Visible','off','Color','w','Position',[100 100 1100 600]);
subplot(2,1,1);plot(elapsed,t.bw_edge_mhz);grid on;ylabel('Detected edge MHz');
title('Recorded summaries: sparse observations, not all decisions');
subplot(2,1,2);stairs(elapsed,t.active_m);grid on;ylabel('Applied M');xlabel('Unwrapped DSP clock time (s)');
print(f,fullfile(output_dir,[stem '_timeline.png']),'-dpng','-r120');close(f);
end
