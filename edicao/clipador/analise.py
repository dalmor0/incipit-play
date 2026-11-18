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
    """Quadros pequenos em cinza a 10 fps: energia de movimento por quadro e por coluna."""
    p = abrir([*entrada(clipe, duracao=meta["duracao"] + 1), "-an", "-vf", f"fps={FPS_MOV},scale={W_MOV}:{H_MOV}:flags=area,format=gray",
               "-f", "rawvideo", "-"])
    tam = W_MOV * H_MOV
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
    v = np.concatenate(quadros)
    v = v[: (len(v) // tam) * tam].reshape(-1, H_MOV, W_MOV).astype(np.float32)
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
    return {"energia": energia, "colunas": colunas, "corte": corte, "col_t": col_t, "quadros": pequenos}


def reacao_na_camera(mov, caixa):
    """Movimento dentro da caixa da câmera, por quadro (rosto que ri, mão no rosto, pulo na cadeira)."""
    q = mov.get("quadros")
    if q is None or caixa is None or len(q) < 2:
        return None
    x, y, w, h = caixa
    x0, y0 = int(x * W_MOV), int(y * H_MOV)
    x1, y1 = max(x0 + 2, int((x + w) * W_MOV)), max(y0 + 2, int((y + h) * H_MOV))
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


def alinhar_falas(palavras, x):
    """Começo de fala depois de silêncio vai pra subida real da voz no áudio: o Whisper marca a palavra uns 0,2 a
    0,3 s depois (medido nos clipes de teste), e legenda atrasada dá a sensação de dessincronia."""
    if not palavras or len(x) < SR:
        return palavras
    n = 160   # 10 ms
    m = len(x) // n
    db = 20 * np.log10(np.sqrt((x[: m * n].reshape(m, n).astype(np.float64) ** 2).mean(axis=1)) + 1e-9)
    out = []
    antes = -1.0
    for w in palavras:
        w = dict(w)
        if w["i"] - antes >= 0.3 and w["i"] >= 0.3:
            i0 = int(w["i"] * 100)
            lo, hi = max(0, i0 - 35), min(len(db) - 1, i0 + 5)
            base = db[max(0, lo - 30):lo + 1]
            if hi > lo and len(base):
                chao = np.percentile(base, 30)
                sobe = np.where(db[lo:hi] > chao + 12)[0]
                if len(sobe):
                    novo = (lo + sobe[0]) / 100
                    if w["i"] - 0.12 <= novo < w["i"] and novo > antes + 0.05:
                        w["i"] = round(novo, 3)
        antes = w["f"]
        out.append(w)
    return out
