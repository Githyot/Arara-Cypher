import QtQuick
import AraraCypher

// Os tempos de uma batida, um botão por tempo: tocar troca o golpe
// (pausa, baixo, tudo, acorde, agudas, abafa).
Flow {
    id: root
    property var strum: null
    property real slotW: 52
    property int rev: 0               // muda a cada edição (o padrão é mexido no lugar)
    signal changed()

    readonly property var codes: ["", "B", "D", "d", "U", "X"]
    readonly property var codeLabel: ({ "": "·", "B": "baixo", "D": "tudo", "d": "acorde", "U": "agudas", "X": "abafa" })

    spacing: 4
    Repeater {
        model: root.rev, root.strum ? root.strum.pattern.slice() : []
        Rectangle {
            id: slot
            required property string modelData
            required property int index
            width: root.slotW
            height: 62
            radius: Theme.radiusSmall
            color: modelData === "" ? Theme.button
                 : Qt.rgba(Theme.accent.r, Theme.accent.g, Theme.accent.b, 0.18)
            Column {
                anchors.centerIn: parent
                spacing: 1
                Text {
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: slot.modelData === "" ? "·" : slot.modelData === "U" ? "↑" : slot.modelData === "X" ? "×" : "↓"
                    color: slot.modelData === "" || slot.modelData === "X" ? Theme.textDim : Theme.accent
                    font.pixelSize: 22
                    font.weight: Font.Bold
                }
                Text {
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: slot.modelData === "" ? " " : root.codeLabel[slot.modelData]
                    color: Theme.text
                    font.family: Theme.fontFamily
                    font.pixelSize: 10
                }
                Text {
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: root.strum.counts[slot.index] || ""
                    color: Theme.textDim
                    font.family: Theme.fontFamily
                    font.pixelSize: 11
                }
            }
            MouseArea {
                anchors.fill: parent
                cursorShape: Qt.PointingHandCursor
                onClicked: {
                    var i = root.codes.indexOf(slot.modelData)
                    root.strum.pattern[slot.index] = root.codes[(i + 1) % root.codes.length]
                    root.changed()
                }
            }
        }
    }
}
