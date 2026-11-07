use cxx_qt_build::{CxxQtBuilder, QmlFile, QmlModule};

fn main() {
    let qml = [
        "qml/Main.qml",
        "qml/LibraryPage.qml",
        "qml/EditorPage.qml",
        "qml/TunerPage.qml",
        "qml/StudyPage.qml",
        "qml/SettingsPage.qml",
        "qml/AppButton.qml",
        "qml/Card.qml",
        "qml/HeaderBar.qml",
        "qml/Icon.qml",
        "qml/NavItem.qml",
        "qml/PlaceholderPage.qml",
        "qml/SectionTitle.qml",
        "qml/SegmentedControl.qml",
    ];
    for f in qml.iter().chain(["qml/style/Theme.qml"].iter()) {
        println!("cargo:rerun-if-changed={f}");
    }

    let module = QmlModule::new("AraraCypher")
        .qml_file(QmlFile::from("qml/style/Theme.qml").singleton(true))
        .qml_files(qml);

    CxxQtBuilder::new_qml_module(module)
        .qt_module("Quick")
        .qt_module("QuickControls2")
        .files(["src/bridge.rs"])
        .build();
}
