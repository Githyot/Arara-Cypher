//! Leitura de tablatura em texto (o formato de sites e aulas):
//!
//! ```text
//! e|-----------------|
//! B|-----------------|
//! G|------8--6-5-----|
//! D|----6------------|
//! A|-8-8-------------|
//! E|-----------------|
//! ```
//!
//! Cada coluna com número vira um evento (uma nota, ou várias tocadas juntas);
//! `|` no meio da linha vira barra de compasso. Números de dois dígitos
//! (`10`, `12`) contam como uma nota só. Técnicas (`h`, `p`, `/`, `\`, `b`, `~`)
//! ficam guardadas na nota seguinte para a interface mostrar.

use serde::Serialize;

#[derive(Debug, Clone, PartialEq, Eq, Serialize)]
pub struct TabNote {
    /// Corda: 0 = Mi grave ... 5 = Mi agudo.
    pub string: u8,
    pub fret: u8,
    /// Técnica que liga a nota anterior a esta ("h", "p", "/", "\\", "b", "~"), ou vazio.
    #[serde(skip_serializing_if = "String::is_empty")]
    pub tech: String,
}

#[derive(Debug, Clone, PartialEq, Eq, Serialize)]
#[serde(untagged)]
pub enum TabEvent {
    Notes { notes: Vec<TabNote> },
    Bar { bar: bool },
}

/// Lê todo o texto (pode ter vários blocos de 6 linhas) e devolve os eventos em ordem.
pub fn parse(text: &str) -> Vec<TabEvent> {
    let mut out: Vec<TabEvent> = Vec::new();
    let mut block: Vec<(Option<char>, &str)> = Vec::new();
    for raw in text.lines() {
        match split_line(raw) {
            Some(line) => block.push(line),
            None => {
                flush(&mut block, &mut out);
            }
        }
    }
    flush(&mut block, &mut out);
    // Sem barras sobrando nas pontas.
    while matches!(out.last(), Some(TabEvent::Bar { .. })) {
        out.pop();
    }
    while matches!(out.first(), Some(TabEvent::Bar { .. })) {
        out.remove(0);
    }
    out
}

pub fn parse_json(text: &str) -> String {
    serde_json::to_string(&parse(text)).unwrap_or_else(|_| "[]".into())
}

/// "e|--3--|" -> (Some('e'), "--3--|"). Linhas sem "|" depois de uma letra de corda não são tab.
fn split_line(raw: &str) -> Option<(Option<char>, &str)> {
    let line = raw.trim();
    let bar = line.find('|')?;
    let label = line[..bar].trim();
    let letter = match label.chars().count() {
        0 => None,
        1 => {
            let c = label.chars().next().unwrap();
            if !"EADGBeadgb".contains(c) {
                return None;
            }
            Some(c)
        }
        _ => return None,
    };
    let body = &line[bar + 1..];
    if !body.contains('-') {
        return None;
    }
    Some((letter, body))
}

fn string_index(letter: Option<char>, line: usize, lines: usize) -> Option<u8> {
    if lines == 6 {
        // Bloco completo: de cima para baixo é Mi agudo ... Mi grave.
        return Some(5 - line as u8);
    }
    Some(match letter? {
        'e' => 5,
        'B' | 'b' => 4,
        'G' | 'g' => 3,
        'D' | 'd' => 2,
        'A' | 'a' => 1,
        'E' => {
            if line == 0 {
                5
            } else {
                0
            }
        }
        _ => return None,
    })
}

fn flush(block: &mut Vec<(Option<char>, &str)>, out: &mut Vec<TabEvent>) {
    if block.is_empty() {
        return;
    }
    let lines = block.len().min(6);
    // Coluna -> notas que começam nela; colunas com barra em alguma linha.
    let width = block
        .iter()
        .map(|(_, b)| b.chars().count())
        .max()
        .unwrap_or(0);
    let mut columns: Vec<Vec<TabNote>> = vec![Vec::new(); width];
    let mut bars = vec![false; width];

    for (i, (letter, body)) in block.iter().take(6).enumerate() {
        let Some(string) = string_index(*letter, i, lines) else {
            continue;
        };
        let chars: Vec<char> = body.chars().collect();
        let mut c = 0;
        let mut tech = String::new();
        while c < chars.len() {
            let ch = chars[c];
            if ch.is_ascii_digit() {
                let start = c;
                let mut n = 0u32;
                while c < chars.len() && chars[c].is_ascii_digit() && c - start < 2 {
                    n = n * 10 + chars[c].to_digit(10).unwrap();
                    c += 1;
                }
                if n <= 24 {
                    columns[start].push(TabNote {
                        string,
                        fret: n as u8,
                        tech: std::mem::take(&mut tech),
                    });
                }
                continue;
            }
            match ch {
                '|' => {
                    // A barra final da linha não conta como compasso no meio.
                    if c + 1 < chars.len() {
                        bars[c] = true;
                    }
                }
                'h' | 'p' | '/' | '\\' | 'b' | '~' => tech = ch.to_string(),
                '-' | ' ' => {}
                _ => {}
            }
            c += 1;
        }
    }

    if !out.is_empty() && !matches!(out.last(), Some(TabEvent::Bar { .. })) {
        out.push(TabEvent::Bar { bar: true });
    }
    for c in 0..width {
        if bars[c] {
            if !matches!(out.last(), Some(TabEvent::Bar { .. })) && !out.is_empty() {
                out.push(TabEvent::Bar { bar: true });
            }
        } else if !columns[c].is_empty() {
            let mut notes = std::mem::take(&mut columns[c]);
            notes.sort_by_key(|n| n.string);
            out.push(TabEvent::Notes { notes });
        }
    }
    block.clear();
}

#[cfg(test)]
mod tests {
    use super::*;

    fn frets(ev: &[TabEvent]) -> Vec<String> {
        ev.iter()
            .map(|e| match e {
                TabEvent::Bar { .. } => "|".to_string(),
                TabEvent::Notes { notes } => notes
                    .iter()
                    .map(|n| format!("{}:{}{}", n.string, n.tech, n.fret))
                    .collect::<Vec<_>>()
                    .join("+"),
            })
            .collect()
    }

    #[test]
    fn reads_single_notes_and_two_digit_frets() {
        let t = "\
E|-----------------------|
B|-----------------------|
G|------8--6-5-----------|
D|----6---------8/10-----|
A|-8-8-------------------|
E|-----------------------|";
        let ev = parse(t);
        assert_eq!(
            frets(&ev),
            ["1:8", "1:8", "2:6", "3:8", "3:6", "3:5", "2:8", "2:/10"]
        );
    }

    #[test]
    fn chords_bars_and_blocks() {
        let t = "\
e|--0--|--3--|
B|--1--|--0--|
G|--0--|--0--|
D|--2--|--0--|
A|--3--|--2--|
E|-----|--3--|

e|-5-|
B|---|
G|---|
D|---|
A|---|
E|---|";
        let ev = parse(t);
        assert_eq!(
            frets(&ev),
            [
                "1:3+2:2+3:0+4:1+5:0",
                "|",
                "0:3+1:2+2:0+3:0+4:0+5:3",
                "|",
                "5:5"
            ]
        );
        assert!(parse("Uma linha de letra\nE outra").is_empty());
        assert_eq!(
            parse_json("e|-3-|\nB|---|\nG|---|\nD|---|\nA|---|\nE|---|"),
            r#"[{"notes":[{"string":5,"fret":3}]}]"#
        );
    }
}
