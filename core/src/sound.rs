//! Som do metrônomo: um "tic" curto gerado na hora, em WAV, para não
//! precisar guardar arquivos de áudio no app.

/// WAV mono 16 bits, 44,1 kHz: seno na frequência pedida, caindo rápido.
pub fn click_wav(freq: f32, millis: u32) -> Vec<u8> {
    const RATE: u32 = 44_100;
    let n = RATE * millis / 1000;
    let mut data = Vec::with_capacity(n as usize * 2);
    for i in 0..n {
        let t = i as f32 / RATE as f32;
        let env = (-t * 60.0).exp();
        let s = (2.0 * std::f32::consts::PI * freq * t).sin() * env * 0.8;
        data.extend_from_slice(&((s * i16::MAX as f32) as i16).to_le_bytes());
    }
    let mut out = Vec::with_capacity(44 + data.len());
    out.extend_from_slice(b"RIFF");
    out.extend_from_slice(&(36 + data.len() as u32).to_le_bytes());
    out.extend_from_slice(b"WAVEfmt ");
    out.extend_from_slice(&16u32.to_le_bytes()); // tamanho do bloco fmt
    out.extend_from_slice(&1u16.to_le_bytes()); // PCM
    out.extend_from_slice(&1u16.to_le_bytes()); // mono
    out.extend_from_slice(&RATE.to_le_bytes());
    out.extend_from_slice(&(RATE * 2).to_le_bytes()); // bytes por segundo
    out.extend_from_slice(&2u16.to_le_bytes()); // bytes por amostra
    out.extend_from_slice(&16u16.to_le_bytes()); // bits
    out.extend_from_slice(b"data");
    out.extend_from_slice(&(data.len() as u32).to_le_bytes());
    out.extend_from_slice(&data);
    out
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn writes_a_valid_wav_header() {
        let w = click_wav(1000.0, 10);
        assert_eq!(&w[..4], b"RIFF");
        assert_eq!(&w[8..16], b"WAVEfmt ");
        assert_eq!(w.len(), 44 + 441 * 2);
        assert_eq!(u32::from_le_bytes(w[40..44].try_into().unwrap()), 882);
    }
}
