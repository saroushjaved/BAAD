#include "mainwindow.h"

#include <QtCore/QDateTime>
#include <QtCore/QFile>
#include <QtCore/QSaveFile>
#include <QtCore/QTextStream>
#include <QtCore/QCoreApplication>
#include <QtCore/QCryptographicHash>
#include <QtCore/QDir>
#include <QtCore/QStandardPaths>
#include <QtCore/QTimer>
#include <QtCore/QJsonArray>
#include <QtCore/QJsonDocument>
#include <QtGui/QDesktopServices>
#include <QtGui/QCloseEvent>
#include <QtWidgets/QCheckBox>
#include <QtWidgets/QComboBox>
#include <QtWidgets/QAbstractItemView>
#include <QtWidgets/QDoubleSpinBox>
#include <QtWidgets/QFileDialog>
#include <QtWidgets/QFormLayout>
#include <QtWidgets/QFrame>
#include <QtWidgets/QGridLayout>
#include <QtWidgets/QGroupBox>
#include <QtWidgets/QHeaderView>
#include <QtWidgets/QHBoxLayout>
#include <QtWidgets/QLabel>
#include <QtWidgets/QLineEdit>
#include <QtWidgets/QMessageBox>
#include <QtWidgets/QPlainTextEdit>
#include <QtWidgets/QPushButton>
#include <QtWidgets/QSpinBox>
#include <QtWidgets/QSplitter>
#include <QtWidgets/QTableWidget>
#include <QtWidgets/QTabWidget>
#include <QtWidgets/QVBoxLayout>

#include <algorithm>
#include <cmath>
#include <cstring>

#include "plot_widget.h"
#include "serial_backend.h"

static QByteArray structBytes(const void *data, qsizetype size)
{
    return QByteArray(reinterpret_cast<const char *>(data), int(size));
}

static QString appStyleSheet()
{
    return QStringLiteral(R"(
        QWidget#appRoot {
            background: #f5f7fa;
            color: #1f2933;
        }

        QFrame#statusStrip {
            background: #ffffff;
            border: 1px solid #d8dee6;
            border-radius: 7px;
        }

        QLabel#appTitle {
            color: #111827;
            font-size: 14pt;
            font-weight: 700;
        }

        QLabel#statusKey {
            color: #667085;
            font-weight: 600;
        }

        QGroupBox {
            background: #ffffff;
            border: 1px solid #d8dee6;
            border-radius: 7px;
            margin-top: 8px;
            padding-top: 8px;
        }

        QGroupBox::title {
            subcontrol-origin: margin;
            subcontrol-position: top left;
            left: 12px;
            padding: 0 4px;
            color: #354052;
            background: #ffffff;
            font-weight: 600;
        }

        QLabel {
            color: #344054;
        }

        QLabel#valueLabel {
            color: #111827;
            font-weight: 600;
            padding: 2px 0;
        }

        QLineEdit,
        QComboBox,
        QSpinBox,
        QDoubleSpinBox {
            min-height: 30px;
            padding: 2px 7px;
            border: 1px solid #cfd6df;
            border-radius: 5px;
            background: #fbfcfd;
            color: #111827;
            selection-background-color: #2563eb;
            selection-color: #ffffff;
        }

        QLineEdit:focus,
        QComboBox:focus,
        QSpinBox:focus,
        QDoubleSpinBox:focus {
            border-color: #2563eb;
            background: #ffffff;
        }

        QLineEdit:disabled,
        QComboBox:disabled,
        QSpinBox:disabled,
        QDoubleSpinBox:disabled {
            color: #475467;
            background: #f1f4f8;
            border-color: #d5dce5;
        }

        QComboBox {
            padding-right: 28px;
        }

        QComboBox::drop-down {
            subcontrol-origin: padding;
            subcontrol-position: top right;
            width: 24px;
            border-left: 1px solid #d5dce5;
            border-top-right-radius: 5px;
            border-bottom-right-radius: 5px;
            background: #f8fafc;
        }

        QComboBox::down-arrow {
            width: 0;
            height: 0;
            border-left: 4px solid transparent;
            border-right: 4px solid transparent;
            border-top: 5px solid #475467;
            margin-right: 8px;
        }

        QComboBox QAbstractItemView {
            color: #111827;
            background: #ffffff;
            border: 1px solid #cfd6df;
            selection-background-color: #dbeafe;
            selection-color: #111827;
            outline: 0;
        }

        QPushButton {
            min-height: 31px;
            padding: 4px 12px;
            border-radius: 5px;
            border: 1px solid #cbd5e1;
            background: #ffffff;
            color: #1f2937;
            font-weight: 600;
        }

        QPushButton:hover {
            background: #f8fafc;
            border-color: #94a3b8;
        }

        QPushButton:disabled {
            color: #98a2b3;
            background: #eef1f4;
            border-color: #d9dee5;
        }

        QPushButton#primaryButton {
            color: #ffffff;
            border-color: #1d4ed8;
            background: #2563eb;
        }

        QPushButton#primaryButton:hover {
            background: #1d4ed8;
        }

        QPushButton#successButton {
            color: #ffffff;
            border-color: #047857;
            background: #059669;
        }

        QPushButton#successButton:hover {
            background: #047857;
        }

        QPushButton#dangerButton {
            color: #ffffff;
            border-color: #b91c1c;
            background: #dc2626;
        }

        QPushButton#dangerButton:hover {
            background: #b91c1c;
        }

        QCheckBox {
            spacing: 8px;
            color: #273444;
            min-height: 24px;
        }

        QTableWidget,
        QPlainTextEdit {
            background: #ffffff;
            border: 1px solid #d8dee6;
            border-radius: 7px;
            color: #1f2937;
            gridline-color: #e8edf3;
            selection-background-color: #dbeafe;
            selection-color: #111827;
        }

        QTableWidget {
            alternate-background-color: #f8fafc;
        }

        QHeaderView::section {
            background: #eef2f6;
            color: #344054;
            border: none;
            border-right: 1px solid #d8dee6;
            border-bottom: 1px solid #d8dee6;
            padding: 6px 8px;
            font-weight: 600;
        }

        QPlainTextEdit {
            font-family: Consolas, "Cascadia Mono", monospace;
            font-size: 9pt;
            padding: 8px;
        }

        QSplitter::handle {
            background: #e1e7ef;
            height: 6px;
        }
    )");
}

