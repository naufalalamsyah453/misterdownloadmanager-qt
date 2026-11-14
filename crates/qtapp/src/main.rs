mod engine;
mod model;

use cxx_qt_lib::{QGuiApplication, QQmlApplicationEngine, QUrl};

fn main() {
    // The window is drawn and tested with Qt Quick Controls' Basic style, on every desktop;
    // QT_QUICK_CONTROLS_STYLE still wins when someone sets it. Done first, before any thread.
    if std::env::var_os("QT_QUICK_CONTROLS_STYLE").is_none() {
        // SAFETY: no other thread exists yet (the engine's runtime starts with the model).
        unsafe { std::env::set_var("QT_QUICK_CONTROLS_STYLE", "Basic") };
    }
    let mut app = QGuiApplication::new();
    let mut engine = QQmlApplicationEngine::new();
    if let Some(engine) = engine.as_mut() {
        engine.load(&QUrl::from(
            "qrc:/qt/qml/org/misterdownloadmanager/qml/Main.qml",
        ));
    }
    if let Some(app) = app.as_mut() {
        app.exec();
    }
}
