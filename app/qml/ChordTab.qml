import QtQuick
import AraraCypher

// Tab colorida de uma parte (StrumStrip) com a mão dos dedos ao lado e,
// no modo de edição, o painel da nota escolhida: tocar numa casa muda o
// número, o dedo (a cor) ou se a corda toca; tocar numa seta troca o golpe.
// Mexe direto em song.voicings e, para os tempos de cada compasso, em
// section.measures[i] (só aquele acorde muda; os outros seguem a batida).
// Avisa com edited().
Column {
    id: root
    property var song: null
    property var chords: []
    property var strum: null
    property var section: null          // a parte de verdade (não a cópia do Repeater)
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
    readonly property var strokeCodes: ["", "B", "D", "d", "U", "X", "XU"]

    function editShape(token) {
        if (!song.voicings) song.voicings = {}
        var v = song.voicings[token]
        if (!v) {
            var sh = Examples.shape(Examples.chordName(token), 0, null) || Examples.blankShape()
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
    // Tempos de um compasso: os próprios dele, se já foi mexido, ou os da batida.
    function patternOf(index) {
        var base = strum ? strum.pattern : ["D"]
        var own = section && section.measures ? section.measures[index] : null
        return own && own.length === base.length ? own : base
    }
    function patterns() {
        var out = []
        for (var i = 0; i < chords.length; ++i) out.push(patternOf(i).slice())
        return out
    }
    // Para mudar só este compasso: cria a cópia dele na parte.
    function ownPattern(index) {
        if (!section) return strum ? strum.pattern : null
        if (!section.measures) section.measures = []
        while (section.measures.length < chords.length) section.measures.push(null)
        var own = section.measures[index]
        if (!own || !strum || own.length !== strum.pattern.length)
            section.measures[index] = own = (strum ? strum.pattern : ["D"]).slice()
        return own
    }
    function cycleStroke(index, step) {
        var pat = ownPattern(index)
        if (!pat) return
        var code = pat[step]
        if (Examples.isPick(code)) {
            // Dedilhado: a seta só vira (para baixo / para cima).
            pat[step] = Examples.pickCode(Examples.pickStrings(code), !Examples.strokeUp(code))
        } else {
            var i = strokeCodes.indexOf(code)
            pat[step] = strokeCodes[(i + 1) % strokeCodes.length]
        }
        changed()
    }
    function baseShape(token) {
        return Examples.shape(Examples.chordName(token), 0, Examples.voicing(song, token)) || Examples.blankShape()
    }
    // Tocar numa casa da tab: se tem número, escolhe; se está vazia, põe a
    // corda naquele tempo (vira dedilhado: só as cordas escolhidas tocam).
    // ---- Teclado ----
    // Com uma casa escolhida: números digitam a casa (dois dígitos seguidos
    // viram 10, 11...), Delete/Backspace tira do tempo, X = não tocar,
    // setas andam entre cordas e tempos, Enter/Esc fecham.
    property string typed: ""
    Timer { id: typedTimer; interval: 900; onTriggered: root.typed = "" }
    function typeDigit(d) {
        if (!sel) return
        // Garante que a nota está no tempo antes de mudar a casa.
        tapCell(sel.index, sel.token, sel.string, sel.step)
        // Dois dígitos seguidos viram um número só se der uma casa (até 20).
        typed = typedTimer.running && typed.length === 1 && parseInt(typed + d) <= 20 ? typed + d : d
        typedTimer.restart()
        var n = Math.min(20, parseInt(typed))
        setFret(n)
    }
    function move(dString, dStep) {
        if (!sel) return
        var n = patternOf(sel.index).length
        var index = sel.index, step = sel.step + dStep
        if (step >= n && index < chords.length - 1) { index++; step = 0 }
        else if (step < 0 && index > 0) { index--; step = n - 1 }
        step = Math.max(0, Math.min(n - 1, step))
        var string = Math.max(0, Math.min(5, sel.string + dString))
        sel = { index: index, token: chords[index], string: string, step: step }
        typed = ""
    }
    focus: editing
    Keys.onPressed: (e) => {
        if (!editing || !sel) return
        if (e.key >= Qt.Key_0 && e.key <= Qt.Key_9) typeDigit(String(e.key - Qt.Key_0))
        else if (e.key === Qt.Key_Backspace || e.key === Qt.Key_Delete) removeFromStep()
        else if (e.key === Qt.Key_X) setFret(-1)
        else if (e.key === Qt.Key_Left) move(0, -1)
        else if (e.key === Qt.Key_Right) move(0, 1)
        else if (e.key === Qt.Key_Up) move(1, 0)
        else if (e.key === Qt.Key_Down) move(-1, 0)
        else if (e.key === Qt.Key_Escape || e.key === Qt.Key_Return || e.key === Qt.Key_Enter) sel = null
        else return
        e.accepted = true
    }

    function tapCell(index, token, string, step) {
        forceActiveFocus()
        sel = { index: index, token: token, string: string, step: step }
        var sh = baseShape(token)
        var code = patternOf(index)[step]
        var strings = Examples.strokeStrings(sh, code)
        if (strings.indexOf(string) >= 0) return
        var pat = ownPattern(index)
        if (!pat) return
        if (sh.frets[string] < 0) {
            // A corda não fazia parte do acorde: os outros tempos deste compasso
            // ficam como estão (viram dedilhado com as cordas que já tocavam),
            // para a nota nova aparecer só onde foi tocada.
            for (var j = 0; j < pat.length; ++j) {
                if (j === step || pat[j] === "" || Examples.isMute(pat[j]) || Examples.isPick(pat[j])) continue
                var keep = Examples.strokeStrings(sh, pat[j])
                pat[j] = keep.length ? Examples.pickCode(keep, Examples.strokeUp(pat[j])) : (Examples.strokeUp(pat[j]) ? "PU" : "P")
            }
            var v = editShape(token)
            if (v) { v.frets[string] = 0; v.fingers[string] = 0 }
        }
        strings.push(string)
        pat[step] = Examples.pickCode(strings, Examples.strokeUp(code))
        changed()
    }
    function removeFromStep() {
        if (!sel) return
        var pat = ownPattern(sel.index)
        if (!pat) return
        var sh = baseShape(sel.token)
        var code = pat[sel.step]
        var strings = Examples.strokeStrings(sh, code).filter(function (s) { return s !== sel.string })
        pat[sel.step] = Examples.pickCode(strings, Examples.strokeUp(code))
        changed()
    }

    spacing: 8

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
            patterns: root.allRev, root.patterns()
            counts: root.strum ? root.strum.counts : []
            zoom: root.zoom
            rev: root.allRev
            editing: root.editing
            selIndex: root.sel ? root.sel.index : -1
            selString: root.sel ? root.sel.string : -1
            selStep: root.sel ? root.sel.step : -1
            onNoteClicked: (i, token, string, step) => root.tapCell(i, token, string, step)
            onStepClicked: (i, step) => root.cycleStroke(i, step)
        }
    }

    Column {
        id: notePanel
        visible: root.editing
        width: parent.width
        spacing: 8
        readonly property bool on: !!root.sel
        readonly property var v: root.allRev, on ? root.baseShape(root.sel.token) : null
        readonly property int fret: v ? v.frets[root.sel.string] : -1
        readonly property int finger: v ? (v.fingers[root.sel.string] || 0) : 0
        Text {
            visible: !notePanel.on
            width: parent.width
            wrapMode: Text.WordWrap
            text: "Toque num lugar vazio (+) para pôr um número naquele tempo: assim se monta o dedilhado. Toque num número para mudar a casa, o dedo ou tirar. Toque numa seta para trocar o golpe. Teclado: digite a casa, Delete tira, setas andam."
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
}
