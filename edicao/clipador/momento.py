"""Acha o melhor trecho do clipe e os pontos de impacto (onde entra o zoom).

Sinais a cada 0,1 s: volume, fala animada (palavra exclamada, risada, palavrão), movimento do jogo, troca de plano,
reação de quem está na câmera (movimento dentro da caixa da câmera), tela parada (menu, carregamento) e as palavras
do assunto que a pessoa pediu ou que deu de nome ao arquivo.

Rodada 2 (conferência de 17/11, nota 4,0): numa live com câmera o jogo ou o vídeo assistido grita mais que o
streamer, então com câmera o que pesa é a reação dele; o zoom só entra em pico de verdade, medido contra o clipe
inteiro; pedido de assunto vale também em clipe curto; trecho que repete (o streamer voltou o vídeo) é cortado.
"""
import re

import numpy as np

from .analise import PASSO, suavizar, z
from .pedido import radicais, sem_acento

RISO = re.compile(r"^(k{2,}|(ha){2,}h?|(he){2,}|rs{1,}|kkk\w*)$")
PALAVRAO = re.compile(r"^(porra|caralh\w*|merda|puta\w*|fod\w*|cacete|krl|vsf|pqp|desgra\w*|fdp|bosta|cu|buceta|viado|arrombad\w*)$")
EXCLAMA = re.compile(r"^(nao+|vai+|corre+|meu deus|nossa|caraca|eita+|uau+|ai+|socorro|mano+|olha|bora+|vamo+|toma+|isso+|let'?s|go+|what|no+|yes+|oh+|wow|pegou|clipa|clipei|safado)$")


def _limpa(p):
    return sem_acento(p.lower()).strip(" .,!?…\"'")


def sinais(dur, db, energia, corte, palavras, plano, reacao=None, parado=None, lance=None):
    n = max(1, int(np.ceil(dur / PASSO)))

    def ajusta(s):
        s = np.asarray(s, dtype=np.float64)
        return np.pad(s, (0, max(0, n - len(s))))[:n]

    db = ajusta(db) if len(db) else np.full(n, -90.0)
    vol = np.clip(z(suavizar(db, 3)), 0, 6)
    mov = np.clip(z(suavizar(ajusta(energia), 3)), 0, 4)
    cut = ajusta(corte)
    rea = np.clip(z(suavizar(ajusta(reacao), 5)), 0, 5) if reacao is not None and len(reacao) else np.zeros(n)
    par = ajusta(parado) if parado is not None and len(parado) else np.zeros(n)
    lan = ajusta(lance) if lance is not None and len(lance) else np.zeros(n)
    fala = np.zeros(n)
    riso = np.zeros(n)
    grito = np.zeros(n)
    assunto = np.zeros(n)
    alvos = []
    chaves = [sem_acento(w.lower()) for w in (plano.get("foco") or []) + (plano.get("foco_nome") or [])]
    for w in (plano.get("foco") or []) + (plano.get("foco_nome") or []):
        alvos += radicais(w)
    from difflib import SequenceMatcher

    def do_assunto(t):
        if any(t.startswith(r) for r in alvos):
            return True
        return any(len(k) >= 6 and len(t) >= 4 and SequenceMatcher(None, t, k).ratio() >= 0.85 for k in chaves)
    for w in palavras:
        a, b = int(w["i"] / PASSO), max(int(w["i"] / PASSO) + 1, int(w["f"] / PASSO))
        a, b = min(a, n - 1), min(b, n)
        t = _limpa(w["p"])
        fala[a:b] += 1
        if RISO.match(t):
            riso[a:b] += 3
        if "!" in w["p"] or EXCLAMA.match(t) or (PALAVRAO.match(t) and vol[a:b].max() > 1.0):
            grito[a:b] += 2
        if alvos and do_assunto(t):
            lo, hi = max(0, a - 20), min(n, b + 30)
            assunto[lo:hi] += 4
    # grito de verdade: fala alta (volume bem acima do resto enquanto tem fala)
    grito += np.where(fala > 0, np.clip(vol - 1.5, 0, 4), 0)
    if reacao is not None and len(reacao):
        # com câmera, grito do vídeo de fundo não mexe a cara de quem está nela: só vale com reação junto
        grito = grito * (suavizar(rea, 10) > 0.5)
    return {"vol": vol, "mov": mov, "corte": cut, "fala": np.clip(fala, 0, 1), "riso": suavizar(riso, 5),
            "grito": suavizar(grito, 5), "assunto": suavizar(assunto, 9), "reacao": rea, "parado": par, "lance": lan, "n": n}


