# Edição automática dos clipes (clipador)

O motor do "Mandar pra edição" do Incipit Play. Pega um clipe de jogo e devolve um vertical 1080x1920 pronto pra
postar: o melhor trecho, câmera em cima e jogo embaixo (quando tem câmera), legenda palavra por palavra, zoom nos
picos, título opcional e áudio no volume das redes (-14 LUFS). Roda inteiro no PC da pessoa, sem servidor.

- `clipador/`: o motor (Python). `python -m clipador editar --clipe X --saida PASTA --pedido "..."`; a saída é uma
  linha JSON por evento (etapa, pronto, erro). O Play roda isso pelo `gui/src/incipitedicao.cpp`.
  - `pedido.py` lê o que a pessoa escreveu ("só a parte da fuga", "mais zoom", "título: X", "30 segundos").
    Leitor de regras: ganhou de dois modelos pequenos locais (Qwen2.5 1.5B e SmolLM2 1.7B) nos mesmos 20 pedidos.
  - `fala.py` transcreve com o faster-whisper (modelo "medium", baixado na primeira vez com o SHA-256 conferido).
  - `momento.py` acha o trecho e os pontos de zoom (volume, grito, risada, movimento, palavra do assunto pedido).
  - `camera.py` acha a câmera do jogador (rosto parado no canto, com moldura) e confere a que a pessoa marcou.
  - `legenda.py` monta a legenda em ASS (4 estilos) e `render.py` monta o vídeo quadro a quadro e grava em H.264.
- `pacote/montar_pacote.py`: monta o pacote que o Play baixa (Python embutido, bibliotecas, ffmpeg, o motor).
- `testes/`: pedidos de teste, cancelar, folha de quadros.
- `LICENCAS-DO-PACOTE.md`: o que vai no pacote e a licença de cada parte.
