#ifndef BAAD_PROTOCOL_CODEC_H
#define BAAD_PROTOCOL_CODEC_H

#include <QtCore/QByteArray>
#include <QtCore/QVector>

#include "baad_serial_protocol.h"

struct BaadPacket {
    quint8 type = 0;
    quint16 sequence = 0;
    QByteArray payload;
};

class ProtocolCodec {
public:
    static QByteArray encode(quint8 type, quint16 sequence, const QByteArray &payload = {});
    QVector<BaadPacket> feed(const QByteArray &data);
    void reset();
    quint64 errors() const { return m_errors; }

private:
    QByteArray m_buffer;
    quint64 m_errors = 0;
};

#endif