static void tuneFormLayout(QFormLayout *layout)
{
    layout->setContentsMargins(12, 16, 12, 12);
    layout->setHorizontalSpacing(10);
    layout->setVerticalSpacing(7);
    layout->setLabelAlignment(Qt::AlignLeft);
    layout->setFieldGrowthPolicy(QFormLayout::AllNonFixedFieldsGrow);
}

static void tuneGridLayout(QGridLayout *layout)
{
    layout->setContentsMargins(12, 16, 12, 12);
    layout->setHorizontalSpacing(8);
    layout->setVerticalSpacing(7);
}

static void markValueLabel(QLabel *label)
{
    label->setObjectName(QStringLiteral("valueLabel"));
    label->setTextInteractionFlags(Qt::TextSelectableByMouse);
}

static void styleButton(QPushButton *button, const char *role)
{
    button->setObjectName(QString::fromLatin1(role));
    button->setCursor(Qt::PointingHandCursor);
}

static QLabel *makeStatusKey(const QString &text)
{
    auto *label = new QLabel(text);
    label->setObjectName(QStringLiteral("statusKey"));
    return label;
}

MainWindow::MainWindow(QWidget *parent)
    : QMainWindow(parent)
    , m_serial(new SerialBackend(this))
{
    buildUi();
    refreshPorts();
    updateTones();

    connect(m_serial, &SerialBackend::dataReceived, this, &MainWindow::onSerialData);
    connect(m_serial, &SerialBackend::errorOccurred, this, &MainWindow::onSerialError);
    connect(m_serial, &SerialBackend::openChanged, this, &MainWindow::onSerialOpenChanged);
    m_burstTimer = new QTimer(this);
    m_burstTimer->setInterval(1000);
    connect(m_burstTimer, &QTimer::timeout, this, &MainWindow::retryBurst);
    m_controlTimer = new QTimer(this);
    m_controlTimer->setSingleShot(true);
    m_controlTimer->setInterval(2000);
    connect(m_controlTimer, &QTimer::timeout, this, [this] {
        if (!m_controlPending || m_burstBusy) return;
        appendLog(QStringLiteral("Command %1 acknowledgement timed out; outcome unknown. Inspect status before retrying.").arg(m_controlPending));
        m_controlPending = 0;
        m_codec.reset();
        requestStatus(); updateEnabled(); checkRecording();
    });
}

