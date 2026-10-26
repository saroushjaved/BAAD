#include "dma_decoder.h"

#include <QtCore/QLocale>

#include "baad_serial_protocol.h"

static quint64 readLe64(const char *src)
{
    quint64 value = 0;
    for (int i = 7; i >= 0; --i) {
        value = (value << 8) | quint8(src[i]);
    }
    return value;
}

static qint16 signExtend(quint64 value, int bits)
{
    const quint64 sign = 1ull << (bits - 1);
    const quint64 mask = (1ull << bits) - 1ull;
    value &= mask;
    if ((value & sign) != 0ull) {
        value |= ~mask;
    }
    return qint16(qint64(value));
}

static QStringList decodeFlags(quint16 flags)
{
    QStringList names;
    const struct {
        quint16 mask;
        const char *name;
    } known[] = {
        {1u << 0, "estimate"},
        {1u << 1, "decision"},
        {1u << 2, "frame_error"},
        {1u << 3, "active"},
        {1u << 4, "overflow"},
        {1u << 5, "m_changed"},
        {1u << 6, "decision_error"},
        {1u << 7, "no_active"},
        {1u << 8, "rate_changed"},
        {1u << 9, "settling"},
        {1u << 10, "cfg_error"},
        {1u << 11, "cic_overflow"},
        {1u << 12, "m_valid"},
        {1u << 13, "psd_input_valid"},
    };

    for (const auto &entry : known) {
        if ((flags & entry.mask) != 0u) {
            names.push_back(QString::fromLatin1(entry.name));
        }
    }

    return names;
}

static void decodeCommonHeader(const QVector<quint64> &words, DecodedDmaRecord *record)
{
    const quint64 w0 = words[0];
    record->flags = quint16(w0 & 0xffffu);
    record->wordCount = quint16((w0 >> 16) & 0xffffu);
    record->type = quint8((w0 >> 32) & 0xffu);
    record->flagNames = decodeFlags(record->flags);
    record->kind = record->type == 0x01 ? QStringLiteral("summary") :
                   record->type == 0x02 ? QStringLiteral("psd_input") :
                   record->type == 0x03 ? QStringLiteral("cic") :
                                           QStringLiteral("unknown");

    if (words.size() > 1) {
        record->cycleCount = quint32((words[1] >> 32) & 0xffffffffu);
        record->frameId = quint32(words[1] & 0xffffffffu);
    }
}

static void decodeSummary(const QVector<quint64> &words, DecodedDmaRecord *record)
{
    decodeCommonHeader(words, record);

    record->decisionFrameId = quint32((words[2] >> 32) & 0xffffffffu);
    record->recordsEmitted = quint32(words[2] & 0xffffffffu);

    const quint64 w3 = words[3];
    record->bwEdgeBins = quint16(w3 & 0x0fffu);
    record->bwSpanBins = quint16((w3 >> 12) & 0x0fffu);
    record->overflowCount = quint16((w3 >> 24) & 0x0fffu);
    record->activeBinCount = quint16((w3 >> 36) & 0x0fffu);
    record->frameBinCount = quint16((w3 >> 48) & 0x0fffu);

    const quint64 w4 = words[4];
    record->peakSignedBin = signExtend(w4, 13);
    record->highSignedBin = signExtend(w4 >> 13, 13);
    record->lowSignedBin = signExtend(w4 >> 26, 13);

    const quint64 w5 = words[5];
    record->peakBin = quint16(w5 & 0x07ffu);
    record->highBin = quint16((w5 >> 11) & 0x07ffu);
    record->lowBin = quint16((w5 >> 22) & 0x07ffu);

    record->peakPower = words[6] & ((1ull << 33) - 1ull);
    record->minPower = words[7] & ((1ull << 33) - 1ull);
    record->totalPower = words[8] & ((1ull << 45) - 1ull);
    record->activePower = words[9] & ((1ull << 45) - 1ull);

    const quint64 w10 = words[10];
    record->decimationFactor = quint16((w10 >> 48) & 0xffffu);
    record->candidateFactor = quint16((w10 >> 32) & 0xffffu);
    record->stableCount = quint16((w10 >> 16) & 0xffffu);
    record->decisionEdgeBins = quint16((w10 >> 4) & 0x0fffu);

    const quint64 w11 = words[11];
    record->activeDecimationFactor = quint16((w11 >> 48) & 0xffffu);
    record->activeGainShift = quint8((w11 >> 40) & 0xffu);
    record->mI = qint16((w11 >> 24) & 0xffffu);
    record->mQ = qint16((w11 >> 8) & 0xffffu);

    const double binHz = double(BAAD_SYSTEM_SAMPLE_RATE_HZ) / double(BAAD_FFT_SIZE);
    record->bwSpanMHz = double(record->bwSpanBins) * binHz / 1.0e6;
    record->bwEdgeMHz = double(record->bwEdgeBins) * binHz / 1.0e6;
}

static void decodeCic(const QVector<quint64> &words, DecodedDmaRecord *record)
{
    decodeCommonHeader(words, record);

    const quint64 w2 = words[2];
    record->mI = qint16((w2 >> 48) & 0xffffu);
    record->mQ = qint16((w2 >> 32) & 0xffffu);
    record->activeDecimationFactor = quint16((w2 >> 16) & 0xffffu);
    record->activeGainShift = quint8((w2 >> 8) & 0xffu);

    const quint64 w3 = words[3];
    record->decimationFactor = quint16((w3 >> 48) & 0xffffu);
    record->candidateFactor = quint16((w3 >> 32) & 0xffffu);
    record->stableCount = quint16((w3 >> 16) & 0xffffu);
    record->recordsEmitted = quint32(w3 & 0xffffu);
}

