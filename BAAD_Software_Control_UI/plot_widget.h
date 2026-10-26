#ifndef BAAD_PLOT_WIDGET_H
#define BAAD_PLOT_WIDGET_H

#include <QtCore/QString>
#include <QtCore/QSize>
#include <QtCore/QVector>
#include <QtGui/QColor>
#include <QtWidgets/QWidget>

class PlotWidget : public QWidget {
    Q_OBJECT

public:
    explicit PlotWidget(QWidget *parent = nullptr);

    void setTitle(const QString &title);
    void setAxisLabels(const QString &yLabel, const QString &xLabel);
    void setFixedRange(double minimum, double maximum);
    void setAutoRange();
    void setSquareAspect(bool enabled);
    void setLineColor(const QColor &color);
    void setCapacity(int capacity);
    void append(double value);
    void clear();

    QSize sizeHint() const override;
    bool hasHeightForWidth() const override;
    int heightForWidth(int width) const override;

protected:
    void paintEvent(QPaintEvent *event) override;

private:
    QVector<double> m_values;
    int m_capacity = 240;
    QString m_title = QStringLiteral("Bandwidth span");
    QString m_yLabel = QStringLiteral("MHz");
    QString m_xLabel = QStringLiteral("recent summary records");
    QColor m_lineColor = QColor(34, 94, 168);
    bool m_hasFixedRange = false;
    bool m_squareAspect = false;
    double m_fixedMinimum = 0.0;
    double m_fixedMaximum = 1.0;
};

#endif
