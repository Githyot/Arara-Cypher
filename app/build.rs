use cxx_qt_build::{CxxQtBuilder, QmlFile, QmlModule};

fn main() {
    let qml = [
        "qml/Main.qml",
        "qml/LibraryPage.qml",
        "qml/EditorPage.qml",
        "qml/TunerPage.qml",
        "qml/StudyPage.qml",
        "qml/SettingsPage.qml",
        "qml/SongPage.qml",
        "qml/StrumTab.qml",
        "qml/TabScore.qml",
        "qml/LessonTab.qml",
        "qml/TabText.qml",
        "qml/AppButton.qml",
        "qml/AppScrollBar.qml",
        "qml/AppTextArea.qml",
        "qml/AppTextField.qml",
        "qml/BigChordDiagram.qml",
        "qml/Card.qml",
        "qml/Collapsible.qml",
        "qml/FretInput.qml",
        "qml/ChordDiagram.qml",
        "qml/HeaderBar.qml",
        "qml/Icon.qml",
        "qml/NavItem.qml",
        "qml/NotationView.qml",
        "qml/PlaceholderPage.qml",
        "qml/ScoreRow.qml",
        "qml/SectionTitle.qml",
        "qml/SegmentedControl.qml",
    ];
    let singletons = ["qml/style/Theme.qml", "qml/data/Examples.qml"];
    for f in qml.iter().chain(singletons.iter()) {
        println!("cargo:rerun-if-changed={f}");
    }

    let module = QmlModule::new("AraraCypher")
        .qml_files(singletons.map(|f| QmlFile::from(f).singleton(true)))
        .qml_files(qml);

    CxxQtBuilder::new_qml_module(module)
        .qt_module("Quick")
        .qt_module("QuickControls2")
        .files(["src/bridge.rs"])
        .build();
}
