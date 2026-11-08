import QtQuick
import QtQuick.Shapes
import AraraCypher

// Tab "deitada" de um acorde tocado com uma batida, no estilo das videoaulas:
// seis linhas (e B G D A E, do agudo para o grave), o número da casa em cima
// da linha da corda (com um contorno na cor do dedo que aperta), "×" para
// corda abafada e a direção da palheta embaixo de cada tempo.
//
// Códigos da batida (um por tempo):
//   "B"  baixo: só a corda da fundamental, palheta para baixo
//   "D"  todas as cordas do acorde, para baixo
//   "d"  cordas do acorde sem o baixo, para baixo
//   "U"  as três cordas mais agudas do acorde, para cima
//   "X"  abafado: palheta para baixo com a mão abafando as cordas
//   ""   pausa
Item {
    id: root
    property string chord
    property int semitones: 0
    property var pattern: []
    property var counts: []
    property bool showStringNames: true
    property bool dashes: true        // traços das cordas (a tab comprida desenha linhas inteiras)
    property bool editing: false      // tocar numa casa ou numa seta para mudar
    property int selString: -1        // corda escolhida para editar (realçada)
    signal noteClicked(int string)
    signal stepClicked(int step)

    readonly property real cellW: 22
    readonly property real rowH: 20
    readonly property real labelW: showStringNames ? 30 : 6
    readonly property var stringNames: ["E", "A", "D", "G", "B", "e"]

    property var voicing: null        // forma tirada da aula (opcional)
    readonly property var shape: Examples.shape(chord, semitones, voicing)

    // Para cada tempo: lista de 6 valores (corda 0 = Mi grave) com a casa,
    // "x" para abafada ou null se a corda não soa.
    readonly property var columns: {
        var cols = []
        if (!shape) return cols
        var played = []
        for (var s = 0; s < 6; ++s)
            if (shape.frets[s] >= 0) played.push(s)
        var upper = played.filter(function (s) { return s > shape.root })
        var top3 = played.slice(-3)
        for (var i = 0; i < pattern.length; ++i) {
            var c = [null, null, null, null, null, null]
            var code = pattern[i]
            var strings = code === "B" ? [shape.root]
                        : code === "D" ? played
                        : code === "d" || code === "X" ? upper
                        : code === "U" ? top3 : []
            for (var k = 0; k < strings.length; ++k)
                c[strings[k]] = code === "X" ? "x" : shape.frets[strings[k]]
            cols.push(c)
        }
        return cols
    }

    implicitWidth: labelW + pattern.length * cellW + 6
    implicitHeight: rowH * 8 + 6
    visible: shape !== null

    // ---- Direção da palheta ----
    Repeater {
        model: root.pattern.length
        Text {
            required property int index
            readonly property string code: root.pattern[index]
            x: root.labelW + index * root.cellW
            width: root.cellW
            y: root.rowH * 6 + 2
            height: root.rowH
            horizontalAlignment: Text.AlignHCenter
            verticalAlignment: Text.AlignVCenter
            text: code === "" ? (root.editing ? "·" : "") : code === "U" ? "↑" : code === "X" && root.editing ? "×" : "↓"
            color: code === "X" || code === "" ? Theme.textDim : Theme.chord
            font.pixelSize: 17
            font.bold: true
            Rectangle {
                visible: root.editing
                anchors.fill: parent
                anchors.margins: 1
                radius: 4
                color: "transparent"
                border.width: 1
                border.color: Qt.rgba(Theme.accent.r, Theme.accent.g, Theme.accent.b, arrowMouse.containsMouse ? 0.9 : 0.3)
            }
            MouseArea {
                id: arrowMouse
                anchors.fill: parent
                enabled: root.editing
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: root.stepClicked(parent.index)
            }
        }
    }

    // ---- Cordas ----
    Repeater {
        model: 6
        Item {
            id: stringRow
            required property int index
            readonly property int string: 5 - index   // linha de cima = Mi agudo
            x: 0
            y: root.rowH * index
            width: root.implicitWidth
            height: root.rowH

            // Nome da corda numa palheta.
            Item {
                visible: root.showStringNames
                width: 24
                height: 18
                anchors.verticalCenter: parent.verticalCenter
                Shape {
                    anchors.fill: parent
                    layer.enabled: true
                    layer.samples: 4
                    ShapePath {
                        strokeColor: Theme.accent
                        strokeWidth: 1.6
                        fillColor: Qt.rgba(Theme.accent.r, Theme.accent.g, Theme.accent.b, 0.18)
                        PathSvg { path: "M9 1.5 C3.5 1.5 1 5 1 9 C1 13 3.5 16.5 9 16.5 C14 16.5 19 12 23 9 C19 6 14 1.5 9 1.5 Z" }
                    }
                }
                Text {
                    x: 3
                    width: 13
                    anchors.verticalCenter: parent.verticalCenter
                    horizontalAlignment: Text.AlignHCenter
                    text: root.stringNames[stringRow.string]
                    color: Theme.text
                    font.family: Theme.fontFamily
                    font.pixelSize: 11
                    font.bold: true
                }
            }

            Repeater {
                model: root.pattern.length
                Item {
                    id: cell
                    required property int index
                    readonly property var value: root.columns.length > index ? root.columns[index][stringRow.string] : null
                    x: root.labelW + index * root.cellW
                    width: root.cellW
                    height: root.rowH

                    // Realce da corda escolhida e área de toque no modo de edição.
                    Rectangle {
                        visible: root.editing && (root.selString === stringRow.string || cellMouse.containsMouse)
                        anchors.fill: parent
                        radius: 4
                        color: Qt.rgba(Theme.accent.r, Theme.accent.g, Theme.accent.b,
                                       root.selString === stringRow.string ? 0.22 : 0.12)
                    }
                    MouseArea {
                        id: cellMouse
                        anchors.fill: parent
                        enabled: root.editing
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: root.noteClicked(stringRow.string)
                    }
                    // Linha da corda (tracejada, como nas aulas).
                    Rectangle {
                        visible: root.dashes && cell.value === null
                        anchors.centerIn: parent
                        width: root.cellW - 8
                        height: 1.5
                        color: Theme.textDim
                        opacity: 0.6
                    }
                    // Casa tocada: o número, com contorno na cor do dedo.
                    Rectangle {
                        readonly property int finger: cell.value !== null && cell.value !== "x" && root.shape
                                                      ? (root.shape.fingers[stringRow.string] || 0) : 0
                        visible: cell.value !== null
                        anchors.centerIn: parent
                        width: 19
                        height: 19
                        radius: 9.5
                        color: Theme.card     // esconde a linha da corda atrás do número
                        border.width: finger > 0 ? 1.6 : 0
                        border.color: Theme.fingerColors[finger]
                        Text {
                            anchors.centerIn: parent
                            text: cell.value === "x" ? "×" : (cell.value !== null ? cell.value : "")
                            color: cell.value === "x" ? Theme.textDim : Theme.chord
                            font.family: Theme.fontFamily
                            font.pixelSize: String(cell.value).length > 1 ? 11 : 14
                            font.bold: true
                        }
                    }
                }
            }
        }
    }

    // ---- Contagem ----
    Repeater {
        model: root.pattern.length
        Text {
            required property int index
            x: root.labelW + index * root.cellW
            width: root.cellW
            y: root.rowH * 7 + 2
            height: root.rowH
            horizontalAlignment: Text.AlignHCenter
            verticalAlignment: Text.AlignVCenter
            text: root.counts.length > index ? root.counts[index] : ""
            color: Theme.textDim
            font.family: Theme.fontFamily
            font.pixelSize: 10
        }
    }
}
