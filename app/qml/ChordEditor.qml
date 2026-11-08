import QtQuick
import AraraCypher

// Editor de braço: a forma de um acorde desenhada como no diagrama, para
// mexer com cliques. Clicar numa casa põe o dedo escolhido nela (clicar de
// novo tira); clicar em cima do braço troca entre O (solta) e X (não toca);
// as setas mudam a casa onde o desenho começa. Mexe direto em `voicing`
// ({ frets, fingers }) e avisa com changed().
Column {
    id: root
    property var voicing: null
    property int rev: 0
    property string chord: ""           // nome (ou token "X@2") para o Banco de Braços
    property int capo: 0                // casas de verdade: o banco conta do capo
    signal changed()

    // Banco de Braços: outras formas conhecidas deste acorde.
    readonly property var bank: chord ? JSON.parse(Music.chordShapes(Examples.chordName(chord), 0)) : []
    property int bankIndex: -1
    onChordChanged: bankIndex = -1
    function useBank(i) {
        if (!voicing || bank.length === 0) return
        bankIndex = (i + bank.length) % bank.length
        var b = bank[bankIndex]
        for (var s = 0; s < 6; ++s) voicing.frets[s] = b.frets[s] > 0 ? b.frets[s] + capo : b.frets[s]
        voicing.fingers = b.fingers.slice()
        fitBase()
        touch()
    }

    property int finger: 1                 // dedo que o próximo clique põe
    property int localRev: 0
    readonly property int allRev: rev + localRev
    readonly property var frets: allRev, voicing ? voicing.frets.slice() : [-1, -1, -1, -1, -1, -1]
    readonly property var fingers: allRev, voicing ? (voicing.fingers || [0, 0, 0, 0, 0, 0]).slice() : [0, 0, 0, 0, 0, 0]
    // Primeira casa do desenho: segue a forma, mas dá para mudar.
    property int base: 1
    function fitBase() {
        var fr = voicing ? voicing.frets : [], lo = 99, hi = 0
        for (var i = 0; i < fr.length; ++i) if (fr[i] > 0) { lo = Math.min(lo, fr[i]); hi = Math.max(hi, fr[i]) }
        base = hi <= 5 ? 1 : lo
    }
    onVoicingChanged: fitBase()
    Component.onCompleted: fitBase()

    readonly property real cellW: 34
    readonly property real cellH: 40
    readonly property real leftPad: 40
    readonly property real topPad: 34
    spacing: 10

    function touch() { localRev++; changed() }
    function setFret(s, f) {
        if (!voicing) return
        if (!voicing.fingers) voicing.fingers = [0, 0, 0, 0, 0, 0]
        if (voicing.frets[s] === f && f > 0) { voicing.frets[s] = 0; voicing.fingers[s] = 0 }
        else { voicing.frets[s] = f; voicing.fingers[s] = f > 0 ? finger : 0 }
        touch()
    }
    function toggleOpen(s) {
        if (!voicing) return
        voicing.frets[s] = voicing.frets[s] === 0 ? -1 : 0
        voicing.fingers[s] = 0
        touch()
    }

    // Formas do Banco de Braços.
    Row {
        visible: root.bank.length > 0
        spacing: 6
        Text {
            height: Theme.controlHeight
            verticalAlignment: Text.AlignVCenter
            text: "Banco de Braços:"
            color: Theme.textDim
            font.family: Theme.fontFamily
            font.pixelSize: Theme.fontSize - 1
        }
        AppButton { text: "◀"; onClicked: root.useBank(root.bankIndex < 0 ? root.bank.length - 1 : root.bankIndex - 1) }
        Text {
            height: Theme.controlHeight
            verticalAlignment: Text.AlignVCenter
            text: root.bankIndex < 0 ? root.bank.length + " formas" : "forma " + (root.bankIndex + 1) + " de " + root.bank.length
            color: Theme.text
            font.family: Theme.fontFamily
            font.pixelSize: Theme.fontSize - 1
        }
        AppButton { text: "▶"; onClicked: root.useBank(root.bankIndex + 1) }
    }

    // Dedo escolhido.
    Row {
        spacing: 6
        Text {
            height: Theme.controlHeight
            verticalAlignment: Text.AlignVCenter
            text: "Dedo:"
            color: Theme.textDim
            font.family: Theme.fontFamily
            font.pixelSize: Theme.fontSize - 1
        }
        Repeater {
            model: [1, 2, 3, 4, 5]
            Rectangle {
                required property int modelData
                readonly property bool chosen: root.finger === modelData
                width: Theme.controlHeight; height: width; radius: width / 2
                color: chosen ? Theme.fingerColors[modelData] : Theme.button
                border.width: 2
                border.color: Theme.fingerColors[modelData]
                Text {
                    anchors.centerIn: parent
                    text: parent.modelData === 5 ? "P" : parent.modelData
                    color: parent.chosen ? Theme.card : Theme.fingerColors[parent.modelData]
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.fontSize
                    font.bold: true
                }
                MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: root.finger = parent.modelData }
            }
        }
    }

    Item {
        width: root.leftPad + root.cellW * 5 + 40
        height: root.topPad + root.cellH * 5 + 30

        // Casa inicial, com setas para subir e descer o desenho.
        Column {
            x: 0; y: root.topPad
            spacing: 2
            Text {
                width: root.leftPad - 6
                horizontalAlignment: Text.AlignRight
                text: root.base + "ª"
                color: Theme.accent
                font.family: Theme.fontFamily
                font.pixelSize: Theme.fontSize + 2
                font.bold: true
            }
            AppButton { width: root.leftPad - 6; text: "▲"; flat: true; enabled: root.base > 1; onClicked: root.base-- }
            AppButton { width: root.leftPad - 6; text: "▼"; flat: true; enabled: root.base < 15; onClicked: root.base++ }
        }

        // Pestana (nut) quando começa na 1ª casa.
        Rectangle {
            visible: root.base === 1
            x: root.leftPad - 2; y: root.topPad - 4
            width: root.cellW * 5 + 4; height: 5
            color: Theme.text
        }
        // Linhas das cordas e das casas.
        Repeater {
            model: 6
            Rectangle {
                required property int index
                x: root.leftPad + index * root.cellW
                y: root.topPad
                width: 2; height: root.cellH * 5
                color: Theme.textDim
            }
        }
        Repeater {
            model: 6
            Rectangle {
                required property int index
                x: root.leftPad; y: root.topPad + index * root.cellH
                width: root.cellW * 5 + 2; height: 2
                color: Theme.textDim
            }
        }

        // O / X em cima de cada corda (clicar troca).
        Repeater {
            model: 6
            Item {
                required property int index
                readonly property int f: root.frets[index]
                x: root.leftPad + index * root.cellW - 13
                y: 0
                width: 28; height: 28
                Text {
                    anchors.centerIn: parent
                    text: parent.f < 0 ? "X" : parent.f === 0 ? "O" : "·"
                    color: parent.f < 0 ? Theme.destructive : Theme.text
                    font.family: Theme.fontFamily
                    font.pixelSize: 18
                    font.bold: true
                }
                MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: root.toggleOpen(parent.index) }
            }
        }

        // Casas clicáveis e os dedos.
        Repeater {
            model: 30
            Item {
                required property int index
                readonly property int s: index % 6
                readonly property int row: Math.floor(index / 6)
                readonly property int fret: root.base + row
                readonly property bool on: root.frets[s] === fret
                readonly property int fg: on ? (root.fingers[s] || 0) : 0
                x: root.leftPad + s * root.cellW - root.cellW / 2
                y: root.topPad + row * root.cellH
                width: root.cellW; height: root.cellH
                Rectangle {
                    visible: parent.on || hover.containsMouse
                    anchors.centerIn: parent
                    width: 26; height: 26; radius: 13
                    opacity: parent.on ? 1 : 0.35
                    color: parent.on ? (parent.fg > 0 ? Theme.fingerColors[parent.fg] : Theme.accent) : Theme.fingerColors[root.finger]
                    Text {
                        anchors.centerIn: parent
                        visible: parent.parent.on
                        text: parent.parent.fg === 5 ? "P" : parent.parent.fg > 0 ? parent.parent.fg : ""
                        color: Theme.card
                        font.family: Theme.fontFamily
                        font.pixelSize: 14
                        font.bold: true
                    }
                }
                MouseArea {
                    id: hover
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: root.setFret(parent.s, parent.fret)
                }
            }
        }
        // Nome das cordas embaixo.
        Repeater {
            model: 6
            Text {
                required property int index
                x: root.leftPad + index * root.cellW - width / 2 + 1
                y: root.topPad + root.cellH * 5 + 6
                text: ["E", "A", "D", "G", "B", "e"][index]
                color: Theme.textDim
                font.family: Theme.monoFamily
                font.pixelSize: 12
                font.bold: true
            }
        }
    }
    Text {
        width: parent.width
        wrapMode: Text.WordWrap
        text: "Escolha o dedo e clique na casa (clicar de novo tira). Em cima do braço: O = corda solta, X = não toca. ▲▼ mudam a casa onde o desenho começa."
        color: Theme.textDim
        font.family: Theme.fontFamily
        font.pixelSize: Theme.fontSize - 2
    }
}