void MainWindow::buildUi()
{
    setWindowTitle(QStringLiteral("BAAD Board Test — build 26091301 / protocol 2"));
    resize(1280, 900);
    setMinimumSize(1120, 760);
    setStyleSheet(appStyleSheet());

    auto *central = new QWidget(this);
    central->setObjectName(QStringLiteral("appRoot"));
    auto *root = new QVBoxLayout(central);
    root->setContentsMargins(16, 14, 16, 16);
    root->setSpacing(10);

    auto *statusStrip = new QFrame();
    statusStrip->setObjectName(QStringLiteral("statusStrip"));
    auto *statusStripLayout = new QHBoxLayout(statusStrip);
    statusStripLayout->setContentsMargins(14, 8, 14, 8);
    statusStripLayout->setSpacing(12);

    auto *titleLabel = new QLabel(QStringLiteral("BAAD Control"));
    titleLabel->setObjectName(QStringLiteral("appTitle"));
    m_connectionLabel = new QLabel(QStringLiteral("Disconnected"));
    m_frameLabel = new QLabel(QStringLiteral("-"));
    m_bandwidthLabel = new QLabel(QStringLiteral("-"));
    m_decimationLabel = new QLabel(QStringLiteral("-"));
    m_flagsLabel = new QLabel(QStringLiteral("-"));
    m_recordCountLabel = new QLabel(QStringLiteral("0"));
    m_dmaStatusLabel = new QLabel(QStringLiteral("-"));
    markValueLabel(m_connectionLabel);
    markValueLabel(m_frameLabel);
    markValueLabel(m_bandwidthLabel);
    markValueLabel(m_decimationLabel);
    markValueLabel(m_flagsLabel);
    markValueLabel(m_recordCountLabel);
    markValueLabel(m_dmaStatusLabel);

    statusStripLayout->addWidget(titleLabel);
    statusStripLayout->addSpacing(10);
    statusStripLayout->addWidget(makeStatusKey(QStringLiteral("Link")));
    statusStripLayout->addWidget(m_connectionLabel);
    statusStripLayout->addSpacing(8);
    statusStripLayout->addWidget(makeStatusKey(QStringLiteral("Frame")));
    statusStripLayout->addWidget(m_frameLabel);
    statusStripLayout->addWidget(makeStatusKey(QStringLiteral("BW")));
    statusStripLayout->addWidget(m_bandwidthLabel, 1);
    statusStripLayout->addWidget(makeStatusKey(QStringLiteral("M")));
    statusStripLayout->addWidget(m_decimationLabel);
    statusStripLayout->addWidget(makeStatusKey(QStringLiteral("Records")));
    statusStripLayout->addWidget(m_recordCountLabel);
    statusStripLayout->addWidget(makeStatusKey(QStringLiteral("DMA")));
    statusStripLayout->addWidget(m_dmaStatusLabel);
    statusStripLayout->addStretch(1);
    root->addWidget(statusStrip, 0);

    auto *top = new QGridLayout();
    top->setHorizontalSpacing(12);
    top->setVerticalSpacing(10);
    root->addLayout(top);

    auto *serialBox = new QGroupBox(QStringLiteral("Serial"));
    auto *serialLayout = new QGridLayout(serialBox);
    tuneGridLayout(serialLayout);
    m_portCombo = new QComboBox();
    m_baudCombo = new QComboBox();
    m_baudCombo->addItem(QStringLiteral("115200"));
    m_refreshButton = new QPushButton(QStringLiteral("Refresh"));
    m_connectButton = new QPushButton(QStringLiteral("Connect"));
    m_helloButton = new QPushButton(QStringLiteral("HELLO"));
    m_statusButton = new QPushButton(QStringLiteral("Status"));
    styleButton(m_refreshButton, "secondaryButton");
    styleButton(m_connectButton, "primaryButton");
    styleButton(m_helloButton, "secondaryButton");
    styleButton(m_statusButton, "secondaryButton");

    serialLayout->addWidget(new QLabel(QStringLiteral("Port")), 0, 0);
    serialLayout->addWidget(m_portCombo, 0, 1);
    serialLayout->addWidget(new QLabel(QStringLiteral("Baud")), 1, 0);
    serialLayout->addWidget(m_baudCombo, 1, 1);
    serialLayout->addWidget(m_refreshButton, 0, 2);
    serialLayout->addWidget(m_connectButton, 1, 2);
    serialLayout->addWidget(m_helloButton, 0, 3);
    serialLayout->addWidget(m_statusButton, 1, 3);
    top->addWidget(serialBox, 0, 0, Qt::AlignTop);

    auto *ddsBox = new QGroupBox(QStringLiteral("DDS"));
    auto *ddsLayout = new QVBoxLayout(ddsBox);
    ddsLayout->setContentsMargins(14, 20, 14, 14);
    ddsLayout->setSpacing(10);
    auto *ddsForm = new QFormLayout();
    tuneFormLayout(ddsForm);
    ddsForm->setContentsMargins(0, 0, 0, 0);
    m_bandwidthSpin = new QDoubleSpinBox();
    m_bandwidthSpin->setRange(0.001, 20.0);
    m_bandwidthSpin->setDecimals(3);
    m_bandwidthSpin->setSingleStep(0.5);
    m_bandwidthSpin->setSuffix(QStringLiteral(" MHz total"));
    m_bandwidthSpin->setValue(2.0);
    m_applyButton = new QPushButton(QStringLiteral("Apply DDS"));
    styleButton(m_applyButton, "primaryButton");
    ddsForm->addRow(QStringLiteral("Bandwidth"), m_bandwidthSpin);
    m_presetCombo = new QComboBox();
    m_presetCombo->addItems({"Custom", "B02 — 2 MHz (nominal M16)", "B04 — 4 MHz (nominal M8)", "B08 — 8 MHz (nominal M4)", "B16 — 16 MHz (nominal M2)"});
    m_presetCombo->setToolTip("Presets set existing six-tone DDS bandwidth only. Expected M is conditional on measured spectrum, threshold and guard; no automatic pass claim.");
    ddsForm->addRow(QStringLiteral("Test case"), m_presetCombo);
    ddsLayout->addLayout(ddsForm);

    m_toneTable = new QTableWidget(BAAD_DDS_COUNT, 4);
    m_toneTable->setHorizontalHeaderLabels({QStringLiteral("#"), QStringLiteral("Tone MHz"),
                                            QStringLiteral("PINC dec"), QStringLiteral("PINC hex")});
    m_toneTable->horizontalHeader()->setSectionResizeMode(QHeaderView::Stretch);
    m_toneTable->verticalHeader()->setVisible(false);
    m_toneTable->setEditTriggers(QAbstractItemView::NoEditTriggers);
    m_toneTable->setSelectionMode(QAbstractItemView::NoSelection);
    m_toneTable->setAlternatingRowColors(true);
    m_toneTable->setShowGrid(false);
    m_toneTable->setFrameShape(QFrame::NoFrame);
    m_toneTable->verticalHeader()->setDefaultSectionSize(26);
    m_toneTable->horizontalHeader()->setFixedHeight(32);
    m_toneTable->setMinimumHeight(164);
    m_toneTable->setMaximumHeight(188);
    ddsLayout->addWidget(m_toneTable);
    ddsLayout->addWidget(m_applyButton);
    top->addWidget(ddsBox, 0, 1);

    auto *captureBox = new QGroupBox(QStringLiteral("Capture"));
    auto *captureLayout = new QGridLayout(captureBox);
    tuneGridLayout(captureLayout);
    m_thresholdEdit = new QLineEdit(QStringLiteral("5000"));
    m_packetCountSpin = new QSpinBox();
    m_packetCountSpin->setRange(1, 4);
    m_packetCountSpin->setValue(3);
    m_updateIntervalSpin = new QSpinBox();
    m_updateIntervalSpin->setRange(50, 60000);
    m_updateIntervalSpin->setValue(200);
    m_updateIntervalSpin->setSuffix(QStringLiteral(" ms"));
    m_startButton = new QPushButton(QStringLiteral("Summaries"));
    m_stopButton = new QPushButton(QStringLiteral("Stop"));
    m_saveButton = new QPushButton(QStringLiteral("Result folder"));
    m_sourceCombo = new QComboBox();
    m_sourceCombo->addItems({"PSD input", "CIC output"});
    m_sampleCountSpin = new QSpinBox();
    m_sampleCountSpin->setRange(256, BAAD_BURST_MAX_SAMPLES);
    m_sampleCountSpin->setSingleStep(256);
    m_sampleCountSpin->setValue(4096);
    m_burstButton = new QPushButton("Capture burst");
    m_abortButton = new QPushButton("Abort burst");
    m_burstLabel = new QLabel("Contiguous bursts; all results saved automatically");
    m_burstLabel->setWordWrap(true);
    styleButton(m_startButton, "successButton");
    styleButton(m_stopButton, "dangerButton");
    styleButton(m_saveButton, "secondaryButton");
    captureLayout->addWidget(new QLabel(QStringLiteral("Threshold")), 0, 0);
    captureLayout->addWidget(m_thresholdEdit, 0, 1);
    captureLayout->addWidget(new QLabel(QStringLiteral("Packet records")), 0, 2);
    captureLayout->addWidget(m_packetCountSpin, 0, 3);
    captureLayout->addWidget(new QLabel(QStringLiteral("Interval")), 1, 0);
    captureLayout->addWidget(m_updateIntervalSpin, 1, 1);
    captureLayout->addWidget(new QLabel(QStringLiteral("Burst samples")), 1, 2);
    captureLayout->addWidget(m_sampleCountSpin, 1, 3);
    captureLayout->addWidget(m_sourceCombo, 2, 0, 1, 2);
    captureLayout->addWidget(m_burstButton, 2, 2);
    captureLayout->addWidget(m_abortButton, 2, 3);
    auto *buttonRow = new QWidget();
    auto *buttonLayout = new QGridLayout(buttonRow);
    buttonLayout->setContentsMargins(0, 0, 0, 0);
    buttonLayout->setHorizontalSpacing(8);
    buttonLayout->addWidget(m_startButton, 0, 0);
    buttonLayout->addWidget(m_stopButton, 0, 1);
    buttonLayout->addWidget(m_saveButton, 0, 2);
    captureLayout->addWidget(buttonRow, 3, 0, 1, 4);
    captureLayout->addWidget(m_burstLabel, 4, 0, 1, 4);
    captureLayout->setColumnStretch(1, 1);
    captureLayout->setColumnStretch(3, 1);
    top->addWidget(captureBox, 0, 2, Qt::AlignTop);

    top->setColumnStretch(0, 12);
    top->setColumnStretch(1, 22);
    top->setColumnStretch(2, 15);

    auto *splitter = new QSplitter(Qt::Vertical);
    splitter->setChildrenCollapsible(false);
    root->addWidget(splitter, 1);

    auto *mainPanel = new QWidget();
    auto *mainLayout = new QVBoxLayout(mainPanel);
    mainLayout->setContentsMargins(0, 0, 0, 0);
    mainLayout->setSpacing(10);
    auto *plotTabs = new QTabWidget();

    m_bandwidthPlot = new PlotWidget();
    m_bandwidthPlot->setTitle(QStringLiteral("Bandwidth span"));
    m_bandwidthPlot->setAxisLabels(QStringLiteral("MHz"), QStringLiteral("recent summary records"));
    m_bandwidthPlot->setLineColor(QColor(34, 94, 168));

    m_psdInputIPlot = new PlotWidget();
    m_psdInputIPlot->setTitle(QStringLiteral("PSD input I"));
    m_psdInputIPlot->setAxisLabels(QStringLiteral("int16"), QStringLiteral("recent input samples"));
    m_psdInputIPlot->setAutoRange();
    m_psdInputIPlot->setSquareAspect(true);
    m_psdInputIPlot->setLineColor(QColor(82, 45, 128));

    m_psdInputQPlot = new PlotWidget();
    m_psdInputQPlot->setTitle(QStringLiteral("PSD input Q"));
    m_psdInputQPlot->setAxisLabels(QStringLiteral("int16"), QStringLiteral("recent input samples"));
    m_psdInputQPlot->setAutoRange();
    m_psdInputQPlot->setSquareAspect(true);
    m_psdInputQPlot->setLineColor(QColor(168, 102, 22));

    m_cicIPlot = new PlotWidget();
    m_cicIPlot->setTitle(QStringLiteral("CIC output I"));
    m_cicIPlot->setAxisLabels(QStringLiteral("int16"), QStringLiteral("recent decimated samples"));
    m_cicIPlot->setAutoRange();
    m_cicIPlot->setSquareAspect(true);
    m_cicIPlot->setLineColor(QColor(0, 132, 122));

    m_cicQPlot = new PlotWidget();
    m_cicQPlot->setTitle(QStringLiteral("CIC output Q"));
    m_cicQPlot->setAxisLabels(QStringLiteral("int16"), QStringLiteral("recent decimated samples"));
    m_cicQPlot->setAutoRange();
    m_cicQPlot->setSquareAspect(true);
    m_cicQPlot->setLineColor(QColor(191, 87, 0));

    plotTabs->addTab(m_bandwidthPlot, "Bandwidth summaries");
    auto addPair = [plotTabs](PlotWidget *i, PlotWidget *q, const QString &name) {
        auto *page = new QWidget(); auto *layout = new QHBoxLayout(page);
        layout->addWidget(i); layout->addWidget(q); plotTabs->addTab(page, name);
    };
    addPair(m_psdInputIPlot, m_psdInputQPlot, "PSD input burst I/Q");
    addPair(m_cicIPlot, m_cicQPlot, "CIC output burst I/Q");
    mainLayout->addWidget(plotTabs, 1);

    m_recordTable = new QTableWidget(0, 9);
    m_recordTable->setHorizontalHeaderLabels({QStringLiteral("Type"), QStringLiteral("Frame"),
                                              QStringLiteral("Span MHz"), QStringLiteral("Edge MHz"),
                                              QStringLiteral("M"), QStringLiteral("Active bins"),
                                              QStringLiteral("I"), QStringLiteral("Q"),
                                              QStringLiteral("Flags")});
    m_recordTable->horizontalHeader()->setSectionResizeMode(QHeaderView::Stretch);
    m_recordTable->verticalHeader()->setVisible(false);
    m_recordTable->setEditTriggers(QAbstractItemView::NoEditTriggers);
    m_recordTable->setAlternatingRowColors(true);
    m_recordTable->setShowGrid(false);
    m_recordTable->setFrameShape(QFrame::NoFrame);
    m_recordTable->verticalHeader()->setDefaultSectionSize(24);
    m_recordTable->horizontalHeader()->setFixedHeight(32);
    m_recordTable->setMaximumHeight(118);
    m_recordTable->setMinimumHeight(94);
    mainLayout->addWidget(m_recordTable, 0);
    splitter->addWidget(mainPanel);

    m_log = new QPlainTextEdit();
    m_log->setReadOnly(true);
    m_log->setMaximumBlockCount(800);
    m_log->setPlaceholderText(QStringLiteral("Event log"));
    m_log->setMaximumHeight(96);
    splitter->addWidget(m_log);
    splitter->setStretchFactor(0, 4);
    splitter->setStretchFactor(1, 1);

    setCentralWidget(central);

    connect(m_refreshButton, &QPushButton::clicked, this, &MainWindow::refreshPorts);
    connect(m_connectButton, &QPushButton::clicked, this, &MainWindow::connectOrDisconnect);
    connect(m_helloButton, &QPushButton::clicked, this, &MainWindow::sendHello);
    connect(m_statusButton, &QPushButton::clicked, this, &MainWindow::requestStatus);
    connect(m_bandwidthSpin, qOverload<double>(&QDoubleSpinBox::valueChanged), this, &MainWindow::updateTones);
    connect(m_applyButton, &QPushButton::clicked, this, &MainWindow::applyDds);
    connect(m_startButton, &QPushButton::clicked, this, &MainWindow::startStream);
    connect(m_stopButton, &QPushButton::clicked, this, &MainWindow::stopStream);
    connect(m_saveButton, &QPushButton::clicked, this, &MainWindow::saveRecords);
    connect(m_burstButton, &QPushButton::clicked, this, &MainWindow::startBurst);
    connect(m_abortButton, &QPushButton::clicked, this, &MainWindow::abortBurst);
    connect(m_presetCombo, qOverload<int>(&QComboBox::currentIndexChanged), this, [this](int index) {
        if (index) m_bandwidthSpin->setValue(double(1u << index));
    });

    onSerialOpenChanged(false);
}

