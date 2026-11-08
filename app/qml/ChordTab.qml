import QtQuick
import AraraCypher

// Tab colorida de uma parte (StrumStrip) com a mão dos dedos ao lado e,
// no modo de edição, o painel da nota escolhida: tocar numa casa muda o
// número, o dedo (a cor) ou se a corda toca; tocar numa seta troca o golpe.
// Mexe direto em song.voicings e strum.pattern e avisa com edited().
Column {
    id: root
    property var song: null
    property var chords: []
    property var strum: null
    property int semitones: 0
    property real zoom: 1
    property int rev: 0
    property bool editing: false
    property string status: ""
    signal edited()

    property var sel: null              // { index, token, string, step }
    property int localRev: 0
    onEditingChanged: sel = null
    readonly property int allRev: rev + localRev
    readonly property var strokeCodes: ["", "B", "D", "d", "U", "X"]

    function editShape(token) {
        if (!song.voicings) song.voicings = {}
        var v = song.voicings[token]
        if (!v) {
            var sh = Examples.shape(Examples.chordName(token), 0, null)
            if (!sh) return null
            v = { frets: sh.frets.slice(), fingers: sh.fingers.slice() }
            song.voicings[token] = v
        }
        return v
    }
    function changed() { localRev++; edited() }
    function setFret(fret) {
        var v = editShape(sel.token); if (!v) return
        v.frets[sel.string] = Math.max(-1, Math.min(20, fret))
        if (v.frets[sel.string] <= 0) v.fingers[sel.string] = 0
        changed()
    }
    function setFinger(finger) {
        var v = editShape(sel.token); if (!v) return
        v.fingers[sel.string] = finger
        changed()
    }
    function cycleStroke(step) {
        if (!strum) return
        var code = strum.pattern[step]
        if (Examples.isPick(code)) {
            // Dedilhado: a seta só vira (para baixo / para cima).
            strum.pattern[step] = Examples.pickCode(Examples.pickStrings(code), !Examples.strokeUp(code))
        } else {
            var i = strokeCodes.indexOf(code)
            strum.pattern[step] = strokeCodes[(i + 1) % strokeCodes.length]
        }
        changed()
    }
    function baseShape(token) {
        return Examples.shape(Examples.chordName(token), 0, Examples.voicing(song, token))
    }
    // Tocar numa casa da tab: se tem número, escolhe; se está vazia, põe a
    // corda naquele tempo (vira dedilhado: só as cordas escolhidas tocam).
    function tapCell(index, token, string, step) {
        sel = { index: index, token: token, string: string, step: step }
        if (!strum) return
        var sh = baseShape(token)
        var code = strum.pattern[step]
        var strings = Examples.strokeStrings(sh, code)
        if (strings.indexOf(string) >= 0) return
        if (sh && sh.frets[string] < 0) {
            var v = editShape(token)
            if (v) { v.frets[string] = 0; v.fingers[string] = 0 }
        }
        strings.push(string)
        strum.pattern[step] = Examples.pickCode(strings, Examples.strokeUp(code))
        changed()
    }
    function removeFromStep() {
        if (!strum || !sel) return
        var sh = baseShape(sel.token)
        var code = strum.pattern[sel.step]
        var strings = Examples.strokeStrings(sh, code).filter(function (s) { return s !== sel.string })
        strum.pattern[sel.step] = Examples.pickCode(strings, Examples.strokeUp(code))
        sel = null
        changed()
    }

    spacing: 8

    Column {
        id: notePanel
        visible: root.editing
        width: parent.width
        spacing: 8
        readonly property bool on: !!root.sel
        readonly property var v: root.allRev, on ? Examples.shape(Examples.chordName(root.sel.token), 0, Examples.voicing(root.song, root.sel.token)) : null
        readonly property int fret: v ? v.frets[root.sel.string] : -1
        readonly property int finger: v ? (v.fingers[root.sel.string] || 0) : 0
        Text {
            visible: !notePanel.on
            width: parent.width
            wrapMode: Text.WordWrap
            text: "Toque num lugar vazio (+) para pôr um número naquele tempo: assim se monta o dedilhado. Toque num número para mudar a casa, o dedo ou tirar. Toque numa seta para trocar o golpe."
                  + (root.status ? " " + root.status : "")
            color: Theme.textDim
            font.family: Theme.fontFamily
            font.pixelSize: Theme.fontSize - 1
        }
        Flow {
            visible: notePanel.on
            width: parent.width
            spacing: 8
            Text {
                height: Theme.controlHeight
                verticalAlignment: Text.AlignVCenter
                text: notePanel.on ? Examples.chordName(root.sel.token) + " · corda " + ["E", "A", "D", "G", "B", "e"][root.sel.string] : ""
                color: Theme.chord
                font.family: Theme.fontFamily
                font.pixelSize: Theme.fontSize + 1
                font.bold: true
            }
            Row {
                spacing: 4
                AppButton { iconName: "remove"; onClicked: root.setFret(notePanel.fret - 1) }
                Text {
                    width: 64
                    height: Theme.controlHeight
                    horizontalAlignment: Text.AlignHCenter
                    verticalAlignment: Text.AlignVCenter
                    text: notePanel.fret < 0 ? "não toca" : notePanel.fret === 0 ? "solta" : "casa " + notePanel.fret
                    color: Theme.text
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.fontSize
                }
                AppButton { iconName: "add"; onClicked: root.setFret(notePanel.fret + 1) }
            }
            Row {
                spacing: 4
                Repeater {
                    model: [0, 1, 2, 3, 4, 5]
                    Rectangle {
                        required property int modelData
                        readonly property bool chosen: notePanel.finger === modelData
                        readonly property bool usable: notePanel.fret > 0 || modelData === 0
                        width: Theme.controlHeight
                        height: Theme.controlHeight
                        radius: width / 2
                        opacity: usable ? 1 : 0.35
                        color: chosen ? Qt.rgba(Theme.accent.r, Theme.accent.g, Theme.accent.b, 0.18) : Theme.button
                        border.width: chosen ? 3 : 2
                        border.color: modelData === 0 ? Theme.textDim : Theme.fingerColors[modelData]
                        Text {
                            anchors.centerIn: parent
                            text: parent.modelData === 0 ? "–" : parent.modelData === 5 ? "P" : parent.modelData
                            color: parent.modelData === 0 ? Theme.textDim : Theme.fingerColors[parent.modelData]
                            font.family: Theme.fontFamily
                            font.pixelSize: Theme.fontSize
                            font.bold: true
                        }
                        MouseArea {
                            anchors.fill: parent
                            enabled: parent.usable
                            cursorShape: Qt.PointingHandCursor
                            onClicked: root.setFinger(parent.modelData)
                        }
                    }
                }
            }
            AppButton {
                text: "Tirar deste tempo"
                onClicked: root.removeFromStep()
            }
            AppButton {
                flat: true
                text: notePanel.fret < 0 ? "Tocar a corda" : "Não tocar no acorde"
                onClicked: root.setFret(notePanel.fret < 0 ? 0 : -1)
            }
            AppButton { text: "Pronto"; flat: true; onClicked: root.sel = null }
            Text {
                height: Theme.controlHeight
                verticalAlignment: Text.AlignVCenter
                text: root.status
                color: Theme.textDim
                font.family: Theme.fontFamily
                font.pixelSize: Theme.fontSize - 2
            }
        }
    }

    Item {
        width: parent.width
        height: Math.max(strip.implicitHeight, hand.implicitHeight)
        HandLegend {
            id: hand
            anchors.right: parent.right
            zoom: Math.min(root.zoom, 1.2)
        }
        StrumStrip {
            id: strip
            width: parent.width - hand.width - 12
            chords: root.chords
            song: root.song
            // Na edição a tab fica no tom original (as casas salvas são as de verdade).
            semitones: root.editing ? 0 : root.semitones
            pattern: root.allRev, root.strum ? root.strum.pattern.slice() : ["D"]
            counts: root.strum ? root.strum.counts : []
            zoom: root.zoom
            rev: root.allRev
            editing: root.editing
            selIndex: root.sel ? root.sel.index : -1
            selString: root.sel ? root.sel.string : -1
            selStep: root.sel ? root.sel.step : -1
            onNoteClicked: (i, token, string, step) => root.tapCell(i, token, string, step)
            onStepClicked: (step) => root.cycleStroke(step)
        }
    }
}
