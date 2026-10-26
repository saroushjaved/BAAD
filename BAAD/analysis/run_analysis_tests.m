function tests=run_analysis_tests()
% Offline decoder fixtures are fabricated TEST DATA, never board evidence.
assert(baad_crc32(uint8('123456789'))==uint32(hex2dec('CBF43926')));
tested=0;
for source=0:1
    for count=[256 8192]
        bytes=fixture(count,source,4,0,false); capture=read_baad_burst(bytes,baad_crc32(bytes));
        assert(capture.capture_id==7 && capture.sample_count==count && capture.valid_for_spectrum);
        assert(isequal(real(capture.iq),(0:count-1).'-100) && all(imag(capture.iq)==-500));
        assert(capture.cycle_offset(end)==(count-1)*(1+source*3)); tested=tested+1;
    end
end
bytes=fixture(256,1,4,0,false);
bad=bytes; bad(75)=bitxor(bad(75),uint8(1)); must_fail(@() read_baad_burst(bad),'BAAD:RecordCRC');
must_fail(@() read_baad_burst(bytes,uint32(1)),'BAAD:TransferCRC');
must_fail(@() read_baad_burst(bytes(1:end-1)),'BAAD:Length');
warning('off','BAAD:InvalidCapture'); cleanup=onCleanup(@() warning('on','BAAD:InvalidCapture')); %#ok<NASGU>
capture=read_baad_burst(fixture(256,1,4,1,false)); assert(~capture.valid_for_spectrum && capture.flags==1);
capture=read_baad_burst(fixture(256,1,4,0,true)); assert(~capture.valid_for_spectrum && ~capture.contiguous);
% Confirm signed tie handling and exact M=1 bypass.
[y,~,~]=baad_cic_fixed(complex([-32768;-1;0;1;32767]),1);
assert(isequal(y,complex([-32768;-1;0;1;32767])));
% Fabricated summary with one 32-bit cycle wrap and no board measurements.
test_dir=tempname;mkdir(test_dir);test_cleanup=onCleanup(@() rmdir(test_dir,'s')); %#ok<NASGU>
host_utc=["2026-09-14T00:00:00.000Z";"2026-09-14T00:00:00.200Z"];
kind=["summary";"summary"];valid=[1;1];cycle=[2^32-6200000;6200000];frame_id=[100;200];
active_m=[16;8];flags=[0;0];bw_edge_mhz=[1;2];
t=table(host_utc,kind,valid,cycle,frame_id,active_m,flags,bw_edge_mhz);
test_file=fullfile(test_dir,'fabricated_summary.csv');writetable(t,test_file);
summary=analyze_baad_summary(test_file,test_dir);assert(abs(summary.observed_duration_s-.2)<1e-12);
t.frame_id(2)=1;writetable(t,test_file);must_fail(@() analyze_baad_summary(test_file,test_dir),'BAAD:PossibleReset');
tests=struct('crc_known_vector',true,'valid_burst_fixtures',tested,'corrupt_record_rejected',true, ...
    'corrupt_transfer_rejected',true,'truncation_rejected',true,'flagged_capture_retained_invalid',true, ...
    'gapped_capture_retained_invalid',true,'m1_bypass',true,'summary_wrap_and_reset',true);
end
function bytes=fixture(n,source,m,flags,gap)
w=zeros(n+10,1,'uint64');
w(1)=bitor(bitshift(uint64(hex2dec('BAAD')),48),bitor(bitshift(uint64(2),40), ...
    bitor(bitshift(uint64(4),32),bitor(bitshift(uint64(n+10),16),uint64(flags)))));
w(2)=bitor(bitshift(uint64(7),32),uint64(n)); w(3)=uint64(100000);
offsets=(0:n-1).'* (1+source*(m-1)); if gap, offsets(100:end)=offsets(100:end)+1; end
w(4)=w(3)+uint64(offsets(end));
w(5)=bitor(bitshift(uint64(62000000),32),bitor(bitshift(uint64(m),16),bitor(bitshift(uint64(3*log2(m)),8),uint64(source))));
w(6)=bitshift(uint64(42),32); w(7)=uint64(4294967304);
ival=uint64(mod((0:n-1).'-100,65536)); qval=bitshift(uint64(mod(-500,65536)),16);
w(9:n+8)=bitor(bitshift(uint64(offsets),32),bitor(ival,qval));
w(n+9)=bitor(bitshift(uint64(hex2dec('454E4421')),32),bitor(bitshift(uint64(n),16),uint64(flags)));
bytes=typecast(w,'uint8'); [~,~,endian]=computer; assert(endian=='L','Test fixture requires little endian');
crc=baad_crc32(bytes(1:end-8));
w(n+10)=bitor(bitshift(uint64(hex2dec('43524332')),32),uint64(crc)); bytes=typecast(w,'uint8');
end
function must_fail(action,id)
failed=false;
try, action(); catch error, failed=strcmp(error.identifier,id); end
assert(failed,'Expected rejection %s',id);
end
