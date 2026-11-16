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


def janelas_visiveis(pids, classe_abertura=False):
    """janelas visíveis "Incipit Play" dos processos; a abertura do lançador (classe IncipitPlayAbertura) à parte"""
    achou = []
    proc = ctypes.WINFUNCTYPE(ctypes.c_bool, wt.HWND, wt.LPARAM)

    def cb(h, _):
        p = wt.DWORD()
        user32.GetWindowThreadProcessId(h, ctypes.byref(p))
        if p.value in pids and user32.IsWindowVisible(h):
            n = ctypes.create_unicode_buffer(256)
            user32.GetWindowTextW(h, n, 256)
            c = ctypes.create_unicode_buffer(256)
            user32.GetClassNameW(h, c, 256)
            e_abertura = c.value == "IncipitPlayAbertura"
            if n.value.startswith("Incipit Play") and e_abertura == classe_abertura:
                achou.append(h)
        return True

    user32.EnumWindows(proc(cb), 0)
    return achou


def familia(pid):
    try:
        p = psutil.Process(pid)
        return {pid} | {c.pid for c in p.children(recursive=True)}
    except Exception:
        return {pid}


def janela_do_pid(pid):
    j = janelas_visiveis(familia(pid))
    return j[0] if j else None


def sem_moldura(h, w, ht, aba="playstation"):
    """1920x1080 não cabe com moldura numa tela de 1080: usa a tela cheia do próprio app (F11). Antes, clica no item
    do menu da aba aberta: ele pega o foco sem trocar de tela, e o F11 chega no app."""
    por_cliente(h, 40, 60, 1280, 800)
    for _ in range(3):
        frente(h)
        time.sleep(0.4)
        clicar(h, 100, Y_MENU.get(aba, 118))
        time.sleep(0.6)
        user32.keybd_event(0x7A, 0, 0, 0)
        time.sleep(0.05)
        user32.keybd_event(0x7A, 0, 2, 0)
        time.sleep(1.5)
        c = wt.RECT()
        user32.GetClientRect(h, ctypes.byref(c))
        if (c.right, c.bottom) == (w, ht):
            return


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


def foto_janela(h):
    """copia só a janela do app (PrintWindow com conteúdo completo), mesmo com outra janela por cima"""
    from PIL import Image
    gdi = ctypes.windll.gdi32
    r = wt.RECT()
    user32.GetClientRect(h, ctypes.byref(r))
    w, ht = r.right, r.bottom
    hdc = user32.GetDC(h)
    mem = gdi.CreateCompatibleDC(hdc)
    bmp = gdi.CreateCompatibleBitmap(hdc, w, ht)
    gdi.SelectObject(mem, bmp)
    user32.PrintWindow(h, mem, 1 | 2)          # PW_CLIENTONLY | PW_RENDERFULLCONTENT
    class BIH(ctypes.Structure):
        _fields_ = [("biSize", ctypes.c_uint32), ("biWidth", ctypes.c_int32), ("biHeight", ctypes.c_int32),
                    ("biPlanes", ctypes.c_uint16), ("biBitCount", ctypes.c_uint16), ("biCompression", ctypes.c_uint32),
                    ("biSizeImage", ctypes.c_uint32), ("a", ctypes.c_int32), ("b", ctypes.c_int32),
                    ("c", ctypes.c_uint32), ("d", ctypes.c_uint32)]
    bi = BIH(ctypes.sizeof(BIH), w, -ht, 1, 32, 0, 0, 0, 0, 0, 0)
    buf = ctypes.create_string_buffer(w * ht * 4)
    gdi.GetDIBits(mem, bmp, 0, ht, buf, ctypes.byref(bi), 0)
    gdi.DeleteObject(bmp)
    gdi.DeleteDC(mem)
    user32.ReleaseDC(h, hdc)
    return Image.frombuffer("RGB", (w, ht), buf, "raw", "BGRX", 0, 1)


def caixa_cliente(h):
    r = wt.RECT()
    user32.GetClientRect(h, ctypes.byref(r))
    p = wt.POINT(0, 0)
    user32.ClientToScreen(h, ctypes.byref(p))
    return (p.x, p.y, p.x + r.right, p.y + r.bottom)


def limpar_geometria():
    """cada print começa numa janela normal de 1280x800 (o app lembra o último tamanho e a tela cheia)"""
    # fecha só a cópia de teste (nunca o Incipit Play que a pessoa estiver usando)
    for p in psutil.process_iter(["name", "exe"]):
        try:
            if p.info["name"] in ("IncipitPlay.exe", "IncipitPlay-app.exe") and p.info["exe"] and os.path.normcase(p.info["exe"]).startswith(os.path.normcase(os.path.abspath(APP))):
                p.kill()
        except Exception:
            pass
    time.sleep(0.5)
    with winreg.CreateKey(winreg.HKEY_CURRENT_USER, CHAVE + r"\settings") as k:
        winreg.SetValueEx(k, "geometry", 0, winreg.REG_SZ, GEOMETRIA)


GEOMETRIA = "@Rect(40 60 1280 800)"


def abrir(app, ui, env_extra=None):
    limpar_geometria()
    env = dict(os.environ)
    if ui:
        env["INCIPIT_UI_DIR"] = ui
    env.update(env_extra or {})
    global ABERTURA_S
    ABERTURA_S = None
    t0 = time.perf_counter()
    pr = subprocess.Popen([os.path.join(app, "IncipitPlay.exe")], cwd=app, env=env,
                          stdout=subprocess.DEVNULL, stderr=open(os.path.join(SAIDA, "app-stderr.log"), "ab"))
    h = None
    while time.perf_counter() - t0 < 90 and not h:
        fam = familia(pr.pid)
        if ABERTURA_S is None and janelas_visiveis(fam, classe_abertura=True):
            ABERTURA_S = time.perf_counter() - t0
        h = janela_do_pid(pr.pid)
        time.sleep(0.02)
    return pr, h, time.perf_counter() - t0


