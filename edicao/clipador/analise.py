"""Lê o clipe: áudio (pra fala e pros picos) e movimento da imagem (pra ação e enquadramento)."""
import numpy as np

from .base import Falha, abrir, audio_de, entrada

SR = 16000
PASSO = 0.1   # resolução das séries, em segundos


def audio(clipe, meta):
    """Áudio mono a 16 kHz em float32 (o que o faster-whisper pede)."""
    if not meta["audio"]:
        return np.zeros(int(meta["duracao"] * SR), dtype=np.float32)
    filtro = audio_de(0, meta.get("faixas", 1)) + "aformat=channel_layouts=mono,aresample=16000[a]"
    # lê só o que o cabeçalho diz (+1 s): arquivo que mente a duração não come a memória (achado M1)
    p = abrir([*entrada(clipe, duracao=meta["duracao"] + 1), "-filter_complex", filtro, "-map", "[a]", "-f", "f32le", "-"])
    dados, err = p.communicate()
    if p.returncode != 0 and not dados:
        raise Falha("Não consegui ler o áudio do clipe.", err.decode("utf-8", "replace")[-400:])
    return np.frombuffer(dados, dtype=np.float32).copy()


def volume_db(x):
    """Volume (dB RMS) a cada 0,1 s."""
    n = int(SR * PASSO)
    m = len(x) // n
    if m == 0:
        return np.full(1, -90.0)
    q = x[: m * n].reshape(m, n).astype(np.float64)
    rms = np.sqrt((q * q).mean(axis=1) + 1e-12)
    return 20 * np.log10(rms + 1e-9)


W_MOV, H_MOV, FPS_MOV = 96, 54, 10


