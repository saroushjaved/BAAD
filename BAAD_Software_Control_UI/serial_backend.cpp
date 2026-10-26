#include "serial_backend.h"

#include <QtCore/QByteArray>
#include <QtCore/QDebug>
#include <QtCore/QSet>
#include <QtCore/QtGlobal>

#include <iterator>

#include <windows.h>

static HANDLE toHandle(void *handle)
{
    return reinterpret_cast<HANDLE>(handle);
}

SerialBackend::SerialBackend(QObject *parent)
    : QObject(parent)
{
    connect(&m_pollTimer, &QTimer::timeout, this, &SerialBackend::poll);
    m_pollTimer.setInterval(10);
}

SerialBackend::~SerialBackend()
{
    closePort();
}

QStringList SerialBackend::availablePorts()
{
    QStringList ports;

    for (int i = 1; i <= 256; ++i) {
        const QString name = QStringLiteral("COM%1").arg(i);
        wchar_t target[512] = {};
        if (QueryDosDeviceW(reinterpret_cast<LPCWSTR>(name.utf16()), target, DWORD(std::size(target))) != 0) {
            ports.push_back(name);
        }
    }

    return ports;
}

bool SerialBackend::isOpen() const
{
    return m_handle != nullptr && toHandle(m_handle) != INVALID_HANDLE_VALUE;
}

QString SerialBackend::portName() const
{
    return m_portName;
}

bool SerialBackend::openPort(const QString &portName, int baudRate)
{
    closePort();

    const QString nativeName = QStringLiteral("\\\\.\\%1").arg(portName);
    HANDLE handle = CreateFileW(reinterpret_cast<LPCWSTR>(nativeName.utf16()),
                                GENERIC_READ | GENERIC_WRITE,
                                0,
                                nullptr,
                                OPEN_EXISTING,
                                FILE_ATTRIBUTE_NORMAL,
                                nullptr);

    if (handle == INVALID_HANDLE_VALUE) {
        emit errorOccurred(QStringLiteral("Failed to open %1").arg(portName));
        return false;
    }

    DCB dcb = {};
    dcb.DCBlength = sizeof(dcb);
    if (!GetCommState(handle, &dcb)) {
        CloseHandle(handle);
        emit errorOccurred(QStringLiteral("Failed to read COM settings for %1").arg(portName));
        return false;
    }

    dcb.BaudRate = DWORD(baudRate);
    dcb.ByteSize = 8;
    dcb.Parity = NOPARITY;
    dcb.StopBits = ONESTOPBIT;
    dcb.fBinary = TRUE;
    dcb.fParity = FALSE;
    dcb.fOutxCtsFlow = FALSE;
    dcb.fOutxDsrFlow = FALSE;
    dcb.fDsrSensitivity = FALSE;
    dcb.fOutX = FALSE;
    dcb.fInX = FALSE;
    dcb.fAbortOnError = FALSE;
    dcb.fDtrControl = DTR_CONTROL_ENABLE;
    dcb.fRtsControl = RTS_CONTROL_ENABLE;

    if (!SetCommState(handle, &dcb)) {
        CloseHandle(handle);
        emit errorOccurred(QStringLiteral("Failed to apply COM settings for %1").arg(portName));
        return false;
    }

    COMMTIMEOUTS timeouts = {};
    timeouts.ReadIntervalTimeout = 1;
    timeouts.ReadTotalTimeoutConstant = 1;
    timeouts.ReadTotalTimeoutMultiplier = 0;
    timeouts.WriteTotalTimeoutConstant = 100;
    timeouts.WriteTotalTimeoutMultiplier = 1;
    if (!SetCommTimeouts(handle, &timeouts) || !SetupComm(handle, 65536, 65536)) {
        CloseHandle(handle);
        emit errorOccurred(QStringLiteral("Failed to configure bounded COM timeouts/buffers"));
        return false;
    }
    PurgeComm(handle, PURGE_RXCLEAR | PURGE_TXCLEAR);

    m_handle = handle;
    m_portName = portName;
    m_pollTimer.start();
    emit openChanged(true);
    return true;
}

void SerialBackend::closePort()
{
    if (!isOpen()) {
        return;
    }

    m_pollTimer.stop();
    CloseHandle(toHandle(m_handle));
    m_handle = nullptr;
    m_portName.clear();
    emit openChanged(false);
}

bool SerialBackend::writeData(const QByteArray &data)
{
    if (!isOpen()) {
        emit errorOccurred(QStringLiteral("Serial port is not open"));
        return false;
    }

    DWORD written = 0;
    const BOOL ok = WriteFile(toHandle(m_handle),
                              data.constData(),
                              DWORD(data.size()),
                              &written,
                              nullptr);
    if (!ok || written != DWORD(data.size())) {
        emit errorOccurred(QStringLiteral("Serial write failed"));
        return false;
    }

    return true;
}

void SerialBackend::poll()
{
    if (!isOpen()) {
        return;
    }

    DWORD errors = 0;
    COMSTAT stat = {};
    if (!ClearCommError(toHandle(m_handle), &errors, &stat)) {
        emit errorOccurred(QStringLiteral("Serial status read failed"));
        closePort();
        return;
    }

    if (errors != 0) {
        emit errorOccurred(QStringLiteral("UART framing/parity/overrun flags 0x%1; receive buffer purged").arg(errors, 0, 16));
        PurgeComm(toHandle(m_handle), PURGE_RXCLEAR);
    }

    if (stat.cbInQue == 0) {
        return;
    }

    const DWORD toRead = qMin<DWORD>(stat.cbInQue, 4096);
    QByteArray data;
    data.resize(int(toRead));

    DWORD read = 0;
    if (!ReadFile(toHandle(m_handle), data.data(), toRead, &read, nullptr)) {
        emit errorOccurred(QStringLiteral("Serial read failed"));
        closePort();
        return;
    }

    if (read != 0) {
        data.resize(int(read));
        emit dataReceived(data);
    }
}
