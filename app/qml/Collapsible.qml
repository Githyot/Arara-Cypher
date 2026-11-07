import QtQuick
import QtQuick.Layouts
import AraraCypher

// Grupo que abre e fecha: um cabeçalho clicável (seta, título, selo opcional)
// e o conteúdo. Fechado, mostra um resumo de uma linha no cabeçalho.
Column {
    id: root
    property string title
    property string summary         // aparece só quando está fechado
    property string badge           // ex.: "2×"
    property string hint            // texto pequeno à direita, sempre visível
    property bool expanded: true
    default property alias body: inner.data
    spacing: 6

    Rectangle {
        id: header
        width: root.width
        height: Math.max(32, headerRow.implicitHeight + 10)
        radius: Theme.radiusSmall
        color: mouse.containsMouse ? Qt.rgba(Theme.text.r, Theme.text.g, Theme.text.b, 0.06) : "transparent"

        RowLayout {
            id: headerRow
            x: 4
            width: parent.width - 8
            anchors.verticalCenter: parent.verticalCenter
            spacing: 8

            Text {
                text: "›"
                rotation: root.expanded ? 90 : 0
                Behavior on rotation { NumberAnimation { duration: 120 } }
                Layout.preferredWidth: 14
                horizontalAlignment: Text.AlignHCenter
                color: Theme.textDim
                font.pixelSize: Theme.fontSize + 6
                font.weight: Font.Bold
            }
            Text {
                text: root.title
                color: Theme.text
                font.family: Theme.fontFamily
                font.pixelSize: Theme.fontSize + 1
                font.weight: Font.Bold
            }
            Rectangle {
                visible: root.badge.length > 0
                Layout.preferredWidth: badgeText.implicitWidth + 12
                Layout.preferredHeight: badgeText.implicitHeight + 4
                radius: height / 2
                color: Qt.rgba(Theme.accent.r, Theme.accent.g, Theme.accent.b, 0.15)
                Text {
                    id: badgeText
                    anchors.centerIn: parent
                    text: root.badge
                    color: Theme.accent
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.fontSize - 2
                    font.weight: Font.Bold
                }
            }
            Text {
                Layout.fillWidth: true
                text: root.expanded ? "" : root.summary
                elide: Text.ElideRight
                color: Theme.textDim
                font.family: Theme.fontFamily
                font.pixelSize: Theme.fontSize - 1
            }
            Text {
                visible: root.hint.length > 0
                text: root.hint
                color: Theme.textDim
                font.family: Theme.fontFamily
                font.pixelSize: Theme.fontSize - 2
            }
        }
        MouseArea {
            id: mouse
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: root.expanded = !root.expanded
        }
    }

    Column {
        id: inner
        visible: root.expanded
        width: root.width
        spacing: 10
    }
}
