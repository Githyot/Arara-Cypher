pragma Singleton
import QtQuick
import Qt.labs.settings

// Fica numa subpasta de propósito: se estivesse em qml/ junto com os outros
// arquivos, o import implícito da pasta esconderia o singleton do módulo.
//
// Tema global do app. Dois estilos visuais (GNOME/Adwaita e Apple) e três
// esquemas de cor (sistema, claro, escuro). Tudo na interface lê as cores,
// raios e fontes daqui, então trocar o estilo muda o app inteiro na hora.
QtObject {
    id: theme

    // ---- Preferências (salvas entre execuções) ----
    property string style: "gnome"      // "gnome" | "apple"
    property string scheme: "system"    // "system" | "light" | "dark"

    property Settings _settings: Settings {
        category: "appearance"
        property alias style: theme.style
        property alias scheme: theme.scheme
    }

    // ---- Estado derivado ----
    readonly property bool apple: style === "apple"
    // Qt.styleHints.colorScheme existe a partir do Qt 6.5 (2 = escuro).
    readonly property bool systemDark: Qt.styleHints.colorScheme !== undefined
                                       && Qt.styleHints.colorScheme === 2
    readonly property bool dark: scheme === "dark" || (scheme === "system" && systemDark)

    // ---- Cores ----
    // GNOME: paleta do libadwaita. Apple: cores de sistema do iOS/macOS.
    readonly property color accent: apple ? (dark ? "#0a84ff" : "#007aff")
                                          : (dark ? "#78aeed" : "#3584e4")
    readonly property color accentBg: apple ? accent : "#3584e4"
    readonly property color accentFg: "#ffffff"

    readonly property color window: apple ? (dark ? "#000000" : "#f2f2f7")
                                          : (dark ? "#222226" : "#fafafb")
    readonly property color view: apple ? (dark ? "#1c1c1e" : "#ffffff")
                                        : (dark ? "#1d1d20" : "#ffffff")
    readonly property color sidebar: apple ? (dark ? "#1c1c1e" : "#e8e8ed")
                                           : (dark ? "#2e2e32" : "#ebebed")
    readonly property color headerBar: apple ? window
                                             : (dark ? "#2e2e32" : "#ffffff")
    readonly property color card: apple ? (dark ? "#1c1c1e" : "#ffffff")
                                        : (dark ? "#36363a" : "#ffffff")
    readonly property color text: apple ? (dark ? "#ffffff" : "#000000")
                                        : (dark ? "#ffffff" : "#2e2e33")
    readonly property color textDim: apple ? (dark ? "#98989f" : "#6c6c70")
                                           : (dark ? "#9a9a9e" : "#77767b")
    readonly property color border: apple ? (dark ? "#38383a" : "#d1d1d6")
                                          : (dark ? "#3a3a3e" : "#dedee1")
    readonly property color button: apple ? (dark ? "#2c2c2e" : "#e5e5ea")
                                          : (dark ? "#3a3a3e" : "#e8e8ea")
    readonly property color buttonHover: Qt.darker(button, dark ? 0.85 : 1.06)
    readonly property color selection: apple ? accent
                                             : (dark ? "#3a3a3e" : "#dcdcdf")
    readonly property color selectionFg: apple ? accentFg : text
    readonly property color destructive: apple ? (dark ? "#ff453a" : "#ff3b30")
                                               : (dark ? "#ff7b63" : "#e01b24")
    readonly property color success: apple ? (dark ? "#30d158" : "#34c759")
                                           : (dark ? "#8ff0a4" : "#2ec27e")
    // Acordes destacados na cifra (usado a partir do passo 2).
    readonly property color chord: apple ? (dark ? "#ff9f0a" : "#c93400")
                                         : (dark ? "#ffa348" : "#c64600")

    // ---- Forma ----
    readonly property int radiusSmall: apple ? 8 : 6
    readonly property int radius: apple ? 10 : 12
    readonly property int controlHeight: apple ? 34 : 34
    readonly property bool pillButtons: apple
    readonly property int spacing: 12
    readonly property int pagePadding: 18

    // ---- Tipografia ----
    readonly property string fontFamily: _firstAvailable(
        apple ? ["SF Pro Text", "SF Pro Display", "Inter", "Roboto", "Cantarell"]
              : ["Adwaita Sans", "Cantarell", "Inter", "Roboto"])
    readonly property string monoFamily: _firstAvailable(
        apple ? ["SF Mono", "Menlo", "JetBrains Mono", "DejaVu Sans Mono", "monospace"]
              : ["Adwaita Mono", "Source Code Pro", "DejaVu Sans Mono", "monospace"])
    readonly property int fontSize: apple ? 15 : 14
    readonly property int titleSize: apple ? 30 : 15       // título da página
    readonly property int titleWeight: apple ? Font.Bold : Font.Bold
    readonly property int headingSize: apple ? 20 : 18

    function _firstAvailable(names) {
        var available = Qt.fontFamilies()
        for (var i = 0; i < names.length; ++i)
            if (available.indexOf(names[i]) !== -1)
                return names[i]
        return names[names.length - 1]
    }

    // Ícones simbólicos 16x16 desenhados como caminhos SVG, para poderem ser
    // pintados com a cor do tema sem depender de um tema de ícones do sistema
    // (que não existe no Android).
    readonly property var icons: ({
        "library": "M1 2h3v12H1zM5 2h3v12H5zM9.3 2.8l2.9-.8 2.8 11.2-2.9.8z",
        "edit": "M10.5 1.5l4 4-9 9h-4v-4z",
        "tuner": "M1 7h2v2H1zM4 4h2v8H4zM7 1h2v14H7zM10 4h2v8h-2zM13 6h2v4h-2z",
        "study": "M8 1a7 7 0 1 0 0 14A7 7 0 0 0 8 1zM6 4.8l5.2 3.2L6 11.2z",
        "settings": "M1 3h14v2H1zM1 7h14v2H1zM1 11h14v2H1zM3.5 1.5h3v5h-3zM9.5 5.5h3v5h-3zM5.5 9.5h3v5h-3z",
        "add": "M7 2h2v5h5v2H9v5H7V9H2V7h5z",
        "remove": "M2 7h12v2H2z",
        "note": "M6 2.5l8-2v10a2.5 2.5 0 1 1-1.5-2.3V3.9L7.5 5.2v7.3a2.5 2.5 0 1 1-1.5-2.3z"
    })
}
