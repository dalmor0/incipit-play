"""Tempo de abertura do Incipit Play: do início do processo até a janela principal aparecer, N vezes seguidas.

uso: python ferramentas/medir_abertura.py <pasta do app> [--vezes 3] [--direto] [--saida medidas.json]

Sem --direto abre pelo lançador (IncipitPlay.exe, o duplo clique de verdade) e anota também quando a tela de
abertura apareceu. Com outra cópia do Incipit Play aberta o lançador só traz aquela pra frente (cópia única):
nesse caso use --direto, que abre o IncipitPlay-app.exe e mede só o app.
A config da pessoa (aba, tamanho) é guardada antes e devolvida no fim; só a cópia de teste é fechada.
"""
import json
import os
import sys
import time
import winreg

import conferir_app as ca

if __name__ == "__main__":
    APP = os.path.abspath(sys.argv[1])
    arg = lambda nome, padrao=None: sys.argv[sys.argv.index(nome) + 1] if nome in sys.argv else padrao
    VEZES = int(arg("--vezes", "3"))
    ca.APP = APP
    ca.SAIDA = os.path.dirname(os.path.abspath(arg("--saida", os.path.join(APP, "..", "medidas-abertura.json"))))
    guardar = [("hub", "aba"), ("settings", "geometry")]
    guardado = {}
    for g, n in guardar:
        try:
            with winreg.OpenKey(winreg.HKEY_CURRENT_USER, ca.CHAVE + "\\" + g) as k:
                guardado[(g, n)] = winreg.QueryValueEx(k, n)
        except FileNotFoundError:
            pass
    rel = {"app": APP, "modo": "direto (sem lançador)" if "--direto" in sys.argv else "lançador", "vezes": []}
    try:
        ca.gravar("hub", "aba", "playstation")
        for i in range(VEZES):
            pr, h, t = ca.abrir(APP, None)
            v = {"janela_s": round(t, 2) if h else None, "tela_de_abertura_s": round(ca.ABERTURA_S, 2) if ca.ABERTURA_S is not None else None}
            rel["vezes"].append(v)
            print(json.dumps(v, ensure_ascii=False), flush=True)
            time.sleep(3)
            ca.fechar(pr)
            time.sleep(3)
    finally:
        for (g, n), (v, t) in guardado.items():
            with winreg.CreateKey(winreg.HKEY_CURRENT_USER, ca.CHAVE + "\\" + g) as k:
                winreg.SetValueEx(k, n, 0, t, v)
    saida = arg("--saida")
    if saida:
        with open(saida, "w", encoding="utf-8") as f:
            json.dump(rel, f, ensure_ascii=False, indent=2)
