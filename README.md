# Incipit Play

Hub de Remote Play pro Windows, da Incipit. Junta num app só o PlayStation (PS4 e PS5, pelo motor do
[chiaki-ng](https://github.com/streetpea/chiaki-ng)), o Xbox (o Remote Play oficial da Microsoft, numa janela própria do
Edge) e o Switch (por placa de captura). Salva clipe do jogo num atalho de teclado.

O Incipit Play é um fork do chiaki-ng, que nasceu do [Chiaki](https://git.sr.ht/~thestr4ng3r/chiaki) de Florian Märkl.
O motor de PlayStation é deles. A interface, o hub, os clipes e o lançador são da Incipit.

Este projeto não tem ligação com a Sony Interactive Entertainment, a Microsoft nem a Nintendo, e não é aprovado por
elas. PlayStation, Xbox e Switch são marcas dos seus donos e aparecem aqui só pra dizer o console.

## Baixar

Pelo Incipit Instalador: https://github.com/dalmor0/incipit-releases/releases/latest/download/IncipitSetup.exe
(site: https://incipithouse.com.br). O zip do Play se chama `IncipitPlay-portatil-<versão>-<commit>.zip`, e o
`<commit>` no nome é o commit deste repositório que gerou aquele build.

## Compilar

O build oficial roda no GitHub Actions, em `.github/workflows/incipit-windows.yml` (Windows x64, MSYS2 mingw64):

```
gh workflow run incipit-windows.yml -R dalmor0/incipit-play
gh run download <id> -R dalmor0/incipit-play
```

Saem dois arquivos: `IncipitPlay-portatil-<versão>-<commit>.zip` e `IncipitPlay-instalador.exe` (Inno Setup,
`scripts/incipit-play.iss`).

Na sua máquina, os passos são os mesmos do workflow:

1. Instale o [MSYS2](https://www.msys2.org/) e, no terminal MINGW64, os pacotes da lista `pacboy` do workflow
   (Qt 6, OpenSSL, Opus, FFTW, json-c, libevent, miniupnpc, speexdsp, shaderc, SPIRV-Cross, Vulkan, protobuf e o
   resto), mais `pip install protobuf`.
2. `git clone --recursive https://github.com/dalmor0/incipit-play` (os submódulos em `third-party/` são necessários).
3. `scripts/build-libplacebo-windows.sh`, o FFmpeg do passo "Setup ffmpeg" e `scripts/build-sdl2-compat.sh .`
   com `scripts/build-hidapi.sh .`.
4. `cmake -S . -B build -G Ninja -DCMAKE_BUILD_TYPE=Release -DCHIAKI_ENABLE_CLI=OFF` e
   `cmake --build build --target chiaki`.
5. O passo "Deploy" do workflow junta as DLLs, compila o lançador `launcher/incipit-play-launcher.c` (que vira
   `IncipitPlay.exe`) e copia fontes e licenças.

Pra mexer só na interface sem recompilar: a variável `INCIPIT_UI_DIR=<repo>/gui/src/qml` faz o app ler o QML do
disco. Sem ela, vale a interface compilada dentro do .exe.

Onde fica cada coisa e as notas de desenvolvimento: `LEIA-INCIPIT.md`. Revisão de segurança: `SEGURANCA.md`.

## Licença

**AGPL-3.0**, a mesma do chiaki-ng: texto em `LICENSE` (igual a `COPYING`) e, com a exceção do OpenSSL, em
`LICENSES/AGPL-3.0-only-OpenSSL.txt`. Quem recebe o Incipit Play tem direito a este código, inclusive às mudanças
da Incipit. O botão "Código do Incipit Play", em Configurações > Sobre, abre este repositório.

As bibliotecas que vão junto no Windows, com as licenças de cada uma, estão em `NOTICE.md`. O zip leva os textos das
licenças na pasta `licencas/`.

## Marca

O nome "Incipit" e o logo da Incipit são marcas da Incipit, não estão incluídos na licença do código (AGPL-3.0,
seção 7, item e) e não podem ser usados pra apresentar uma versão modificada como se fosse a nossa. Quem distribuir
uma versão modificada deve trocar o nome e o logo. O código continua livre nos termos da AGPL.

O README original do chiaki-ng está em `README-chiaki-ng.md`.

---

**English.** Incipit Play is a Windows Remote Play hub (PlayStation through chiaki-ng, Xbox through Microsoft's
official web player, Switch through a capture card) with clip recording. It is a fork of chiaki-ng and is licensed
under the AGPL-3.0 (`LICENSE`). Build instructions above follow `.github/workflows/incipit-windows.yml`. Third-party
notices: `NOTICE.md`. The "Incipit" name and logo are trademarks and are not licensed for modified versions.
