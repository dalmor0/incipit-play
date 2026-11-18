"""Acha o melhor trecho do clipe e os pontos de impacto (onde entra o zoom).

Sinais a cada 0,1 s: volume (pico, grito), fala animada (palavra exclamada, risada, palavrão),
movimento da imagem (ação, troca de plano) e as palavras do assunto que a pessoa pediu.
"""
import re

import numpy as np

from .analise import PASSO, suavizar, z
from .pedido import radicais, sem_acento

RISO = re.compile(r"^(k{2,}|(ha){2,}h?|(he){2,}|rs{1,}|kkk\w*)$")
PALAVRAO = re.compile(r"^(porra|caralh\w*|merda|puta\w*|fod\w*|cacete|krl|vsf|pqp|desgra\w*|fdp|bosta|cu|buceta|viado|arrombad\w*)$")
EXCLAMA = re.compile(r"^(nao+|vai+|corre+|meu deus|nossa|caraca|eita+|uau+|ai+|socorro|mano+|olha|bora+|vamo+|toma+|isso+|let'?s|go+|what|no+|yes+|oh+|wow)$")


def _limpa(p):
    return sem_acento(p.lower()).strip(" .,!?…\"'")


def sinais(dur, db, energia, corte, palavras, plano):
    n = max(1, int(np.ceil(dur / PASSO)))

    def ajusta(s):
        s = np.asarray(s, dtype=np.float64)
        return np.pad(s, (0, max(0, n - len(s))))[:n]

    db = ajusta(db) if len(db) else np.full(n, -90.0)
    vol = np.clip(z(suavizar(db, 3)), 0, 6)
    mov = np.clip(z(suavizar(ajusta(energia), 3)), 0, 4)
    cut = ajusta(corte)
    fala = np.zeros(n)
    riso = np.zeros(n)
    grito = np.zeros(n)
    assunto = np.zeros(n)
    alvos = []
    for w in plano.get("foco") or []:
        alvos += radicais(w)
    for w in palavras:
        a, b = int(w["i"] / PASSO), max(int(w["i"] / PASSO) + 1, int(w["f"] / PASSO))
        a, b = min(a, n - 1), min(b, n)
        t = _limpa(w["p"])
        fala[a:b] += 1
        if RISO.match(t):
            riso[a:b] += 3
        if "!" in w["p"] or EXCLAMA.match(t) or PALAVRAO.match(t):
            grito[a:b] += 2
        if alvos and any(t.startswith(r) for r in alvos):
            lo, hi = max(0, a - 20), min(n, b + 30)
            assunto[lo:hi] += 4
    # grito de verdade: fala alta (volume bem acima do resto enquanto tem fala)
    grito += np.where(fala > 0, np.clip(vol - 1.5, 0, 4), 0)
    return {"vol": vol, "mov": mov, "corte": cut, "fala": np.clip(fala, 0, 1), "riso": suavizar(riso, 5),
            "grito": suavizar(grito, 5), "assunto": suavizar(assunto, 9), "n": n}


def pontuacao(s, plano):
    tipo = plano.get("foco_tipo")
    pesos = {"vol": 1.0, "mov": 0.6, "corte": 0.4, "fala": 0.5, "riso": 1.0, "grito": 1.2, "assunto": 0.0}
    if tipo == "grito":
        pesos.update(vol=2.0, grito=2.5)
    elif tipo == "risada":
        pesos.update(riso=3.0)
    elif tipo == "acao":
        pesos.update(mov=2.0, corte=1.0, vol=1.2)
    elif tipo == "fala":
        pesos.update(fala=1.5)
    if plano.get("foco"):
        pesos["assunto"] = 3.0
    total = np.zeros(s["n"])
    for k, p in pesos.items():
        total += p * s[k]
    return total


def _fronteiras(palavras):
    """Começos de frase (palavra depois de pausa de 0,35 s) e fins de frase."""
    inis, fins = [0.0], []
    for a, b in zip(palavras, palavras[1:]):
        if b["i"] - a["f"] >= 0.35:
            fins.append(a["f"])
            inis.append(b["i"])
    if palavras:
        fins.append(palavras[-1]["f"])
    return inis, fins


