// Ponto de entrada mínimo. Toda a lógica fica em Rust (app/) e a interface
// em QML (app/qml/); este arquivo só cria a janela.
#include <QtCore/QCoreApplication>
#include <QtGui/QGuiApplication>
#include <QtQml/QQmlApplicationEngine>
#include <QtQuickControls2/QQuickStyle>

int
main(int argc, char* argv[])
{
  QCoreApplication::setOrganizationName(QStringLiteral("AraraCypher"));
  QCoreApplication::setOrganizationDomain(QStringLiteral("githyot.github.io"));
  QCoreApplication::setApplicationName(QStringLiteral("AraraCypher"));
  QGuiApplication::setDesktopFileName(
    QStringLiteral("io.github.githyot.araracypher"));

  QGuiApplication app(argc, argv);

  // Os temas GNOME e Apple são desenhados pelo próprio app em cima do
  // estilo "Basic", que é igual em todas as plataformas.
  QQuickStyle::setStyle(QStringLiteral("Basic"));

  QQmlApplicationEngine engine;
  // O Qt 6.5+ já procura módulos QML em qrc:/qt/qml; no 6.4 é preciso avisar.
  engine.addImportPath(QStringLiteral("qrc:/qt/qml"));
  const QUrl url(QStringLiteral("qrc:/qt/qml/AraraCypher/qml/Main.qml"));
  QObject::connect(
    &engine,
    &QQmlApplicationEngine::objectCreated,
    &app,
    [url](QObject* obj, const QUrl& objUrl) {
      if (!obj && url == objUrl)
        QCoreApplication::exit(-1);
    },
    Qt::QueuedConnection);
  engine.load(url);

  return app.exec();
}
