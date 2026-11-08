# AraraCypher

App para escrever cifras e tablaturas de violão e guitarra de forma rápida,
por exemplo enquanto você assiste a uma aula no YouTube. Roda no **Fedora** e
no **Android**, com dois visuais à escolha: **GNOME** (Adwaita) e **Apple**.

## Plano

1. **Base do app** (em andamento): Rust + Qt/QML, temas GNOME e Apple,
   build automático para Fedora (.rpm) e Android (.apk).
2. **Editor de cifras e tabs**: acordes em cima da letra, tablaturas, batida e
   dedilhado, diagramas de acorde, transposição, biblioteca local, colar cifra pronta.
3. **Microfone acompanhando**: afinador, detecção da nota/acorde e cursor que
   segue a música.
4. **Modo de estudo lúdico**: praticar por trechos, depois tocar tudo na ordem
   e no ritmo, com metrônomo e pontuação.

## Como baixar

Cada build no GitHub Actions gera dois arquivos na aba **Actions** → último
build → **Artifacts**:

- `araracypher-fedoraNN-rpm`: escolha o NN da sua versão (`rpm -E %fedora`) e instale com `sudo dnf install ./araracypher-*.rpm`
- `araracypher-android-apk`: copie para o celular e abra para instalar
  (é preciso permitir "instalar apps desconhecidos").

## Compilar no Fedora

```sh
sudo dnf install gcc-c++ cmake rust cargo \
    qt6-qtbase-devel qt6-qtbase-private-devel qt6-qtdeclarative-devel
cmake -S . -B build -DCMAKE_BUILD_TYPE=Release
cmake --build build -j
./build/araracypher
```

Testes do núcleo (não precisam do Qt): `cargo test -p araracypher-core`.

## Organização do código

| Pasta        | O que tem |
|--------------|-----------|
| `core/`      | Lógica em Rust puro: acordes, transposição e, nos próximos passos, cifras, tabs e áudio. |
| `app/`       | Ponte Rust ↔ QML ([cxx-qt](https://github.com/KDAB/cxx-qt)) e as telas em `app/qml/`. |
| `app/qml/style/Theme.qml` | Cores, fontes e formas dos temas GNOME e Apple. |
| `cpp/main.cpp` | Ponto de entrada mínimo que abre a janela. |
| `packaging/` | Atalho `.desktop` e ícone para o Linux. |

## Licença

GPL-3.0-or-later. Veja [LICENSE](LICENSE).

O Banco de Braços (`core/data/chords-db.json`) vem do projeto
[chords-db](https://github.com/tombatossals/chords-db), de David Rubert, sob a
licença MIT (veja [core/data/chords-db.LICENSE](core/data/chords-db.LICENSE)).
