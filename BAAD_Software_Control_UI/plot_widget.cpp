#include "plot_widget.h"

#include <QtCore/QtGlobal>
#include <QtGui/QPainter>
#include <QtGui/QPainterPath>
#include <QtWidgets/QSizePolicy>

#include <cmath>

static QString formatAxisValue(double value)
{
    const double magnitude = std::fabs(value);
    if (magnitude >= 100.0 || magnitude == 0.0) {
        return QString::number(value, 'f', 0);
    }
    return QString::number(value, 'f', 1);
}

PlotWidget::PlotWidget(QWidget *parent)
    : QWidget(parent)
{
    setMinimumHeight(110);
    setSizePolicy(QSizePolicy::Expanding, QSizePolicy::Preferred);
    setAttribute(Qt::WA_StyledBackground, false);
}

void PlotWidget::setTitle(const QString &title)
{
    m_title = title;
    update();
}

void PlotWidget::setAxisLabels(const QString &yLabel, const QString &xLabel)
{
    m_yLabel = yLabel;
    m_xLabel = xLabel;
    update();
}

void PlotWidget::setFixedRange(double minimum, double maximum)
{
    if (minimum == maximum) {
        maximum = minimum + 1.0;
    }
    m_hasFixedRange = true;
    m_fixedMinimum = qMin(minimum, maximum);
    m_fixedMaximum = qMax(minimum, maximum);
    update();
}

void PlotWidget::setAutoRange()
{
    m_hasFixedRange = false;
    update();
}

void PlotWidget::setSquareAspect(bool enabled)
{
    m_squareAspect = enabled;
    setMinimumHeight(enabled ? 125 : 110);
    updateGeometry();
}

void PlotWidget::setLineColor(const QColor &color)
{
    m_lineColor = color;
    update();
}

void PlotWidget::setCapacity(int capacity)
{
    m_capacity = qMax(2, capacity);
    while (m_values.size() > m_capacity) {
        m_values.removeFirst();
    }
    update();
}

void PlotWidget::append(double value)
{
    m_values.push_back(value);
    while (m_values.size() > m_capacity) {
        m_values.removeFirst();
    }
    update();
}

void PlotWidget::clear()
{
    m_values.clear();
    update();
}

QSize PlotWidget::sizeHint() const
{
    return m_squareAspect ? QSize(260, 140) : QSize(520, 130);
}

bool PlotWidget::hasHeightForWidth() const
{
    return false;
}

int PlotWidget::heightForWidth(int width) const
{
    return QWidget::heightForWidth(width);
}

void PlotWidget::paintEvent(QPaintEvent *event)
{
    Q_UNUSED(event);

    QPainter painter(this);
    painter.setRenderHint(QPainter::Antialiasing);

    const QRectF card = QRectF(rect()).adjusted(0.5, 0.5, -0.5, -0.5);
    painter.setPen(QPen(QColor(216, 222, 230), 1.0));
    painter.setBrush(QColor(255, 255, 255));
    painter.drawRoundedRect(card, 7.0, 7.0);

    const QRectF plot = rect().adjusted(58, 34, -16, -30);
    painter.setPen(QColor(226, 232, 240));
    painter.setBrush(QColor(251, 252, 253));
    painter.drawRoundedRect(plot, 5.0, 5.0);

    const QFont normalFont = painter.font();
    QFont titleFont = normalFont;
    titleFont.setBold(true);
    painter.setFont(titleFont);
    painter.setPen(QColor(31, 41, 55));
    painter.drawText(QRectF(plot.left(), 9, plot.width(), 20),
                     Qt::AlignLeft | Qt::AlignVCenter,
                     m_title);
    painter.setFont(normalFont);
    painter.setPen(QColor(97, 110, 124));
    painter.drawText(QRectF(6, plot.top() - 20, 44, 18),
                     Qt::AlignRight | Qt::AlignVCenter,
                     m_yLabel);
    painter.drawText(QRectF(plot.left(), plot.bottom() + 4, plot.width(), 20),
                     Qt::AlignCenter,
                     m_xLabel);

    if (m_values.isEmpty()) {
        painter.setPen(QColor(140, 150, 160));
        painter.drawText(plot, Qt::AlignCenter, QStringLiteral("No records"));
        return;
    }

    double minimum = m_hasFixedRange ? m_fixedMinimum : m_values.first();
    double maximum = m_hasFixedRange ? m_fixedMaximum : m_values.first();
    if (!m_hasFixedRange) {
        for (double value : m_values) {
            minimum = qMin(minimum, value);
            maximum = qMax(maximum, value);
        }

        double span = maximum - minimum;
        if (span == 0.0) {
            const double magnitude = qMax(1.0, std::fabs(maximum));
            span = magnitude * 0.20;
        }
        const double margin = span * 0.08;
        minimum -= margin;
        maximum += margin;
    }

    const auto yForValue = [&](double value) {
        const double normalized = (value - minimum) / (maximum - minimum);
        return plot.bottom() - normalized * plot.height();
    };

    painter.setPen(QColor(224, 229, 235));
    for (int i = 1; i < 4; ++i) {
        const double y = plot.top() + (plot.height() * double(i) / 4.0);
        painter.drawLine(QPointF(plot.left(), y), QPointF(plot.right(), y));
    }

    painter.setPen(QColor(120, 130, 140));
    painter.drawText(QRectF(4, plot.top() - 4, 48, 18),
                     Qt::AlignRight | Qt::AlignVCenter,
                     formatAxisValue(maximum));
    painter.drawText(QRectF(4, plot.bottom() - 14, 48, 18),
                     Qt::AlignRight | Qt::AlignVCenter,
                     formatAxisValue(minimum));

    if (minimum < 0.0 && maximum > 0.0) {
        painter.setPen(QPen(QColor(220, 224, 228), 1.0, Qt::DashLine));
        const double zeroY = yForValue(0.0);
        painter.drawLine(QPointF(plot.left(), zeroY), QPointF(plot.right(), zeroY));
    }

    if (m_values.size() < 2) {
        return;
    }

    QPainterPath path;
    const int xDenominator = qMax(1, m_values.size() - 1);
    for (int i = 0; i < m_values.size(); ++i) {
        const double x = plot.left() + (double(i) / double(xDenominator)) * plot.width();
        const double y = yForValue(m_values[i]);
        if (i == 0) {
            path.moveTo(x, y);
        } else {
            path.lineTo(x, y);
        }
    }

    painter.setPen(QPen(m_lineColor, 2.0));
    painter.drawPath(path);
}