def pontuacao(s, plano, com_camera=False):
    tipo = plano.get("foco_tipo")
    if com_camera:
        # quem importa é o streamer: a reação dele e a fala dele; o conteúdo de fundo grita mais e engana
        pesos = {"vol": 0.4, "mov": 0.2, "corte": 0.1, "fala": 0.4, "riso": 1.6, "grito": 1.2, "reacao": 1.8, "lance": 0.6, "assunto": 0.0}
    else:
        pesos = {"vol": 0.8, "mov": 0.5, "corte": 0.3, "fala": 0.3, "riso": 1.0, "grito": 1.2, "reacao": 0.0, "lance": 1.8, "assunto": 0.0}
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
    elif plano.get("foco_nome"):
        pesos["assunto"] = 1.6
    total = np.zeros(s["n"])
    for k, p in pesos.items():
        total += p * s[k]
    # tela parada sem ninguém falando (menu, carregamento) nunca é o melhor momento; parada com fala é conversa
    return total * (1 - 0.8 * s["parado"] * (1 - s["fala"]))


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


def _sem_repeticao(a, b, palavras, score):
    """O streamer voltou o vídeo: uma frase de 7 palavras ou mais aparece duas vezes, a mais de 5 s. Fica a parte
    (antes da segunda vez ou depois da primeira) que tem mais pontos."""
    ws = [w for w in palavras if a <= w["i"] < b]
    toks = [_limpa(w["p"]) for w in ws]
    k = 7   # gente repete frase curta de propósito ("não chegou a sair um gen"); fala inteira repetida é vídeo voltando
    vistos = {}
    for i in range(len(toks) - k + 1):
        g = tuple(toks[i:i + k])
        if not all(g):
            continue
        if g in vistos and ws[i]["i"] - ws[vistos[g]]["i"] > 5.0:
            j0 = vistos[g]
            antes = (a, ws[i]["i"] - 0.2)
            depois = (ws[j0 + k - 1]["f"] + 0.2, b)

            def pontos(x):
                return score[int(x[0] / PASSO):int(x[1] / PASSO)].sum()
            opcoes = [o for o in (antes, depois) if o[1] - o[0] >= 6]
            if not opcoes:
                return a, b
            return max(opcoes, key=pontos)
        vistos.setdefault(g, i)
    return a, b


def _aparar_parado(a, b, s, palavras, folga=1.0):
    """Corta tela parada sem fala nas pontas (menu no fim, carregamento no começo)."""
    par = s["parado"]
    fala = s["fala"]
    ia, ib = int(a / PASSO), int(b / PASSO)
    i = ia
    while i < ib - 1 and par[i] > 0.5 and fala[i] == 0:
        i += 1
    j = ib - 1
    while j > i and par[j] > 0.5 and fala[j] == 0:
        j -= 1
    if (i - ia) * PASSO >= folga:
        a = max(a, i * PASSO - 0.3)
    if (ib - 1 - j) * PASSO >= folga:
        b = min(b, (j + 1) * PASSO + 0.4)
    return a, b


