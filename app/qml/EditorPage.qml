import QtQuick
import QtQuick.Controls.Basic
import QtQuick.Layouts
import QtQuick.Dialogs
import AraraCypher

// Editor de cifra: dados da música, batidas, partes (acordes, tablatura,
// repetições) e as formas dos acordes. Também lê uma cifra colada.
// A música fica num objeto JS (`draft`); os campos de texto escrevem direto
// nele, e mudanças de estrutura (somar/tirar partes, batidas) aumentam `rev`
// para as listas se redesenharem.
Rectangle {
    id: page
    color: Theme.window

    property var draft: null
    property int rev: 0
    property string editingChord: ""     // acorde com a forma aberta para editar
    property string message: ""

    signal saved(var song)
    signal closed()

    readonly property var codes: ["", "B", "D", "d", "U", "X"]
    readonly property var codeLabel: ({ "": "·", "B": "baixo", "D": "tudo", "d": "acorde", "U": "agudas", "X": "abafa" })

    function defaultStrum() {
        return { name: "Batida", pattern: ["B", "", "d", "U", "", "U", "d", "U"],
                 counts: ["1", "e", "2", "e", "3", "e", "4", "e"] }
    }

    function blank() {
        return { title: "", artist: "", key: "C", capo: 0, video: "",
                 strums: [defaultStrum()], voicings: {},
                 sections: [{ name: "Intro", repeat: 1, chords: [] }] }
    }

    // Abre uma música para editar (null = nova). Exemplos viram uma cópia.
    function load(song) {
        var d = song ? JSON.parse(JSON.stringify(song)) : blank()
        if (!d.strums) d.strums = d.strum ? [d.strum] : [defaultStrum()]
        if (!d.voicings) d.voicings = {}
        if (!d.sections) d.sections = []
        if (d.capo === undefined) d.capo = 0
        if (d.video === undefined) d.video = ""
        draft = d
        editingChord = ""
        message = ""
        pasteArea.text = ""
        rev++
        flick.contentY = 0
    }

    function bump() { rev++ }

    // ---- Tab digitada no braço ----
    // Usa o último bloco de 6 linhas da tab (ou cria um) e acrescenta colunas.
    function tabBlock(text) {
        var lines = text.length > 0 ? text.split("\n") : []
        while (lines.length > 0 && lines[lines.length - 1].trim() === "") lines.pop()
        var labels = ["e", "B", "G", "D", "A", "E"]
        var n = lines.length
        var ok = n >= 6
        for (var i = 0; ok && i < 6; ++i)
            if (!/^\s*[EADGBe]\s*\|/.test(lines[n - 6 + i])) ok = false
        if (!ok) {
            if (n > 0) lines.push("")
            for (var j = 0; j < 6; ++j) lines.push(labels[j] + "|-")
            n = lines.length
        }
        return { head: lines.slice(0, n - 6), block: lines.slice(n - 6) }
    }
    function tabJoin(t) { return t.head.concat(t.block).join("\n") }
    function tabAppend(text, notes) {
        var t = tabBlock(text)
        var w = 1
        for (var k = 0; k < notes.length; ++k) w = Math.max(w, String(notes[k].fret).length)
        for (var i = 0; i < 6; ++i) {
            var s = 5 - i
            var line = t.block[i].replace(/\|\s*$/, "")
            if (line.length === 1 || /\|$/.test(line)) line += "-"
            var token = "-".repeat(w)
            for (var m = 0; m < notes.length; ++m)
                if (notes[m].string === s) token = (String(notes[m].fret) + "-".repeat(w)).substring(0, w)
            t.block[i] = line + token + "-"
        }
        return tabJoin(t)
    }
    function tabBar(text) {
        var t = tabBlock(text)
        for (var i = 0; i < 6; ++i) t.block[i] = t.block[i].replace(/\|\s*$/, "") + "|-"
        return tabJoin(t)
    }

    function chordsOf(text) {
        return text.split(/\s+/).filter(function (t) { return t.length > 0 })
    }

    // Acordes diferentes da música, na ordem em que aparecem.
    readonly property var distinctChords: {
        rev
        var out = []
        if (!draft) return out
        for (var i = 0; i < draft.sections.length; ++i)
            for (var j = 0; j < draft.sections[i].chords.length; ++j) {
                var c = draft.sections[i].chords[j]
                if (out.indexOf(c) < 0 && Music.isChord(Examples.chordName(c))) out.push(c)
            }
        return out
    }

    function readPaste(replace) {
        var parts = JSON.parse(Library.parseSheet(pasteArea.text))
        if (parts.length === 0) {
            message = "Não achei acordes nem tablatura nesse texto."
            return
        }
        if (replace) draft.sections = parts
        else draft.sections = draft.sections.concat(parts)
        message = parts.length === 1 ? "Li 1 parte." : "Li " + parts.length + " partes."
        pasteArea.text = ""
        bump()
    }

    // Lê o texto de um print (OCR no próprio computador) e põe no campo de
    // colar, para conferir antes de ler as partes.
    property string pendingImage: ""
    function readImage(url) {
        var path = decodeURIComponent(String(url).replace(/^file:\/\//, ""))
        pendingImage = path
        message = "Lendo o print..."
        ocrTimer.start()
    }
    Timer {
        id: ocrTimer
        interval: 60
        onTriggered: {
            var r = JSON.parse(Library.readImage(page.pendingImage))
            if (r.ok && r.text.trim().length > 0) {
                pasteArea.text = r.text
                page.message = "Li o print. Confira o texto abaixo (o leitor pode errar uma letra ou outra) e toque em Ler."
            } else {
                page.message = r.ok ? "Não achei texto nessa imagem." : r.text
            }
        }
    }
    FileDialog {
        id: imageDialog
        title: "Escolha o print da cifra ou da tab"
        nameFilters: ["Imagens (*.png *.jpg *.jpeg *.webp *.bmp)"]
        onAccepted: page.readImage(selectedFile)
    }

    function moveSection(i, d) {
        var j = i + d
        if (j < 0 || j >= draft.sections.length) return
        var tmp = draft.sections[i]
        draft.sections[i] = draft.sections[j]
        draft.sections[j] = tmp
        bump()
    }

    function startVoicing(chord) {
        if (!draft.voicings[chord]) {
            var s = Examples.shape(chord, 0, null)
            draft.voicings[chord] = s ? { frets: s.frets.slice(), fingers: s.fingers.slice() }
                                      : { frets: [-1, -1, -1, -1, -1, -1], fingers: [0, 0, 0, 0, 0, 0] }
        }
        editingChord = chord
        bump()
    }

    function save() {
        if (!draft.title || draft.title.trim().length === 0) draft.title = "Sem título"
        // Partes vazias (sem acordes, sem tab e sem nota) não vão para o arquivo.
        draft.sections = draft.sections.filter(function (s) {
            return s.chords.length > 0 || (s.tab && s.tab.length > 0) || (s.note && s.note.length > 0)
        })
        // Formas de acordes que saíram da música também.
        var keep = {}
        for (var k in draft.voicings)
            if (distinctChords.indexOf(k) >= 0) keep[k] = draft.voicings[k]
        draft.voicings = keep
        var id = Library.save(JSON.stringify(draft))
        if (id.length === 0) {
            message = "Não consegui salvar. Veja se a pasta " + Library.folder + " pode ser gravada."
            return
        }
        draft.id = id
        saved(JSON.parse(JSON.stringify(draft)))
    }

    Component.onCompleted: if (!draft) load(null)

    ColumnLayout {
        anchors.fill: parent
        spacing: 0

        HeaderBar {
            Layout.fillWidth: true
            title: page.draft && page.draft.id ? "Editar cifra" : "Nova cifra"
            AppButton { text: "Cancelar"; flat: true; onClicked: page.closed() }
            AppButton { text: "Salvar"; suggested: true; onClicked: page.save() }
        }

        Flickable {
            id: flick
            ScrollBar.vertical: AppScrollBar {}
            Layout.fillWidth: true
            Layout.fillHeight: true
            contentHeight: body.implicitHeight + 2 * Theme.pagePadding
            clip: true

            Column {
                id: body
                y: Theme.pagePadding
                width: Math.min(parent.width - 2 * Theme.pagePadding, 760)
                x: (parent.width - width) / 2
                spacing: 10

                Text {
                    visible: page.message.length > 0
                    width: parent.width
                    wrapMode: Text.WordWrap
                    text: page.message
                    color: Theme.accent
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.fontSize
                }

                // ---- Dados ----
                SectionTitle { text: "Música" }
                Card {
                    width: parent.width
                    GridLayout {
                        width: parent.width
                        columns: width > 520 ? 2 : 1
                        columnSpacing: 10
                        rowSpacing: 8
                        AppTextField {
                            Layout.fillWidth: true
                            placeholderText: "Título"
                            text: page.rev, page.draft ? page.draft.title : ""
                            onTextEdited: page.draft.title = text
                        }
                        AppTextField {
                            Layout.fillWidth: true
                            placeholderText: "Artista"
                            text: page.rev, page.draft ? (page.draft.artist || "") : ""
                            onTextEdited: page.draft.artist = text
                        }
                        RowLayout {
                            Layout.fillWidth: true
                            spacing: 8
                            Text {
                                text: "Tom"
                                color: Theme.text
                                font.family: Theme.fontFamily
                                font.pixelSize: Theme.fontSize
                            }
                            AppTextField {
                                Layout.preferredWidth: 90
                                mono: true
                                placeholderText: "C"
                                text: page.rev, page.draft ? (page.draft.key || "") : ""
                                onTextEdited: page.draft.key = text
                            }
                            Item { Layout.fillWidth: true }
                            Text {
                                text: "Capo"
                                color: Theme.text
                                font.family: Theme.fontFamily
                                font.pixelSize: Theme.fontSize
                            }
                            AppButton {
                                iconName: "remove"
                                onClicked: { page.draft.capo = Math.max(0, (page.draft.capo || 0) - 1); page.bump() }
                            }
                            Text {
                                Layout.preferredWidth: 28
                                horizontalAlignment: Text.AlignHCenter
                                text: page.rev, page.draft && page.draft.capo ? page.draft.capo : "—"
                                color: Theme.text
                                font.family: Theme.fontFamily
                                font.pixelSize: Theme.fontSize
                            }
                            AppButton {
                                iconName: "add"
                                onClicked: { page.draft.capo = Math.min(12, (page.draft.capo || 0) + 1); page.bump() }
                            }
                        }
                        AppTextField {
                            Layout.fillWidth: true
                            placeholderText: "Link do vídeo (YouTube)"
                            text: page.rev, page.draft ? (page.draft.video || "") : ""
                            onTextEdited: page.draft.video = text
                        }
                    }
                }

                // ---- Colar cifra ----
                SectionTitle { text: "Colar cifra" }
                Card {
                    width: parent.width
                    Text {
                        width: parent.width
                        wrapMode: Text.WordWrap
                        text: "Cole uma cifra ou tablatura copiada de um site, ou abra um print (também dá para arrastar a imagem para cá). O app pega as partes ([Intro], [Refrão]...), os acordes, as repetições (2x) e as linhas de tab. A letra fica de fora."
                        color: Theme.textDim
                        font.family: Theme.fontFamily
                        font.pixelSize: Theme.fontSize - 1
                    }
                    AppTextArea {
                        DropArea {
                            anchors.fill: parent
                            keys: ["text/uri-list"]
                            onDropped: (drop) => { if (drop.hasUrls) page.readImage(drop.urls[0]) }
                        }
                        id: pasteArea
                        width: parent.width
                        height: 140
                        placeholderText: "[Intro] Am  F  C  G\n\n[Refrão]\nC        G\n..."
                    }
                    Flow {
                        width: parent.width
                        spacing: 8
                        AppButton {
                            text: "Abrir print..."
                            onClicked: imageDialog.open()
                        }
                        AppButton {
                            text: "Ler e substituir as partes"
                            enabled: pasteArea.text.length > 0
                            onClicked: page.readPaste(true)
                        }
                        AppButton {
                            text: "Ler e acrescentar"
                            enabled: pasteArea.text.length > 0
                            onClicked: page.readPaste(false)
                        }
                    }
                }

                // ---- Batidas ----
                RowLayout {
                    width: parent.width
                    SectionTitle { Layout.fillWidth: true; text: "Batidas" }
                    AppButton {
                        text: "Nova batida"
                        iconName: "add"
                        flat: true
                        onClicked: { var s = page.defaultStrum(); s.name = "Batida " + (page.draft.strums.length + 1); page.draft.strums.push(s); page.bump() }
                    }
                }
                Repeater {
                    model: page.rev, page.draft ? page.draft.strums : []
                    Card {
                        id: strumCard
                        required property var modelData
                        required property int index
                        width: body.width
                        RowLayout {
                            width: parent.width
                            Text {
                                text: (strumCard.index + 1) + "."
                                color: Theme.textDim
                                font.family: Theme.fontFamily
                                font.pixelSize: Theme.fontSize
                            }
                            AppTextField {
                                Layout.fillWidth: true
                                text: strumCard.modelData.name
                                placeholderText: "Nome da batida"
                                onTextEdited: strumCard.modelData.name = text
                            }
                            AppButton {
                                text: "−4"
                                visible: strumCard.modelData.pattern.length > 4
                                onClicked: { strumCard.modelData.pattern.splice(-4, 4); strumCard.modelData.counts.splice(-4, 4); page.bump() }
                            }
                            AppButton {
                                text: "+4"
                                visible: strumCard.modelData.pattern.length < 16
                                onClicked: {
                                    var n = strumCard.modelData.pattern.length / 2
                                    strumCard.modelData.pattern.push("", "", "", "")
                                    strumCard.modelData.counts.push(String(n + 1), "e", String(n + 2), "e")
                                    page.bump()
                                }
                            }
                            AppButton {
                                visible: page.draft.strums.length > 1
                                iconName: "remove"
                                onClicked: {
                                    page.draft.strums.splice(strumCard.index, 1)
                                    for (var i = 0; i < page.draft.sections.length; ++i) {
                                        var s = page.draft.sections[i].strum || 0
                                        if (s === strumCard.index) delete page.draft.sections[i].strum
                                        else if (s > strumCard.index) page.draft.sections[i].strum = s - 1
                                    }
                                    page.bump()
                                }
                            }
                        }
                        Text {
                            width: parent.width
                            text: "Toque em cada tempo para trocar: · pausa, baixo, tudo, acorde (sem o baixo), agudas (para cima), abafa."
                            wrapMode: Text.WordWrap
                            color: Theme.textDim
                            font.family: Theme.fontFamily
                            font.pixelSize: Theme.fontSize - 2
                        }
                        Flow {
                            width: parent.width
                            spacing: 4
                            Repeater {
                                model: strumCard.modelData.pattern
                                Rectangle {
                                    id: slot
                                    required property string modelData
                                    required property int index
                                    width: 52
                                    height: 62
                                    radius: Theme.radiusSmall
                                    color: modelData === "" ? Theme.button
                                         : Qt.rgba(Theme.accent.r, Theme.accent.g, Theme.accent.b, 0.18)
                                    Column {
                                        anchors.centerIn: parent
                                        spacing: 1
                                        Text {
                                            anchors.horizontalCenter: parent.horizontalCenter
                                            text: slot.modelData === "" ? "·" : slot.modelData === "U" ? "↑" : "↓"
                                            color: slot.modelData === "" || slot.modelData === "X" ? Theme.textDim : Theme.accent
                                            font.pixelSize: 22
                                            font.weight: Font.Bold
                                        }
                                        Text {
                                            anchors.horizontalCenter: parent.horizontalCenter
                                            text: slot.modelData === "" ? " " : page.codeLabel[slot.modelData]
                                            color: Theme.text
                                            font.family: Theme.fontFamily
                                            font.pixelSize: 10
                                        }
                                        Text {
                                            anchors.horizontalCenter: parent.horizontalCenter
                                            text: strumCard.modelData.counts[slot.index] || ""
                                            color: Theme.textDim
                                            font.family: Theme.fontFamily
                                            font.pixelSize: 11
                                        }
                                    }
                                    MouseArea {
                                        anchors.fill: parent
                                        cursorShape: Qt.PointingHandCursor
                                        onClicked: {
                                            var i = page.codes.indexOf(slot.modelData)
                                            strumCard.modelData.pattern[slot.index] = page.codes[(i + 1) % page.codes.length]
                                            page.bump()
                                        }
                                    }
                                }
                            }
                        }
                    }
                }

                // ---- Partes ----
                RowLayout {
                    width: parent.width
                    SectionTitle { Layout.fillWidth: true; text: "Partes" }
                    AppButton {
                        text: "Nova parte"
                        iconName: "add"
                        flat: true
                        onClicked: { page.draft.sections.push({ name: "Parte " + (page.draft.sections.length + 1), repeat: 1, chords: [] }); page.bump() }
                    }
                }
                Repeater {
                    model: page.rev, page.draft ? page.draft.sections : []
                    Card {
                        id: secCard
                        required property var modelData
                        required property int index
                        property bool showTab: !!modelData.tab
                        property bool showBoard: false
                        property var history: []
                        width: body.width

                        RowLayout {
                            width: parent.width
                            spacing: 6
                            AppTextField {
                                Layout.fillWidth: true
                                text: secCard.modelData.name
                                placeholderText: "Nome da parte (Intro, Refrão...)"
                                onTextEdited: secCard.modelData.name = text
                            }
                            AppButton {
                                iconName: "remove"
                                onClicked: { secCard.modelData.repeat = Math.max(1, (secCard.modelData.repeat || 1) - 1); page.bump() }
                            }
                            Text {
                                text: (secCard.modelData.repeat || 1) + "×"
                                color: Theme.accent
                                font.family: Theme.fontFamily
                                font.pixelSize: Theme.fontSize
                                font.weight: Font.Bold
                            }
                            AppButton {
                                iconName: "add"
                                onClicked: { secCard.modelData.repeat = (secCard.modelData.repeat || 1) + 1; page.bump() }
                            }
                        }

                        AppTextField {
                            id: chordField
                            width: parent.width
                            mono: true
                            placeholderText: "Acordes separados por espaço: Am F C G"
                            text: secCard.modelData.chords.join("  ")
                            onTextEdited: secCard.modelData.chords = page.chordsOf(text)
                            onEditingFinished: page.bump()
                            readonly property var bad: page.chordsOf(text).filter(function (c) {
                                return !Music.isChord(Examples.chordName(c))
                            })
                        }
                        Text {
                            visible: chordField.bad.length > 0
                            width: parent.width
                            wrapMode: Text.WordWrap
                            text: "Não reconheci: " + chordField.bad.join(", ")
                            color: Theme.destructive
                            font.family: Theme.fontFamily
                            font.pixelSize: Theme.fontSize - 1
                        }

                        RowLayout {
                            visible: page.draft.strums.length > 1
                            width: parent.width
                            Text {
                                Layout.fillWidth: true
                                text: "Batida"
                                color: Theme.text
                                font.family: Theme.fontFamily
                                font.pixelSize: Theme.fontSize
                            }
                            SegmentedControl {
                                model: page.draft.strums.map(function (s, i) { return { value: String(i), label: String(i + 1) } })
                                current: String(secCard.modelData.strum || 0)
                                onActivated: (v) => { secCard.modelData.strum = Number(v); page.bump() }
                            }
                        }

                        AppTextArea {
                            visible: secCard.showTab
                            width: parent.width
                            height: Math.max(120, contentHeight + 24)
                            placeholderText: "e|-----------------|\nB|-----------------|\nG|-----5-----------|\nD|---7-------------|\nA|-----------------|\nE|-----------------|"
                            text: secCard.modelData.tab || ""
                            onTextChanged: secCard.modelData.tab = text
                            id: tabArea
                        }

                        AppButton {
                            visible: secCard.showTab
                            text: secCard.showBoard ? "Esconder o braço" : "Digitar no braço"
                            onClicked: secCard.showBoard = !secCard.showBoard
                        }
                        FretInput {
                            visible: secCard.showTab && secCard.showBoard
                            width: parent.width
                            function push(t) {
                                secCard.history.push(tabArea.text)
                                tabArea.text = t
                            }
                            onColumn: (notes) => push(page.tabAppend(tabArea.text, notes))
                            onRest: push(page.tabAppend(tabArea.text, []))
                            onBar: push(page.tabBar(tabArea.text))
                            onUndo: if (secCard.history.length > 0) tabArea.text = secCard.history.pop()
                        }

                        AppTextField {
                            width: parent.width
                            placeholderText: "Observação (opcional)"
                            text: secCard.modelData.note || ""
                            onTextEdited: secCard.modelData.note = text
                        }

                        Row {
                            spacing: 6
                            AppButton {
                                text: secCard.showTab ? "Sem tab" : "Tab (riff, solo)"
                                onClicked: {
                                    if (secCard.showTab) delete secCard.modelData.tab
                                    else secCard.modelData.tab = ""
                                    secCard.showTab = !secCard.showTab
                                }
                            }
                            AppButton { text: "Subir"; enabled: secCard.index > 0; onClicked: page.moveSection(secCard.index, -1) }
                            AppButton { text: "Descer"; enabled: secCard.index < page.draft.sections.length - 1; onClicked: page.moveSection(secCard.index, 1) }
                            AppButton {
                                text: "Apagar"
                                onClicked: { page.draft.sections.splice(secCard.index, 1); page.bump() }
                            }
                        }
                    }
                }

                // ---- Formas ----
                SectionTitle { text: "Formas dos acordes" }
                Card {
                    width: parent.width
                    Text {
                        width: parent.width
                        wrapMode: Text.WordWrap
                        text: page.distinctChords.length === 0
                              ? "Os acordes das partes aparecem aqui."
                              : "Toque num acorde para mudar a forma no braço (casas, dedos, cordas soltas ou abafadas). Para o mesmo acorde com duas formas, escreva com apelido nas partes: Gm7@2."
                        color: Theme.textDim
                        font.family: Theme.fontFamily
                        font.pixelSize: Theme.fontSize - 1
                    }
                    Flow {
                        width: parent.width
                        spacing: 8
                        Repeater {
                            model: page.distinctChords
                            Rectangle {
                                id: vbox
                                required property string modelData
                                readonly property bool custom: page.rev, !!page.draft.voicings[modelData]
                                width: 104
                                height: vname.implicitHeight + vdiag.implicitHeight + 28
                                radius: Theme.radiusSmall
                                color: page.editingChord === modelData
                                       ? Qt.rgba(Theme.accent.r, Theme.accent.g, Theme.accent.b, 0.22)
                                       : Qt.rgba(Theme.chord.r, Theme.chord.g, Theme.chord.b, Theme.dark ? 0.16 : 0.09)
                                Text {
                                    id: vname
                                    y: 6
                                    anchors.horizontalCenter: parent.horizontalCenter
                                    text: vbox.modelData + (vbox.custom ? " ✎" : "")
                                    color: Theme.chord
                                    font.family: Theme.monoFamily
                                    font.pixelSize: Theme.fontSize + 2
                                    font.weight: Font.Bold
                                }
                                ChordDiagram {
                                    id: vdiag
                                    anchors.top: vname.bottom
                                    anchors.topMargin: 6
                                    anchors.horizontalCenter: parent.horizontalCenter
                                    chord: Examples.chordName(vbox.modelData)
                                    voicing: page.rev, page.draft.voicings[vbox.modelData] || null
                                }
                                MouseArea {
                                    anchors.fill: parent
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: page.editingChord === vbox.modelData ? page.editingChord = ""
                                                                                    : page.startVoicing(vbox.modelData)
                                }
                            }
                        }
                    }
                }

                // Editor da forma escolhida.
                Card {
                    id: voicingCard
                    visible: page.editingChord.length > 0 && !!page.draft.voicings[page.editingChord]
                    width: parent.width
                    readonly property var v: page.rev, page.draft && page.editingChord ? page.draft.voicings[page.editingChord] : null

                    RowLayout {
                        width: parent.width
                        Text {
                            Layout.fillWidth: true
                            text: "Forma de " + page.editingChord
                            color: Theme.chord
                            font.family: Theme.fontFamily
                            font.pixelSize: Theme.fontSize + 2
                            font.weight: Font.Bold
                        }
                        AppButton {
                            text: "Usar a do app"
                            onClicked: { delete page.draft.voicings[page.editingChord]; page.editingChord = ""; page.bump() }
                        }
                        AppButton { text: "Pronto"; suggested: true; onClicked: page.editingChord = "" }
                    }

                    RowLayout {
                        width: parent.width
                        spacing: 16
                        Column {
                            spacing: 4
                            Repeater {
                                model: 6
                                RowLayout {
                                    id: stringRow
                                    required property int index
                                    readonly property int s: 5 - index    // agudo em cima
                                    readonly property int fret: voicingCard.v ? voicingCard.v.frets[s] : -1
                                    readonly property int finger: voicingCard.v ? voicingCard.v.fingers[s] : 0
                                    spacing: 6
                                    Text {
                                        Layout.preferredWidth: 18
                                        text: ["E", "A", "D", "G", "B", "e"][stringRow.s]
                                        color: Theme.textDim
                                        font.family: Theme.monoFamily
                                        font.pixelSize: Theme.fontSize
                                        font.weight: Font.Bold
                                    }
                                    AppButton {
                                        iconName: "remove"
                                        onClicked: { voicingCard.v.frets[stringRow.s] = Math.max(-1, stringRow.fret - 1); if (voicingCard.v.frets[stringRow.s] <= 0) voicingCard.v.fingers[stringRow.s] = 0; page.bump() }
                                    }
                                    Text {
                                        Layout.preferredWidth: 64
                                        horizontalAlignment: Text.AlignHCenter
                                        text: stringRow.fret < 0 ? "não toca" : stringRow.fret === 0 ? "solta" : stringRow.fret + "ª casa"
                                        color: stringRow.fret < 0 ? Theme.destructive : Theme.text
                                        font.family: Theme.fontFamily
                                        font.pixelSize: Theme.fontSize - 1
                                    }
                                    AppButton {
                                        iconName: "add"
                                        onClicked: { voicingCard.v.frets[stringRow.s] = Math.min(20, stringRow.fret + 1); page.bump() }
                                    }
                                    AppButton {
                                        enabled: stringRow.fret > 0
                                        text: stringRow.finger > 0 ? "dedo " + stringRow.finger : "dedo –"
                                        onClicked: { voicingCard.v.fingers[stringRow.s] = (stringRow.finger + 1) % 5; page.bump() }
                                    }
                                }
                            }
                        }
                        BigChordDiagram {
                            Layout.alignment: Qt.AlignTop
                            chord: Examples.chordName(page.editingChord)
                            voicing: voicingCard.v
                        }
                    }
                }

                // ---- Fim ----
                Row {
                    spacing: 8
                    AppButton { text: "Salvar"; suggested: true; onClicked: page.save() }
                    AppButton { text: "Cancelar"; onClicked: page.closed() }
                    AppButton {
                        visible: !!(page.draft && page.draft.id)
                        text: "Apagar cifra"
                        onClicked: deleteConfirm.visible = true
                    }
                }
                Card {
                    id: deleteConfirm
                    visible: false
                    width: parent.width
                    Text {
                        width: parent.width
                        wrapMode: Text.WordWrap
                        text: "Apagar \"" + (page.draft ? page.draft.title : "") + "\" da sua biblioteca? Não dá para desfazer."
                        color: Theme.text
                        font.family: Theme.fontFamily
                        font.pixelSize: Theme.fontSize
                    }
                    Row {
                        spacing: 8
                        AppButton {
                            text: "Apagar"
                            onClicked: { Library.remove(page.draft.id); deleteConfirm.visible = false; page.draft = null; page.load(null); page.closed() }
                        }
                        AppButton { text: "Não apagar"; onClicked: deleteConfirm.visible = false }
                    }
                }
                Item { width: 1; height: 24 }
            }
        }
    }
}
