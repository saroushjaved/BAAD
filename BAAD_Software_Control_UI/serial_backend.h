#ifndef BAAD_SERIAL_BACKEND_H
#define BAAD_SERIAL_BACKEND_H

#include <QtCore/QObject>
#include <QtCore/QByteArray>
#include <QtCore/QTimer>
#include <QtCore/QStringList>

class SerialBackend : public QObject {
    Q_OBJECT

public:
    explicit SerialBackend(QObject *parent = nullptr);
    ~SerialBackend() override;

    static QStringList availablePorts();

    bool isOpen() const;
    QString portName() const;

public slots:
    bool openPort(const QString &portName, int baudRate);
    void closePort();
    bool writeData(const QByteArray &data);

signals:
    void dataReceived(const QByteArray &data);
    void errorOccurred(const QString &message);
    void openChanged(bool open);

private slots:
    void poll();

private:
    void *m_handle = nullptr;
    QString m_portName;
    QTimer m_pollTimer;
};

#endif