static void decodePsdInput(const QVector<quint64> &words, DecodedDmaRecord *record)
{
    decodeCommonHeader(words, record);

    const quint64 w2 = words[2];
    record->mI = qint16((w2 >> 48) & 0xffffu);
    record->mQ = qint16((w2 >> 32) & 0xffffu);
    record->decimationFactor = quint16((w2 >> 16) & 0xffffu);
    record->candidateFactor = quint16(w2 & 0xffffu);

    const quint64 w3 = words[3];
    record->activeDecimationFactor = quint16((w3 >> 48) & 0xffffu);
    record->activeGainShift = quint8((w3 >> 40) & 0xffu);
    record->stableCount = quint16((w3 >> 24) & 0xffffu);
    record->recordsEmitted = quint32((w3 >> 8) & 0xffffu);
}

QVector<DecodedDmaRecord> DmaDecoder::decodePayload(const QByteArray &payload)
{
    QVector<DecodedDmaRecord> records;
    int offset = 0;

    while ((offset + 8) <= payload.size()) {
        DecodedDmaRecord record;
        const quint64 first = readLe64(payload.constData() + offset);
        const quint16 magic = quint16((first >> 48) & 0xffffu);
        const quint8 version = quint8((first >> 40) & 0xffu);
        const quint8 type = quint8((first >> 32) & 0xffu);
        const quint16 words = quint16((first >> 16) & 0xffffu);

        if (magic != 0xBAADu || version != 0x01u || words == 0u) {
            record.error = QStringLiteral("Invalid DMA record header at byte %1").arg(offset);
            records.push_back(record);
            break;
        }

        const int bytes = int(words) * 8;
        if ((offset + bytes) > payload.size()) {
            record.error = QStringLiteral("Truncated DMA record at byte %1").arg(offset);
            records.push_back(record);
            break;
        }

        QVector<quint64> wordValues;
        wordValues.reserve(words);
        for (int i = 0; i < int(words); ++i) {
            wordValues.push_back(readLe64(payload.constData() + offset + (i * 8)));
        }

        record.raw = payload.mid(offset, bytes);
        record.type = type;
        record.wordCount = words;

        if (type == 0x01 && words == 12u) {
            decodeSummary(wordValues, &record);
            record.valid = true;
        } else if (type == 0x02 && words == 4u) {
            decodePsdInput(wordValues, &record);
            record.valid = true;
        } else if (type == 0x03 && words == 4u) {
            decodeCic(wordValues, &record);
            record.valid = true;
        } else {
            record.kind = QStringLiteral("unknown");
            record.error = QStringLiteral("Unsupported DMA record type %1 words %2").arg(type).arg(words);
        }

        records.push_back(record);
        offset += bytes;
    }

    if (offset < payload.size() && payload.size() - offset < 8) {
        DecodedDmaRecord r; r.error = QStringLiteral("Trailing partial DMA word at byte %1").arg(offset); records.append(r);
    }
    return records;
}

QString DmaDecoder::csvHeader()
{
    return QStringLiteral("kind,valid,error,cycle,frame_id,decision_frame_id,flags,bw_span_mhz,bw_edge_mhz,active_bins,frame_bins,overflow_count,low_signed_bin,high_signed_bin,peak_signed_bin,peak_power,min_power,total_power,active_power,decimation_m,candidate_m,stable_count,active_m,gain_shift,i,q,flag_names,records_emitted,bw_span_bins,bw_edge_bins,decision_edge_bins\n");
}

QString DmaDecoder::toCsvLine(const DecodedDmaRecord &record)
{
    const auto q = [](const QString &s) {
        QString out = s;
        out.replace('"', "\"\"");
        return QStringLiteral("\"%1\"").arg(out);
    };

    QStringList cols;
    cols << q(record.kind)
         << (record.valid ? QStringLiteral("1") : QStringLiteral("0"))
         << q(record.error)
         << QString::number(record.cycleCount)
         << QString::number(record.frameId)
         << QString::number(record.decisionFrameId)
         << QString::number(record.flags)
         << QLocale::c().toString(record.bwSpanMHz, 'f', 6)
         << QLocale::c().toString(record.bwEdgeMHz, 'f', 6)
         << QString::number(record.activeBinCount)
         << QString::number(record.frameBinCount)
         << QString::number(record.overflowCount)
         << QString::number(record.lowSignedBin)
         << QString::number(record.highSignedBin)
         << QString::number(record.peakSignedBin)
         << QString::number(record.peakPower)
         << QString::number(record.minPower)
         << QString::number(record.totalPower)
         << QString::number(record.activePower)
         << QString::number(record.decimationFactor)
         << QString::number(record.candidateFactor)
         << QString::number(record.stableCount)
         << QString::number(record.activeDecimationFactor)
         << QString::number(record.activeGainShift)
         << QString::number(record.mI)
         << QString::number(record.mQ)
         << q(record.flagNames.join('|'))
         << QString::number(record.recordsEmitted)
         << QString::number(record.bwSpanBins)
         << QString::number(record.bwEdgeBins)
         << QString::number(record.decisionEdgeBins);

    return cols.join(',') + QLatin1Char('\n');
}
