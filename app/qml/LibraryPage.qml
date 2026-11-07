import QtQuick
import QtQuick.Layouts
import AraraCypher

// Lista das cifras salvas. Por enquanto só o estado vazio; a biblioteca
// de verdade chega no passo 2 junto com o editor.
Rectangle {
    id: page
    signal requestPage(int index)
    color: Theme.window

    ColumnLayout {
        anchors.fill: parent
        spacing: 0

        HeaderBar {
            Layout.fillWidth: true
            title: "Biblioteca"
            AppButton {
                iconName: "add"
                flat: true
                onClicked: page.requestPage(1)
            }
        }

        Item {
            Layout.fillWidth: true
            Layout.fillHeight: true
            PlaceholderPage {
                anchors.centerIn: parent
                iconName: "library"
                title: "Nenhuma cifra ainda"
                description: "Suas cifras e tablaturas vão aparecer aqui. Comece escrevendo uma nova ou colando uma cifra pronta."
                AppButton {
                    text: "Nova cifra"
                    suggested: true
                    onClicked: page.requestPage(1)
                }
            }
        }
    }
}
