function [output, indices, stats] = baad_cic_fixed(input, m)
% Fixed-rate arithmetic reference for existing three-stage 32-bit CIC.
% Begins with cleared states and M already active, emits phase 0, suppresses
% the first three comb outputs for M>1. No vendor IP or rate-switch timing model.
assert(any(m==[1 2 4 8 16]),'Supported M: 1,2,4,8,16');
assert(all(real(input(:))==fix(real(input(:))) & imag(input(:))==fix(imag(input(:)))));
assert(all(abs(real(input(:)))<=32768 & abs(imag(input(:)))<=32768));
input=input(:); indices=(1:m:numel(input)).';
if m==1
    output=input(indices); stats=struct('saturated_components',0,'outputs',numel(output)); return
end
states=zeros(3,2); delays=zeros(3,2); output=zeros(numel(indices),2); oi=0; sats=0;
for n=1:numel(input)
    value=[real(input(n)) imag(input(n))];
    for stage=1:3
        states(stage,:)=wrap32(states(stage,:)+value); value=states(stage,:);
    end
    if mod(n-1,m)==0
        for stage=1:3
            delta=wrap32(value-delays(stage,:)); delays(stage,:)=value; value=delta;
        end
        % RTL adds a positive half-LSB, so negative ties round toward +Inf.
        rounded=floor(wrap32(value+2^(3*log2(m)-1))/m^3);
        sats=sats+sum(rounded>32767 | rounded< -32768);
        oi=oi+1; output(oi,:)=min(max(rounded,-32768),32767);
    end
end
output=complex(output(4:end,1),output(4:end,2)); indices=indices(4:end);
stats=struct('saturated_components',sats,'outputs',numel(output));
end
function result=wrap32(value)
result=mod(value+2^31,2^32)-2^31;
end
