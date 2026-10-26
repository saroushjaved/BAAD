#ifndef BAAD_SESSION_RECORDER_H
#define BAAD_SESSION_RECORDER_H
#include <QtCore/QFile>
#include <QtCore/QJsonObject>
#include "burst_transfer.h"
#include "dma_decoder.h"

// Flush every append and atomically replace metadata. Files are durable across
// ordinary app crashes; OS/power-loss durability still depends on the filesystem.
class SessionRecorder {
public:
    ~SessionRecorder();
    bool start(const QString &parentDirectory, const QJsonObject &metadata);
    void close();
    bool active() const { return m_active; }
    QString directory() const { return m_dir; }
    QString error() const { return m_error; }
    bool raw(const QByteArray &data, bool tx);
    bool event(const QString &kind, const QJsonObject &details = {});
    bool summary(const DecodedDmaRecord &record);
    bool metadata(const QString &key, const QJsonObject &value);
    bool capture(const QByteArray &bytes, const BurstRecord &record, const QString &failure = {});
    bool testRun(const QString &caseId, const QJsonObject &configuration);
private:
    bool append(QFile &file, const QByteArray &data);
    bool writeAtomic(const QString &name, const QByteArray &data);
    bool manifest();
    bool fail(const QString &message);
    QString m_dir, m_error;
    bool m_active = false;
    QJsonObject m_metadata;
    QFile m_rx, m_tx, m_events, m_summary, m_tests;
    quint64 m_summaryCount = 0, m_captureCount = 0;
};
#endif
