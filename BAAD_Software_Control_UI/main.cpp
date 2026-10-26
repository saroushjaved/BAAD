#include "mainwindow.h"

#include <QApplication>
#include <QFont>
#include <QStyleFactory>
#include <QTimer>
#include <QFontDatabase>

int main(int argc, char *argv[])
{
    QApplication a(argc, argv);
    if (a.arguments().contains("--smoke-test")) QFontDatabase::addApplicationFont("C:/Windows/Fonts/segoeui.ttf");
    QApplication::setStyle(QStyleFactory::create(QStringLiteral("Fusion")));
    a.setFont(QFont(QStringLiteral("Segoe UI"), 9));

    MainWindow w;
    w.show();
    if (a.arguments().contains("--smoke-test")) {
        QTimer::singleShot(250, &a, [&w, &a] {
            const QString path = qEnvironmentVariable("BAAD_SMOKE_IMAGE");
            if (!path.isEmpty() && !w.grab().save(path)) { a.exit(2); return; }
            a.quit();
        });
    }
    return QCoreApplication::exec();
}
