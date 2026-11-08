import QtQuick
import QtQuick.Controls.Basic
import QtQuick.Layouts
import AraraCypher

ApplicationWindow {
    id: window
    width: 1000
    height: 680
    minimumWidth: 340
    minimumHeight: 480
    visible: true
    title: "AraraCypher"
    color: Theme.window
    font.family: Theme.fontFamily
    font.pixelSize: Theme.fontSize

    // Abaixo desta largura (celular ou janela estreita) a barra lateral
    // vira uma barra de abas embaixo.
    readonly property bool compact: width < 720
    property int currentPage: 0

    readonly property var pages: [
        { icon: "library",  label: "Biblioteca" },
        { icon: "edit",     label: "Editor" },
        { icon: "tuner",    label: "Afinador" },
        { icon: "study",    label: "Estudo" },
        { icon: "settings", label: "Ajustes" }
    ]

    RowLayout {
        anchors.fill: parent
        spacing: 0

        // ---- Barra lateral (computador) ----
        Rectangle {
            visible: !window.compact
            Layout.fillHeight: true
            Layout.preferredWidth: 230
            color: Theme.sidebar

            Column {
                anchors.fill: parent
                anchors.margins: 8
                spacing: 2

                Item {
                    width: parent.width
                    height: Theme.apple ? 56 : 39
                    Row {
                        spacing: 10
                        anchors.verticalCenter: parent.verticalCenter
                        x: 8
                        Icon {
                            name: "note"
                            size: 18
                            color: Theme.accent
                            anchors.verticalCenter: parent.verticalCenter
                        }
                        Text {
                            text: "AraraCypher"
                            color: Theme.text
                            font.family: Theme.fontFamily
                            font.pixelSize: Theme.apple ? 17 : 15
                            font.weight: Font.Bold
                            anchors.verticalCenter: parent.verticalCenter
                        }
                    }
                }
                Item { width: 1; height: Theme.apple ? 0 : 8 }

                Repeater {
                    model: window.pages
                    NavItem {
                        required property var modelData
                        required property int index
                        width: parent.width
                        iconName: modelData.icon
                        label: modelData.label
                        selected: window.currentPage === index
                        onClicked: window.currentPage = index
                    }
                }
            }

            Rectangle {
                anchors { top: parent.top; bottom: parent.bottom; right: parent.right }
                width: 1
                color: Theme.dark ? Qt.rgba(0, 0, 0, 0.36) : Qt.rgba(0, 0, 0, 0.08)
            }
        }

        // ---- Conteúdo ----
        ColumnLayout {
            Layout.fillWidth: true
            Layout.fillHeight: true
            spacing: 0

            StackLayout {
                Layout.fillWidth: true
                Layout.fillHeight: true
                currentIndex: window.currentPage

                LibraryPage {
                    id: libraryPage
                    onRequestPage: (i) => window.currentPage = i
                    onNewSong: { editorPage.load(null); window.currentPage = 1 }
                    onEditSong: (song) => { editorPage.load(song); window.currentPage = 1 }
                }
                EditorPage {
                    id: editorPage
                    onSaved: (song) => { libraryPage.showSong(song); window.currentPage = 0 }
                    onClosed: window.currentPage = 0
                }
                TunerPage {}
                StudyPage {}
                SettingsPage {}
            }

            // ---- Barra de abas (celular) ----
            Rectangle {
                visible: window.compact
                Layout.fillWidth: true
                Layout.preferredHeight: 60
                color: Theme.apple ? Qt.rgba(Theme.view.r, Theme.view.g, Theme.view.b, 0.94)
                                   : Theme.headerBar
                Rectangle {
                    anchors { left: parent.left; right: parent.right; top: parent.top }
                    height: 1
                    color: Theme.border
                }
                RowLayout {
                    anchors.fill: parent
                    anchors.topMargin: 1
                    spacing: 0
                    Repeater {
                        model: window.pages
                        NavItem {
                            required property var modelData
                            required property int index
                            Layout.fillWidth: true
                            Layout.fillHeight: true
                            vertical: true
                            iconName: modelData.icon
                            label: modelData.label
                            selected: window.currentPage === index
                            onClicked: window.currentPage = index
                        }
                    }
                }
            }
        }
    }
}
