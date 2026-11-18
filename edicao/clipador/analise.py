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


def alinhar_falas(palavras, x, ini=0.0, fim=None, trecho_pronto=None):
    """O Whisper marca a primeira palavra depois de silêncio cedo demais (até 1 s antes, medido nas conferências):
    a legenda aparecia com a tela em silêncio. O começo de cada fala vai pro começo do pedaço de voz (VAD) em que ela
    cai; se cair no silêncio, vai pro próximo pedaço de voz (até 1,5 s depois)."""
    if not palavras or len(x) < SR:
        return palavras
    # VAD no TRECHO que vai pro vídeo (o mesmo áudio que a pessoa ouve); no clipe inteiro ele marca diferente
    fim = len(x) / SR if fim is None else fim
    # de preferência o áudio do trecho como vai sair (nivelado e limitado): o detector de voz muda com o nível
    trecho = trecho_pronto if trecho_pronto is not None else np.asarray(x[int(ini * SR):int(fim * SR)], dtype=np.float32)
    voz = [(a + ini, b + ini) for a, b in regioes_de_voz(trecho)]
    if not voz:
        return palavras
    out = []
    antes = -1.0
    for w in palavras:
        w = dict(w)
        if ini <= w["i"] < fim and not any(r[0] - 0.05 <= w["i"] < r[1] for r in voz):
            # começa no silêncio: vai pro começo da próxima fala; sem fala perto, o Whisper inventou e sai
            prox = [r for r in voz if w["i"] < r[0] <= w["i"] + 1.5 and r[0] >= antes - 0.01]
            if not prox:
                continue
            dur = min(w["f"] - w["i"], 0.8)
            w["i"], w["f"] = round(prox[0][0] + 0.03, 3), round(prox[0][0] + 0.03 + dur, 3)
        if w["i"] - antes >= 0.3:
            dentro = [r for r in voz if r[0] - 0.05 <= w["i"] < r[1]]
            if dentro:
                ini = dentro[0][0]
                # começo do pedaço de voz bem antes da palavra é outra fala (ou o próprio barulho): fica a do Whisper
                if w["i"] - ini > 0.6:
                    ini = w["i"]
            else:
                prox = [r for r in voz if w["i"] < r[0] <= w["i"] + 1.5]
                ini = prox[0][0] + 0.03 if prox else w["i"] + 0.1
            novo = max(ini, w["i"] - 0.05)
            if novo < w["f"] - 0.05:
                w["i"] = round(novo, 3)
            elif novo < w["f"] + 1.0:
                dur = w["f"] - w["i"]
                w["i"], w["f"] = round(novo, 3), round(novo + dur, 3)
        antes = w["f"]
        out.append(w)
    return out
