#ifndef BAAD_DDS_MATH_H
#define BAAD_DDS_MATH_H

#include <QtCore/QVector>
#include <QtCore/QString>
#include <QtCore/QtGlobal>

#include "baad_serial_protocol.h"

struct DdsTone {
    int index = 0;
    double offsetHz = 0.0;
    qint32 toneHz = 0;
    quint32 pinc = 0;
};

class DdsMath {
public:
    static quint32 freqToPinc(qint32 freqHz,
                              quint32 sampleRateHz = BAAD_SYSTEM_SAMPLE_RATE_HZ);

    static QVector<DdsTone> makeTones(double totalBandwidthHz,
                                      qint32 ifHz = BAAD_SYSTEM_IF_HZ,
                                      quint32 sampleRateHz = BAAD_SYSTEM_SAMPLE_RATE_HZ);

    static bool tonesInRange(const QVector<DdsTone> &tones,
                             quint32 sampleRateHz = BAAD_SYSTEM_SAMPLE_RATE_HZ,
                             QString *error = nullptr);
};

#endif
