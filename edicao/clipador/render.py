"""Monta o vertical 1080x1920 quadro a quadro (enquadramento e zoom) e entrega pro ffmpeg
gravar em H.264 com a legenda, o título e o áudio medido."""
import json
import os
import random
import shutil
import subprocess
from pathlib import Path

import numpy as np

from .base import FONTES, Falha, abrir, audio_de, entrada, rodar

LARG, ALT, FPS = 1080, 1920, 30
SW, SH = 1920, 1080               # o quadro de origem é normalizado pra 1920x1080
CAM_ALT = 640                     # câmera em cima: 1/3 da tela (o "Gameplay" do Opus usa 30%)


def curva_zoom(t, impactos, forca):
    """Zoom no instante t: soco rápido no impacto, segura e volta macio."""
    amp = {0.5: 0.07, 1.0: 0.14, 2.0: 0.22}.get(forca, 0.14 * forca)
    z = 1.0
    for t0, f in impactos:
        d = t - t0
        if d < 0 or d > 1.5:
            continue
        if d < 0.12:
            e = 1 - (1 - d / 0.12) ** 3
        elif d < 0.85:
            e = 1.0
        else:
            x = (d - 0.85) / 0.65
            e = 1 - (x * x * (3 - 2 * x))
        z = max(z, 1.0 + amp * f * e)
    return z


def _afim(cx, cy, w_fonte, h_fonte, w_dest, h_dest, zoom):
    """Matriz que leva o retângulo (centro cx,cy; w_fonte x h_fonte / zoom) pra w_dest x h_dest."""
    s = w_dest / (w_fonte / zoom)
    return np.float32([[s, 0, w_dest / 2 - s * cx], [0, s, h_dest / 2 - s * cy]])


def seguir_acao(col_t, fps_mov, a, b, largura_janela):
    """Centro horizontal do recorte acompanhando o movimento, bem suavizado e com folga parada."""
    if col_t is None or len(col_t) == 0:
        return lambda t: SW / 2
    ia, ib = int(a * fps_mov), max(int(a * fps_mov) + 1, int(b * fps_mov))
    seg = col_t[ia:ib]
    if len(seg) == 0:
        return lambda t: SW / 2
    xs = (np.arange(seg.shape[1]) + 0.5) / seg.shape[1] * SW
    peso = seg + 1e-3
    cent = (peso * xs).sum(axis=1) / peso.sum(axis=1)
    k = max(1, int(fps_mov * 2.5))
    cent = np.convolve(np.pad(cent, (k, k), mode="edge"), np.ones(2 * k + 1) / (2 * k + 1), mode="valid")
    meio = SW / 2
    folga = largura_janela * 0.18
    cent = np.where(np.abs(cent - meio) < folga, meio, cent - np.sign(cent - meio) * folga)
    lim = (SW - largura_janela) / 2
    cent = np.clip(cent, meio - lim * 0.6, meio + lim * 0.6)
    ts = np.arange(len(cent)) / fps_mov

    return lambda t: float(np.interp(t, ts, cent))


def _cobrir(img, w, h):
    """Recorte central que cobre w x h sem distorcer."""
    import cv2
    ih, iw = img.shape[:2]
    s = max(w / iw, h / ih)
    nw, nh = int(round(iw * s)), int(round(ih * s))
    r = cv2.resize(img, (nw, nh), interpolation=cv2.INTER_AREA if s < 1 else cv2.INTER_CUBIC)
    x, y = (nw - w) // 2, (nh - h) // 2
    return r[y:y + h, x:x + w]


