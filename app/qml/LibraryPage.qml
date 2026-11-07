import QtQuick
import QtQuick.Layouts
import AraraCypher

// Lista das cifras. Por enquanto mostra as músicas de exemplo; a biblioteca
// salva no aparelho chega no passo 2 junto com o editor.
Rectangle {
    id: page
    signal requestPage(int index)
    property var openSong: null
    color: Theme.window

    ColumnLayout {
        anchors.fill: parent
        spacing: 0
        visible: page.openSong === null

        HeaderBar {
            Layout.fillWidth: true
            title: "Biblioteca"
            AppButton {
                iconName: "add"
                flat: true
                onClicked: page.requestPage(1)
            }
        }

        Flickable {
            Layout.fillWidth: true
            Layout.fillHeight: true
            contentHeight: list.implicitHeight + 2 * Theme.pagePadding
            clip: true

            Column {
                id: list
                y: Theme.pagePadding
                width: Math.min(parent.width - 2 * Theme.pagePadding, 720)
                x: (parent.width - width) / 2
                spacing: 8

                SectionTitle { text: "Exemplos" }

                Repeater {
                    model: Examples.songs
                    Card {
                        id: songCard
                        required property var modelData
                        width: list.width
                        padding: 12

                        RowLayout {
                            width: parent.width
                            spacing: 12
                            Rectangle {
                                Layout.preferredWidth: 44
                                Layout.preferredHeight: 44
                                radius: Theme.radiusSmall + 2
                                color: Qt.rgba(Theme.accent.r, Theme.accent.g, Theme.accent.b, 0.15)
                                Icon {
                                    anchors.centerIn: parent
                                    name: "note"
                                    size: 20
                                    color: Theme.accent
                                }
                            }
                            Column {
                                Layout.fillWidth: true
                                spacing: 2
                                Text {
                                    width: parent.width
                                    text: songCard.modelData.title
                                    color: Theme.text
                                    elide: Text.ElideRight
                                    font.family: Theme.fontFamily
                                    font.pixelSize: Theme.fontSize + 1
                                    font.weight: Font.DemiBold
                                }
                                Text {
                                    width: parent.width
                                    text: songCard.modelData.artist + " · Tom " + songCard.modelData.key
                                    color: Theme.textDim
                                    elide: Text.ElideRight
                                    font.family: Theme.fontFamily
                                    font.pixelSize: Theme.fontSize - 1
                                }
                            }
                            Text {
                                text: "›"
                                color: Theme.textDim
                                font.pixelSize: 24
                            }
                        }

                        MouseArea {
                            parent: songCard
                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                            onClicked: page.openSong = songCard.modelData
                        }
                    }
                }

                Item { width: 1; height: 16 }

                Text {
                    width: parent.width
                    wrapMode: Text.WordWrap
                    horizontalAlignment: Text.AlignHCenter
                    text: "Suas cifras vão aparecer aqui quando o editor ficar pronto."
                    color: Theme.textDim
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.fontSize - 1
                }
            }
        }
    }

    Loader {
        anchors.fill: parent
        active: page.openSong !== null
        sourceComponent: SongPage {
            song: page.openSong
            onBack: page.openSong = null
        }
    }
}