ABERTURA_S = None


def processo_app(pr):
    for p in psutil.process_iter(["pid", "name"]):
        if p.info["name"] == "IncipitPlay-app.exe" and p.info["pid"] in familia(pr.pid):
            return p.info["pid"]
    for p in psutil.process_iter(["pid", "name", "exe"]):
        if p.info["name"] == "IncipitPlay-app.exe" and p.info["exe"] and os.path.normcase(p.info["exe"]).startswith(os.path.normcase(os.path.abspath(APP))):
            return p.info["pid"]
    return pr.pid


def ram_mb(pid):
    p = psutil.Process(pid)
    total = p.memory_info()
    filhos = sum(c.memory_info().rss for c in p.children(recursive=True))
    return round(total.rss / 2**20, 1), round(total.private / 2**20, 1), round(filhos / 2**20, 1)


def fechar(pr):
    for pid in sorted(familia(pr.pid), reverse=True):
        try:
            psutil.Process(pid).kill()
        except Exception:
            pass


if __name__ == "__main__":
    APP, SAIDA = sys.argv[1], sys.argv[2]
    UI = sys.argv[sys.argv.index("--ui") + 1] if "--ui" in sys.argv else None
    os.makedirs(SAIDA, exist_ok=True)
    GUARDAR = [("aparencia", "modo"), ("aparencia", "destaque"), ("hub", "aba"), ("hub", "secao"), ("settings", "geometry"), ("clipes", "pasta")]
    guardado = {}
    for g, n in GUARDAR:
        try:
            with winreg.OpenKey(winreg.HKEY_CURRENT_USER, CHAVE + "\\" + g) as k:
                guardado[(g, n)] = winreg.QueryValueEx(k, n)
        except FileNotFoundError:
            pass
    import atexit

    def devolver():
        for (g, n), (v, t) in guardado.items():
            with winreg.CreateKey(winreg.HKEY_CURRENT_USER, CHAVE + "\\" + g) as k:
                winreg.SetValueEx(k, n, 0, t, v)
    atexit.register(devolver)
    gravar("aparencia", "destaque", "hora-azul")
    rel = {"app": APP, "ui": UI or "(compilada)"}

    # 1) abertura e RAM parada (aba PlayStation, 1280x800)
    gravar("hub", "aba", "playstation")
    gravar("aparencia", "modo", "dark")
    pr, h, t = abrir(APP, UI)
    rel["abertura_s"] = round(t, 2)
    rel["tela_de_abertura_s"] = round(ABERTURA_S, 2) if ABERTURA_S is not None else None
    time.sleep(20)
    rel["ram_parada_mb"] = dict(zip(["working_set", "privada", "filhos"], ram_mb(processo_app(pr))))
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
             ("14-ip-invalido", "playstation", None, "dark", [(1153, 68), "abc", "ENTER"]),
             ("15-clipes-vazio", "clipes", None, "dark", ["VAZIO"]),
             ("13-xbox-claro", "xbox", None, "light", [])]
    so = [a for a in sys.argv if a.startswith("--so=")]
    if so:
        telas = [t for t in telas if t[0] in so[0][5:].split(",")]
    tamanhos = [(1280, 800), (1920, 1080)]
    if "--so-1280" in sys.argv:
        tamanhos = tamanhos[:1]
    if "--so-1920" in sys.argv:
        tamanhos = tamanhos[1:]
    for w, ht in tamanhos:
        GEOMETRIA = "@Rect(0 0 1920 1080)" if (w != 1280 and "--larga" in sys.argv) else "@Rect(40 60 1280 800)"
        for nome, aba, secao, tema, cliques in telas:
            if [c for c in cliques if c != "VAZIO"] and w != 1280:
                continue
            gravar("hub", "aba", aba)
            gravar("aparencia", "modo", tema)
            if secao:
                gravar("hub", "secao", secao)
            vazio = os.path.join(SAIDA, "pasta-vazia")
            os.makedirs(vazio, exist_ok=True)
            gravar("clipes", "pasta", vazio if "VAZIO" in cliques else guardado.get(("clipes", "pasta"), ("", 1))[0])
            pr, h, _ = abrir(APP, UI)
            if not h:
                print("janela não abriu", nome)
                fechar(pr)
                continue
            time.sleep(1.0)
            if w == 1280:
                por_cliente(h, 40, 60, w, ht)
            elif "--larga" in sys.argv:
                user32.SetWindowPos(h, -1, 0, 0, 0, 0, 0x0001 | 0x0002 | 0x0040)
                frente(h)
            else:
                sem_moldura(h, w, ht, aba)
            time.sleep(2.0)
            for passo in cliques:
                if passo == "VAZIO":
                    continue
                if passo == "ENTER":
                    user32.keybd_event(0x0D, 0, 0, 0); user32.keybd_event(0x0D, 0, 2, 0)
                elif isinstance(passo, str):
                    for ch in passo.upper():
                        user32.keybd_event(ord(ch), 0, 0, 0); user32.keybd_event(ord(ch), 0, 2, 0)
                        time.sleep(0.05)
                else:
                    clicar(h, *passo)
                time.sleep(1.5)
            time.sleep(1.5)
            img = foto_janela(h)
            arq = os.path.join(SAIDA, f"{nome}-{w}x{ht}.png")
            img.save(arq)
            print(arq, img.size)
            fechar(pr)
    with open(os.path.join(SAIDA, "medidas.json"), "w", encoding="utf-8") as f:
        json.dump(rel, f, ensure_ascii=False, indent=2)
