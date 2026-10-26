#include "burst_transfer.h"
#include <QtCore/QLocale>
#include <cstring>
#include <algorithm>

static quint64 le64(const char *p) {
    quint64 v = 0;
    for (int i = 7; i >= 0; --i) v = (v << 8) | quint8(p[i]);
    return v;
}
static quint32 crc32(const QByteArray &v) {
    return baad_crc32(reinterpret_cast<const uint8_t *>(v.constData()), quint32(v.size()));
}
void BurstTransfer::reset() { m_ready = {}; m_data.clear(); m_active = false; }
bool BurstTransfer::begin(const QByteArray &payload, QString *error) {
    if (payload.size() != sizeof(BaadCaptureReady)) { *error = "Malformed CAPTURE_READY"; return false; }
    BaadCaptureReady r = {};
    memcpy(&r, payload.constData(), sizeof(r));
    if (r.total_bytes < (256u + 10u) * 8u || r.total_bytes > (BAAD_BURST_MAX_SAMPLES + 10u) * 8u || r.total_bytes % 8u || r.flags > 65535u) {
        *error = "CAPTURE_READY count or flags out of bounds"; return false;
    }
    if (m_active) {
        if (memcmp(&r, &m_ready, sizeof(r)) == 0) return true;
        *error = "CAPTURE_READY changed during transfer"; return false;
    }
    m_ready = r; m_active = true; m_data.reserve(int(r.total_bytes)); return true;
}
QByteArray BurstTransfer::nextRequest() const {
    if (!m_active || complete()) return {};
    BaadReadCapture r = {m_ready.capture_id, quint32(m_data.size()),
        quint16(std::min(quint32(BAAD_BURST_CHUNK_BYTES), m_ready.total_bytes - quint32(m_data.size()))), 0};
    return QByteArray(reinterpret_cast<const char *>(&r), sizeof(r));
}
BurstTransfer::Result BurstTransfer::accept(const QByteArray &payload, QString *error) {
    if (!m_active || payload.size() < 12) { *error = "Unexpected or short capture chunk"; return Error; }
    BaadCaptureChunk c = {};
    memcpy(&c, payload.constData(), size_t(std::min(payload.size(), qsizetype(sizeof(c)))));
    if (c.capture_id != m_ready.capture_id || c.reserved || !c.length || c.length > BAAD_BURST_CHUNK_BYTES ||
        payload.size() != 12 + c.length || c.offset > m_ready.total_bytes || c.length > m_ready.total_bytes - c.offset) {
        *error = "Capture chunk ID, range or length mismatch"; return Error;
    }
    if (c.offset < quint32(m_data.size())) {
        if (c.offset + c.length <= quint32(m_data.size()) && m_data.mid(c.offset, c.length) == payload.mid(12)) return Duplicate;
        *error = "Conflicting duplicate capture chunk"; return Error;
    }
    if (c.offset != quint32(m_data.size())) { *error = "Out-of-order capture chunk"; return Error; }
    const quint32 expected = std::min(quint32(BAAD_BURST_CHUNK_BYTES), m_ready.total_bytes - c.offset);
    if (c.length != expected) { *error = "Capture chunk does not match requested length"; return Error; }
    m_data.append(payload.constData() + 12, c.length);
    if (!complete()) return More;
    if (crc32(m_data) != m_ready.crc32) { *error = "Full capture CRC32 mismatch"; return Error; }
    const BurstRecord r = record();
    if (!r.integrityValid) { *error = r.error; return Error; }
    return Complete;
}
BurstRecord BurstTransfer::record() const {
    BurstRecord r = BurstRecord::decode(m_data);
    if (r.integrityValid && (r.captureId != m_ready.capture_id || r.flags != m_ready.flags || crc32(m_data) != m_ready.crc32)) {
        r.integrityValid = r.scienceValid = false; r.error = "Capture metadata/full-record CRC mismatch";
    }
    return r;
}
BurstRecord BurstRecord::decode(const QByteArray &bytes) {
    BurstRecord r;
    auto fail = [&r](const QString &why) { r.error = why; return r; };
    if (bytes.size() < (256 + 10) * 8 || bytes.size() > (8192 + 10) * 8 || bytes.size() % 8) return fail("Burst length outside bounds");
    auto w = [&bytes](int n) { return le64(bytes.constData() + n * 8); };
    const quint64 h = w(0), meta = w(4);
    const quint32 n = quint32(w(1));
    if ((h >> 32) != 0xbaad0204u || ((h >> 16) & 65535u) * 8 != quint64(bytes.size()) ||
        n < 256 || n > 8192 || (n + 10) * 8 != quint32(bytes.size())) return fail("Burst header/count mismatch");
    r.flags = quint16(h); r.captureId = quint32(w(1) >> 32); r.startCycle = w(2); r.endCycle = w(3);
    r.sampleRate = quint32(meta >> 32); r.m = quint16(meta >> 16); r.gain = quint8(meta >> 8); r.source = quint8(meta);
    r.frameId = quint32(w(5) >> 32);
    if (r.sampleRate != BAAD_SYSTEM_SAMPLE_RATE_HZ || r.source > 1 ||
        (r.m != 1 && r.m != 2 && r.m != 4 && r.m != 8 && r.m != 16) ||
        r.gain != (r.m == 1 ? 0 : r.m == 2 ? 3 : r.m == 4 ? 6 : r.m == 8 ? 9 : 12) ||
        quint32(w(5)) != 0 || w(6) != 0x0000000100000008ull || w(7) != 0)
        return fail("Burst metadata/version incompatible");
    const quint64 trailer = w(8 + int(n)), tail = w(9 + int(n));
    if ((trailer >> 32) != 0x454e4421u || quint16(trailer >> 16) != n || quint16(trailer) != r.flags ||
        (tail >> 32) != 0x43524332u || quint32(tail) != crc32(bytes.first(bytes.size() - 8))) return fail("Burst trailer/count/inner CRC32 mismatch");
    bool cadence = true;
    r.samples.reserve(int(n));
    quint32 previous = 0;
    for (quint32 j = 0; j < n; ++j) {
        quint64 sample = w(8 + int(j));
        BurstSample s = {quint32(sample >> 32), qint16(sample), qint16(sample >> 16)};
        if ((j == 0 && s.offset != 0) || (j && s.offset - previous != (r.source ? r.m : 1))) cadence = false;
        previous = s.offset; r.samples.append(s);
    }
    if (r.endCycle < r.startCycle || r.endCycle - r.startCycle != previous) return fail("Capture start/end cycle metadata mismatch");
    r.integrityValid = true;
    r.scienceValid = r.flags == 0 && cadence;
    if (r.flags) r.error = QStringLiteral("Capture invalidated by hardware flags 0x%1; preserve, do not use for steady-state metrics").arg(r.flags, 4, 16, QLatin1Char('0'));
    else if (!cadence) r.error = "Non-contiguous sample cadence; preserve, do not use for steady-state metrics";
    return r;
}
QString BurstRecord::toCsv() const {
    QString out = "capture_id,source,sample_index,cycle,offset_cycles,time_s,i,q,m,gain_shift,flags,science_valid\n";
    for (int j = 0; j < samples.size(); ++j) {
        const auto &s = samples[j];
        out += QStringLiteral("%1,%2,%3,%4,%5,%6,%7,%8,%9,%10,%11,%12\n")
            .arg(captureId).arg(source ? "cic" : "psd_input").arg(j).arg(startCycle + s.offset).arg(s.offset)
            .arg(QLocale::c().toString(double(s.offset) / sampleRate, 'g', 17))
            .arg(s.i).arg(s.q).arg(m).arg(gain).arg(flags).arg(scienceValid ? 1 : 0);
    }
    return out;
}
