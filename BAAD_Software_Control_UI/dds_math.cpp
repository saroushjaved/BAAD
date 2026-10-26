#include "dds_math.h"

#include <QtCore/QString>
#include <cmath>

quint32 DdsMath::freqToPinc(qint32 freqHz, quint32 sampleRateHz)
{
    const quint64 phaseMod = 1ull << BAAD_DDS_PHASE_BITS;
    const quint64 phaseMask = phaseMod - 1ull;
    const quint64 absHz = freqHz < 0 ? quint64(-qint64(freqHz)) : quint64(freqHz);
    quint64 inc = (absHz * phaseMod) / sampleRateHz;
    inc &= phaseMask;

    if (freqHz < 0) {
        return quint32((phaseMod - inc) & phaseMask);
    }

    return quint32(inc);
}

QVector<DdsTone> DdsMath::makeTones(double totalBandwidthHz,
                                    qint32 ifHz,
                                    quint32 sampleRateHz)
{
    QVector<DdsTone> tones;
    tones.reserve(BAAD_DDS_COUNT);

    const double first = -totalBandwidthHz / 2.0;
    const double step = totalBandwidthHz / double(BAAD_DDS_COUNT - 1u);

    for (int i = 0; i < int(BAAD_DDS_COUNT); ++i) {
        DdsTone tone;
        tone.index = i;
        tone.offsetHz = first + (double(i) * step);
        tone.toneHz = qint32(std::llround(double(ifHz) + tone.offsetHz));
        tone.pinc = freqToPinc(tone.toneHz, sampleRateHz);
        tones.push_back(tone);
    }

    return tones;
}

bool DdsMath::tonesInRange(const QVector<DdsTone> &tones,
                           quint32 sampleRateHz,
                           QString *error)
{
    const qint32 limit = qint32(sampleRateHz / 2u);

    for (const DdsTone &tone : tones) {
        if (tone.toneHz < -limit || tone.toneHz > limit) {
            if (error != nullptr) {
                *error = QStringLiteral("Tone %1 is %2 Hz, outside +/- %3 Hz")
                             .arg(tone.index)
                             .arg(tone.toneHz)
                             .arg(limit);
            }
            return false;
        }
    }

    return true;
}
