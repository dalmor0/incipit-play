"""Teste do cancelar: começa uma edição, manda "cancelar" no meio e confere que saiu rápido, sem vídeo pela metade
e sem processo do ffmpeg sobrando.   python testes/cancelar.py <clipe> <pasta-saida> [segundos-até-cancelar]"""
import json, os, subprocess, sys, time
from pathlib import Path

clipe, saida = sys.argv[1], Path(sys.argv[2])
espera = float(sys.argv[3]) if len(sys.argv) > 3 else 8
env = dict(os.environ, INCIPIT_EDICAO_ENTRADA="1", PYTHONIOENCODING="utf-8")
p = subprocess.Popen([sys.executable, "-m", "clipador", "editar", "--clipe", clipe, "--saida", str(saida)],
                     stdin=subprocess.PIPE, stdout=subprocess.PIPE, stderr=subprocess.DEVNULL, env=env, cwd=Path(__file__).parent.parent)
t0 = time.time()
ultima = None
import threading
linhas = []
threading.Thread(target=lambda: [linhas.append(l) for l in p.stdout], daemon=True).start()
time.sleep(espera)
etapa = json.loads(linhas[-1]) if linhas else {}
t_c = time.time()
p.stdin.write(b"cancelar\n"); p.stdin.flush()
p.wait(timeout=30)
time.sleep(0.5)
fim = json.loads(linhas[-1]) if linhas else {}
parciais = list(saida.glob("*.parcial.mp4")) if saida.exists() else []
ff = subprocess.run(["tasklist", "/FI", "IMAGENAME eq ffmpeg.exe"], capture_output=True, text=True).stdout.count("ffmpeg.exe")
print(json.dumps({"cancelado_em": etapa.get("texto"), "pct": etapa.get("pct"), "saiu_em_s": round(time.time() - t_c, 2),
                  "codigo": p.returncode, "ultimo_evento": fim, "parciais": [str(x) for x in parciais], "ffmpeg_vivos": ff}, ensure_ascii=False))