def movimento(clipe, meta, cancelado=lambda: False):
    """Quadros pequenos a 10 fps: energia de movimento por quadro e por coluna, e a cor (clarão vermelho, flash)."""
    p = abrir([*entrada(clipe, duracao=meta["duracao"] + 1), "-an", "-vf", f"fps={FPS_MOV},scale={W_MOV}:{H_MOV}:flags=area,format=rgb24",
               "-f", "rawvideo", "-"])
    tam = W_MOV * H_MOV * 3
    quadros = []
    while True:
        b = p.stdout.read(tam * 50)
        if not b:
            break
        quadros.append(np.frombuffer(b, dtype=np.uint8))
        if cancelado():
            p.kill()
            break
    p.wait()
    if not quadros:
        return {"energia": np.zeros(1), "colunas": np.ones(W_MOV), "corte": np.zeros(1)}
    rgb = np.concatenate(quadros)
    rgb = rgb[: (len(rgb) // tam) * tam].reshape(-1, H_MOV, W_MOV, 3).astype(np.float32)
    v = rgb.mean(axis=3)
    # vinheta vermelha de dano: vermelho nas bordas da tela acima do centro (sangue, golpe). Luz quente da cena
    # pinta a tela toda por igual e não conta.
    red = (rgb[..., 0] - (rgb[..., 1] + rgb[..., 2]) / 2).clip(0) if len(rgb) else np.zeros((1, H_MOV, W_MOV))
    bh, bw = max(1, int(H_MOV * 0.18)), max(1, int(W_MOV * 0.15))
    borda = np.concatenate([red[:, :bh, :].reshape(len(red), -1), red[:, -bh:, :].reshape(len(red), -1),
                            red[:, bh:-bh, :bw].reshape(len(red), -1), red[:, bh:-bh, -bw:].reshape(len(red), -1)], axis=1).mean(axis=1)
    centro = red[:, bh:-bh, bw:-bw].reshape(len(red), -1).mean(axis=1)
    vermelho = (borda - centro).clip(0)
    brilho = v.mean(axis=(1, 2)) if len(v) else np.zeros(1)
    del rgb
    if len(v) < 2:
        return {"energia": np.zeros(1), "colunas": np.ones(W_MOV), "corte": np.zeros(1)}
    dif = np.abs(np.diff(v, axis=0))
    energia = dif.mean(axis=(1, 2))
    colunas = dif.mean(axis=(0, 1))
    # troca de plano: diferença grande e repentina comparada com a vizinhança
    corte = (energia > np.median(energia) * 4 + 12).astype(np.float32)
    # série por coluna ao longo do tempo (pra seguir a ação no recorte do centro)
    col_t = dif.mean(axis=1)
    # quadros pequenos (uint8) até 15 min: dão a reação dentro da caixa da câmera
    pequenos = v.astype(np.uint8) if len(v) <= FPS_MOV * 900 else None
    return {"energia": energia, "colunas": colunas, "corte": corte, "col_t": col_t, "quadros": pequenos,
            "vermelho": vermelho, "brilho": brilho}


def lance(mov, db, n):
    """Sinal do lance do jogo, a cada 0,1 s: clarão vermelho ou flash de repente, pancada na imagem (energia que
    salta muito acima do normal) e estouro do áudio. Sem depender de ninguém falar."""
    def serie(x):
        return para_passo(np.asarray(x, dtype=np.float64), FPS_MOV, n) if x is not None and len(x) > 1 else np.zeros(n)
    verm = serie(mov.get("vermelho"))
    bri = serie(mov.get("brilho"))
    ene = serie(mov.get("energia"))
    # a vinheta aparece de repente e fica uns segundos: sobe em relação aos 2 s anteriores
    # e o dano FICA na tela uns segundos; luz da cena que passa (porta, janela) dura 1 s: vale a subida sustentada
    d_verm = np.zeros(n)
    for t in range(20, max(20, n - 5)):
        prev = verm[t - 20:t].mean()
        prox = verm[t:t + 30]
        subida = max(0.0, prox[:20].mean() - prev)
        if subida > 0.5:
            d_verm[t] = min(6.0, 2.0 * subida * float((prox > prev + 0.8).mean()))
    # flash: brilho que salta e volta em menos de meio segundo (explosão, tiro), não troca de ambiente
    d_bri = np.clip(z(np.abs(bri - suavizar(bri, 9))) - 3.0, 0, 6)
    pancada = np.clip(z(ene) - 3.0, 0, 6)
    dbn = np.pad(np.asarray(db, dtype=np.float64), (0, max(0, n - len(db))))[:n] if len(db) else np.full(n, -90.0)
    estouro = np.clip(z(suavizar(dbn, 2)) - 3.0, 0, 6)
    # câmera girando também mexe muito a imagem e não é lance: a pancada por movimento só entra fraca
    sinal = d_verm + 0.5 * d_bri + 0.2 * pancada + 0.6 * estouro
    # pontas do clipe (corte do gravador) e menu (tela parada) não são lance
    sinal[:10] = 0
    sinal[max(0, n - 10):] = 0
    par = para_passo(parado(mov.get("energia", np.zeros(1))), FPS_MOV, n)
    sinal = sinal * (1 - par)
    return suavizar(sinal, 3)


def reacao_na_camera(mov, caixa):
    """Movimento dentro da caixa da câmera, por quadro (rosto que ri, mão no rosto, pulo na cadeira)."""
    q = mov.get("quadros")
    if q is None or caixa is None or len(q) < 2:
        return None
    x, y, w, h = caixa
    x0, y0 = int(x * W_MOV), int(y * H_MOV)
    # só a metade de cima da caixa: rosto e cabeça (risada, susto); mão no queixo embaixo não é reação
    x1, y1 = max(x0 + 2, int((x + w) * W_MOV)), max(y0 + 2, int((y + h * 0.55) * H_MOV))
    reg = q[:, y0:y1, x0:x1].astype(np.float32)
    return np.abs(np.diff(reg, axis=0)).mean(axis=(1, 2))


def parado(energia):
    """1 onde a imagem está parada (menu, carregamento, tela de pausa): energia de movimento abaixo de 0,8."""
    return (np.asarray(energia) < 0.8).astype(np.float32)


def para_passo(serie, fps_origem, n):
    """Reamostra uma série (fps_origem) pra n pontos de 0,1 s."""
    if len(serie) == 0:
        return np.zeros(n)
    t_o = np.arange(len(serie)) / fps_origem
    t_n = np.arange(n) * PASSO
    return np.interp(t_n, t_o, serie)


def z(serie):
    s = np.asarray(serie, dtype=np.float64)
    med = np.median(s)
    mad = np.median(np.abs(s - med)) * 1.4826 + 1e-6
    return (s - med) / mad


def suavizar(serie, janela):
    if janela <= 1 or len(serie) < 2:
        return np.asarray(serie, dtype=np.float64)
    k = np.ones(int(janela)) / int(janela)
    return np.convolve(serie, k, mode="same")


def onda(db, pontos=240):
    """Resumo do volume pra desenhar a linha do tempo no Play (0 a 1)."""
    if len(db) == 0:
        return []
    idx = np.linspace(0, len(db), pontos + 1).astype(int)
    v = [float(db[a:b].max()) if b > a else float(db[min(a, len(db) - 1)]) for a, b in zip(idx[:-1], idx[1:])]
    v = np.clip((np.array(v) + 60) / 60, 0, 1)
    return [round(float(x), 3) for x in v]


def regioes_de_voz(x):
    """Pedaços com voz (VAD do faster-whisper, Silero), em segundos."""
    try:
        from faster_whisper.vad import VadOptions, get_speech_timestamps
    except Exception:
        return []
    return [(r["start"] / SR, r["end"] / SR) for r in get_speech_timestamps(x, VadOptions(min_silence_duration_ms=250, speech_pad_ms=60))]


def energia_db(x, passo=0.01, jan=0.03):
    """Energia em dB de 10 em 10 ms (janela de 30 ms, média de 50 ms)."""
    h, w = int(SR * passo), int(SR * jan)
    if len(x) <= w:
        return np.full(1, -100.0)
    n = (len(x) - w) // h + 1
    c = np.concatenate([[0.0], np.cumsum(np.asarray(x, dtype=np.float64) ** 2)])
    idx = np.arange(n) * h
    db = 10 * np.log10((c[idx + w] - c[idx]) / w + 1e-10)
    return np.convolve(db, np.ones(5) / 5, mode="same")


def ponta_no_vao(e, t, voz, antes, depois, dur, palavras=()):
    """Ponta do trecho dentro de uma fala vai pro vão mais perto entre duas falas: pelo menos 0,25 s com a energia
    perto do chão de ruído (até 6 dB acima), fora de qualquer palavra transcrita. Vão de 0,05 s entre palavras da
    mesma frase não serve (abria em "Pro canto do mapa", sem o verbo). e = energia_db do clipe inteiro."""
    dentro_voz = any(r0 + 0.05 < t < r1 - 0.05 for r0, r1 in voz)
    dentro_pal = any(w["i"] + 0.02 < t < w["f"] - 0.02 for w in palavras)
    if not dentro_voz and not dentro_pal:
        return t
    i0, i1 = max(0, int((t - antes) * 100)), min(len(e) - 1, int((t + depois) * 100))
    if i1 - i0 < 30:
        return t
    trecho = e[i0:i1 + 1]
    chao = float(np.percentile(trecho, 10))
    baixo = trecho <= chao + 6
    melhor, dist = None, 1e9
    k = 0
    while k < len(baixo):
        if not baixo[k]:
            k += 1
            continue
        j = k
        while j < len(baixo) and baixo[j]:
            j += 1
        if j - k >= 25:
            # o ponto do vão mais perto de t (começo do trecho: o fim do vão; fim do trecho: o começo do vão)
            cand = (i0 + j - 5) / 100.0 if antes > depois else (i0 + k + 5) / 100.0
            if not any(w["i"] < cand < w["f"] for w in palavras):
                d = abs(cand - t)
                if d < dist:
                    melhor, dist = cand, d
        k = j
    if melhor is None and palavras:
        # plano B (jogo e anime com música não têm vão de silêncio): o maior intervalo entre duas palavras perto,
        # com bônus pra fim de frase (pontuação); nunca no meio da palavra
        ws = sorted((w for w in palavras if t - antes - 1 <= w["i"] <= t + depois + 1), key=lambda w: w["i"])
        notas = []
        for w0, w1 in zip(ws, ws[1:]):
            meio = (w0["f"] + w1["i"]) / 2
            if not (t - antes <= meio <= t + depois):
                continue
            vao = max(0.0, w1["i"] - w0["f"])
            fim_frase = 0.4 if w0["p"].rstrip()[-1:] in ".!?…" else (0.15 if w0["p"].rstrip()[-1:] == "," else 0.0)
            ponto = w1["i"] - 0.06 if antes > depois else w0["f"] + 0.06
            notas.append((vao + fim_frase - 0.08 * abs(ponto - t), ponto))
        if notas:
            melhor = max(notas)[1]
            # o tempo do Whisper erra uns 0,1 s: confere na energia e fica no ponto mais baixo a até 0,15 s
            c, r = int(melhor * 100), 15
            lo, hi = max(0, c - r), min(len(e), c + r + 1)
            if hi > lo:
                melhor = (lo + int(np.argmin(e[lo:hi]))) / 100.0
        else:
            for w in palavras:
                if w["i"] < t < w["f"]:
                    melhor = w["i"] - 0.05 if antes > depois else w["f"] + 0.05
    return t if melhor is None else float(min(dur, max(0.0, melhor)))


def _subida(e, ini, de, ate, teto=0.15):
    """A subida da voz: primeiro instante entre de e ate com a energia 8 dB acima do chão de ruído de antes. Medir
    contra o pico atrasava a fala que começa baixa e vira grito. Nunca mais de 0,15 s depois de de."""
    a, b = max(0, int((de - ini) * 100)), min(len(e), int((ate - ini) * 100) + 1)
    if b - a < 2:
        return de
    antes = e[max(0, a - 50):a + 3]
    chao = float(np.percentile(antes, 20)) if len(antes) else float(e[a:b].min())
    acima = np.where(e[a:b] >= chao + 8)[0]
    t = ini + (a + int(acima[0])) / 100.0 - 0.02 if len(acima) else de
    return min(t, de + teto)


def alinhar_falas(palavras, x, ini=0.0, fim=None, trecho_pronto=None):
    """O Whisper marca o começo de uma frase depois de silêncio cedo demais (até 1 s antes, medido nas
    conferências): a legenda aparecia com a tela em silêncio. Cada FRASE (palavras separadas por pausa de 0,3 s) anda
    inteira, sem mudar a ordem: o começo dela vai pro começo do pedaço de voz (VAD do áudio do trecho como sai no
    vídeo) em que ela cai, ou pro próximo pedaço de voz se cair no silêncio (até 1,5 s); sem voz perto, a frase é
    invenção do Whisper e sai."""
    if not palavras or len(x) < SR:
        return palavras
    fim = len(x) / SR if fim is None else fim
    trecho = trecho_pronto if trecho_pronto is not None else np.asarray(x[int(ini * SR):int(fim * SR)], dtype=np.float32)
    voz = [(r0 + ini, r1 + ini) for r0, r1 in regioes_de_voz(trecho)]
    if not voz:
        return palavras
    e = energia_db(trecho)
    ordem = sorted((dict(w) for w in palavras), key=lambda w: w["i"])
    # frases
    frases, atual = [], []
    for w in ordem:
        if atual and w["i"] - atual[-1]["f"] >= 0.3:
            frases.append(atual)
            atual = []
        atual.append(w)
    if atual:
        frases.append(atual)
    out = []
    fim_ant = -1.0
    for fr in frases:
        c0 = fr[0]["i"]
        if not (ini <= c0 < fim):
            out.extend(fr)
            fim_ant = fr[-1]["f"]
            continue
        dentro = [r for r in voz if r[0] - 0.05 <= c0 < r[1]]
        if dentro:
            # o começo da região do VAD tem folga (e o barulho do jogo junto): vale a subida da voz dentro dela
            comeco = _subida(e, ini, dentro[0][0], c0 + 0.15) if c0 - dentro[0][0] <= 1.2 else c0
        else:
            prox = [r for r in voz if c0 < r[0] <= c0 + 1.5]
            if not prox:
                # frase toda no silêncio: o Whisper inventou
                if not any(r[0] < fr[-1]["f"] and fr[0]["i"] < r[1] for r in voz):
                    continue
                comeco = c0 + 0.1
            else:
                comeco = _subida(e, ini, prox[0][0], prox[0][0] + 0.8) + 0.03
        # o Whisper pôs a frase antes da voz ("Clipei" 0,8 s antes, no barulho do jogo): espera a subida, até 1 s
        comeco = _subida(e, ini, comeco, comeco + 1.0, teto=1.0) + 0.02
        comeco = max(comeco, c0 - 0.05, fim_ant + 0.02)
        delta = comeco - c0
        for w in fr:
            w["i"] = round(w["i"] + delta, 3)
            w["f"] = round(w["f"] + delta, 3)
        out.extend(fr)
        fim_ant = fr[-1]["f"]
    return out
