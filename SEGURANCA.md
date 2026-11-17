# Incipit Play · revisão de segurança (16/11/2026)

Feita sobre o que a Incipit acrescentou ao chiaki-ng (o motor de PlayStation é o deles, auditado por eles).
Checklist base: `SEGURANCA/checklist-app-com-ia.md` e `EMPRESA/produto-apps/VICIOS-DE-IA.md`.

## O que foi olhado e o que ficou

| Ponto | Risco | Como ficou |
|---|---|---|
| A interface pode abrir programa (`launchDetached`) | QML mal-intencionado abrir qualquer .exe | Só abre `msedge.exe` com caminho absoluto que existe, e só com argumentos que começam com `--`. Teste: `launchDetached("C:/Windows/System32/cmd.exe", [])` devolve falso. |
| Interface carregada de pasta | Alguém trocar a interface por uma maliciosa | Só com a variável `INCIPIT_UI_DIR` (uso de desenvolvimento). O app instalado usa a interface compilada dentro do .exe. |
| Nome de console vindo da rede | Um aparelho na rede anunciar um "PS5" com nome em HTML pra carregar coisa de fora | Todo texto novo usa `Text.PlainText` (InTexto, confirmação). |
| Apagar clipe | Apagar arquivo fora da pasta de clipes | `trash` só aceita .mp4 dentro da pasta de clipes, e manda pra Lixeira (dá pra recuperar). `removeTemp` só apaga .mkv da pasta temporária da placa. |
| Mandar pra edição | Copiar coisa errada | Copia só o .mp4 e o .json escolhidos na biblioteca, pra pasta que a pessoa escolheu. Nunca sobrescreve: se já existe, devolve o que está lá. |
| OBS | Falar com servidor de fora | Só conecta em `127.0.0.1`, porta escolhida, protocolo obs-websocket 5 com o desafio SHA-256 dele. |
| Cópia única | Duas cópias brigando pelo mesmo console | O lançador (`IncipitPlay.exe`) olha o mutex `Local\IncipitPlay-aberto` que o app segura e, se já estiver aberto, só traz a janela pra frente. Provado: o segundo lançador sai sozinho e segue um app só. |
| Atalho global | Virar keylogger | Usa `RegisterHotKey` do Windows: o app só fica sabendo do atalho dele, nenhuma outra tecla. |
| Gravação contínua | Encher a memória | Anel com o tempo do clipe + 12 s e teto de 900 MB. Ao fim do jogo, zera. |
| Importar a config do chiaki-ng | Mexer na config dele | Só lê `HKCU\Software\Chiaki\Chiaki`; escreve só em `HKCU\Software\Incipit\Incipit Play`. Não copia a marca de "Vulkan travou" nem o renderizador forçado. |
| Campos | Texto gigante | Código de registro com 8 dígitos (validador), PIN com 4, porta com 1 a 65535; o IP vai pro motor, que só tenta conectar. |

## Ataque próprio (16/11, builds 3 a 5)
Interface de teste (`D:\ferramentas\incipit-play\teste-ataque\ui\Main.qml`) chamando as funções direto:
`launchDetached(cmd.exe)` deu falso; Edge com argumento sem `--`, falso; caminho relativo, falso; Lixeira num .mp4
fora da pasta de clipes, falso; Lixeira com `..` saindo da pasta, falso; `removeTemp` fora da pasta temporária,
falso. As iscas continuaram no lugar.

## O que fica como ressalva (herdado ou pendente)

- **Tokens da PSN e senha do OBS: resolvido na rodada 5.** Cifrados com o DPAPI do Windows (`gui/src/incipitcofre.cpp`,
  prefixo `dpapi1:`, só a mesma conta do Windows neste PC abre). Os que estavam em texto aberto (inclusive os importados do
  chiaki-ng) são cifrados na primeira leitura, sem perder o login. Prova: antes, `psn_auth_token` e `psn_refresh_token` em
  texto aberto e uma senha de OBS de teste plantada em `clipes/obsSenha`; depois de abrir o build 9, os três viraram
  `dpapi1:` e a senha aberta sumiu; a conta PSN continuou conectada. As chaves de registro do console (`rp_key`) continuam
  como o chiaki-ng guarda.
- **Repositório privado e licença AGPL:** quem receber o binário tem direito ao código. Enquanto o app for só do Gustavo, ok. Antes de dar pra outra pessoa, abrir o repositório (pede o sim) ou mandar o código junto.
- **Instalador sem assinatura de código:** o Windows mostra "editor desconhecido". Assinar custa dinheiro (pede o sim).
- **Login da Microsoft** acontece na página oficial, no Edge, num perfil só do Incipit Play (`%LOCALAPPDATA%\Incipit\Incipit Play\xbox-web`). O app nunca vê a senha.
