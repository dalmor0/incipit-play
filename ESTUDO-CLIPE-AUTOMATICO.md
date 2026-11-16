# Estudo: clipador automático pro Incipit Play

Data: 16/11/2026. Pesquisa na web feita hoje. Onde não achei fonte boa, está escrito "estimativa minha" ou "não confirmado".

## Resumo

- Quase todo mundo mistura 2 ou 3 sinais: evento do jogo (ou kill feed lido da tela), pico de áudio e chat, e transcrição de fala. Nenhuma ferramenta publica o método exato.
- O Incipit Play recebe vídeo de console por streaming. Não tem API de jogo nem Overwolf, então o caminho é ler a tela e o áudio. É o que dá pra fazer.
- Pra GTA RP, o momento é fala e reação. Isso é áudio mais transcrição, não kill feed.
- Fase 1 (pico de áudio mais marcação manual) custa quase nada de GPU e já dá pra entregar na versão 1. Visão e fala viram pagas depois.

## 1. Como as outras ferramentas acham o momento

| Ferramenta | Como detecta | Jogos | Local ou nuvem | Preço |
|---|---|---|---|---|
| Medal.tv | "Medal AI" detecta eventos e salva sozinho. O método (evento do jogo ou vídeo) não é publicado. [Medal](https://medal.tv/auto-clipping), [suporte](https://support.medal.tv/support/solutions/articles/48001167701-what-is-automatic-event-detection-auto-clipping-) | Diz 100+ jogos; a lista real fica em Configurações dentro do app. Só Windows | Local, no app | Premium por volta de US$ 9,99/mês, só achei em loja parceira ([Green Man Gaming](https://www.greenmangaming.com/xp-offers/medaltv/)); confirmar em [medal.tv/premium](https://medal.tv/premium) |
| Outplayed (Overwolf) | Eventos oficiais do jogo pela API de eventos da Overwolf ([docs](https://dev.overwolf.com/ow-native/guides/general-tech/auto-highlights-supported-games)) | Lista curta: LoL, Dota 2, Fortnite, CS2, PUBG, R6, Apex, Rocket League, Valorant, Overwatch e poucos mais. Não achei GTA V na documentação | Local | Não achei preço confiável |
| NVIDIA Highlights / NVIDIA App | O jogo manda os eventos (headshot, multikill, etc.) pra NVIDIA, que salva o clipe ([NVIDIA](https://www.nvidia.com/en-us/geforce/news/battlefield-v-nvidia-highlights/)). No GeForce NOW usam reconhecimento de imagem na nuvem ([NVIDIA](https://blogs.nvidia.com/blog/geforce-now-highlights-freestyle-montage)) | Só jogos que integraram | Local (placa GeForce) | Grátis |
| Eklipse | Lê sinais da VOD: kill feed, pico de áudio, velocidade do chat ([Eklipse](https://eklipse.gg/compare/eklipse-vs-streamladder/)). Fonte é o próprio site deles | Diz 1.000+ | Nuvem | Preços contraditórios entre fontes; conferir no site |
| StreamLadder (ClipGPT) | Varre a VOD inteira, dá nota por momento. Uma resenha diz que usa análise de transcrição, não olha a jogada ([Eklipse, rival](https://eklipse.gg/compare/streamladder-alternatives/)) | Qualquer vídeo | Nuvem | Grátis básico; Silver ~US$ 9; Gold ~US$ 27/mês (ClipGPT no Gold, segundo [resenha](https://www.twoaveragegamers.com/best-ai-tools-for-gaming-content-creators-in-2026/)) |
| Powder | Detecção treinada em 40+ jogos mais reação, chat, áudio e transcrição ([Eklipse](https://eklipse.gg/compare/clipbot-alternatives/)) | 40+ | Nuvem | Fontes dizem que fechou em 2024 ou 2025 |
| Athenascope | Visão computacional no vídeo, enviado pra servidor deles ([TechCrunch](https://techcrunch.com/?p=2200891), [PC Gamer](https://www.pcgamer.com/uk/this-tech-uses-ai-to-automatically-create-highlight-clips-for-you-in-fortnite-and-pubg)) | Fortnite, Rocket League, PUBG no lançamento | Nuvem | Era grátis. Fechou em 2022 segundo [concorrente](https://www.framedrop.ai/blog/athenascope-alternative) |

Leitura: quem roda local e é confiável (Medal, Outplayed, NVIDIA) depende de integração com o jogo. Quem funciona em qualquer jogo (Eklipse, StreamLadder) roda na nuvem sobre VOD e é cobrado por mês. Dois produtos de visão pura (Athenascope, Powder) fecharam, o que sugere que o negócio é difícil de sustentar sozinho.

## 2. O que serve pra GTA RP e pra jogo de tiro

**Jogo de tiro (Valorant, CoD, Apex etc.)**
- Kill feed lido por OCR ou template matching num canto fixo da tela. Multikill = vários kills em poucos segundos. Barato e preciso.
- Pico de áudio (tiro, grito do jogador) ajuda de reforço.
- Cada jogo tem HUD diferente: um perfil por jogo, com a região do kill feed e as cores.

**GTA RP**
- O momento é fala engraçada, discussão, reação, pico de risada. Kill feed quase não existe.
- Serve: pico de áudio da voz do Gustavo e do chat de voz, depois transcrição (whisper) pra achar palavra-chave e confirmar que teve fala. Chat da Twitch (pico de mensagens e emote) é o melhor sinal de "isso foi bom" na live.
- Não serve: evento oficial. Não achei GTA V na lista de eventos da Overwolf, e o GTA Online usa BattlEye ([Wikipedia](https://en.wikipedia.org/wiki/BattlEye)).
- Ninguém na tabela se vende como bom pra RP. É uma brecha real do produto.

## 3. Custo local e risco pro stream

Números abaixo são ordem de grandeza. Só o primeiro tem medição citada; o resto é estimativa minha e tem que ser medido numa máquina do Gustavo antes de prometer.

- **Pico de áudio:** CPU quase zero (RMS ou LUFS por janela de 100 ms sobre PCM). Sem GPU. É de graça.
- **Chat da Twitch:** só rede, sem custo de máquina.
- **Detector de visão pequeno (YOLO nano, 1 a 2 fps):** um fornecedor de hospedagem mede YOLOv8n a centenas de fps numa RTX 4060/5060 Ti a 640x640 ([GigaGPU](https://gigagpu.com/run-yolov8-on-rtx-4060/), fonte interessada), então 1 a 2 fps é irrisório. VRAM: estimativa minha, algumas centenas de MB. Uso de GPU: estimativa minha, abaixo de 5%. O custo real é copiar o quadro e redimensionar, e isso eu faria na CPU a partir do quadro que o decodificador já gerou.
- **OCR do kill feed:** recorte pequeno, 1 a 2 fps, CPU. Estimativa minha: poucos % de um núcleo.
- **Whisper small pra fala:** a doc do Whisper original fala em cerca de 2 GB de VRAM pro small ([Mintlify](https://www.mintlify.com/openai/whisper/concepts/models)). Com faster-whisper em int8 deve ficar abaixo disso (inferência minha, não achei medida). Rodar em blocos de 10 a 30 s e não contínuo reduz a carga. É o item mais pesado dos três.

**Risco de atrapalhar o stream.** O app já decodifica 1080p60 (decodificador de hardware da GPU, bloco separado dos núcleos de CUDA) e o jogo roda no console, não no PC. Quem sofre é o OBS, que codifica o stream na mesma GPU. Regras:
1. Visão e whisper rodam com prioridade baixa e só quando o app está fora de uma live, ou em fila, depois da live.
2. Se a GPU passar de um limite (ex.: 80%) ou o OBS perder quadro, a análise pausa sozinha.
3. Fase 1 não usa GPU, então não tem esse risco.
4. Alternativa sem risco nenhum: analisar o .mp4 já salvo, depois da sessão.

## 4. Plano em fases

**Fase 1: barata e local (junto com a versão 1)**
- Pico de áudio sugere marcador na linha do tempo; Alt+F10 continua sendo o gesto principal.
- Marcação manual (atalho de "marcar aqui") e clipe dos últimos 90 s.
- Entrega pro usuário: "o app me lembra dos momentos que eu esqueci de clipar", com lista de candidatos pra aprovar ou descartar na aba Clipes.
- Cobrar: não. É o gancho do app gratuito.

**Fase 2: visão por jogo (OCR/YOLO, 1 a 2 fps)**
- Perfil por jogo, começando pelos que o Gustavo joga (jogos de tiro). Kill feed, multikill, tela de vitória.
- Entrega: clipe automático de multikill sem apertar nada.
- Cobrar: plano pago faz sentido aqui, porque a manutenção por jogo é o custo (HUD muda a cada atualização). Pacote de perfis por jogo ou mensalidade baixa. Referência de mercado: Medal e StreamLadder na faixa de US$ 9 a 27 por mês (fontes na tabela, a conferir).

**Fase 3: fala e chat com IA, possivelmente pago**
- Whisper local pra transcrever e achar frase marcante, mais chat da Twitch (pico de mensagens) pra GTA RP e live.
- Clipe já vertical com legenda, pra cortes curtos.
- Cobrar: é o que ninguém faz bem pra RP. Se usar nuvem pra modelo maior, vira custo recorrente e entra na assinatura. Se rodar tudo local, dá pra vender como licença.

## 5. Riscos

- **Anti-cheat.** Ler a tela (captura de vídeo) é o que OBS e todo mundo faz, e aqui nem toca no jogo: o jogo está no console. É o caso mais seguro possível. Injetar DLL ou ler memória do jogo é o que bane conta; evitar sempre. Não achei documentação oficial de EAC ou Vanguard dizendo que OCR de tela é permitido, então "é ok" é inferência: não há injeção nem hook. Relato: o Vanguard tira screenshots da tela ([80.lv](https://80.lv/articles/valorant-league-of-legends-players-are-worried-about-games-allegedly-taking-screenshots-of-their-whole-screens)), o que só importa se o app rodar no mesmo PC do jogo, o que o Play não faz. Overwolf, por exemplo, pode ser bloqueado por anti-cheat de terceiros como a FACEIT ([suporte Overwolf](https://support.overwolf.com/support/solutions/articles/9000233364-using-overwolf-and-faceit)). Mais um motivo pra não depender dele.
- **Termos de uso dos jogos.** Gravar e clipar o próprio gameplay costuma ser permitido, mas cada publisher tem política de conteúdo. Não li os termos de GTA/Rockstar nem dos jogos de tiro nesta pesquisa; revisar um por um antes de listar "jogo suportado" no marketing.
- **Twitch.** Se for usar API (criar clipe, ler chat), vale o contrato de desenvolvedor. A API de Create Clip tem limite de taxa mais apertado e já deu 503 em fóruns ([fórum Twitch](https://discuss.dev.twitch.com/t/create-clip-rate-limit-questions/17472)). Não li o Developer Services Agreement inteiro; ler antes da fase 3. Usar só o chat do próprio canal do usuário, com a conta dele, reduz o risco.
- **Privacidade.** O voice chat do GTA RP tem outras pessoas falando. Transcrever fala de terceiros no PC do usuário é uma coisa; mandar áudio pra nuvem é outra. Regra: fase 3 roda local por padrão, nada sobe sem aviso claro, e o texto dos termos do app deve dizer isso. Não achei, nesta pesquisa, jurisprudência ou norma específica sobre transcrição de voz de terceiros em live, então vale checar com advogado antes de cobrar.
- **Marca.** Não prometer "detecta tudo". Prometer o que existe: "sugere momentos, você aprova".

## Próximo passo

Medir a fase 2 e 3 na máquina do Gustavo (GPU, % com OBS ligado) antes de decidir preço. Confirmar preços atuais nos sites oficiais, porque as fontes de preço aqui são de terceiros e discordam.
