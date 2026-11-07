import QtQuick
import QtQuick.Layouts
import AraraCypher

Rectangle {
    color: Theme.window
    ColumnLayout {
        anchors.fill: parent
        spacing: 0
        HeaderBar { Layout.fillWidth: true; title: "Estudo" }
        Item {
            Layout.fillWidth: true
            Layout.fillHeight: true
            PlaceholderPage {
                anchors.centerIn: parent
                iconName: "study"
                title: "Em breve"
                description: "O modo de estudo, com prática por trechos, ritmo e pontuação, chega no passo 4."
            }
        }
    }
}
