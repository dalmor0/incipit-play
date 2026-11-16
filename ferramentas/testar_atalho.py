"""Transmite do console pela linha de comando (sem clique), aperta o atalho de salvar e confere o arquivo.
uso: python ferramentas/testar_atalho.py <pasta do app> <apelido do console> <ip> [segundos antes do atalho]
"""
import ctypes
import glob
import os
import subprocess
import sys
import time

import psutil

app, apelido, ip = sys.argv[1], sys.argv[2], sys.argv[3]
espera = int(sys.argv[4]) if len(sys.argv) > 4 else 40
pasta = os.path.join(os.path.expanduser("~"), "Videos", "Incipit Play")
antes = set(glob.glob(os.path.join(pasta, "**", "*.mp4"), recursive=True))
u = ctypes.windll.user32
pr = subprocess.Popen([os.path.join(app, "IncipitPlay.exe"), "stream", apelido, ip], cwd=app,
                      stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
time.sleep(espera)
p = psutil.Process(pr.pid)
print("ram jogando (MB):", round(p.memory_info().rss / 2**20), "privada", round(p.memory_info().private / 2**20))
u.keybd_event(0x12, 0, 0, 0); u.keybd_event(0x77, 0, 0, 0); time.sleep(0.05)
u.keybd_event(0x77, 0, 2, 0); u.keybd_event(0x12, 0, 2, 0)
time.sleep(12)
print("ram depois (MB):", round(p.memory_info().rss / 2**20), "privada", round(p.memory_info().private / 2**20))
pr.kill()
novos = sorted(set(glob.glob(os.path.join(pasta, "**", "*.mp4"), recursive=True)) - antes)
for n in novos:
    base = n[:-4]
    print("salvo:", n, os.path.getsize(n), "bytes; miniatura:", os.path.exists(base + ".jpg"))
if not novos:
    print("nenhum arquivo novo")