void MainWindow::refreshPorts()
{
    const QString current = m_portCombo->currentText();
    m_portCombo->clear();
    m_portCombo->addItems(SerialBackend::availablePorts());
    const int idx = m_portCombo->findText(current);
    if (idx >= 0) {
        m_portCombo->setCurrentIndex(idx);
    }
}

void MainWindow::connectOrDisconnect()
{
    if (m_serial->isOpen()) {
        if (m_identityOk) sendPacket(BAAD_PKT_STOP_STREAM);
        m_serial->closePort();
        return;
    }

    if (m_portCombo->currentText().isEmpty()) {
        QMessageBox::warning(this, QStringLiteral("Serial"), QStringLiteral("No COM port selected."));
        return;
    }

    const QString directory = QFileDialog::getExistingDirectory(this, "Choose parent folder for a new recorded test session",
        QStandardPaths::writableLocation(QStandardPaths::DocumentsLocation));
    if (directory.isEmpty()) return;
    auto hash = [](const QString &path) {
        QFile file(path);
        if (!file.open(QIODevice::ReadOnly)) return QStringLiteral("unavailable");
        QCryptographicHash h(QCryptographicHash::Sha256); h.addData(&file); return QString::fromLatin1(h.result().toHex());
    };
    QJsonObject metadata = {{"port", m_portCombo->currentText()}, {"baud", 115200}, {"protocol", int(BAAD_SERIAL_VERSION)},
        {"ui_build_id", QString::number(BAAD_BUILD_ID, 16)}, {"qt_version", qVersion()},
        {"executable_sha256", hash(QCoreApplication::applicationFilePath())},
        {"release_manifest_sha256", hash(QCoreApplication::applicationDirPath() + "/release_manifest.json")},
        {"timing_note", "Device cycles use nominal 62 MHz; host UTC is receipt time. Board measurement remains user supplied."}};
    if (!m_session.start(directory, metadata)) {
        QMessageBox::critical(this, "Recording required", m_session.error()); return;
    }
    appendLog("Recording session: " + m_session.directory());
    if (!m_serial->openPort(m_portCombo->currentText(), 115200)) m_session.close();
}