def escolher(dur, s, palavras, plano, com_camera=False):
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
    score = pontuacao(s, plano, com_camera)
    # pedido de assunto ou de momento: a janela é em volta dele, mesmo em clipe curto
    tem_foco = bool(plano.get("foco")) and s["assunto"].max() > 0.5
    tem_tipo = tipo in ("grito", "risada", "acao")
    janela_curta = False
    if not alvo:
        if tem_foco or tem_tipo:
            alvo = 15.0
        elif 20 < dur <= 40:
            alvo, janela_curta = 18.0, True     # clipe de 20 a 40 s: o lance costuma estar em 15 a 20 s dele
        else:
            alvo = dur if dur <= 40 else 30
    alvo = float(min(alvo, dur))
    if tipo == "inicio":
        return 0.0, alvo
    if tipo == "fim":
        return dur - alvo, dur
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
            lugar = 1.0 if 0.3 <= pos <= 0.8 else 0.5
            v = media + 0.35 * pico[j] * lugar
            if v > melhor:
                melhor, ia = v, i
        a, b = ia * PASSO, (ia + L) * PASSO
        if janela_curta:
            # concentração medida só nos picos (lance, grito, riso, reação), sem a fala corrida
            forte = s["lance"] + s["grito"] + s["riso"] + (s["reacao"] if com_camera else 0)
            cf = np.concatenate([[0], np.cumsum(forte)])
            if forte.max() < 1.5:
                # sem pico em lugar nenhum: o atalho de "últimos segundos" guarda o lance no fim
                fim_util = n
                while fim_util > L and s["parado"][fim_util - 1] > 0.5 and s["fala"][fim_util - 1] == 0:
                    fim_util -= 1
                ia = fim_util - L
                a, b = ia * PASSO, fim_util * PASSO
            else:
                melhor_f = max(range(0, n - L + 1, 2), key=lambda i: (cf[i + L] - cf[i]) + 0.001 * i)
                if (cf[melhor_f + L] - cf[melhor_f]) >= 0.6 * cf[-1]:
                    ia = melhor_f
                    # o pico fica no último terço: tensão antes, reação depois
                    pico_i = melhor_f + int(np.argmax(forte[melhor_f:melhor_f + L]))
                    ia = int(min(max(0, pico_i - int(0.7 * L)), n - L))
                    a, b = ia * PASSO, (ia + L) * PASSO
                else:
                    a, b = 0.0, dur
    # a reação logo depois do fim entra (risada, grito, palavrão até 4 s depois)
    if b < dur - 0.2 and not plano.get("duracao"):
        reac = s["riso"] + s["grito"] + (s["reacao"] if com_camera else 0)
        ib, iff = int(b / PASSO), min(n, int((b + 4.0) / PASSO))
        if iff > ib and reac[ib:iff].max() > 1.5:
            fim_reac = ib + int(np.where(reac[ib:iff] > 1.0)[0].max())
            b = min(dur, (fim_reac + 1) * PASSO + 0.6)
    # a conversa que continua depois do lance entra até a primeira pausa de 1 s (a piada vem depois do golpe)
    if not plano.get("duracao") and b < dur - 0.2:
        seguinte = [w for w in palavras if b - 0.5 <= w["i"] <= b + 8.0]
        fim_fala = b
        for w in sorted(seguinte, key=lambda w: w["i"]):
            if w["i"] - fim_fala > 1.5:
                break
            fim_fala = max(fim_fala, w["f"])
        if fim_fala > b:
            b = min(dur, fim_fala + 0.5, a + alvo + 8.0)
    a, b = _sem_repeticao(a, b, palavras, score)
    # não começar nem terminar no meio da frase (até 2 s de folga)
    inis, fins = _fronteiras(palavras)
    if a > 0.05:
        antes = [x for x in inis if a - 2.0 <= x <= a + 0.3]
        if antes:
            a = max(0.0, min(antes, key=lambda x: abs(x - a)) - 0.15)
        else:
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
    if plano.get("duracao") and b - a > plano["duracao"] + 3.0:
        # duração pedida: fecha a frase em até 3 s a mais; se não der, termina no fim de frase anterior
        lim = a + plano["duracao"]
        fechos = [x for x in fins if lim - 3.0 <= x <= lim + 3.0]
        b = round(min(dur, (min(fechos, key=lambda x: abs(x - lim)) + 0.4) if fechos else lim + 1.0), 2)
    if plano.get("duracao") and b - a < plano["duracao"] - 3 and dur >= plano["duracao"]:
        falta = plano["duracao"] - (b - a)
        b = min(dur, b + falta)
        if b - a < plano["duracao"] - 3:
            a = max(0.0, b - plano["duracao"])
    a, b = _aparar_parado(a, b, s, palavras)
    # clipe curto inteiro: tira só o silêncio parado das pontas
    if not plano.get("duracao") and dur <= 40 and a == 0 and b == dur:
        vivo = np.where((s["vol"] > 0.3) | (s["mov"] > 0.3) | (s["fala"] > 0))[0]
        if len(vivo):
            a = max(0.0, vivo[0] * PASSO - 0.5)
            b = min(dur, vivo[-1] * PASSO + 1.0)
            if b - a < min(8.0, dur):
                a, b = 0.0, dur
    return round(a, 2), round(b, 2)


def impactos(a, b, s, plano, com_camera=False):
    """Momentos de zoom dentro do trecho: [(t_relativo, forca)]. Só pico de verdade: grito, risada, palavrão
    exclamado, reação forte na câmera ou troca de plano com ação, medido contra o clipe INTEIRO."""
    zoom = plano.get("zoom", 1.0)
    if zoom <= 0:
        return []
    if com_camera:
        # com câmera: só a voz dele (grito já filtrado pela reação), a risada e o rosto que reage
        # reação só conta forte (rosto que se mexe muito); risada dele sempre
        rosto = s["reacao"] > 1.0
        imp = 1.8 * s["riso"] + 1.0 * np.clip(s["reacao"] - 1.0, 0, 6) + 1.2 * s["grito"] * rosto + 0.8 * s["vol"] * rosto
    else:
        imp = 1.4 * s["grito"] + 1.4 * s["riso"] + 1.5 * s["lance"] + 0.3 * s["vol"]
    imp = imp * (1 - s["parado"])
    ia, ib = int(a / PASSO), int(b / PASSO)
    seg = imp[ia:ib]
    if len(seg) < 5:
        return []
    limiar = max(np.percentile(imp, 93 if zoom < 2 else 88), 2.4 if zoom < 2 else 2.0)
    vao = int((3.0 if zoom < 2 else 2.0) / PASSO)
    maximo = max(1, int((b - a) / (6.0 if zoom < 2 else 4.0)))
    ordem = np.argsort(-seg)
    pegos = []
    for i in ordem:
        if seg[i] < limiar or len(pegos) >= maximo:
            break
        if i * PASSO < 2.0 or i * PASSO > (b - a) - 0.8:
            continue
        if all(abs(i - j) >= vao for j, _ in pegos):
            pegos.append((i, float(seg[i])))
    pegos.sort()
    topo = max([v for _, v in pegos], default=1.0)
    return [(round(i * PASSO - 0.1, 2), round(0.6 + 0.4 * v / topo, 2)) for i, v in pegos]
