#ifndef BAAD_DMA_DECODER_H
#define BAAD_DMA_DECODER_H

#include <QtCore/QByteArray>
#include <QtCore/QString>
#include <QtCore/QStringList>
#include <QtCore/QVector>

struct DecodedDmaRecord {
    bool valid = false;
    QString error;
    QString kind;
    quint8 type = 0;
    quint16 flags = 0;
    quint16 wordCount = 0;
    quint32 frameId = 0;
    quint32 decisionFrameId = 0;
    quint32 cycleCount = 0;
    quint32 recordsEmitted = 0;
    quint16 frameBinCount = 0;
    quint16 activeBinCount = 0;
    quint16 overflowCount = 0;
    quint16 bwSpanBins = 0;
    quint16 bwEdgeBins = 0;
    qint16 lowSignedBin = 0;
    qint16 highSignedBin = 0;
    qint16 peakSignedBin = 0;
    quint16 lowBin = 0;
    quint16 highBin = 0;
    quint16 peakBin = 0;
    quint64 peakPower = 0;
    quint64 minPower = 0;
    quint64 totalPower = 0;
    quint64 activePower = 0;
    quint16 decimationFactor = 0;
    quint16 candidateFactor = 0;
    quint16 stableCount = 0;
    quint16 decisionEdgeBins = 0;
    quint16 activeDecimationFactor = 0;
    quint8 activeGainShift = 0;
    qint16 mI = 0;
    qint16 mQ = 0;
    double bwSpanMHz = 0.0;
    double bwEdgeMHz = 0.0;
    QStringList flagNames;
    QByteArray raw;
};

class DmaDecoder {
public:
    static QVector<DecodedDmaRecord> decodePayload(const QByteArray &payload);
    static QString csvHeader();
    static QString toCsvLine(const DecodedDmaRecord &record);
};

#endif
