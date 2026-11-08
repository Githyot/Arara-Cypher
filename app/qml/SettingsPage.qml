import QtQuick
import QtQuick.Controls.Basic
import QtQuick.Layouts
import AraraCypher

Rectangle {
    color: Theme.window

    ColumnLayout {
        anchors.fill: parent
        spacing: 0

        HeaderBar { Layout.fillWidth: true; title: "Ajustes" }

        Flickable {

            ScrollBar.vertical: AppScrollBar {}
            Layout.fillWidth: true
            Layout.fillHeight: true
            contentHeight: content.implicitHeight + 2 * Theme.pagePadding
            clip: true

            Column {
                id: content
                y: Theme.pagePadding
                width: Math.min(parent.width - 2 * Theme.pagePadding, 560)
                x: (parent.width - width) / 2
                spacing: 8

                SectionTitle { text: "Aparência" }

                Card {
                    width: parent.width

                    RowLayout {
                        width: parent.width
                        Text {
                            Layout.fillWidth: true
                            text: "Estilo"
                            color: Theme.text
                            font.family: Theme.fontFamily
                            font.pixelSize: Theme.fontSize
                        }
                        SegmentedControl {
                            model: [{ value: "gnome", label: "GNOME" },
                                    { value: "apple", label: "Apple" }]
                            current: Theme.style
                            onActivated: (v) => Theme.style = v
                        }
                    }

                    Rectangle { width: parent.width; height: 1; color: Theme.border; opacity: 0.6 }

                    RowLayout {
                        width: parent.width
                        Text {
                            Layout.fillWidth: true
                            text: "Cores"
                            color: Theme.text
                            font.family: Theme.fontFamily
                            font.pixelSize: Theme.fontSize
                        }
                        SegmentedControl {
                            model: [{ value: "system", label: "Sistema" },
                                    { value: "light", label: "Claro" },
                                    { value: "dark", label: "Escuro" }]
                            current: Theme.scheme
                            onActivated: (v) => Theme.scheme = v
                        }
                    }
                }

                Item { width: 1; height: 12 }
                SectionTitle { text: "Sobre" }

                Card {
                    width: parent.width
                    RowLayout {
                        width: parent.width
                        Text {
                            Layout.fillWidth: true
                            text: "Versão"
                            color: Theme.text
                            font.family: Theme.fontFamily
                            font.pixelSize: Theme.fontSize
                        }
                        Text {
                            text: Music.version
                            color: Theme.textDim
                            font.family: Theme.fontFamily
                            font.pixelSize: Theme.fontSize
                        }
                    }
                }
            }
        }
    }
}
