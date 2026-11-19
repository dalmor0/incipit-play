# Incipit Play

Hub de Remote Play da Incipit: PlayStation (motor do chiaki-ng, AGPL-3.0), Xbox (Remote Play oficial da Microsoft
em janela própria do Edge) e Switch (placa de captura UVC), com clipes no atalho. Código aberto em
`dalmor0/incipit-play` (AGPL-3.0). Apresentação pública e como compilar: `README.md`.

## Onde fica cada coisa
- Interface nova: `gui/src/qml/` (IncipitHub, Pagina*, In*, Tema, ClipesConfig). A antiga do chiaki-ng continua lá
  pras telas de jogo e pros "Mais ajustes".
- Gravador de clipes, atalho global e OBS: `gui/src/cliprecorder.cpp` (ligado em `streamsession.cpp`).
- Nome, config própria e importação da config do chiaki-ng: `gui/src/main.cpp`.
- Lançador nativo `launcher/incipit-play-launcher.c` (vira `IncipitPlay.exe`, 104 KB, só DLL do Windows): mostra a tela de
  abertura na hora, deixa uma cópia só e abre o app de verdade, `IncipitPlay-app.exe`. Com argumentos (`stream`, `list`) só
  repassa.
- Cofre DPAPI pros segredos: `gui/src/incipitcofre.cpp`.
- Instalador: `scripts/incipit-play.iss`. Build: `.github/workflows/incipit-windows.yml` (só roda na mão).
- Binários prontos: os do Actions (passo 3 abaixo); o zip publicado vai no release do Incipit Instalador.
- Conferência: `ferramentas/conferir_app.py` (abertura, RAM, prints), `ferramentas/testar_atalho.py`
  (transmite e salva um clipe), `ferramentas/testar_conexao.py`, `ferramentas/testar_rolagem.py` (roda do mouse nas
  abas, antes e depois) e `ferramentas/medir_abertura.py` (tempo até a janela, N vezes).
  Com outro Incipit Play aberto, `--direto` abre o `IncipitPlay-app.exe` sem o lançador (a cópia única não deixa
  abrir outro pelo lançador). Com o TeamViewer aberto, `--postar` manda clique e tecla como mensagem do Windows, porque
  o clique sintético não chega. Coordenada de clique muda com o layout: o clique antigo do "Registrar" cai no Jogar,
  que acorda o PS5 de verdade.
- Identidade (18/11): tokens da família Incipit em `Tema.qml` (azul-marinho `#121624`, botão forte sempre no azul do
  logo, degradê `luz1`/`luz2` só em recompensa, `mono` em número e atalho). Botões: `forte`, `normal`, `quieto`, `perigo`.

- Edição automática dos clipes ("Mandar pra edição"): motor em `edicao/` (Python, ver `edicao/README.md`), ligado
  ao app por `gui/src/incipitedicao.cpp` (baixa o pacote com SHA-256 fixo, roda num Job do Windows com prioridade
  baixa, espera a transmissão acabar) e pelas telas `ClipesEdicao.qml`, `EdicaoPedido.qml` e `EdicaoCamera.qml`.
  Mudou o motor: `python edicao/pacote/montar_pacote.py <pasta>`, novo release `edicao-<versão>` em
  dalmor0/incipit-releases (nunca o Latest) e a versão, o endereço, o tamanho e o SHA-256 novos no
  `incipitedicao.cpp`. Desenvolvimento: `INCIPIT_EDICAO_DIR=<pacote aberto>` pula o download.

## Gerar uma versão
1. `git push` neste repositório.
2. `gh workflow run incipit-windows.yml -R dalmor0/incipit-play` (uns 25 min no Actions).
3. `gh run download <id> -R dalmor0/incipit-play`: sai `IncipitPlay-instalador.exe` e
   `IncipitPlay-portatil-<versão>-<commit>.zip` (dentro, `IncipitPlay-Win/IncipitPlay.exe`). O instalador da família
   (Incipit) usa esse zip como pacote do Play: não mudar nome nem estrutura.

## Mexer só na interface
`INCIPIT_UI_DIR=<esta pasta>/gui/src/qml` faz o app carregar o QML do disco (desenvolvimento). Sem a variável, vale
a interface compilada dentro do .exe.

## Config
`HKCU\Software\Incipit\Incipit Play` (a do chiaki-ng, `HKCU\Software\Chiaki\Chiaki`, só é lida, uma vez).
Clipes em `Vídeos\Incipit Play\<data hora> <jogo>\`, um .mp4, um .json e uma .jpg por clipe.
