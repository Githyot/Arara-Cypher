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

        /// Verdadeiro se o texto é um nome de acorde válido.
        #[qinvokable]
        #[cxx_name = "isChord"]
        fn is_chord(&self, name: &QString) -> bool;
    }
}

use araracypher_core::{chord, Chord};
use cxx_qt_lib::QString;

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

    pub fn is_chord(&self, name: &QString) -> bool {
        name.to_string().parse::<Chord>().is_ok()
    }
}
