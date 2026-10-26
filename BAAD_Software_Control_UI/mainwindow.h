#ifndef BAAD_MAIN_WINDOW_H
#define BAAD_MAIN_WINDOW_H

#include <QtCore/QByteArray>
#include <QtCore/QVector>
#include <QtWidgets/QMainWindow>

#include "dds_math.h"
#include "dma_decoder.h"
#include "protocol_codec.h"
#include "burst_transfer.h"
#include "session_recorder.h"

class QCheckBox;
class QComboBox;
class QDoubleSpinBox;
class QLabel;
class QLineEdit;
class QPushButton;
class QPlainTextEdit;
class QSpinBox;
class QTableWidget;
class PlotWidget;
class SerialBackend;
class QTimer;
class QCloseEvent;

class MainWindow : public QMainWindow {
    Q_OBJECT

public:
    explicit MainWindow(QWidget *parent = nullptr);

protected:
    void closeEvent(QCloseEvent *event) override;

private slots:
    void refreshPorts();
    void connectOrDisconnect();
    void sendHello();
    void applyDds();
    void startStream();
    void stopStream();
    void requestStatus();
    void saveRecords();
    void updateTones();
    void onSerialData(const QByteArray &data);
    void onSerialError(const QString &message);
    void onSerialOpenChanged(bool open);
    void startBurst();
    void abortBurst();
    void retryBurst();

private:
    void buildUi();
    void sendPacket(quint8 type, const QByteArray &payload = {});
    void handlePacket(const BaadPacket &packet);
    void handleAck(const BaadPacket &packet, bool positive);
    void handleStatus(const QByteArray &payload);
    void handleDmaRecord(const QByteArray &payload);
    void appendLog(const QString &line);
    void appendRecordRow(const DecodedDmaRecord &record);
    QVector<DdsTone> currentTones() const;
    void updateEnabled();
    void pullChunk();
    void finishBurst(const QString &failure = {});
    void checkRecording();
    QJsonObject configuration() const;

    SerialBackend *m_serial = nullptr;
    ProtocolCodec m_codec;
    quint16 m_nextSequence = 0;
    quint64 m_recordTotal = 0;
    bool m_captureStreamRequested = false;
    bool m_identityOk = false, m_burstBusy = false, m_haveRxSequence = false;
    quint16 m_lastRxSequence = 0;
    quint8 m_controlPending = 0;
    QJsonObject m_pendingConfiguration;
    BurstTransfer m_burst;
    SessionRecorder m_session;
    QTimer *m_burstTimer = nullptr;
    QTimer *m_controlTimer = nullptr;
    int m_retries = 0;
    QComboBox *m_presetCombo = nullptr;
    QComboBox *m_sourceCombo = nullptr;
    QSpinBox *m_sampleCountSpin = nullptr;
    QPushButton *m_burstButton = nullptr, *m_abortButton = nullptr;
    QLabel *m_burstLabel = nullptr;

    QComboBox *m_portCombo = nullptr;
    QComboBox *m_baudCombo = nullptr;
    QPushButton *m_refreshButton = nullptr;
    QPushButton *m_connectButton = nullptr;
    QPushButton *m_helloButton = nullptr;
    QPushButton *m_statusButton = nullptr;

    QDoubleSpinBox *m_bandwidthSpin = nullptr;
    QTableWidget *m_toneTable = nullptr;
    QPushButton *m_applyButton = nullptr;

    QLineEdit *m_thresholdEdit = nullptr;
    QSpinBox *m_packetCountSpin = nullptr;
    QSpinBox *m_updateIntervalSpin = nullptr;
    QPushButton *m_startButton = nullptr;
    QPushButton *m_stopButton = nullptr;
    QPushButton *m_saveButton = nullptr;

    QLabel *m_connectionLabel = nullptr;
    QLabel *m_frameLabel = nullptr;
    QLabel *m_bandwidthLabel = nullptr;
    QLabel *m_decimationLabel = nullptr;
    QLabel *m_flagsLabel = nullptr;
    QLabel *m_recordCountLabel = nullptr;
    QLabel *m_dmaStatusLabel = nullptr;

    QTableWidget *m_recordTable = nullptr;
    PlotWidget *m_bandwidthPlot = nullptr;
    PlotWidget *m_psdInputIPlot = nullptr;
    PlotWidget *m_psdInputQPlot = nullptr;
    PlotWidget *m_cicIPlot = nullptr;
    PlotWidget *m_cicQPlot = nullptr;
    QPlainTextEdit *m_log = nullptr;
};

#endif
