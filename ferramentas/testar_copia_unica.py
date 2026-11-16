"""Cópia única e tela de abertura do lançador.
uso: python ferramentas/testar_copia_unica.py <pasta do app> <pasta de saída>
1. abre o IncipitPlay.exe e fotografa a tela de abertura assim que ela aparece;
2. espera a janela do app; abre o IncipitPlay.exe de novo e confere que o segundo sai sozinho sem abrir outro app.
"""
import os
import subprocess
import sys
import time

import importlib.util
spec = importlib.util.spec_from_file_location("c", os.path.join(os.path.dirname(__file__), "conferir_app.py"))
c = importlib.util.module_from_spec(spec)
spec.loader.exec_module(c)
import psutil

APP, SAIDA = sys.argv[1], sys.argv[2]
c.APP, c.SAIDA = APP, SAIDA
os.makedirs(SAIDA, exist_ok=True)
exe = os.path.join(APP, "IncipitPlay.exe")


def apps():
    return [p.pid for p in psutil.process_iter(["name", "exe"])
            if p.info["name"] == "IncipitPlay-app.exe" and p.info["exe"]
            and os.path.normcase(p.info["exe"]).startswith(os.path.normcase(os.path.abspath(APP)))]


c.limpar_geometria()
t0 = time.perf_counter()
pr = subprocess.Popen([exe], cwd=APP)
abertura = None
foto = False
while time.perf_counter() - t0 < 90:
    fam = c.familia(pr.pid)
    a = c.janelas_visiveis(fam, classe_abertura=True)
    if a and abertura is None:
        abertura = time.perf_counter() - t0
    if a and not foto:
        time.sleep(0.3)
        try:
            c.foto_janela(a[0]).save(os.path.join(SAIDA, "tela-de-abertura.png"))
            foto = True
        except Exception as e:
            print("foto da abertura falhou:", e)
    if c.janela_do_pid(pr.pid):
        break
    time.sleep(0.02)
janela = time.perf_counter() - t0
print(f"tela de abertura em {abertura:.2f} s; janela do app em {janela:.1f} s" if abertura else f"sem tela de abertura; janela em {janela:.1f} s")
print("apps abertos depois da primeira:", len(apps()))

t1 = time.perf_counter()
segundo = subprocess.Popen([exe], cwd=APP)
try:
    segundo.wait(15)
    print(f"segundo lançador saiu sozinho em {time.perf_counter() - t1:.1f} s, código {segundo.returncode}")
except subprocess.TimeoutExpired:
    print("segundo lançador NÃO saiu em 15 s")
    segundo.kill()
time.sleep(2)
print("apps abertos depois da segunda:", len(apps()))
for pid in apps():
    psutil.Process(pid).kill()
