#include "session_recorder.h"
#include <QtCore/QDateTime>
#include <QtCore/QDir>
#include <QtCore/QJsonDocument>
#include <QtCore/QSaveFile>
#include <QtCore/QUuid>

static QString utc() { return QDateTime::currentDateTimeUtc().toString(Qt::ISODateWithMs); }
static QByteArray json(const QJsonObject &o) { return QJsonDocument(o).toJson(QJsonDocument::Indented); }
SessionRecorder::~SessionRecorder() { close(); }
bool SessionRecorder::fail(const QString &message) { if (m_error.isEmpty()) m_error = message; return false; }
bool SessionRecorder::append(QFile &file, const QByteArray &data) {
    if (!m_error.isEmpty()) return false;
    if (!file.isOpen() || file.write(data) != data.size() || !file.flush()) return fail("Session write failed: " + file.fileName() + ": " + file.errorString());
    return true;
}
bool SessionRecorder::writeAtomic(const QString &name, const QByteArray &data) {
    if (!m_error.isEmpty()) return false;
    QSaveFile file(QDir(m_dir).filePath(name));
    if (!file.open(QIODevice::WriteOnly) || file.write(data) != data.size() || !file.commit()) return fail("Session atomic write failed: " + file.fileName() + ": " + file.errorString());
    return true;
}
bool SessionRecorder::manifest() {
    m_metadata["summary_records"] = QString::number(m_summaryCount);
    m_metadata["capture_attempts_saved"] = QString::number(m_captureCount);
    return writeAtomic("manifest.json", json(m_metadata));
}
bool SessionRecorder::start(const QString &parent, const QJsonObject &metadata) {
    close(); m_error.clear(); m_summaryCount = m_captureCount = 0;
    const QString id = QDateTime::currentDateTimeUtc().toString("yyyyMMddTHHmmsszzzZ") + "_" + QUuid::createUuid().toString(QUuid::WithoutBraces).left(8);
    m_dir = QDir(parent).absoluteFilePath(id);
    if (!QDir().mkpath(m_dir)) return fail("Cannot create session directory: " + m_dir);
    m_metadata = metadata; m_metadata["session_id"] = id; m_metadata["started_utc"] = utc();
    m_metadata["format_version"] = 2; m_metadata["board_acceptance"] = "pending user test";
    m_metadata["status"] = "open";
    QFile *files[] = {&m_rx, &m_tx, &m_events, &m_summary, &m_tests};
    const char *names[] = {"uart_rx.bin", "uart_tx.bin", "events.jsonl", "summary.csv", "test_runs.jsonl"};
    for (int i = 0; i < 5; ++i) {
        files[i]->setFileName(QDir(m_dir).filePath(QString::fromLatin1(names[i])));
        if (!files[i]->open(QIODevice::WriteOnly | QIODevice::NewOnly)) { fail("Cannot open session file: " + files[i]->fileName()); close(); return false; }
    }
    m_active = true;
    if (!append(m_summary, "host_utc," + DmaDecoder::csvHeader().toUtf8()) || !manifest() || !event("session_started")) { close(); return false; }
    return true;
}
void SessionRecorder::close() {
    if (m_active && m_error.isEmpty()) {
        event("session_closed"); m_metadata["closed_utc"] = utc(); m_metadata["status"] = "closed"; manifest();
    }
    m_rx.close(); m_tx.close(); m_events.close(); m_summary.close(); m_tests.close(); m_active = false;
}
bool SessionRecorder::raw(const QByteArray &data, bool tx) { return m_active && append(tx ? m_tx : m_rx, data); }
bool SessionRecorder::event(const QString &kind, const QJsonObject &details) {
    QJsonObject o = details; o["utc"] = utc(); o["event"] = kind;
    return m_active && append(m_events, QJsonDocument(o).toJson(QJsonDocument::Compact) + '\n');
}
bool SessionRecorder::summary(const DecodedDmaRecord &record) {
    if (!m_active || !append(m_summary, (utc() + ',' + DmaDecoder::toCsvLine(record)).toUtf8())) return false;
    ++m_summaryCount; return true;
}
bool SessionRecorder::metadata(const QString &key, const QJsonObject &value) { m_metadata[key] = value; return m_active && manifest(); }
bool SessionRecorder::capture(const QByteArray &bytes, const BurstRecord &record, const QString &failure) {
    if (!m_active) return false;
    ++m_captureCount;
    const QString stem = QStringLiteral("capture_%1_id%2").arg(m_captureCount, 4, 10, QLatin1Char('0')).arg(record.captureId);
    QJsonObject meta = {{"capture_id", double(record.captureId)}, {"integrity_valid", record.integrityValid},
        {"science_valid", record.scienceValid && failure.isEmpty()}, {"validation_message", failure.isEmpty() ? record.error : failure},
        {"flags", record.flags}, {"samples", record.samples.size()}, {"source", record.source ? "cic" : "psd_input"},
        {"sample_rate_hz", double(record.sampleRate)}, {"m", record.m}, {"gain_shift", record.gain},
        {"start_cycle", QString::number(record.startCycle)}, {"end_cycle", QString::number(record.endCycle)},
        {"frame_id", double(record.frameId)}, {"crc32", QString::number(baad_crc32(reinterpret_cast<const uint8_t *>(bytes.constData()), quint32(bytes.size())), 16)}};
    if (!writeAtomic(stem + ".bin", bytes) || !writeAtomic(stem + ".json", json(meta))) return false;
    BurstRecord csvRecord = record;
    if (!failure.isEmpty()) csvRecord.scienceValid = false;
    if (record.integrityValid && !writeAtomic(stem + ".csv", csvRecord.toCsv().toUtf8())) return false;
    return event("capture_saved", {{"stem", stem}, {"validation", meta}}) && manifest();
}
bool SessionRecorder::testRun(const QString &caseId, const QJsonObject &configuration) {
    QJsonObject o = {{"utc", utc()}, {"case_id", caseId}, {"configuration", configuration},
        {"result", "pending board observations; no automatic pass claim"}};
    return m_active && append(m_tests, QJsonDocument(o).toJson(QJsonDocument::Compact) + '\n');
}
