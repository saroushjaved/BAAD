#include "protocol_codec.h"

#include <cstring>

static void putLe16(char *dst, quint16 value)
{
    dst[0] = char(value & 0xffu);
    dst[1] = char((value >> 8) & 0xffu);
}

static quint16 getLe16(const char *src)
{
    return quint16(quint8(src[0])) | (quint16(quint8(src[1])) << 8);
}

QByteArray ProtocolCodec::encode(quint8 type, quint16 sequence, const QByteArray &payload)
{
    if (payload.size() > BAAD_SERIAL_MAX_PAYLOAD) return {};
    QByteArray frame;
    frame.resize(int(BAAD_SERIAL_HEADER_BYTES) + payload.size() + int(BAAD_SERIAL_CRC_BYTES));

    putLe16(frame.data(), BAAD_SERIAL_MAGIC);
    frame[2] = char(BAAD_SERIAL_VERSION);
    frame[3] = char(type);
    putLe16(frame.data() + 4, sequence);
    putLe16(frame.data() + 6, quint16(payload.size()));

    if (!payload.isEmpty()) {
        memcpy(frame.data() + BAAD_SERIAL_HEADER_BYTES, payload.constData(), size_t(payload.size()));
    }

    quint16 crc = baad_crc16_ccitt(reinterpret_cast<const uint8_t *>(frame.constData() + 2),
                                   BAAD_SERIAL_HEADER_BYTES - 2u);
    if (!payload.isEmpty()) {
        crc = baad_crc16_ccitt_update(crc,
                                      reinterpret_cast<const uint8_t *>(payload.constData()),
                                      uint32_t(payload.size()));
    }
    putLe16(frame.data() + BAAD_SERIAL_HEADER_BYTES + payload.size(), crc);

    return frame;
}

QVector<BaadPacket> ProtocolCodec::feed(const QByteArray &data)
{
    QVector<BaadPacket> packets;
    m_buffer.append(data);

    while (m_buffer.size() >= int(BAAD_SERIAL_HEADER_BYTES)) {
        int magicOffset = -1;
        for (int i = 0; i <= m_buffer.size() - int(BAAD_SERIAL_HEADER_BYTES); ++i) {
            if (getLe16(m_buffer.constData() + i) == BAAD_SERIAL_MAGIC) {
                magicOffset = i;
                break;
            }
        }

        if (magicOffset < 0) {
            // Preserve a partial header across reads, including its magic bytes.
            m_buffer = m_buffer.last(int(BAAD_SERIAL_HEADER_BYTES) - 1);
            break;
        }

        if (magicOffset > 0) {
            m_buffer.remove(0, magicOffset);
        }

        if (m_buffer.size() < int(BAAD_SERIAL_HEADER_BYTES)) {
            break;
        }

        if (quint8(m_buffer[2]) != BAAD_SERIAL_VERSION) {
            ++m_errors;
            m_buffer.remove(0, 1);
            continue;
        }

        const quint16 payloadLength = getLe16(m_buffer.constData() + 6);
        if (payloadLength > BAAD_SERIAL_MAX_PAYLOAD) {
            ++m_errors;
            m_buffer.remove(0, 1);
            continue;
        }

        const int total = int(BAAD_SERIAL_HEADER_BYTES) + int(payloadLength) + int(BAAD_SERIAL_CRC_BYTES);
        if (m_buffer.size() < total) {
            break;
        }

        quint16 crc = baad_crc16_ccitt(reinterpret_cast<const uint8_t *>(m_buffer.constData() + 2),
                                       BAAD_SERIAL_HEADER_BYTES - 2u);
        if (payloadLength != 0u) {
            crc = baad_crc16_ccitt_update(
                crc,
                reinterpret_cast<const uint8_t *>(m_buffer.constData() + BAAD_SERIAL_HEADER_BYTES),
                payloadLength);
        }
        const quint16 expected = getLe16(m_buffer.constData() + BAAD_SERIAL_HEADER_BYTES + payloadLength);

        if (crc != expected) {
            ++m_errors;
            m_buffer.remove(0, 1);
            continue;
        }

        BaadPacket packet;
        packet.type = quint8(m_buffer[3]);
        packet.sequence = getLe16(m_buffer.constData() + 4);
        packet.payload = m_buffer.mid(int(BAAD_SERIAL_HEADER_BYTES), payloadLength);
        packets.push_back(packet);

        m_buffer.remove(0, total);
    }

    return packets;
}

void ProtocolCodec::reset()
{
    m_buffer.clear();
}
