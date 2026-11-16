"""Teste de conexão do Incipit Play com o PS5: abre o app, aperta Jogar no primeiro console, espera e tira print.
uso: python ferramentas/testar_conexao.py <pasta do app> <pasta de saída> [segundos]
Só fecha a cópia de teste. Guarda e devolve a aba e o tamanho de janela da pessoa.
"""
import os
import sys
import time

sys.argv = [sys.argv[0]] + sys.argv[1:]
import importlib.util
spec = importlib.util.spec_from_file_location("c", os.path.join(os.path.dirname(__file__), "conferir_app.py"))
c = importlib.util.module_from_spec(spec)
spec.loader.exec_module(c)

APP, SAIDA = sys.argv[1], sys.argv[2]
ESPERA = int(sys.argv[3]) if len(sys.argv) > 3 and sys.argv[3].isdigit() else 35
c.APP, c.SAIDA = APP, SAIDA
os.makedirs(SAIDA, exist_ok=True)
c.gravar("hub", "aba", "playstation")
pr, h, t = c.abrir(APP, None)
print("janela em", round(t, 1), "s")
time.sleep(4)
c.por_cliente(h, 40, 60, 1280, 800)
time.sleep(1.5)
c.ImageGrab.grab(bbox=c.caixa_cliente(h), all_screens=True).save(os.path.join(SAIDA, "conexao-0-antes.png"))
c.clicar(h, 1170, 209)        # "Jogar" do primeiro console em 1280x800
for i in (10, ESPERA):
    time.sleep(i if i == 10 else ESPERA - 10)
    c.ImageGrab.grab(bbox=c.caixa_cliente(h), all_screens=True).save(os.path.join(SAIDA, f"conexao-{i}s.png"))
print("ram durante o jogo (MB):", c.ram_mb(pr.pid))
if "--atalho" in sys.argv:
    # atalho de salvar: Alt+F8 (o Alt+F10 é da NVIDIA neste PC)
    u = c.user32
    u.keybd_event(0x12, 0, 0, 0); u.keybd_event(0x77, 0, 0, 0); time.sleep(0.05)
    u.keybd_event(0x77, 0, 2, 0); u.keybd_event(0x12, 0, 2, 0)
    time.sleep(10)
    c.ImageGrab.grab(bbox=c.caixa_cliente(h), all_screens=True).save(os.path.join(SAIDA, "conexao-salvo.png"))
    print("ram depois de salvar (MB):", c.ram_mb(pr.pid))
c.fechar(pr)