void MainWindow::sendHello()
{
    if (m_burstBusy) return;
    m_identityOk = false; updateEnabled();
    sendPacket(BAAD_PKT_HELLO);
}

void MainWindow::applyDds()
{
    if (!m_identityOk || m_burstBusy || m_controlPending) return;
    const QVector<DdsTone> tones = currentTones();
    QString error;
    if (!DdsMath::tonesInRange(tones, BAAD_SYSTEM_SAMPLE_RATE_HZ, &error)) {
        QMessageBox::warning(this, QStringLiteral("DDS"), error);
        return;
    }

    BaadSetDdsPayload payload = {};
    payload.sample_rate_hz = BAAD_SYSTEM_SAMPLE_RATE_HZ;
    payload.if_hz = BAAD_SYSTEM_IF_HZ;
    payload.bandwidth_hz = quint32(std::llround(m_bandwidthSpin->value() * 1.0e6));

    for (int i = 0; i < tones.size(); ++i) {
        payload.pinc[i] = tones[i].pinc;
        payload.tone_hz[i] = tones[i].toneHz;
    }

    m_bandwidthLabel->setText(QStringLiteral("DDS %1 MHz requested; waiting for measured summary")
                                  .arg(m_bandwidthSpin->value(), 0, 'f', 3));
    m_pendingConfiguration = configuration();
    m_session.testRun(m_presetCombo->currentText(), m_pendingConfiguration);
    m_controlPending = BAAD_PKT_SET_DDS_CONFIG;
    sendPacket(BAAD_PKT_SET_DDS_CONFIG, structBytes(&payload, sizeof(payload)));
    updateEnabled();
}

void MainWindow::startStream()
{
    if (!m_identityOk || m_burstBusy || m_controlPending) return;
    bool ok = false;
    const quint64 threshold = m_thresholdEdit->text().trimmed().toULongLong(&ok, 0);
    if (!ok || threshold > ((1ull << 33) - 1ull)) {
        QMessageBox::warning(this, QStringLiteral("Capture"), QStringLiteral("Threshold must fit in 33 bits."));
        return;
    }

    BaadStartStreamPayload payload = {};
    payload.power_threshold_lo = quint32(threshold & 0xffffffffull);
    payload.power_threshold_hi = quint8((threshold >> 32) & 0x01ull);
    payload.capture_flags = BAAD_CAPTURE_FLAG_SUMMARY;
    const int packetRecordCount = m_packetCountSpin->value();
    payload.packet_record_count = quint16(packetRecordCount);
    payload.cic_sample_interval = 1;
    payload.psd_input_sample_interval = 1;
    payload.interval_ms = quint16(m_updateIntervalSpin->value());

    m_captureStreamRequested = true;
    m_pendingConfiguration = configuration();
    m_controlPending = BAAD_PKT_START_STREAM;
    sendPacket(BAAD_PKT_START_STREAM, structBytes(&payload, sizeof(payload)));
    updateEnabled();
}

void MainWindow::stopStream()
{
    if (m_burstBusy) finishBurst("User stopped stream/capture");
    m_captureStreamRequested = false;
    m_controlPending = BAAD_PKT_STOP_STREAM;
    sendPacket(BAAD_PKT_STOP_STREAM);
    updateEnabled();
}

void MainWindow::requestStatus()
{
    sendPacket(BAAD_PKT_GET_STATUS);
}

void MainWindow::saveRecords()
{
    if (!m_session.directory().isEmpty()) QDesktopServices::openUrl(QUrl::fromLocalFile(m_session.directory()));
    else QMessageBox::information(this, "Results", "Connect to create a session. All incoming bytes, summaries and completed/failed bursts are saved automatically.");
}

void MainWindow::updateTones()
{
    const QVector<DdsTone> tones = currentTones();
    for (int i = 0; i < tones.size(); ++i) {
        const DdsTone &tone = tones[i];
        m_toneTable->setItem(i, 0, new QTableWidgetItem(QString::number(tone.index)));
        m_toneTable->setItem(i, 1, new QTableWidgetItem(QString::number(double(tone.toneHz) / 1.0e6, 'f', 6)));
        m_toneTable->setItem(i, 2, new QTableWidgetItem(QString::number(tone.pinc)));
        m_toneTable->setItem(i, 3, new QTableWidgetItem(QStringLiteral("0x%1").arg(tone.pinc, 8, 16, QLatin1Char('0')).toUpper()));
    }
}

