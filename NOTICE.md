# Incipit Play · créditos e licenças

Incipit Play
Copyright (C) 2026 Incipit
Licença: GNU Affero General Public License v3.0 (`LICENSE`), com a exceção do OpenSSL
(`LICENSES/AGPL-3.0-only-OpenSSL.txt`). Código: https://github.com/dalmor0/incipit-play

## Projeto de origem

- **chiaki-ng**, de Street Pea e colaboradores. AGPL-3.0 com exceção do OpenSSL.
  https://github.com/streetpea/chiaki-ng
- **Chiaki**, de Florian Märkl e colaboradores, base do chiaki-ng. AGPL-3.0 com exceção do OpenSSL.
  https://git.sr.ht/~thestr4ng3r/chiaki

A lista de autores do código herdado está no histórico do git deste repositório e no `README-chiaki-ng.md`.

## Código de terceiros dentro do repositório

| Componente | Onde | Licença |
|---|---|---|
| nanopb | `third-party/nanopb` (submódulo) | zlib |
| Jerasure | `third-party/jerasure` (submódulo) | BSD-3-Clause |
| GF-Complete | `third-party/gf-complete` (submódulo) | BSD-3-Clause |
| curl | `third-party/curl` (submódulo) | curl (estilo MIT) |
| cpp-steam-tools | `third-party/cpp-steam-tools` (submódulo, de Street Pea) | ver o repositório do submódulo |
| setsu | `setsu/` | AGPL-3.0 com exceção do OpenSSL (do Chiaki) |
| Fonte Archivo | `gui/src/qml/fonts/` | SIL Open Font License 1.1 (`OFL-Archivo.txt`) |
| Fonte Young Serif | `gui/src/qml/fonts/` | SIL Open Font License 1.1 (`OFL-YoungSerif.txt`) |
| Fonte IBM Plex Mono | `gui/src/qml/fonts/` | SIL Open Font License 1.1 (`OFL-IBMPlexMono.txt`) |
| Pintura da hora azul (faixa do menu) | `gui/src/qml/imagens/hora-azul.jpg` | da Incipit House, a mesma do site; uso no Incipit Play |

## Bibliotecas que vão junto no Windows

O zip do Incipit Play traz estas bibliotecas como DLL, ligadas de forma dinâmica. Cada uma continua com a própria
licença. Os textos vão na pasta `licencas/` do zip: a lista exata de pacotes MSYS2 com versão, licença declarada e
endereço fica em `licencas/PACOTES.txt`, gerada pelo build.

| Biblioteca | Licença |
|---|---|
| Qt 6 (Core, Gui, Qml, Quick, Multimedia, Svg, WebSockets e módulos) | LGPL-3.0 |
| FFmpeg (avcodec, avformat, avutil, swresample, swscale), build gpl-shared de streetpea/FFmpeg-Builds | GPL (texto no `licencas/ffmpeg/`) |
| libplacebo | LGPL-2.1 ou posterior |
| SDL 3 e sdl2-compat | zlib |
| hidapi | BSD-3-Clause (uma das opções da licença dele) |
| OpenSSL (libcrypto) | Apache-2.0 |
| Opus | BSD-3-Clause |
| SpeexDSP | BSD-3-Clause |
| FFTW 3 | GPL-2.0 ou posterior |
| libevent, miniupnpc, libssh2, double-conversion, PCRE2, zstd | BSD |
| json-c, lcms2, libdovi, HarfBuzz, md4c, nghttp2, libpsl, libffi, Brotli | MIT |
| shaderc, SPIRV-Cross | Apache-2.0 |
| GLib, gettext (libintl), libiconv, Graphite2 | LGPL |
| libidn2, libunistring | LGPL-3.0 ou GPL-2.0 |
| FreeType | FreeType License |
| ICU | Unicode License |
| zlib, libpng, libjpeg-turbo, bzip2, libb2 | licenças próprias, permissivas |
| GCC runtime (libgcc, libstdc++), winpthreads | GPL-3.0 com a GCC Runtime Library Exception; MIT e BSD |

O código-fonte de cada biblioteca está no projeto dela ou nos pacotes de fonte do MSYS2
(https://packages.msys2.org). O do FFmpeg está em https://github.com/streetpea/FFmpeg-Builds.

## Edição automática dos clipes (pacote baixado à parte)

O "Mandar pra edição" usa um pacote que o Play baixa na primeira vez, de
https://github.com/dalmor0/incipit-releases/releases/tag/edicao-1.0.3, conferido pelo SHA-256 escrito em
`gui/src/incipitedicao.cpp`. Dentro dele: o motor `edicao/clipador` (deste repositório, AGPL-3.0), Python 3.12
embutido (PSF), faster-whisper e CTranslate2 (MIT), ONNX Runtime (MIT), tokenizers (Apache-2.0), OpenCV
(Apache-2.0), NumPy (BSD), o detector de rosto YuNet (MIT), as fontes Work Sans, Anton e Archivo (OFL) e o
FFmpeg 9.0.2 do gyan.dev (GPL-3.0). Lista completa com versão e link do código em `edicao/LICENCAS-DO-PACOTE.md`.
O leitor de fala (Whisper "medium" convertido pelo SYSTRAN, MIT) é baixado na primeira edição, de commit fixo
no Hugging Face, e cada arquivo é conferido pelo SHA-256.

## Marca

"Incipit" e o logo da Incipit são marcas da Incipit e ficam fora da licença do código (AGPL-3.0, seção 7, item e).
Versão modificada distribuída por outra pessoa deve usar outro nome e outro logo.

PlayStation é marca da Sony Interactive Entertainment. Xbox é marca da Microsoft. Nintendo Switch é marca da
Nintendo. O Incipit Play não tem ligação com essas empresas.
