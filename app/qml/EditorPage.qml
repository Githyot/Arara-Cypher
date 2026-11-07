import QtQuick
import QtQuick.Controls.Basic
import QtQuick.Layouts
import AraraCypher

// O editor completo chega no passo 2. Por enquanto esta página mostra um
// teste de transposição que roda no núcleo em Rust, para confirmar que a
// ligação Rust <-> QML funciona em cada plataforma.
Rectangle {
    id: page
    color: Theme.window
    property int semitones: 0

    ColumnLayout {
        anchors.fill: parent
        spacing: 0

        HeaderBar {
            Layout.fillWidth: true
            title: "Editor"
        }

        Flickable {

            ScrollBar.vertical: AppScrollBar {}
            Layout.fillWidth: true
            Layout.fillHeight: true
            contentHeight: content.implicitHeight + 2 * Theme.pagePadding
            clip: true

            Column {
                id: content
                x: Theme.pagePadding
                y: Theme.pagePadding
                width: Math.min(parent.width - 2 * Theme.pagePadding, 560)
                spacing: 10

                Text {
                    width: parent.width
                    text: "O editor de cifras e tablaturas chega no próximo passo. Enquanto isso, teste a transposição de acordes:"
                    color: Theme.textDim
                    wrapMode: Text.WordWrap
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.fontSize
                }

                SectionTitle { text: "Transpor acordes" }

                Card {
                    width: parent.width

                    TextField {
                        id: input
                        width: parent.width
                        text: "G D/F# Em C"
                        placeholderText: "Digite acordes separados por espaço"
                        color: Theme.text
                        placeholderTextColor: Theme.textDim
                        font.family: Theme.monoFamily
                        font.pixelSize: Theme.fontSize + 1
                        selectByMouse: true
                        background: Rectangle {
                            radius: Theme.radiusSmall
                            color: Theme.apple ? Theme.window : Theme.button
                            border.width: input.activeFocus ? 2 : 0
                            border.color: Theme.accent
                        }
                        padding: 9
                    }

                    RowLayout {
                        width: parent.width
                        spacing: 8
                        AppButton { iconName: "remove"; onClicked: page.semitones-- }
                        Text {
                            Layout.fillWidth: true
                            horizontalAlignment: Text.AlignHCenter
                            text: (page.semitones > 0 ? "+" : "") + page.semitones
                                  + (Math.abs(page.semitones) === 1 ? " semitom" : " semitons")
                            color: Theme.text
                            font.family: Theme.fontFamily
                            font.pixelSize: Theme.fontSize
                        }
                        AppButton { iconName: "add"; onClicked: page.semitones++ }
                    }

                    Text {
                        width: parent.width
                        wrapMode: Text.WordWrap
                        color: Theme.chord
                        font.family: Theme.monoFamily
                        font.pixelSize: Theme.fontSize + 4
                        font.weight: Font.Bold
                        text: input.text.split(/\s+/).filter(s => s.length > 0)
                                  .map(s => Music.transposeChord(s, page.semitones)).join("  ")
                    }
                }
            }
        }
    }
}