void MainWindow::onSerialData(const QByteArray &data)
{
    m_session.raw(data, false);
    const quint64 before = m_codec.errors();
    for (const BaadPacket &packet : m_codec.feed(data)) {
        if (m_haveRxSequence && packet.sequence != quint16(m_lastRxSequence + 1))
            m_session.event("rx_sequence_gap_or_duplicate", {{"previous", m_lastRxSequence}, {"current", packet.sequence}});
        m_haveRxSequence = true; m_lastRxSequence = packet.sequence;
        m_session.event("rx_packet", {{"type", packet.type}, {"sequence", packet.sequence}, {"bytes", packet.payload.size()}});
        handlePacket(packet);
    }
    if (m_codec.errors() != before) appendLog(QStringLiteral("UART framing/CRC errors: +%1; burst chunks will retry.").arg(m_codec.errors() - before));
    checkRecording();
}

void MainWindow::onSerialError(const QString &message)
{
    appendLog(QStringLiteral("ERROR: %1").arg(message));
}

void MainWindow::onSerialOpenChanged(bool open)
{
    m_identityOk = false; m_controlPending = 0;
    if (m_controlTimer) m_controlTimer->stop();
    m_codec.reset(); m_haveRxSequence = false;
    if (!open && m_burstBusy) finishBurst("Serial disconnected before capture completed");
    if (!open) { m_captureStreamRequested = false; m_session.close(); }

    m_connectionLabel->setText(open ? QStringLiteral("Connected to %1").arg(m_serial->portName())
                                    : QStringLiteral("Disconnected"));
    m_connectButton->setText(open ? QStringLiteral("Disconnect") : QStringLiteral("Connect"));
    m_helloButton->setEnabled(open);
    m_statusButton->setEnabled(open);
    updateEnabled();
    if (open) { m_recordTotal = 0; m_recordTable->setRowCount(0); sendHello(); }
}

void MainWindow::sendPacket(quint8 type, const QByteArray &payload)
{
    if (!m_serial->isOpen()) {
        appendLog(QStringLiteral("Serial port is not open."));
        return;
    }

    const QByteArray frame = ProtocolCodec::encode(type, m_nextSequence++, payload);
    if (type != BAAD_PKT_HELLO && type != BAAD_PKT_GET_STATUS && !m_identityOk) { appendLog("Command blocked: matched HELLO identity required."); return; }
    if (m_session.active()) {
        m_session.raw(frame, true);
        m_session.event("tx_command", {{"type", type}, {"sequence", quint16(m_nextSequence - 1)}, {"payload_hex", QString::fromLatin1(payload.toHex())}});
    }
    if (!m_serial->writeData(frame)) appendLog("Command write did not complete; inspect link and reconnect.");
    if (m_controlPending == type && !m_burstBusy) m_controlTimer->start();
}

void MainWindow::handlePacket(const BaadPacket &packet)
{
    switch (packet.type) {
    case BAAD_PKT_ACK:
        handleAck(packet, true);
        break;
    case BAAD_PKT_NACK:
        handleAck(packet, false);
        break;
    case BAAD_PKT_STATUS:
        handleStatus(packet.payload);
        break;
    case BAAD_PKT_DMA_RECORD:
        handleDmaRecord(packet.payload);
        break;
    case BAAD_PKT_HELLO_INFO: {
        if (packet.payload.size() != sizeof(BaadHelloPayload)) { appendLog("Malformed HELLO_INFO; board controls remain disabled."); break; }
        BaadHelloPayload h = {}; memcpy(&h, packet.payload.constData(), sizeof(h));
        m_identityOk = h.hardware_id == BAAD_BUILD_ID && h.firmware_id == BAAD_BUILD_ID &&
            h.sample_rate_hz == BAAD_SYSTEM_SAMPLE_RATE_HZ && h.fft_size == BAAD_FFT_SIZE &&
            h.max_samples == BAAD_BURST_MAX_SAMPLES && (h.capabilities & 3u) == 3u;
        m_session.metadata("identity", {{"hardware_id", QString::number(h.hardware_id, 16)}, {"firmware_id", QString::number(h.firmware_id, 16)},
            {"sample_rate_hz", double(h.sample_rate_hz)}, {"fft_size", h.fft_size}, {"max_samples", h.max_samples},
            {"capabilities", double(h.capabilities)}, {"matched", m_identityOk}});
        appendLog(m_identityOk ? "Matched hardware + firmware build 26091301; board controls enabled." : "INCOMPATIBLE build/protocol: program the matched BIT and ELF; board controls disabled.");
        m_connectionLabel->setText(m_identityOk ? "Matched: " + m_serial->portName() : "IDENTITY MISMATCH");
        updateEnabled(); break;
    }
    case BAAD_PKT_CAPTURE_READY: {
        if (!m_burstBusy) { appendLog("Device holds a capture; use Abort burst to release it before a new acquisition."); break; }
        QString error;
        const bool already = m_burst.active();
        if (!m_burst.begin(packet.payload, &error)) { finishBurst(error); break; }
        if (!already) { m_retries = 0; pullChunk(); }
        break;
    }
    case BAAD_PKT_CAPTURE_DATA: {
        if (!m_burstBusy) break;
        QString error;
        const auto result = m_burst.accept(packet.payload, &error);
        if (result == BurstTransfer::Error) { finishBurst(error); break; }
        if (result == BurstTransfer::Duplicate) break;
        m_retries = 0;
        m_burstLabel->setText(QStringLiteral("Receiving %1 / %2 bytes").arg(m_burst.bytes().size()).arg(m_burst.ready().total_bytes));
        if (result == BurstTransfer::Complete) finishBurst(); else pullChunk();
        break;
    }
    default:
        appendLog(QStringLiteral("Unhandled packet type 0x%1").arg(packet.type, 2, 16, QLatin1Char('0')));
        break;
    }
}