class Montador:
    def __init__(self, layout, camera, impactos, forca, centro_x):
        import cv2
        self.cv2 = cv2
        self.layout = layout
        self.cam = None
        if camera:
            x, y, w, h = camera
            self.cam = (x * SW, y * SH, w * SW, h * SH)
        self.impactos = impactos
        self.forca = forca
        self.centro_x = centro_x
        self.tela = np.zeros((ALT, LARG, 3), np.uint8)

    def quadro(self, f, t):
        cv2 = self.cv2
        z = curva_zoom(t, self.impactos, self.forca) if self.impactos else 1.0
        out = self.tela
        if self.layout == "camera" and self.cam:
            cx, cy, cw, ch = self.cam
            # câmera: cobre 1080x640 a partir da caixa, com um zoom bem menor no impacto
            alvo = LARG / CAM_ALT
            if cw / ch > alvo:
                w2, h2 = ch * alvo, ch
            else:
                w2, h2 = cw, cw / alvo
            zc = 1.0 + (z - 1.0) * 0.4
            M = _afim(cx + cw / 2, cy + ch / 2, w2, h2, LARG, CAM_ALT, zc)
            cv2.warpAffine(f, M, (LARG, CAM_ALT), dst=out[:CAM_ALT], flags=cv2.INTER_LINEAR, borderMode=cv2.BORDER_REPLICATE)
            # jogo: 1080x1280 embaixo
            gh = ALT - CAM_ALT
            jw = SH * LARG / gh
            M = _afim(self.centro_x(t), SH / 2, jw, SH, LARG, gh, z)
            cv2.warpAffine(f, M, (LARG, gh), dst=out[CAM_ALT:], flags=cv2.INTER_LINEAR, borderMode=cv2.BORDER_REPLICATE)
            out[CAM_ALT - 3:CAM_ALT + 3] = (24, 18, 14)
        elif self.layout == "desfocado":
            fundo = cv2.resize(f[:, (SW - 608) // 2:(SW + 608) // 2], (68, 120), interpolation=cv2.INTER_AREA)
            fundo = cv2.GaussianBlur(fundo, (0, 0), 3.2)
            cv2.resize(fundo, (LARG, ALT), dst=out, interpolation=cv2.INTER_LINEAR)
            np.multiply(out, 0.5, out=out, casting="unsafe")
            fh = 680
            fw = SH * LARG / fh   # largura de origem que cabe (corta ~5% de cada lado)
            y0 = (ALT - fh) // 2 - 110
            M = _afim(SW / 2, SH / 2, fw, SH, LARG, fh, z)
            cv2.warpAffine(f, M, (LARG, fh), dst=out[y0:y0 + fh], flags=cv2.INTER_LINEAR, borderMode=cv2.BORDER_REPLICATE)
        else:  # centro
            jw = SH * LARG / ALT
            M = _afim(self.centro_x(t), SH / 2, jw, SH, LARG, ALT, z)
            cv2.warpAffine(f, M, (LARG, ALT), dst=out, flags=cv2.INTER_LINEAR, borderMode=cv2.BORDER_REPLICATE)
        return out


def medir_volume(clipe, a, dur, cwd, faixas=1):
    code, _, err = rodar([*entrada(clipe, a, dur), "-filter_complex",
                          audio_de(0, faixas) + "loudnorm=I=-14:TP=-1.5:LRA=11:print_format=json[a]",
                          "-map", "[a]", "-f", "null", "-"], cwd=cwd)
    try:
        js = json.loads(err[err.rindex("{"):err.rindex("}") + 1])
        campos = ("input_i", "input_tp", "input_lra", "input_thresh", "target_offset")
        med = {k: float(js[k]) for k in campos}
    except (ValueError, KeyError, TypeError):
        return None
    import math
    # áudio mudo mede -inf: sem medida, sem loudnorm (achado B1); só número de verdade entra no filtro (B6)
    if not all(math.isfinite(v) for v in med.values()) or med["input_i"] < -70:
        return None
    return {k: f"{v:.2f}" for k, v in med.items()}


def _apagar(arq):
    """Apaga o vídeo pela metade; o Windows pode segurar o arquivo uns instantes depois do processo morrer."""
    import time
    for _ in range(20):
        try:
            arq.unlink(missing_ok=True)
            return
        except PermissionError:
            time.sleep(0.25)


def escolher_musica(pasta):
    if not pasta:
        return None
    p = Path(pasta)
    if not p.is_dir():
        return None
    ok = [x for x in p.iterdir() if x.suffix.lower() in (".mp3", ".m4a", ".wav", ".ogg", ".flac", ".aac") and x.is_file()]
    return random.choice(ok) if ok else None


def render(clipe, meta, a, b, layout, camera, impactos, forca, centro_x, ass_texto, censurados, musica,
           destino, progresso, cancelado, trabalho):
    import cv2
    dur = b - a
    total = max(1, int(round(dur * FPS)))
    # fontes e legenda dentro da pasta de trabalho, com nome simples: o filtro "ass" do ffmpeg
    # lê caminho relativo, então acento e espaço no caminho da pessoa não quebram nada
    fdir = trabalho / "f"
    fdir.mkdir(exist_ok=True)
    for ttf in FONTES.glob("*.ttf"):
        shutil.copy(ttf, fdir / ttf.name)
    (trabalho / "leg.ass").write_text(ass_texto, encoding="utf-8")

    medida = medir_volume(clipe, a, dur, trabalho, meta.get("faixas", 1)) if meta["audio"] else None
    af = []
    for i, f in censurados:
        af.append(f"volume=enable='between(t,{i:.2f},{f:.2f})':volume=0")
    if medida:
        af.append("loudnorm=I=-14:TP=-1.5:LRA=11:measured_I={input_i}:measured_TP={input_tp}:measured_LRA={input_lra}:"
                  "measured_thresh={input_thresh}:offset={target_offset}:linear=true".format(**medida))
    af.append("aresample=48000")

    args = ["-y", "-f", "rawvideo", "-pix_fmt", "bgr24", "-s", f"{LARG}x{ALT}", "-r", str(FPS), "-i", "-"]
    if meta["audio"]:
        args += entrada(clipe, a, dur)
    mus = escolher_musica(musica)
    if mus:
        args += ["-protocol_whitelist", "file,pipe", "-format_whitelist", "mp3,mov,mp4,m4a,wav,ogg,flac,aac",
                 "-stream_loop", "-1", "-i", str(mus)]
    vf = "ass=leg.ass:fontsdir=f,format=yuv420p"
    voz_in = audio_de(1, meta.get("faixas", 1))
    if meta["audio"] and mus:
        fc = (f"{voz_in}{','.join(af)},asplit=2[voz][chave];[2:a]volume=-20dB,aresample=48000[mus];"
              f"[mus][chave]sidechaincompress=threshold=0.05:ratio=8:attack=20:release=400[musb];"
              f"[voz][musb]amix=inputs=2:duration=first:normalize=0[aout];[0:v]{vf}[vout]")
        args += ["-filter_complex", fc, "-map", "[vout]", "-map", "[aout]"]
    elif meta["audio"]:
        args += ["-filter_complex", f"{voz_in}{','.join(af)}[aout];[0:v]{vf}[vout]", "-map", "[vout]", "-map", "[aout]"]
    elif mus:
        args += ["-filter_complex", f"[1:a]volume=-14dB,aresample=48000[aout];[0:v]{vf}[vout]",
                 "-map", "[vout]", "-map", "[aout]"]
    else:
        args += ["-vf", vf]
    parcial = destino.with_name(destino.stem + ".parcial.mp4")
    args += ["-c:v", "libx264", "-preset", "veryfast", "-crf", "19", "-profile:v", "high", "-level", "4.2",
             "-g", str(FPS * 2), "-c:a", "aac", "-b:a", "192k", "-ar", "48000", "-t", f"{dur:.3f}",
             "-movflags", "+faststart", "-threads", str(max(2, min(8, (os.cpu_count() or 4) - 2))), str(parcial)]
    enc = abrir(args, cwd=trabalho, stdin=-1, stdout=None)
    dec = abrir([*entrada(clipe, a, dur), "-an", "-vf",
                 f"fps={FPS},scale={SW}:{SH}:force_original_aspect_ratio=decrease,pad={SW}:{SH}:-1:-1",
                 "-pix_fmt", "bgr24", "-f", "rawvideo", "-"])
    m = Montador(layout, camera, impactos, forca, centro_x)
    tam = SW * SH * 3
    k = 0
    miniatura = None
    try:
        while k < total:
            buf = dec.stdout.read(tam)
            if len(buf) < tam:
                break
            f = np.frombuffer(buf, np.uint8).reshape(SH, SW, 3)
            q = m.quadro(f, k / FPS)
            if k == int(total * 0.35):
                miniatura = q.copy()
            enc.stdin.write(q.tobytes())
            k += 1
            if k % 15 == 0:
                progresso(k / total)
                if cancelado():
                    raise Falha("Cancelado.")
        enc.stdin.close()
        err = enc.stderr.read().decode("utf-8", "replace")
        if enc.wait() != 0:
            if "No space left" in err:
                raise Falha("Sem espaço no disco pra salvar o vídeo.", err[-300:])
            raise Falha("A gravação do vídeo falhou.", err[-600:])
    except BrokenPipeError:
        enc.wait()
        raise Falha("A gravação do vídeo falhou.", enc.stderr.read().decode("utf-8", "replace")[-600:])
    except BaseException:
        for p in (enc, dec):
            try:
                p.kill()
                p.wait(timeout=10)
            except (OSError, subprocess.TimeoutExpired):
                pass
        _apagar(parcial)
        raise
    finally:
        try:
            dec.kill()
        except OSError:
            pass
    if k == 0:
        parcial.unlink(missing_ok=True)
        raise Falha("Não consegui ler a imagem do clipe.")
    os.replace(parcial, destino)
    if miniatura is not None:
        ok, jpg = cv2.imencode(".jpg", cv2.resize(miniatura, (360, 640), interpolation=cv2.INTER_AREA), [cv2.IMWRITE_JPEG_QUALITY, 85])
        if ok:
            destino.with_suffix(".jpg").write_bytes(jpg.tobytes())
    return {"quadros": k, "volume_original": medida, "musica": mus.name if mus else None}
