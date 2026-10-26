NFFT = 2048;
n = (0:NFFT-1).';
w = 0.5 - 0.5*cos(2*pi*n/(NFFT-1));

q15 = round(w * 32767);
q15(q15 > 32767) = 32767;
q15(q15 < 0) = 0;

fid = fopen('hann_2048_q15.mem', 'w');
for k = 1:NFFT
    fprintf(fid, '%04X\n', q15(k));
end
fclose(fid);
