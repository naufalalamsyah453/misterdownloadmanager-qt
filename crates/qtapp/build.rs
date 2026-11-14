use cxx_qt_build::{CxxQtBuilder, QmlModule};

fn main() {
    CxxQtBuilder::new_qml_module(QmlModule::new("org.misterdownloadmanager").qml_files([
        "qml/Main.qml",
        "qml/Theme.qml",
        "qml/Sidebar.qml",
        "qml/DownloadRow.qml",
        "qml/AddUrlDialog.qml",
    ]))
    .file("src/model.rs")
    .build();
}