void MainWindow::handleAck(const BaadPacket &packet, bool positive)
{
    if (packet.payload.size() < int(sizeof(BaadAckPayload))) {
        appendLog(QStringLiteral("Malformed ACK/NACK payload."));
        return;
    }

    BaadAckPayload ack = {};
    memcpy(&ack, packet.payload.constData(), sizeof(ack));

    appendLog(QStringLiteral("%1 request 0x%2 code %3 detail 0x%4")
                  .arg(positive ? QStringLiteral("ACK") : QStringLiteral("NACK"))
                  .arg(ack.request_type, 2, 16, QLatin1Char('0'))
                  .arg(ack.code)
                  .arg(ack.detail, 8, 16, QLatin1Char('0')));

    if (ack.request_type == BAAD_PKT_START_STREAM) {
        m_captureStreamRequested = positive;
    } else if (ack.request_type == BAAD_PKT_STOP_STREAM && positive) {
        m_captureStreamRequested = false;
    }
    m_session.event("ack", {{"positive", positive}, {"request", ack.request_type}, {"code", ack.code}, {"detail", QString::number(ack.detail, 16)}});
    if (positive && (ack.request_type == BAAD_PKT_SET_DDS_CONFIG || ack.request_type == BAAD_PKT_START_STREAM))
        m_session.metadata(ack.request_type == BAAD_PKT_SET_DDS_CONFIG ? "last_acknowledged_dds_request" : "last_acknowledged_stream_request", m_pendingConfiguration);
    if (m_controlPending == ack.request_type) { m_controlPending = 0; m_controlTimer->stop(); }
    if (!positive && m_burstBusy && (ack.request_type == BAAD_PKT_CAPTURE_BURST || ack.request_type == BAAD_PKT_READ_CAPTURE))
        finishBurst(QStringLiteral("Device rejected/failed burst: code %1 detail 0x%2").arg(ack.code).arg(ack.detail, 8, 16, QLatin1Char('0')));
    updateEnabled(); checkRecording();
}

void MainWindow::handleStatus(const QByteArray &payload)
{
    if (payload.size() < int(sizeof(BaadStatusPayload))) {
        appendLog(QStringLiteral("Malformed STATUS payload."));
        return;
    }

    BaadStatusPayload status = {};
    memcpy(&status, payload.constData(), sizeof(status));
    m_recordCountLabel->setText(QString::number(status.records_sent));
    m_dmaStatusLabel->setText(QStringLiteral("0x%1").arg(status.dma_status, 8, 16, QLatin1Char('0')).toUpper());
    appendLog(QStringLiteral("STATUS dds=0x%1 dma=0x%2 streaming=%3 records=%4 errors=%5")
                  .arg(status.dds_status, 8, 16, QLatin1Char('0'))
                  .arg(status.dma_status, 8, 16, QLatin1Char('0'))
                  .arg(status.streaming)
                  .arg(status.records_sent)
                  .arg(status.protocol_errors));
    m_session.event("device_status", {{"uptime_us", QString::number(status.uptime_us)}, {"records_sent", double(status.records_sent)},
        {"packets_sent", double(status.packets_sent)}, {"records_emitted", double(status.records_emitted)}, {"records_dropped", double(status.records_dropped)},
        {"dma_errors", double(status.dma_errors)}, {"dma_timeouts", double(status.dma_timeouts)}, {"dma_resets", double(status.dma_resets)},
        {"last_error", QString::number(status.last_error, 16)}, {"protocol_errors", double(status.protocol_errors)},
        {"capture_status", QString::number(status.capture_status, 16)}, {"streaming", bool(status.streaming)}});
    m_dmaStatusLabel->setToolTip(QStringLiteral("DMA errors %1; timeouts %2; dropped %3; uptime %4 us").arg(status.dma_errors).arg(status.dma_timeouts).arg(status.records_dropped).arg(status.uptime_us));
}

void MainWindow::handleDmaRecord(const QByteArray &payload)
{
    const QVector<DecodedDmaRecord> records = DmaDecoder::decodePayload(payload);

    for (const DecodedDmaRecord &record : records) {
        ++m_recordTotal;
        m_session.summary(record);
        appendRecordRow(record);

        if (record.valid && record.kind == QStringLiteral("summary")) {
            m_frameLabel->setText(QString::number(record.frameId));
            m_bandwidthLabel->setText(QStringLiteral("%1 MHz span, %2 MHz edge")
                                          .arg(record.bwSpanMHz, 0, 'f', 3)
                                          .arg(record.bwEdgeMHz, 0, 'f', 3));
            const quint16 m = record.decimationFactor != 0u ?
                              record.decimationFactor :
                              record.activeDecimationFactor;
            m_decimationLabel->setText(QString::number(m));
            m_flagsLabel->setText(record.flagNames.join(QStringLiteral(", ")));
            m_bandwidthPlot->append(record.bwSpanMHz);
        } else if (record.valid && record.kind == QStringLiteral("cic")) {
            const quint16 m = record.decimationFactor != 0u ?
                              record.decimationFactor :
                              record.activeDecimationFactor;
            if (m != 0u) {
                m_decimationLabel->setText(QString::number(m));
            }
            m_cicIPlot->append(record.mI);
            m_cicQPlot->append(record.mQ);
        } else if (record.valid && record.kind == QStringLiteral("psd_input")) {
            const quint16 m = record.decimationFactor != 0u ?
                              record.decimationFactor :
                              record.activeDecimationFactor;
            if (m != 0u) {
                m_decimationLabel->setText(QString::number(m));
            }
            m_psdInputIPlot->append(record.mI);
            m_psdInputQPlot->append(record.mQ);
        } else if (!record.valid) {
            appendLog(QStringLiteral("DMA decode error: %1").arg(record.error));
        }
    }

    m_recordCountLabel->setText(QString::number(m_recordTotal));
}

void MainWindow::appendLog(const QString &line)
{
    if (m_session.active()) m_session.event("log", {{"message", line}});
    m_log->appendPlainText(QStringLiteral("[%1] %2")
                               .arg(QDateTime::currentDateTime().toString(QStringLiteral("HH:mm:ss.zzz")))
                               .arg(line));
}

void MainWindow::appendRecordRow(const DecodedDmaRecord &record)
{
    const int row = m_recordTable->rowCount();
    m_recordTable->insertRow(row);
    m_recordTable->setItem(row, 0, new QTableWidgetItem(record.kind));
    m_recordTable->setItem(row, 1, new QTableWidgetItem(QString::number(record.frameId)));
    m_recordTable->setItem(row, 2, new QTableWidgetItem(QString::number(record.bwSpanMHz, 'f', 3)));
    m_recordTable->setItem(row, 3, new QTableWidgetItem(QString::number(record.bwEdgeMHz, 'f', 3)));
    const quint16 m = record.decimationFactor != 0u ?
                      record.decimationFactor :
                      record.activeDecimationFactor;
    m_recordTable->setItem(row, 4, new QTableWidgetItem(QString::number(m)));
    m_recordTable->setItem(row, 5, new QTableWidgetItem(QString::number(record.activeBinCount)));
    m_recordTable->setItem(row, 6, new QTableWidgetItem(QString::number(record.mI)));
    m_recordTable->setItem(row, 7, new QTableWidgetItem(QString::number(record.mQ)));
    m_recordTable->setItem(row, 8, new QTableWidgetItem(record.valid ? record.flagNames.join(QStringLiteral(", "))
                                                                    : record.error));

    while (m_recordTable->rowCount() > 300) {
        m_recordTable->removeRow(0);
    }
    m_recordTable->scrollToBottom();
}

