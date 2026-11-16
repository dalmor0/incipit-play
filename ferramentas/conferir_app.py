"""Conferência do Incipit Play: abre o app, mede o tempo até a janela aparecer e a RAM parada, e tira prints
de cada aba em 1280x800 e 1920x1080 (área de dentro da janela).

uso: python ferramentas/conferir_app.py <pasta do app> <pasta de saída> [--ui <pasta da interface>] [--so-medir]

A aba que abre vem da configuração do próprio app (HKCU\\Software\\Incipit\\Incipit Play, hub/aba e hub/secao),
que o app também usa pra lembrar onde a pessoa parou.
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
from PIL import ImageGrab

user32 = ctypes.windll.user32
ctypes.windll.shcore.SetProcessDpiAwareness(2)
CHAVE = r"Software\Incipit\Incipit Play"


def gravar(grupo, nome, valor):
    with winreg.CreateKey(winreg.HKEY_CURRENT_USER, CHAVE + "\\" + grupo) as k:
        winreg.SetValueEx(k, nome, 0, winreg.REG_SZ, valor)


def janela_do_pid(pid):
    achou = []
    proc = ctypes.WINFUNCTYPE(ctypes.c_bool, wt.HWND, wt.LPARAM)

    def cb(h, _):
        p = wt.DWORD()
        user32.GetWindowThreadProcessId(h, ctypes.byref(p))
        if p.value == pid and user32.IsWindowVisible(h):
            n = ctypes.create_unicode_buffer(256)
            user32.GetWindowTextW(h, n, 256)
            if n.value.startswith("Incipit Play"):
                achou.append(h)
        return True

    user32.EnumWindows(proc(cb), 0)
    return achou[0] if achou else None


def sem_moldura(h, w, ht):
    """1920x1080 não cabe com moldura numa tela de 1080: usa a tela cheia do próprio app (F11) na tela principal."""
    por_cliente(h, 40, 60, 1280, 800)
    user32.keybd_event(0x12, 0, 0, 0)       # Alt solto libera o SetForegroundWindow vindo de outro processo
    user32.keybd_event(0x12, 0, 2, 0)
    user32.SetForegroundWindow(h)
    time.sleep(0.3)
    clicar(h, 1000, 600)                    # foco na janela, numa área vazia
    time.sleep(0.5)
    user32.keybd_event(0x7A, 0, 0, 0)
    time.sleep(0.05)
    user32.keybd_event(0x7A, 0, 2, 0)
    time.sleep(1.5)


def clicar(h, x, y):
    p = wt.POINT(x, y)
    user32.ClientToScreen(h, ctypes.byref(p))
    user32.SetCursorPos(p.x, p.y)
    time.sleep(0.15)
    user32.mouse_event(2, 0, 0, 0, 0)
    time.sleep(0.05)
    user32.mouse_event(4, 0, 0, 0, 0)


def por_cliente(h, x, y, w, ht):
    r = wt.RECT(0, 0, w, ht)
    estilo = user32.GetWindowLongW(h, -16)
    exest = user32.GetWindowLongW(h, -20)
    user32.AdjustWindowRectEx(ctypes.byref(r), estilo, False, exest)
    HWND_TOPMOST = -1
    for _ in range(6):
        user32.ShowWindow(h, 9)          # sai do maximizado (o app lembra o último tamanho)
        time.sleep(0.4)
        user32.SetWindowPos(h, HWND_TOPMOST, x + r.left, y + r.top, r.right - r.left, r.bottom - r.top, 0x0040)
        time.sleep(0.6)
        c = wt.RECT()
        user32.GetClientRect(h, ctypes.byref(c))
        if (c.right, c.bottom) == (w, ht):
            break
    user32.SetForegroundWindow(h)


def caixa_cliente(h):
    r = wt.RECT()
    user32.GetClientRect(h, ctypes.byref(r))
    p = wt.POINT(0, 0)
    user32.ClientToScreen(h, ctypes.byref(p))
    return (p.x, p.y, p.x + r.right, p.y + r.bottom)


def limpar_geometria():
    """o app lembra o último tamanho (e a tela cheia); cada print começa do zero"""
    try:
        with winreg.OpenKey(winreg.HKEY_CURRENT_USER, CHAVE + "\settings", 0, winreg.KEY_ALL_ACCESS) as k:
            for nome in ("geometry", "stream_geometry"):
                try:
                    winreg.DeleteValue(k, nome)
                except FileNotFoundError:
                    pass
    except FileNotFoundError:
        pass
    subprocess.run(["taskkill", "/F", "/IM", "IncipitPlay.exe"], capture_output=True)
    time.sleep(0.5)


def abrir(app, ui, env_extra=None):
    limpar_geometria()
    env = dict(os.environ)
    if ui:
        env["INCIPIT_UI_DIR"] = ui
    env.update(env_extra or {})
    t0 = time.perf_counter()
    pr = subprocess.Popen([os.path.join(app, "IncipitPlay.exe")], cwd=app, env=env,
                          stdout=subprocess.DEVNULL, stderr=open(os.path.join(SAIDA, "app-stderr.log"), "ab"))
    h = None
    while time.perf_counter() - t0 < 45 and not h:
        h = janela_do_pid(pr.pid)
        time.sleep(0.02)
    return pr, h, time.perf_counter() - t0


def ram_mb(pid):
    p = psutil.Process(pid)
    total = p.memory_info()
    filhos = sum(c.memory_info().rss for c in p.children(recursive=True))
    return round(total.rss / 2**20, 1), round(total.private / 2**20, 1), round(filhos / 2**20, 1)


def fechar(pr):
    try:
        pr.terminate()
        pr.wait(10)
    except Exception:
        pr.kill()


if __name__ == "__main__":
    APP, SAIDA = sys.argv[1], sys.argv[2]
    UI = sys.argv[sys.argv.index("--ui") + 1] if "--ui" in sys.argv else None
    os.makedirs(SAIDA, exist_ok=True)
    rel = {"app": APP, "ui": UI or "(compilada)"}

    # 1) abertura e RAM parada (aba PlayStation, 1280x800)
    gravar("hub", "aba", "playstation")
    pr, h, t = abrir(APP, UI)
    rel["abertura_s"] = round(t, 2)
    time.sleep(20)
    rel["ram_parada_mb"] = dict(zip(["working_set", "privada", "filhos"], ram_mb(pr.pid)))
    fechar(pr)
    print(json.dumps(rel, ensure_ascii=False))
    if "--so-medir" in sys.argv:
        sys.exit(0)

    # (nome, aba, seção, tema, cliques em 1280x800 depois de abrir)
    telas = [("1-playstation", "playstation", None, "dark", []), ("2-xbox", "xbox", None, "dark", []),
             ("3-switch", "switch", None, "dark", []),
             ("4-config-contas", "config", "contas", "dark", []), ("5-config-personalizar", "config", "personalizar", "dark", []),
             ("6-config-video", "config", "video", "dark", []), ("7-config-sobre", "config", "sobre", "dark", []),
             ("8-registro", "playstation", None, "dark", [(1153, 209)]),
             ("9-adicionar-ip", "playstation", None, "dark", [(1153, 68)]),
             ("10-playstation-claro", "playstation", None, "light", []),
             ("11-personalizar-claro", "config", "personalizar", "light", []),
             ("12-clipes", "clipes", None, "dark", []),
             ("13-xbox-claro", "xbox", None, "light", [])]
    so = [a for a in sys.argv if a.startswith("--so=")]
    if so:
        telas = [t for t in telas if t[0] in so[0][5:].split(",")]
    tamanhos = [(1280, 800), (1920, 1080)]
    if "--so-1280" in sys.argv:
        tamanhos = tamanhos[:1]
    for w, ht in tamanhos:
        for nome, aba, secao, tema, cliques in telas:
            if cliques and w != 1280:
                continue
            gravar("hub", "aba", aba)
            gravar("aparencia", "modo", tema)
            if secao:
                gravar("hub", "secao", secao)
            pr, h, _ = abrir(APP, UI)
            if not h:
                print("janela não abriu", nome)
                fechar(pr)
                continue
            time.sleep(1.0)
            if w == 1280:
                por_cliente(h, 40, 60, w, ht)
            else:
                sem_moldura(h, w, ht)
            time.sleep(2.0)
            for cx_, cy_ in cliques:
                clicar(h, cx_, cy_)
                time.sleep(1.5)
            time.sleep(1.5)
            img = ImageGrab.grab(bbox=caixa_cliente(h), all_screens=True)
            arq = os.path.join(SAIDA, f"{nome}-{w}x{ht}.png")
            img.save(arq)
            print(arq, img.size)
            fechar(pr)
    gravar("hub", "aba", "playstation")
    gravar("aparencia", "modo", "dark")
    with open(os.path.join(SAIDA, "medidas.json"), "w", encoding="utf-8") as f:
        json.dump(rel, f, ensure_ascii=False, indent=2)
