//! Objetos Rust expostos ao QML.

#[cxx_qt::bridge]
pub mod qobject {
    unsafe extern "C++" {
        include!("cxx-qt-lib/qstring.h");
        type QString = cxx_qt_lib::QString;
    }

    extern "RustQt" {
        /// Utilidades de música disponíveis em todo o QML como `Music`.
        #[qobject]
        #[qml_element]
        #[qml_singleton]
        #[qproperty(QString, version)]
        type Music = super::MusicRust;

        /// Transpõe um acorde (ex.: `G/B` + 2 = `A/C#`).
        #[qinvokable]
        #[cxx_name = "transposeChord"]
        fn transpose_chord(&self, name: &QString, semitones: i32) -> QString;

        /// Forma do acorde (já transposto) no braço, em JSON; vazio se não souber.
        #[qinvokable]
        #[cxx_name = "chordShape"]
        fn chord_shape(&self, name: &QString, semitones: i32) -> QString;

        /// Verdadeiro se o texto é um nome de acorde válido.
        #[qinvokable]
        #[cxx_name = "isChord"]
        fn is_chord(&self, name: &QString) -> bool;

        /// Lê uma tablatura em texto e devolve os eventos (notas e barras) em JSON.
        #[qinvokable]
        #[cxx_name = "parseTab"]
        fn parse_tab(&self, text: &QString) -> QString;

        /// Tab em blocos para a visualização de aula (acordes em cima, setas embaixo).
        #[qinvokable]
        #[cxx_name = "lessonTab"]
        fn lesson_tab(&self, text: &QString) -> QString;
        #[qinvokable]
        #[cxx_name = "tabModel"]
        fn tab_model(&self, text: &QString) -> QString;
        #[qinvokable]
        #[cxx_name = "renderTab"]
        fn render_tab(&self, json: &QString) -> QString;
        #[qinvokable]
        #[cxx_name = "alignArrows"]
        fn align_arrows(&self, text: &QString) -> QString;
        #[qinvokable]
        #[cxx_name = "setArrow"]
        fn set_arrow(&self, text: &QString, system: i32, event: i32, arrow: &QString) -> QString;

        /// Arquivo WAV do "tic" do metrônomo (forte no primeiro tempo), como URL.
        #[qinvokable]
        #[cxx_name = "clickSound"]
        fn click_sound(&self, accent: bool) -> QString;

        /// Pontua o jogo de batida: tempos esperados e toques (JSON, em ms).
        #[qinvokable]
        #[cxx_name = "judgeRhythm"]
        fn judge_rhythm(&self, expected: &QString, taps: &QString) -> QString;
    }

    extern "RustQt" {
        /// Cifras salvas no aparelho, disponível no QML como `Library`.
        /// `revision` aumenta a cada mudança, para o QML ler a lista de novo.
        #[qobject]
        #[qml_element]
        #[qml_singleton]
        #[qproperty(i32, revision)]
        #[qproperty(QString, folder)]
        type Library = super::LibraryRust;

        /// Todas as músicas salvas, como array JSON.
        #[qinvokable]
        fn songs(&self) -> QString;

        /// Salva a música (objeto JSON) e devolve o id; vazio se falhar.
        #[qinvokable]
        fn save(self: Pin<&mut Self>, json: &QString) -> QString;

        /// Apaga a música pelo id.
        #[qinvokable]
        fn remove(self: Pin<&mut Self>, id: &QString) -> bool;

        /// Lê uma cifra colada e devolve as partes com acordes, em JSON.
        #[qinvokable]
        #[cxx_name = "parseSheet"]
        fn parse_sheet(&self, text: &QString) -> QString;

        /// Verdadeiro se o texto parece um acorde (e não uma palavra da letra).
        /// Lê o texto de um print (OCR local). JSON `{"ok":bool,"text":".."}`.
        #[qinvokable]
        #[cxx_name = "readImage"]
        fn read_image(&self, path: &QString) -> QString;

        #[qinvokable]
        #[cxx_name = "isChordToken"]
        fn is_chord_token(&self, text: &QString) -> bool;

        /// Lê a página baixada de um link de cifra: `{title, artist, key, capo, text}`.
        #[qinvokable]
        #[cxx_name = "readPage"]
        fn read_page(&self, html: &QString) -> QString;

        /// Escolhe a letra certa na resposta da busca do LRCLIB:
        /// `{found, instrumental, plain, synced:[{t, text}]}`.
        #[qinvokable]
        #[cxx_name = "pickLyrics"]
        fn pick_lyrics(&self, results: &QString, title: &QString, artist: &QString) -> QString;

        /// Lê uma música inteira de um texto: partes, batidas com BPM, formas,
        /// tom, capotraste, artista e título. JSON no formato das músicas.
        #[qinvokable]
        #[cxx_name = "parseSong"]
        fn parse_song(&self, text: &QString) -> QString;

        /// Conteúdo de um arquivo de texto (.txt) escolhido pelo usuário.
        #[qinvokable]
        #[cxx_name = "readTextFile"]
        fn read_text_file(&self, path: &QString) -> QString;
    }
}

