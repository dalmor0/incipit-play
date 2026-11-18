"""Legenda palavra por palavra e título, em ASS (o ffmpeg desenha com a libass).

Estilo padrão: creme (Work Sans Black Italic, #FFEDCD, sombra preta a 49%, contorno escuro fino), grande pro
vertical. Mais três pra escolher.
"""
import re

from .pedido import sem_acento
from .momento import PALAVRAO

ESTILOS = {
    # nome: (fonte, tamanho, cor primária BGR, contorno, sombra, cor da sombra/contorno, maiúscula, palavras por vez)
    "creme": {"fonte": "Work Sans Black", "italico": 1, "tam": 112, "cor": "&H00CDEDFF", "contorno": 5,
                "sombra": 6, "cor_borda": "&H40000000", "cor_sombra": "&H82000000", "maiuscula": False,
                "max_pal": 3, "max_car": 15, "revela": True, "pop": 0.92},
    "amarela": {"fonte": "Anton", "italico": 0, "tam": 118, "cor": "&H007BF4FF", "contorno": 7, "sombra": 0,
                "cor_borda": "&H00000000", "cor_sombra": "&H00000000", "maiuscula": True,
                "max_pal": 1, "max_car": 14, "revela": False, "pop": 0.8},
    "destaque": {"fonte": "Archivo", "italico": 0, "tam": 96, "cor": "&H00FFFFFF", "contorno": 6, "sombra": 2,
                 "cor_borda": "&H00000000", "cor_sombra": "&H64000000", "maiuscula": True,
                 "max_pal": 3, "max_car": 18, "revela": False, "pop": 0.9, "marca": "&H00FFB07D"},
    "limpa": {"fonte": "Archivo", "italico": 0, "tam": 72, "cor": "&H00FFFFFF", "contorno": 4, "sombra": 0,
              "cor_borda": "&H00000000", "cor_sombra": "&H00000000", "maiuscula": False,
              "max_pal": 6, "max_car": 30, "revela": False, "pop": None},
}
PADRAO = "creme"
VAZIAS = set("""para pra pro com sem uma uns umas isso esse essa aqui ali onde quando como mais menos muito tudo nada
voce voces eles elas dele dela nao sim ainda entao depois antes agora sobre entre todo toda todos todas""".split())


