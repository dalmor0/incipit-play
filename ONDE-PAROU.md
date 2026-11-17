# Incipit Play · onde parou (16/11/2026 ~21h30, antes do reinício do PC)

Rodada 5 pedida pela Central: (1) tela de abertura nativa + cópia única, (2) ID da PSN só com o fim, (3) DPAPI nos tokens
da PSN e na senha do OBS com migração, (4) BAIXOS da banca r4. Meta: 9 no diretor de arte e na produção.

## Pronto e provado
- Código todo no repo `dalmor0/incipit-play` (último commit "Lancador: titulo sem recorte e com respiro").
- Lançador nativo `launcher/incipit-play-launcher.c` vira `IncipitPlay.exe` (104 KB, só DLL do Windows); o app virou
  `IncipitPlay-app.exe`. Zip continua com `IncipitPlay-Win/IncipitPlay.exe` (contrato com o Incipit Instalador).
- Cópia única provada (build 9 e 10): segundo lançador sai sozinho, segue 1 app só.
- Tela de abertura aparece em 0,2 a 2,5 s na maioria (4 a 15 s com a máquina em memória crítica); app em 5,8 a 32 s.
- DPAPI provado no build 9: tokens da PSN e senha do OBS passaram de TEXTO ABERTO pra `dpapi1:` sozinhos, senha aberta
  apagada. Script: `D:\TEMP\...\scratchpad\cofre.py` (se sumir: ler `HKCU\Software\Incipit\Incipit Play\settings`).
  **Falta apagar a senha de teste do OBS** ("senha-de-teste-123", plantada por mim): rodar o cofre.py com `limpar`,
  ou apagar `clipes/obsSenhaCofre` no registro.
- ID da PSN "conta terminada em c1c=", grade de cores com teto de 920, rótulos do Vídeo centrados, "Procurando outros
  consoles", cartão do clipe com hora e tamanho, botões de 44 px. Conferido no preview (`conferencia/ajuste5/`).

## Em andamento quando parou
- Build 11 no Actions (run 43986444440): só ajusta o texto da tela de abertura. Se terminou: `gh run download
  43986444440 -R dalmor0/incipit-play` em `D:\ferramentas\incipit-play\build11`, copiar instalador e zip pra
  `D:\ferramentas\incipit-play\versao-1.10.1\` (hoje lá está o build 10, 3f77052).
- Prints finais com o build 10 em `D:\ferramentas\incipit-play\conferencia\entrega5\` SAÍRAM RUINS (máquina travando antes do
  reinício: 5 janelas não abriram e 3 prints brancos). Refazer tudo depois do reinício, de preferência com o build 11:
  refazer com `python ferramentas/conferir_app.py <build>/app/IncipitPlay-Win <saida> --so=1-playstation,2-xbox,3-switch,4-config-contas,5-config-personalizar,6-config-video,7-config-sobre,10-playstation-claro,11-personalizar-claro,12-clipes,13-xbox-claro,15-clipes-vazio --larga`).

## Próximos passos
1. Baixar o build 11, print da tela de abertura (`ferramentas/testar_copia_unica.py`), conferir que o título não corta.
2. Prints finais (comando acima), renomear `-1920x1080` pra `-1920x1061`, olhar todos.
3. Banca r5: `site-diretor-arte` e `site-producao` (opus) com os prints, a tela de abertura e as provas acima; meta 9 nos dois.
4. Teste do instalador do build 11 numa pasta nova (instala, abre pelo lançador, desinstala).
5. Atualizar `EMPRESA/fichas/devolucoes/2026-11-16-incipit-play.md` (rodada 5) e o item 77 do `EMPRESA/ESPERA-VOCE.md`;
   apagar a senha de teste do OBS; avisar a Central em uma linha (`maestri ask "TERMINAL CENTRAL - PC" ...`).

## Cuidados
- Testes dividem a config com o Incipit Play instalado do Gustavo: o roteiro guarda e devolve aba, cor, tamanho e pasta.
- Nunca matar IncipitPlay de fora de `D:\ferramentas\incipit-play\build*`. O botão Jogar acorda o PS5 de verdade.
- Clipe só no atalho (adendo 2). Gravador de clipe provado no build b7d0aa9 e não mudou desde então.
