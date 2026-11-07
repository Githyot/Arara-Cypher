import QtQuick
import QtQuick.Controls.Basic
import AraraCypher

// Barra de rolagem sempre visível (quando há o que rolar), fina como no
// GNOME/macOS e mais larga ao passar o mouse, para dar para arrastar.
ScrollBar {
    id: bar
    policy: size < 1 ? ScrollBar.AlwaysOn : ScrollBar.AlwaysOff
    minimumSize: 0.06
    padding: 2
    contentItem: Rectangle {
        implicitWidth: bar.hovered || bar.pressed ? 10 : 6
        implicitHeight: 40
        radius: width / 2
        color: Theme.text
        opacity: bar.pressed ? 0.55 : bar.hovered ? 0.42 : 0.28
        Behavior on implicitWidth { NumberAnimation { duration: 120 } }
    }
    background: Item { implicitWidth: 14 }
}
