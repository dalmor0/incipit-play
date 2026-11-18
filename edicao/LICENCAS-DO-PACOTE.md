# Pacote de edição do Incipit Play: o que vai dentro e a licença de cada parte

O pacote é baixado pelo Incipit Play na primeira vez que alguém manda um clipe pra edição. Roda só no PC da
pessoa; nada é mandado pra fora. O código do motor (`clipador/`) está em https://github.com/dalmor0/incipit-play
(pasta `edicao/`), sob a AGPL-3.0 como o resto do Play.

| Parte | Versão | Licença | Código-fonte |
|---|---|---|---|
| Python (embutido) | 3.12.10 | PSF License | https://www.python.org/downloads/release/python-31210/ |
| faster-whisper | 1.2.1 | MIT | https://github.com/SYSTRAN/faster-whisper |
| CTranslate2 | 4.8.2 | MIT | https://github.com/OpenNMT/CTranslate2 |
| ONNX Runtime | 1.30.0 | MIT | https://github.com/microsoft/onnxruntime |
| tokenizers | 0.23.2 | Apache-2.0 | https://github.com/huggingface/tokenizers |
| OpenCV (headless) | 5.0.0 | Apache-2.0 (o wheel traz FFmpeg LGPL dentro do videoio) | https://github.com/opencv/opencv-python |
| NumPy | 2.5.3 | BSD-3-Clause | https://github.com/numpy/numpy |
| tqdm, colorama, PyYAML, flatbuffers, packaging, protobuf | as do wheel | MPL-2.0/MIT, BSD, MIT, Apache-2.0, Apache-2.0/BSD, BSD-3 | PyPI |
| FFmpeg (ffmpeg.exe, build essentials do gyan.dev) | 9.0.2 | GPL-3.0 (com libx264, libass e outras GPL) | https://ffmpeg.org/download.html e https://www.gyan.dev/ffmpeg/builds/ |
| YuNet (detector de rosto, `modelos/yunet.onnx`) | 2023mar | MIT | https://github.com/opencv/opencv_zoo |
| Work Sans, Anton, Archivo | | SIL Open Font License 1.1 | Google Fonts |

O leitor de fala (modelo Whisper "small" convertido pelo SYSTRAN, MIT) não vem no pacote: é baixado na primeira
edição, de https://huggingface.co/Systran/faster-whisper-small no commit fixo, e cada arquivo é conferido pelo
SHA-256 antes de ser usado.

O FFmpeg é GPL-3.0; o Incipit Play é AGPL-3.0, que permite juntar com GPL-3.0 (AGPL-3.0, seção 13). O
código-fonte de cada versão do FFmpeg está nos links acima.
