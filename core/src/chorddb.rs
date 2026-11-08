//! Banco de Braços: formas de acordes de violão do projeto chords-db
//! (MIT, <https://github.com/tombatossals/chords-db>, ver data/chords-db.LICENSE).
//! Cada acorde tem várias formas (aberta, com pestana, mais em cima...).
//! A chave é `fundamental|sufixo|baixo`, com as notas em semitons (C = 0).

use std::collections::HashMap;
use std::sync::OnceLock;

use crate::chord::Chord;
use crate::shape::ChordShape;

type Entry = ([i8; 6], [u8; 6]);

fn db() -> &'static HashMap<String, Vec<Entry>> {
    static DB: OnceLock<HashMap<String, Vec<Entry>>> = OnceLock::new();
    DB.get_or_init(|| {
        serde_json::from_str(include_str!("../data/chords-db.json")).unwrap_or_default()
    })
}

/// Sufixo do jeito da cifra brasileira (`m7(9)`, `7M`, `9`, `°`) no nome
/// usado pelo banco (`m9`, `maj7`, `add9`, `dim`).
fn canon(suffix: &str) -> String {
    let s = suffix.replace(' ', "");
    let (base, ext) = match s.find('(') {
        Some(i) => (&s[..i], s[i + 1..].trim_end_matches(')').to_string()),
        None => (s.as_str(), String::new()),
    };
    let base = match base {
        "7M" | "M7" | "maj7" | "7+" => "maj7",
        "M" | "maj" => "",
        "°" | "º" | "o" => "dim",
        "°7" | "º7" | "o7" => "dim7",
        "ø" | "m7b5" | "m7-5" => "m7b5",
        "+" | "5+" => "aug",
        "4" | "sus4" => "sus4",
        "74" | "7sus4" | "7sus" => "7sus4",
        "9" => "add9",
        "m9" => "madd9",
        b => b,
    };
    let ext: Vec<&str> = ext.split([',', '/']).filter(|e| !e.is_empty()).collect();
    match (base, ext.as_slice()) {
        (b, []) => b.to_string(),
        ("7", ["9"]) => "9".into(),
        ("m7", ["9"]) => "m9".into(),
        ("maj7", ["9"]) => "maj9".into(),
        ("7", ["11"]) => "11".into(),
        ("m7", ["11"]) => "m11".into(),
        ("maj7", ["11"]) => "maj11".into(),
        ("7", ["13"]) => "13".into(),
        ("maj7", ["13"]) => "maj13".into(),
        ("7", ["b9"] | ["9-"]) => "7b9".into(),
        ("7", ["#9"] | ["9+"]) => "7#9".into(),
        ("7", ["b5"] | ["5-"]) => "7b5".into(),
        ("m7", ["b5"] | ["5-"]) => "m7b5".into(),
        ("7", ["4"]) => "7sus4".into(),
        ("", ["9"]) => "add9".into(),
        ("m", ["9"]) => "madd9".into(),
        ("", ["11"]) => "add11".into(),
        ("6", ["9"]) => "69".into(),
        ("m6", ["9"]) => "m69".into(),
        (b, e) => format!("{b}{}", e.join("")),
    }
}

fn to_shape(e: &Entry, root: u8) -> ChordShape {
    let open = [4u8, 9, 2, 7, 11, 4];
    let frets = e.0.map(|f| if f < 0 { None } else { Some(f as u8) });
    let root_string = (0..6)
        .find(|&s| frets[s].is_some_and(|f| (open[s] + f) % 12 == root))
        .or_else(|| (0..6).find(|&s| frets[s].is_some()))
        .unwrap_or(0);
    ChordShape {
        frets,
        fingers: e.1,
        root_string,
    }
}

/// Todas as formas do banco para o acorde (vazio se não tiver).
pub fn shapes(chord: &Chord) -> Vec<ChordShape> {
    let root = chord.root.semitone();
    let bass = chord
        .bass
        .map(|b| b.semitone().to_string())
        .unwrap_or_default();
    let key = format!("{root}|{}|{bass}", canon(&chord.suffix));
    db().get(&key)
        .map(|v| v.iter().map(|e| to_shape(e, root)).collect())
        .unwrap_or_default()
}

/// Formas do banco em JSON (lista), para o QML.
pub fn shapes_json(name: &str) -> String {
    let list: Vec<String> = name
        .parse::<Chord>()
        .map(|c| shapes(&c).iter().map(ChordShape::to_json).collect())
        .unwrap_or_default();
    format!("[{}]", list.join(","))
}

#[cfg(test)]
mod tests {
    use super::*;

    fn first(name: &str) -> Option<[i8; 6]> {
        shapes(&name.parse().unwrap())
            .first()
            .map(|s| s.frets.map(|f| f.map_or(-1, |v| v as i8)))
    }

    #[test]
    fn finds_brazilian_names() {
        assert_eq!(first("Em"), Some([0, 2, 2, 0, 0, 0]));
        assert!(first("Em7(9)").is_some());
        assert!(first("A11").is_some());
        assert!(first("C7M").is_some());
        assert!(first("G/B").is_some());
        assert!(first("C9").is_some());
        assert!(shapes(&"Bm".parse().unwrap()).len() > 1);
        assert!(!db().is_empty());
    }
}