use araracypher_core::{chord, library, ocr, shape, sheet, tab, Chord};
use core::pin::Pin;
use cxx_qt::CxxQtType;
use cxx_qt_lib::QString;
use std::path::PathBuf;

pub struct MusicRust {
    version: QString,
}

impl Default for MusicRust {
    fn default() -> Self {
        Self {
            version: QString::from(env!("CARGO_PKG_VERSION")),
        }
    }
}

impl qobject::Music {
    pub fn transpose_chord(&self, name: &QString, semitones: i32) -> QString {
        QString::from(chord::transpose_name(&name.to_string(), semitones).as_str())
    }

    pub fn chord_shape(&self, name: &QString, semitones: i32) -> QString {
        let transposed = chord::transpose_name(&name.to_string(), semitones);
        QString::from(shape::shape_json(&transposed).as_str())
    }

    pub fn is_chord(&self, name: &QString) -> bool {
        name.to_string().parse::<Chord>().is_ok()
    }

    pub fn parse_tab(&self, text: &QString) -> QString {
        QString::from(tab::parse_json(&text.to_string()).as_str())
    }

    pub fn tab_model(&self, text: &QString) -> QString {
        QString::from(tab::edit_model_json(&text.to_string()).as_str())
    }

    pub fn render_tab(&self, json: &QString) -> QString {
        QString::from(tab::render_json(&json.to_string()).as_str())
    }

    pub fn align_arrows(&self, text: &QString) -> QString {
        QString::from(tab::align_arrows(&text.to_string()).as_str())
    }

    pub fn set_arrow(&self, text: &QString, system: i32, event: i32, arrow: &QString) -> QString {
        let t = text.to_string();
        if system < 0 || event < 0 {
            return QString::from(t.as_str());
        }
        QString::from(tab::set_arrow(&t, system as usize, event as usize, &arrow.to_string()).as_str())
    }

    pub fn lesson_tab(&self, text: &QString) -> QString {
        QString::from(tab::lesson_json(&text.to_string()).as_str())
    }

    pub fn click_sound(&self, accent: bool) -> QString {
        let name = if accent { "forte" } else { "fraco" };
        let path = std::env::temp_dir().join(format!("araracypher-tic-{name}.wav"));
        let wav = araracypher_core::sound::click_wav(if accent { 1760.0 } else { 1175.0 }, 60);
        match std::fs::write(&path, wav) {
            Ok(()) => QString::from(format!("file://{}", path.display()).as_str()),
            Err(_) => QString::default(),
        }
    }

    pub fn judge_rhythm(&self, expected: &QString, taps: &QString) -> QString {
        QString::from(
            araracypher_core::rhythm::judge_json(&expected.to_string(), &taps.to_string()).as_str(),
        )
    }
}

pub struct LibraryRust {
    revision: i32,
    folder: QString,
    dir: PathBuf,
}

impl Default for LibraryRust {
    fn default() -> Self {
        let dir = library::default_dir();
        Self {
            revision: 0,
            folder: QString::from(dir.to_string_lossy().as_ref()),
            dir,
        }
    }
}

