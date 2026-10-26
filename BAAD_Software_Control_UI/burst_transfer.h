#ifndef BAAD_BURST_TRANSFER_H
#define BAAD_BURST_TRANSFER_H

#include <QtCore/QByteArray>
#include <QtCore/QString>
#include <QtCore/QVector>
#include "baad_serial_protocol.h"

struct BurstSample { quint32 offset = 0; qint16 i = 0, q = 0; };
struct BurstRecord {
    bool integrityValid = false, scienceValid = false;
    QString error;
    quint32 captureId = 0, frameId = 0, sampleRate = 0;
    quint64 startCycle = 0, endCycle = 0;
    quint16 flags = 0, m = 0;
    quint8 gain = 0, source = 0;
    QVector<BurstSample> samples;
    static BurstRecord decode(const QByteArray &bytes);
    QString toCsv() const;
};

// Stop-and-wait host pull. At most one bounded capture is resident in memory.
class BurstTransfer {
public:
    enum Result { Error, Duplicate, More, Complete };
    void reset();
    bool begin(const QByteArray &readyPayload, QString *error);
    QByteArray nextRequest() const;
    Result accept(const QByteArray &chunk, QString *error);
    bool active() const { return m_active; }
    bool complete() const { return m_active && quint32(m_data.size()) == m_ready.total_bytes; }
    const QByteArray &bytes() const { return m_data; }
    const BaadCaptureReady &ready() const { return m_ready; }
    BurstRecord record() const;
private:
    BaadCaptureReady m_ready = {};
    QByteArray m_data;
    bool m_active = false;
};
#endif
