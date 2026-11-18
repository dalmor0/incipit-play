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
    return {"energia": energia, "colunas": colunas, "corte": corte, "col_t": col_t}


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