QVector<DdsTone> MainWindow::currentTones() const
{
    return DdsMath::makeTones(m_bandwidthSpin->value() * 1.0e6,
                              BAAD_SYSTEM_IF_HZ,
                              BAAD_SYSTEM_SAMPLE_RATE_HZ);
}

void MainWindow::updateEnabled()
{
    const bool open = m_serial->isOpen();
    const bool ready = open && m_identityOk && m_session.active() && m_session.error().isEmpty();
    const bool idle = ready && !m_burstBusy && !m_controlPending;
    m_applyButton->setEnabled(idle); m_startButton->setEnabled(idle); m_burstButton->setEnabled(idle);
    m_stopButton->setEnabled(ready); m_abortButton->setEnabled(ready);
    m_helloButton->setEnabled(open && !m_burstBusy); m_statusButton->setEnabled(open);
    m_bandwidthSpin->setEnabled(idle); m_presetCombo->setEnabled(idle);
    m_thresholdEdit->setEnabled(idle); m_updateIntervalSpin->setEnabled(idle); m_packetCountSpin->setEnabled(idle);
    m_sampleCountSpin->setEnabled(idle); m_sourceCombo->setEnabled(idle);
    m_portCombo->setEnabled(!open); m_baudCombo->setEnabled(!open);
}
QJsonObject MainWindow::configuration() const
{
    QJsonArray tones;
    for (const auto &t : currentTones()) tones.append(QJsonObject{{"hz", t.toneHz}, {"pinc", double(t.pinc)}});
    return {{"requested_bandwidth_hz", m_bandwidthSpin->value() * 1e6}, {"if_hz", BAAD_SYSTEM_IF_HZ},
        {"sample_rate_hz", int(BAAD_SYSTEM_SAMPLE_RATE_HZ)}, {"tones", tones}, {"threshold", m_thresholdEdit->text()},
        {"summary_packet_records", m_packetCountSpin->value()}, {"summary_interval_ms", m_updateIntervalSpin->value()},
        {"burst_samples", m_sampleCountSpin->value()}, {"burst_source", m_sourceCombo->currentText()},
        {"test_preset", m_presetCombo->currentText()}, {"expected_m_note", "Conditional on measured spectrum, threshold and guard; not an observed result"}};
}
void MainWindow::startBurst()
{
    if (!m_identityOk || m_burstBusy || m_controlPending) return;
    BaadBurstRequest r = {quint16(m_sampleCountSpin->value()), quint8(m_sourceCombo->currentIndex()), 0};
    m_burst.reset(); m_burstBusy = true; m_retries = 0; m_controlPending = BAAD_PKT_CAPTURE_BURST;
    m_session.event("capture_requested", configuration());
    m_burstLabel->setText("Waiting for two stable decisions, then contiguous acquisition...");
    sendPacket(BAAD_PKT_CAPTURE_BURST, structBytes(&r, sizeof(r)));
    m_burstTimer->start(); updateEnabled(); checkRecording();
}
void MainWindow::pullChunk()
{
    const auto request = m_burst.nextRequest();
    if (!request.isEmpty()) { sendPacket(BAAD_PKT_READ_CAPTURE, request); m_burstTimer->start(); }
}
void MainWindow::retryBurst()
{
    if (!m_burstBusy) { m_burstTimer->stop(); return; }
    if (++m_retries > 3) { finishBurst("Capture retrieval timeout after three retries; partial bytes preserved"); return; }
    appendLog(QStringLiteral("Capture retry %1 / 3").arg(m_retries));
    m_codec.reset(); // Discard a truncated packet before retrying the idempotent read/status.
    if (m_burst.active()) pullChunk(); else sendPacket(BAAD_PKT_GET_STATUS);
}
void MainWindow::finishBurst(const QString &failure)
{
    if (!m_burstBusy) return;
    m_burstBusy = false; if (m_burstTimer) m_burstTimer->stop();
    BurstRecord r = m_burst.record();
    if (!r.captureId && m_burst.active()) r.captureId = m_burst.ready().capture_id;
    m_session.capture(m_burst.bytes(), r, failure);
    const QString result = !failure.isEmpty() ? failure : !r.error.isEmpty() ? r.error : QStringLiteral("Capture %1: %2 contiguous samples, CRC verified; saved").arg(r.captureId).arg(r.samples.size());
    m_burstLabel->setText(result); appendLog(result);
    if (r.integrityValid) {
        PlotWidget *i = r.source ? m_cicIPlot : m_psdInputIPlot;
        PlotWidget *q = r.source ? m_cicQPlot : m_psdInputQPlot;
        i->clear(); q->clear();
        for (const auto &s : r.samples) { i->append(s.i); q->append(s.q); }
    }
    m_controlPending = 0;
    if (m_serial->isOpen() && m_identityOk) { m_controlPending = BAAD_PKT_ABORT_CAPTURE; sendPacket(BAAD_PKT_ABORT_CAPTURE); }
    updateEnabled();
}
void MainWindow::abortBurst()
{
    if (m_burstBusy) finishBurst("User aborted capture; partial bytes preserved");
    else { m_controlPending = BAAD_PKT_ABORT_CAPTURE; sendPacket(BAAD_PKT_ABORT_CAPTURE); updateEnabled(); }
}
void MainWindow::checkRecording()
{
    if (m_session.error().isEmpty() || !m_serial->isOpen()) return;
    const QString why = m_session.error();
    // Safety stop is still attempted when logging has failed; do not continue an unrecorded run.
    if (m_identityOk) m_serial->writeData(ProtocolCodec::encode(BAAD_PKT_STOP_STREAM, m_nextSequence++, {}));
    m_serial->closePort();
    QMessageBox::critical(this, "Recording failed — link closed", why + "\nA stop was attempted. Verify board status before reconnecting.");
}
void MainWindow::closeEvent(QCloseEvent *event)
{
    if (m_serial->isOpen()) {
        if (m_identityOk) sendPacket(BAAD_PKT_STOP_STREAM);
        m_serial->closePort();
    }
    m_session.close(); event->accept();
}
