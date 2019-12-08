#include <signal.h>
#include <QGuiApplication>
#include <QQmlApplicationEngine>
#include <QQuickWindow>
#include <QTranslator>
#include "quickenums.h"

void registerQmlTypes() {
    // Enums
    qmlRegisterUncreatableType<QuickViewport>("CCTV_Viewer.Enums", 1, 0, "Viewport", "Uncreatable type!");
}

int main(int argc, char *argv[]) {
// NOTE: This code is actual only when using QtMultimedia.
#if defined(Q_OS_LINUX)
    // Ignore the SIGPIPE signal. Can be raised by librtmp.
    signal(SIGPIPE, SIG_IGN);
#endif

    QCoreApplication::setAttribute(Qt::AA_EnableHighDpiScaling);

#if defined(APP_NAME)
    QCoreApplication::setApplicationName(QLatin1String(APP_NAME));
#endif
#if defined(APP_VERSION)
    QCoreApplication::setApplicationVersion(QLatin1String(APP_VERSION));
#endif
#if defined(ORG_NAME)
    QCoreApplication::setOrganizationName(QLatin1String(ORG_NAME));
#endif
#if defined(ORG_DOMAIN)
    QCoreApplication::setOrganizationDomain(QLatin1String(ORG_DOMAIN));
#endif

    registerQmlTypes();

    QCoreApplication::setAttribute(Qt::AA_EnableHighDpiScaling);

    QGuiApplication app(argc, argv);
    QQmlApplicationEngine engine;
    QTranslator translator;
    const QString locale = QLocale::system().name();
    translator.load(QLatin1String("cctv-viewer_") + locale, QLatin1String(":/res/translations/"));
    app.installTranslator(&translator);
    app.setWindowIcon(QIcon(QLatin1String(":/res/icons/cctv-viewer.ico")));

    // NOTE: Debug
    // Testing Right-to-left User Interfaces...
    // (This code must be removed!!!)
//    app.setLayoutDirection(Qt::RightToLeft);

    const QUrl url(QStringLiteral("qrc:/src/qml/main.qml"));
    QObject::connect(&engine, &QQmlApplicationEngine::objectCreated,
                     &app, [url](QObject *obj, const QUrl &objUrl) {
        if (!obj && url == objUrl)
            QCoreApplication::exit(-1);
    }, Qt::QueuedConnection);
    engine.load(url);

    return app.exec();
}
