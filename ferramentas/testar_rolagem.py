"""Roda do mouse nas abas do Incipit Play: abre o app numa aba, tira print, manda a roda pra baixo e pra cima pela
mensagem do Windows (WM_MOUSEWHEEL, chega mesmo com o TeamViewer segurando o mouse) e tira print depois de cada uma.

uso: python ferramentas/testar_rolagem.py <pasta do app> <pasta de saída> [--ui <pasta da interface>]
     [--clipes <pasta com clipes>] [--abas clipes,config,playstation] [--tamanhos 1440x900,1024x640]

Abre o IncipitPlay-app.exe direto (sem o lançador), pra rodar mesmo com outra cópia do Incipit Play aberta.
A config da pessoa (aba, pasta dos clipes, tamanho, tema) é guardada antes e devolvida no fim.
"""
import ctypes
import ctypes.wintypes as wt
import json
import os
import subprocess
import sys
import time
import winreg

import psutil

import conferir_app as ca

user32 = ctypes.windll.user32
CHAVE = ca.CHAVE


def ler(g, n):
    try:
        with winreg.OpenKey(winreg.HKEY_CURRENT_USER, CHAVE + "\\" + g) as k:
            return winreg.QueryValueEx(k, n)
    except FileNotFoundError:
        return None


def abrir_direto(app, ui, w, ht):
    ca.APP = app
    ca.GEOMETRIA = f"@Rect(40 60 {w} {ht})"
    ca.limpar_geometria()
    env = dict(os.environ)
    if ui:
        env["INCIPIT_UI_DIR"] = ui
    t0 = time.perf_counter()
    pr = subprocess.Popen([os.path.join(app, "IncipitPlay-app.exe")], cwd=app, env=env,
                          stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
    h = None
    while time.perf_counter() - t0 < 120 and not h:
        h = ca.janela_do_pid(pr.pid)
        time.sleep(0.05)
    return pr, h


def roda(h, x, y, cliques):
    """cliques > 0 sobe, < 0 desce; 120 por clique, como a roda de verdade"""
    p = wt.POINT(x, y)
    user32.ClientToScreen(h, ctypes.byref(p))
    passo = 120 if cliques > 0 else -120
    for _ in range(abs(cliques)):
        wp = (ctypes.c_ushort(passo).value << 16)
        lp = ((p.y & 0xFFFF) << 16) | (p.x & 0xFFFF)
        user32.PostMessageW(h, 0x020A, wp, lp)
        time.sleep(0.06)
    time.sleep(0.8)


def diferenca(a, b):
    from PIL import ImageChops
    caixa = ImageChops.difference(a.convert("RGB"), b.convert("RGB")).getbbox()
    return caixa is not None


if __name__ == "__main__":
    APP, SAIDA = sys.argv[1], sys.argv[2]
    arg = lambda nome, padrao=None: sys.argv[sys.argv.index(nome) + 1] if nome in sys.argv else padrao
    UI = arg("--ui")
    CLIPES = arg("--clipes")
    ABAS = arg("--abas", "clipes,config,playstation").split(",")
    TAMANHOS = [tuple(int(v) for v in t.split("x")) for t in arg("--tamanhos", "1440x900,1024x640").split(",")]
    os.makedirs(SAIDA, exist_ok=True)
    guardar = [("hub", "aba"), ("hub", "secao"), ("settings", "geometry"), ("clipes", "pasta"), ("aparencia", "modo")]
    guardado = {gn: ler(*gn) for gn in guardar}

    def devolver():
        for (g, n), v in guardado.items():
            if v is not None:
                with winreg.CreateKey(winreg.HKEY_CURRENT_USER, CHAVE + "\\" + g) as k:
                    winreg.SetValueEx(k, n, 0, v[1], v[0])
    import atexit
    atexit.register(devolver)

    rel = []
    for aba in ABAS:
        for w, ht in TAMANHOS:
            ca.gravar("hub", "aba", "config" if aba.startswith("config") else aba)
            if aba.startswith("config"):
                ca.gravar("hub", "secao", aba.split(":")[1] if ":" in aba else "video")
            ca.gravar("aparencia", "modo", "dark")
            if CLIPES:
                ca.gravar("clipes", "pasta", os.path.abspath(CLIPES))
            pr, h = abrir_direto(APP, UI, w, ht)
            if not h:
                rel.append({"aba": aba, "tamanho": f"{w}x{ht}", "erro": "janela não abriu"})
                ca.fechar(pr)
                continue
            time.sleep(1.0)
            ca.por_cliente(h, 40, 60, w, ht)
            time.sleep(3.0)
            nome = aba.replace(":", "-")
            x, y = (w + 232) // 2, ht // 2
            antes = ca.foto_janela(h)
            antes.save(os.path.join(SAIDA, f"{nome}-{w}x{ht}-1-antes.png"))
            roda(h, x, y, -8)
            desceu = ca.foto_janela(h)
            desceu.save(os.path.join(SAIDA, f"{nome}-{w}x{ht}-2-desceu.png"))
            roda(h, x, y, 8)
            subiu = ca.foto_janela(h)
            subiu.save(os.path.join(SAIDA, f"{nome}-{w}x{ht}-3-subiu.png"))
            r = {"aba": aba, "tamanho": f"{w}x{ht}", "desceu": diferenca(antes, desceu), "voltou_ao_topo": not diferenca(antes, subiu)}
            rel.append(r)
            print(json.dumps(r, ensure_ascii=False))
            ca.fechar(pr)
            time.sleep(1.0)
    with open(os.path.join(SAIDA, "rolagem.json"), "w", encoding="utf-8") as f:
        json.dump(rel, f, ensure_ascii=False, indent=2)
