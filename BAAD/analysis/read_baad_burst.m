function capture = read_baad_burst(input, expected_crc32)
% Read one raw protocol-v2 burst record (not a serial packet or legacy snapshot).
% Integrity failures raise errors. Flagged/gapped captures are returned with
% valid_for_spectrum=false and must not be silently used for nominal metrics.
if ischar(input) || isstring(input)
    fid = fopen(input,'rb'); assert(fid>=0,'BAAD:Open','Cannot open burst file');
    cleanup = onCleanup(@() fclose(fid)); %#ok<NASGU>
    bytes = fread(fid,Inf,'*uint8');
else
    bytes = uint8(input(:));
end
assert(numel(bytes)>=80 && mod(numel(bytes),8)==0,'BAAD:Length','Invalid record length');
if nargin>1
    assert(baad_crc32(bytes)==uint32(expected_crc32),'BAAD:TransferCRC','Full transfer CRC mismatch');
end
w = reshape(bytes,8,[]);
u16 = @(row,col) double(w(row,col))+256*double(w(row+1,col));
u32 = @(row,col) uint32(double(w(row,col))+256*double(w(row+1,col))+65536*double(w(row+2,col))+16777216*double(w(row+3,col)));
u64 = @(col) bitor(uint64(u32(1,col)),bitshift(uint64(u32(5,col)),32));
assert(u16(7,1)==hex2dec('BAAD') && w(6,1)==2 && w(5,1)==4,'BAAD:Header','Not a v2 burst record');
count = double(u32(1,2));
assert(count>=256 && count<=8192 && size(w,2)==count+10 && u16(3,1)==count+10,'BAAD:Count','Count/length mismatch');
assert(u32(5,count+9)==uint32(hex2dec('454E4421')) && u16(3,count+9)==count,'BAAD:Trailer','END trailer mismatch');
assert(u32(5,count+10)==uint32(hex2dec('43524332')),'BAAD:Trailer','CRC trailer missing');
assert(baad_crc32(bytes(1:end-8))==u32(1,count+10),'BAAD:RecordCRC','Record CRC mismatch');
assert(u64(7)==uint64(4294967304) && u64(8)==0,'BAAD:Layout','Unknown sample layout');
capture.capture_id = u32(5,2);
capture.flags = u16(1,1);
assert(capture.flags==u16(1,count+9),'BAAD:Flags','Header/trailer flags differ');
capture.sample_count = count;
capture.start_cycle = u64(3); capture.end_cycle = u64(4);
capture.sample_rate_hz = double(u32(5,5));
capture.m = u16(3,5); capture.gain_shift = double(w(2,5));
capture.source = double(w(1,5)); capture.frame_id = u32(5,6);
assert(capture.sample_rate_hz>0 && any(capture.m==[1 2 4 8 16]) && any(capture.source==[0 1]),'BAAD:Metadata','Unsupported Fs/M/source');
assert(capture.gain_shift==3*log2(capture.m),'BAAD:Gain','CIC gain metadata mismatch');
columns = 9:count+8;
ival = u16(1,columns); qval = u16(3,columns);
ival(ival>=32768)=ival(ival>=32768)-65536;
qval(qval>=32768)=qval(qval>=32768)-65536;
capture.iq = complex(ival(:),qval(:));
capture.cycle_offset = double(u32(5,columns)).';
capture.time_s = capture.cycle_offset / capture.sample_rate_hz;
capture.full_crc32 = baad_crc32(bytes);
capture.expected_stride = 1;
if capture.source==1, capture.expected_stride=capture.m; end
capture.contiguous = capture.cycle_offset(1)==0 && ...
    all(diff(capture.cycle_offset)==capture.expected_stride) && ...
    capture.end_cycle>=capture.start_cycle && ...
    capture.end_cycle-capture.start_cycle==uint64(capture.cycle_offset(end));
capture.valid_for_spectrum = capture.flags==0 && capture.contiguous;
if ~capture.valid_for_spectrum
    warning('BAAD:InvalidCapture','Capture %u retained, but flags or cadence prohibit nominal FFT metrics.',capture.capture_id);
end
end