def escolher(dur, s, palavras, plano):
    """Devolve (inicio, fim) em segundos."""
    if plano.get("trecho"):
        a, b = plano["trecho"]
        a = max(0.0, min(float(a), dur - 1))
        b = dur if b is None else max(a + 1, min(float(b), dur))
        return a, b
    if plano.get("inteiro"):
        return 0.0, dur
    tipo = plano.get("foco_tipo")
    alvo = plano.get("duracao")
    if not alvo:
        alvo = dur if dur <= 40 else 30
    alvo = float(min(alvo, dur))
    if tipo == "inicio":
        return 0.0, alvo
    if tipo == "fim":
        return dur - alvo, dur
    score = pontuacao(s, plano)
    n = s["n"]
    L = max(1, int(alvo / PASSO))
    if L >= n:
        a, b = 0.0, dur
    else:
        cum = np.concatenate([[0], np.cumsum(score)])
        melhor, ia = -1e9, 0
        pico = suavizar(score, 5)
        for i in range(0, n - L + 1, 2):
            media = (cum[i + L] - cum[i]) / L
            j = i + int(np.argmax(pico[i:i + L]))
            pos = (j - i) / L
            # o pico no meio pra frente prende mais: começa com tensão e termina com a reação
            lugar = 1.0 if 0.25 <= pos <= 0.8 else 0.6
            v = media + 0.35 * pico[j] * lugar
            if v > melhor:
                melhor, ia = v, i
        a, b = ia * PASSO, (ia + L) * PASSO
    # não começar nem terminar no meio da frase (até 2 s de folga)
    inis, fins = _fronteiras(palavras)
    if a > 0.05:
        antes = [x for x in inis if a - 2.0 <= x <= a + 0.3]
        if antes:
            a = max(0.0, min(antes, key=lambda x: abs(x - a)) - 0.15)
        else:
            # cortando no meio de uma palavra: volta pro começo dela
            for w in palavras:
                if w["i"] < a < w["f"]:
                    a = max(0.0, w["i"] - 0.1)
    if b < dur - 0.05:
        depois = [x for x in fins if b - 1.0 <= x <= b + 2.0]
        if depois:
            b = min(dur, min(depois, key=lambda x: abs(x - b)) + 0.4)
        else:
            for w in palavras:
                if w["i"] < b < w["f"]:
                    b = min(dur, w["f"] + 0.3)
    # clipe curto inteiro: tira só o silêncio parado das pontas
    if not plano.get("duracao") and dur <= 40 and a == 0 and b == dur:
        vivo = np.where((s["vol"] > 0.3) | (s["mov"] > 0.3) | (s["fala"] > 0))[0]
        if len(vivo):
            a = max(0.0, vivo[0] * PASSO - 0.5)
            b = min(dur, vivo[-1] * PASSO + 1.0)
            if b - a < min(8.0, dur):
                a, b = 0.0, dur
    return round(a, 2), round(b, 2)


def impactos(a, b, s, plano):
    """Momentos de zoom dentro do trecho: [(t_relativo, forca)]."""
    zoom = plano.get("zoom", 1.0)
    if zoom <= 0:
        return []
    imp = 1.2 * s["vol"] + 1.4 * s["grito"] + 1.2 * s["riso"] + 0.8 * s["corte"] * s["mov"] + 0.5 * s["mov"]
    if plano.get("foco"):
        imp = imp + 0.3 * s["assunto"]
    ia, ib = int(a / PASSO), int(b / PASSO)
    seg = imp[ia:ib]
    if len(seg) < 5:
        return []
    limiar = np.percentile(seg, 90 if zoom < 2 else 80)
    piso = 2.0 if zoom < 2 else 1.4
    vao = int((3.0 if zoom < 2 else 1.6) / PASSO)
    maximo = max(1, int((b - a) / (5.0 if zoom < 2 else 2.8)))
    ordem = np.argsort(-seg)
    pegos = []
    for i in ordem:
        if seg[i] < max(limiar, piso) or len(pegos) >= maximo:
            break
        if i * PASSO < 0.6 or i * PASSO > (b - a) - 0.8:
            continue
        if all(abs(i - j) >= vao for j, _ in pegos):
            pegos.append((i, float(seg[i])))
    pegos.sort()
    topo = max([v for _, v in pegos], default=1.0)
    return [(round(i * PASSO - 0.1, 2), round(0.6 + 0.4 * v / topo, 2)) for i, v in pegos]