impl qobject::Library {
    pub fn songs(&self) -> QString {
        QString::from(library::list_json(&self.rust().dir).as_str())
    }

    pub fn save(mut self: Pin<&mut Self>, json: &QString) -> QString {
        match library::save(&self.rust().dir, &json.to_string()) {
            Ok(id) => {
                let next = self.revision() + 1;
                self.as_mut().set_revision(next);
                QString::from(id.as_str())
            }
            Err(err) => {
                eprintln!("AraraCypher: não consegui salvar a música: {err}");
                QString::default()
            }
        }
    }

    pub fn remove(mut self: Pin<&mut Self>, id: &QString) -> bool {
        let ok = library::remove(&self.rust().dir, &id.to_string());
        if ok {
            let next = self.revision() + 1;
            self.as_mut().set_revision(next);
        }
        ok
    }

    pub fn parse_sheet(&self, text: &QString) -> QString {
        QString::from(sheet::parse_json(&text.to_string()).as_str())
    }

    pub fn read_image(&self, path: &QString) -> QString {
        let path = path.to_string();
        let prepared = prepare_for_ocr(&path);
        let target = prepared.as_deref().unwrap_or(path.as_str());
        let result = ocr::read_image(target);
        if let Some(tmp) = &prepared {
            let _ = std::fs::remove_file(tmp);
        }
        let (ok, text) = match result {
            Ok(t) => (true, t),
            Err(e) => (false, e),
        };
        let json = format!(
            "{{\"ok\":{},\"text\":{}}}",
            ok,
            serde_json::to_string(&text).unwrap_or_else(|_| "\"\"".into())
        );
        QString::from(json.as_str())
    }

    pub fn is_chord_token(&self, text: &QString) -> bool {
        sheet::is_chord_token(&text.to_string())
    }

    pub fn pick_lyrics(&self, results: &QString, title: &QString, artist: &QString) -> QString {
        QString::from(
            araracypher_core::lyrics::pick_json(
                &results.to_string(),
                &title.to_string(),
                &artist.to_string(),
            )
            .as_str(),
        )
    }

    pub fn parse_song(&self, text: &QString) -> QString {
        QString::from(araracypher_core::song::parse_json(&text.to_string()).as_str())
    }

    pub fn read_text_file(&self, path: &QString) -> QString {
        match std::fs::read(path.to_string()) {
            // Arquivos antigos podem estar em Latin-1; o que não for UTF-8 vira "?".
            Ok(bytes) => QString::from(String::from_utf8_lossy(&bytes).as_ref()),
            Err(_) => QString::default(),
        }
    }

    pub fn read_page(&self, html: &QString) -> QString {
        QString::from(araracypher_core::web::extract_json(&html.to_string()).as_str())
    }
}

/// Aumenta o print, passa para cinza e deixa preto no branco (ver
/// `ocr::binarize`). Devolve o caminho de um PGM temporário, ou None se não
/// conseguiu abrir a imagem (aí o OCR tenta a imagem original).
fn prepare_for_ocr(path: &str) -> Option<String> {
    use cxx_qt_lib::{QImage, TransformationMode};
    let data = std::fs::read(path).ok()?;
    let mut image = QImage::from_data(&data, None)?;
    if image.width() < 1800 {
        let target = (image.width() * 3).min(2400);
        image = image.scaled_to_width(target, TransformationMode::SmoothTransformation);
    }
    let (w, h) = (image.width(), image.height());
    if w <= 0 || h <= 0 {
        return None;
    }
    let mut gray = Vec::with_capacity((w * h) as usize);
    for y in 0..h {
        for x in 0..w {
            let c = image.pixel_color(x, y);
            // Pega o canal mais claro: texto azul ou laranja em fundo escuro
            // continua claro, em vez de virar cinza-escuro.
            gray.push(c.red().max(c.green()).max(c.blue()) as u8);
        }
    }
    let bw = ocr::binarize(&gray);
    let tmp = std::env::temp_dir().join(format!("araracypher-ocr-{}.pgm", std::process::id()));
    std::fs::write(&tmp, ocr::pgm(w as u32, h as u32, &bw)).ok()?;
    Some(tmp.to_string_lossy().into_owned())
}
