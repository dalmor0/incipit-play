"""Conferência medida de um vídeo editado (as passadas da CONFERENCIA_ANTES_DE_MOSTRAR que valem pra clipe de jogo).

  python testes/conferir_video.py <video editado .mp4> [...]

Para cada vídeo: formato (H.264 1080x1920, 30 fps, yuv420p, AAC 48 kHz), volume (EBU R128: integrado, pico real,
faixa), silêncio total mais longo, quadro preto, e legenda no tempo da voz (o começo de cada bloco de legenda
contra o começo real da voz no áudio montado, nas palavras que vêm depois de silêncio).
"""
import json
import re
import subprocess
import sys
from pathlib import Path

import numpy as np

AQUI = Path(__file__).resolve().parent.parent
sys.path.insert(0, str(AQUI))


def roda(args):
    return subprocess.run(args, capture_output=True, text=True, encoding="utf-8", errors="replace")


def formato(v):
    r = roda(["ffprobe", "-v", "error", "-show_entries", "stream=codec_name,width,height,r_frame_rate,pix_fmt,sample_rate,channels:format=duration",
              "-of", "json", v])
    d = json.loads(r.stdout)
    vs = [s for s in d["streams"] if s.get("width")]
    as_ = [s for s in d["streams"] if s.get("sample_rate")]
    return {"video": f"{vs[0]['codec_name']} {vs[0]['width']}x{vs[0]['height']} {vs[0]['r_frame_rate']} {vs[0]['pix_fmt']}" if vs else None,
            "audio": f"{as_[0]['codec_name']} {as_[0]['sample_rate']} Hz {as_[0]['channels']} ch" if as_ else None,
            "duracao": round(float(d["format"]["duration"]), 2)}


def volume(v):
    r = roda(["ffmpeg", "-nostats", "-hide_banner", "-i", v, "-vn", "-af", "ebur128=peak=true", "-f", "null", "-"])
    t = r.stderr[r.stderr.rfind("Summary:"):]
    g = lambda k: float(re.search(k + r":\s+(-?[\d.]+)", t).group(1)) if re.search(k + r":\s+(-?[\d.]+)", t) else None
    return {"I_LUFS": g("I"), "LRA": g("LRA"), "pico_real_dBTP": g("Peak")}


def silencio(v):
    r = roda(["ffmpeg", "-hide_banner", "-i", v, "-vn", "-af", "silencedetect=n=-50dB:d=0.3", "-f", "null", "-"])
    d = [float(x) for x in re.findall(r"silence_duration: ([\d.]+)", r.stderr)]
    return round(max(d), 2) if d else 0.0


def preto(v):
    r = roda(["ffmpeg", "-hide_banner", "-i", v, "-an", "-vf", "blackdetect=d=0.5:pix_th=0.08", "-f", "null", "-"])
    return [(float(a), float(b)) for a, b in re.findall(r"black_start:([\d.]+) black_end:([\d.]+)", r.stderr)]


def onsets(v):
    """Começo da voz: volume a cada 10 ms subindo 12 dB acima do chão logo antes."""
    r = subprocess.run(["ffmpeg", "-v", "error", "-i", v, "-vn", "-ac", "1", "-ar", "16000", "-f", "f32le", "-"], capture_output=True)
    x = np.frombuffer(r.stdout, np.float32)
    n = 160
    m = len(x) // n
    db = 20 * np.log10(np.sqrt((x[:m * n].reshape(m, n) ** 2).mean(axis=1)) + 1e-9)
    return db


def legenda_no_tempo(v, js):
    """Compara o começo de cada bloco de legenda que vem depois de silêncio com a subida da voz."""
    from clipador import legenda, __main__ as mm
    info = json.loads(Path(js).read_text(encoding="utf-8"))
    if not info.get("legenda") or not info.get("palavras_na_legenda"):
        return None
    cache = mm.pasta_cache() / f"{mm.chave(Path(info['origem']))}.json"
    if not cache.is_file():
        return "sem cache da fala"
    pal = json.loads(cache.read_text(encoding="utf-8")).get("palavras") or []
    a, b = info["inicio"], info["fim"]
    dentro = [dict(w, i=w["i"] - a, f=w["f"] - a) for w in pal if w["f"] > a + 0.05 and w["i"] < b - 0.05]
    est = legenda.ESTILOS.get(info.get("estilo") or "creme", legenda.ESTILOS["creme"])
    blocos = legenda.blocos(dentro, est)
    db = onsets(v)
    difs = []
    for k, g in enumerate(blocos):
        ini = g[0]["i"]
        antes = blocos[k - 1][-1]["f"] if k else -1
        if ini - antes < 0.35 or ini < 0.3:
            continue
        i0 = int(ini * 100)
        lo, hi = max(0, i0 - 30), min(len(db) - 1, i0 + 30)
        chao = np.percentile(db[max(0, lo - 30):lo + 1], 30) if lo > 0 else db[0]
        sobe = np.where(db[lo:hi] > chao + 12)[0]
        if len(sobe):
            difs.append(round(ini - (lo + sobe[0]) / 100, 3))
    if not difs:
        return "nenhum bloco depois de silêncio"
    d = np.array(difs)
    return {"blocos_medidos": len(d), "atraso_mediano_s": round(float(np.median(d)), 3),
            "maior_adiantado_s": round(float(d.min()), 3), "maior_atrasado_s": round(float(d.max()), 3),
            "dentro_de_0_10s": int((np.abs(d) <= 0.10).sum())}


if __name__ == "__main__":
    for v in sys.argv[1:]:
        js = str(Path(v).with_suffix(".json"))
        out = {"video": Path(v).name, **formato(v), "volume": volume(v), "silencio_mais_longo_s": silencio(v),
               "quadros_pretos": preto(v)}
        try:
            out["legenda_no_tempo"] = legenda_no_tempo(v, js)
        except Exception as e:
            out["legenda_no_tempo"] = f"não medi: {e!r}"
        print(json.dumps(out, ensure_ascii=False))
