import QtQuick
import QtQuick.Layouts
import AraraCypher

Rectangle {
    color: Theme.window
    ColumnLayout {
        anchors.fill: parent
        spacing: 0
        HeaderBar { Layout.fillWidth: true; title: "Afinador" }
        Item {
            Layout.fillWidth: true
            Layout.fillHeight: true
            PlaceholderPage {
                anchors.centerIn: parent
                iconName: "tuner"
                title: "Em breve"
                description: "O afinador e o acompanhamento pelo microfone chegam no passo 3."
            }
        }
    }
}
