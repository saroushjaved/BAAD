function crc = baad_crc32(bytes)
% Reflected IEEE CRC-32, matching baad_serial_protocol.h and burst RTL.
crc = uint32(hex2dec('FFFFFFFF'));
for value = uint8(bytes(:)).'
    crc = bitxor(crc,uint32(value));
    for bit = 1:8
        lsb = bitand(crc,uint32(1));
        crc = bitshift(crc,-1);
        if lsb, crc = bitxor(crc,uint32(hex2dec('EDB88320'))); end
    end
end
crc = bitcmp(crc);
end