def _ts(t):
    t = max(0.0, t)
    h = int(t // 3600)
    m = int(t % 3600 // 60)
    s = t % 60
    return f"{h}:{m:02d}:{s:05.2f}"


def _esc(t):
    """Texto da pessoa ou da fala não pode virar comando de ASS."""
    t = "".join(c if c.isprintable() else " " for c in t)   # \r, \n e controle viram espaço (achado B2)
    return t.replace("\\", "／").replace("{", "(").replace("}", ")")


def _censura(p):
    base = sem_acento(p.lower()).strip(" .,!?…\"'")
    if PALAVRAO.match(base):
        return p[0] + "*" * max(2, len(p.strip(" .,!?…")) - 1)
    return None


def blocos(palavras, est):
    """Junta as palavras em blocos curtos, quebrando na pausa e na pontuação."""
    out, atual = [], []
    for i, w in enumerate(palavras):
        if atual:
            car = sum(len(x["p"]) + 1 for x in atual) + len(w["p"])
            pausa = w["i"] - atual[-1]["f"]
            if len(atual) >= est["max_pal"] or car > est["max_car"] or pausa > 0.35 or re.search(r"[.!?…,]$", atual[-1]["p"]):
                out.append(atual)
                atual = []
        atual.append(w)
    if atual:
        out.append(atual)
    return out


def montar(palavras, a, b, estilo, maiuscula, censura, titulo, layout, larg=1080, alt=1920):
    est = dict(ESTILOS.get(estilo or PADRAO, ESTILOS[PADRAO]))
    if maiuscula is not None:
        est["maiuscula"] = maiuscula
    # altura da legenda por enquadramento: na emenda da câmera com o jogo, ou no terço de baixo
    y = {"camera": 640 + 170, "centro": int(alt * 0.70), "desfocado": int(alt * 0.76)}.get(layout, int(alt * 0.70))
    cab = f"""[Script Info]
ScriptType: v4.00+
PlayResX: {larg}
PlayResY: {alt}
WrapStyle: 0
ScaledBorderAndShadow: yes
YCbCr Matrix: TV.709

[V4+ Styles]
Format: Name, Fontname, Fontsize, PrimaryColour, SecondaryColour, OutlineColour, BackColour, Bold, Italic, Underline, StrikeOut, ScaleX, ScaleY, Spacing, Angle, BorderStyle, Outline, Shadow, Alignment, MarginL, MarginR, MarginV, Encoding
Style: Leg,{est['fonte']},{est['tam']},{est['cor']},&H000000FF,{est['cor_borda']},{est['cor_sombra']},0,{est['italico']},0,0,100,100,0,0,1,{est['contorno']},{est['sombra']},5,60,60,0,1
Style: Titulo,Archivo,96,&H00161616,&H000000FF,&H00FFFFFF,&H00FFFFFF,0,0,0,0,100,100,0,0,3,22,0,8,70,70,0,1

[Events]
Format: Layer, Start, End, Style, Name, MarginL, MarginR, MarginV, Effect, Text
"""
    linhas = []
    dentro = [dict(w, i=w["i"] - a, f=w["f"] - a) for w in palavras if w["f"] > a + 0.05 and w["i"] < b - 0.05]
    dur = b - a
    if dentro:
        grupos = blocos(dentro, est)
        for gi, g in enumerate(grupos):
            ini = max(0.0, g[0]["i"])
            prox = grupos[gi + 1][0]["i"] if gi + 1 < len(grupos) else dur
            fim = min(dur, prox, max(g[-1]["f"] + 0.25, min(prox, g[-1]["f"] + 0.6)))
            if fim - ini < 0.12:
                fim = min(prox, ini + 0.12) if prox > ini + 0.02 else ini + 0.12
            textos = []
            for k, w in enumerate(g):
                t = w["p"].strip()
                # pontuação igual no vídeo inteiro: sai ponto, vírgula e dois-pontos; ficam ! e ?
                t = t.rstrip(".,;:") or t
                # começo de bloco depois de frase terminada vai com maiúscula
                if k == 0 and t[:1].islower() and (gi == 0 or re.search(r"[.!?…]$", grupos[gi - 1][-1]["p"])):
                    t = t[:1].upper() + t[1:]
                if censura:
                    t = _censura(t) or t
                t = _esc(t.upper() if est["maiuscula"] else t)
                textos.append(t)
            pop = ""
            if est["pop"]:
                s0 = int(est["pop"] * 100)
                pop = f"\\fscx{s0}\\fscy{s0}\\t(0,90,\\fscx106\\fscy106)\\t(90,160,\\fscx100\\fscy100)"
            pos = f"\\an5\\pos({larg // 2},{y})"
            if est["revela"] or est.get("marca"):
                # um evento por palavra: o bloco inteiro no lugar, as palavras que ainda não foram ditas invisíveis
                for k, w in enumerate(g):
                    t0 = max(ini, w["i"]) if k else ini
                    t1 = min(fim, max(t0 + 0.05, g[k + 1]["i"])) if k + 1 < len(g) else fim
                    if t1 <= t0:
                        continue
                    partes = []
                    for j, tx in enumerate(textos):
                        if est["revela"]:
                            partes.append(tx if j <= k else "{\\alpha&HFF&}" + tx + "{\\alpha&H00&}")
                        else:
                            cheia = len(sem_acento(tx).strip(" .,!?…")) >= 4 and sem_acento(tx).lower().strip(" .,!?…") not in VAZIAS
                            partes.append("{\\c" + est["marca"] + "}" + tx + "{\\c" + est["cor"] + "}" if j == k and cheia else tx)
                    efeito = pop if k == 0 else ""
                    linhas.append(f"Dialogue: 1,{_ts(t0)},{_ts(t1)},Leg,,0,0,0,,{{{pos}{efeito}}}" + " ".join(partes))
            else:
                linhas.append(f"Dialogue: 1,{_ts(ini)},{_ts(fim)},Leg,,0,0,0,,{{{pos}{pop}}}" + " ".join(textos))
    if titulo:
        t = _esc(titulo.strip())
        # duas linhas no máximo, quebrando no espaço do meio
        if len(t) > 16 and " " in t:
            meio = len(t) // 2
            esp = min((i for i, c in enumerate(t) if c == " "), key=lambda i: abs(i - meio))
            t = t[:esp] + "\\N" + t[esp + 1:]
        ty = 70 if layout == "camera" else 180
        linhas.append(f"Dialogue: 2,{_ts(0)},{_ts(dur)},Titulo,,0,0,0,,{{\\an8\\pos({larg // 2},{ty})\\fad(150,0)}}{t}")
    return cab + "\n".join(linhas) + "\n", len(dentro)


def trechos_censurados(palavras, a, b):
    out = []
    for w in palavras:
        if w["f"] > a and w["i"] < b and _censura(w["p"].strip()):
            out.append((max(0.0, w["i"] - a), max(0.0, w["f"] - a)))
    return out
