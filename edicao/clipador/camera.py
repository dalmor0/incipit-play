"""Acha a câmera do jogador (o quadradinho com o rosto) num clipe gravado com overlay.

Rosto pequeno, no mesmo lugar na maioria dos quadros: é a câmera. Rosto de personagem do jogo
muda de lugar e some, então não passa. A pessoa pode marcar a área na mão no Play, e aí vale a dela.
Detector YuNet (opencv_zoo, MIT), lido da memória pra funcionar com acento no caminho.
"""
import numpy as np

from .base import MODELOS, abrir, entrada

W, H = 960, 540


def _quadros(clipe, dur, n=10):
    out = []
    for k in range(n):
        t = dur * (k + 0.5) / n
        p = abrir([*entrada(clipe, inicio=t), "-frames:v", "1", "-an",
                   "-vf", f"scale={W}:{H}:force_original_aspect_ratio=decrease,pad={W}:{H}:-1:-1",
                   "-f", "rawvideo", "-pix_fmt", "bgr24", "-"])
        b, _ = p.communicate()
        if len(b) >= W * H * 3:
            out.append(np.frombuffer(b[: W * H * 3], dtype=np.uint8).reshape(H, W, 3))
    return out


def _bordas(quadros, cx, cy, fh):
    """Moldura da câmera pelas linhas que não mexem: borda de overlay fica parada, o jogo anda.
    Devolve (x0, y0, x1, y1) em pixels ou None."""
    import cv2
    est = None
    for q in quadros:
        g = cv2.cvtColor(q, cv2.COLOR_BGR2GRAY).astype(np.float32)
        gx = np.abs(cv2.Sobel(g, cv2.CV_32F, 1, 0, ksize=3))
        gy = np.abs(cv2.Sobel(g, cv2.CV_32F, 0, 1, ksize=3))
        est = (gx, gy) if est is None else (np.minimum(est[0], gx), np.minimum(est[1], gy))
    gx, gy = est
    ya, yb = int(max(0, cy - fh)), int(min(H, cy + fh))
    xa, xb = int(max(0, cx - fh)), int(min(W, cx + fh))

    def melhor(perfil, ini, fim, borda):
        ini, fim = int(max(0, ini)), int(min(len(perfil), fim))
        if fim - ini < 3:
            return borda
        seg = perfil[ini:fim]
        k = int(np.argmax(seg))
        return ini + k if seg[k] > 25 else borda

    col = gx[ya:yb].mean(axis=0)
    lin = gy[:, xa:xb].mean(axis=1)
    x1 = melhor(col, cx + 0.8 * fh, cx + 4.5 * fh, None)
    x0 = melhor(col, cx - 4.5 * fh, cx - 0.8 * fh, None)
    y1 = melhor(lin, cy + 0.9 * fh, cy + 3.5 * fh, None)
    y0 = melhor(lin, cy - 3.0 * fh, cy - 0.9 * fh, None)
    # câmera colada na borda da tela não tem linha daquele lado
    if x0 is None and cx - 4.5 * fh <= 0:
        x0 = 0
    if x1 is None and cx + 4.5 * fh >= W:
        x1 = W
    if y0 is None and cy - 3.0 * fh <= 0:
        y0 = 0
    if y1 is None and cy + 3.5 * fh >= H:
        y1 = H
    # lado sem linha visível (câmera escura encostada no jogo escuro): completa pela proporção 16:9
    if x0 is not None and x1 is not None:
        if y0 is not None and y1 is None:
            y1 = min(H, y0 + (x1 - x0) * 9 / 16)
        elif y1 is not None and y0 is None:
            y0 = max(0, y1 - (x1 - x0) * 9 / 16)
    if y0 is not None and y1 is not None:
        if x0 is not None and x1 is None:
            x1 = min(W, x0 + (y1 - y0) * 16 / 9)
        elif x1 is not None and x0 is None:
            x0 = max(0, x1 - (y1 - y0) * 16 / 9)
    if None in (x0, x1, y0, y1) or x1 - x0 < 1.5 * fh or y1 - y0 < 1.5 * fh:
        return None
    if not (x0 <= cx <= x1 and y0 <= cy <= y1):
        return None
    return x0, y0, x1, y1


def _caixa(cx, cy, fh, quadros=None):
    if quadros:
        b = _bordas(quadros, cx, cy, fh)
        if b:
            x0, y0, x1, y1 = b
            m = 2   # tira a própria linha da moldura
            return [round((x0 + m) / W, 4), round((y0 + m) / H, 4), round((x1 - x0 - 2 * m) / W, 4), round((y1 - y0 - 2 * m) / H, 4)]
    bh = min(H, fh * 3.2)
    bw = min(W, bh * 16 / 9)
    x0 = float(np.clip(cx - bw / 2, 0, W - bw))
    y0 = float(np.clip(cy - bh * 0.45, 0, H - bh))
    return [round(x0 / W, 4), round(y0 / H, 4), round(bw / W, 4), round(bh / H, 4)]


def achar(clipe, dur, todas=False):
    """Caixa da câmera em fração do quadro [x, y, w, h], ou None. Com todas=True, lista de até 2 câmeras."""
    import cv2
    modelo = (MODELOS / "yunet.onnx").read_bytes()
    det = cv2.FaceDetectorYN.create("onnx", np.frombuffer(modelo, np.uint8), np.zeros(0, np.uint8),
                                    (W, H), 0.75, 0.3, 50)
    quadros = _quadros(clipe, dur)
    if len(quadros) < 4:
        return [] if todas else None
    por_quadro = []
    for q in quadros:
        _, fs = det.detect(q)
        lista = []
        for f in ([] if fs is None else fs):
            x, y, w, h = [float(v) for v in f[:4]]
            if 0.03 * H <= h <= 0.30 * H:       # rosto de câmera de canto, não tela cheia
                lista.append((x + w / 2, y + h / 2, h))
        por_quadro.append(lista)
    # grupos: rosto que aparece no mesmo lugar (até 4% da largura) em 60% dos quadros ou mais
    grupos = []
    for lista in por_quadro:
        for r in lista:
            for g in grupos:
                if np.hypot(r[0] - g["c"][0], r[1] - g["c"][1]) < 0.04 * W:
                    g["pts"].append(r)
                    break
            else:
                grupos.append({"c": r, "pts": [r]})
    cams = []
    for g in sorted(grupos, key=lambda g: -len(g["pts"])):
        if len(g["pts"]) < 0.6 * len(quadros):
            break
        cx, cy, fh = np.median(np.array(g["pts"]), axis=0)
        # a câmera fica no canto ou na borda; rosto parado no meio da tela é personagem
        if 0.3 * W < cx < 0.7 * W and 0.25 * H < cy < 0.75 * H:
            continue
        # gente de verdade mexe: retrato desenhado no HUD do jogo fica idêntico de um quadro pro outro
        r = int(max(8, fh * 0.6))
        y0r, y1r = int(max(0, cy - r)), int(min(H, cy + r))
        x0r, x1r = int(max(0, cx - r)), int(min(W, cx + r))
        rec = [q[y0r:y1r, x0r:x1r].astype(np.float32) for q in quadros]
        mexe = np.mean([np.abs(p - q).mean() for p, q in zip(rec, rec[1:])])
        if mexe < 2.5:
            continue
        cams.append((len(g["pts"]), fh, _caixa(cx, cy, fh, quadros)))
    cams.sort(key=lambda c: (-c[0], -c[1]))
    if todas:
        return [c[2] for c in cams[:2]]
    return cams[0][2] if cams else None


def confere(clipe, dur, caixa):
    """A caixa marcada pela pessoa tem rosto em pelo menos 40% dos quadros?"""
    import cv2
    x, y, w, h = caixa
    modelo = (MODELOS / "yunet.onnx").read_bytes()
    quadros = _quadros(clipe, dur, 8)
    if not quadros:
        return False
    x0, y0 = int(x * W), int(y * H)
    x1, y1 = int(min(W, (x + w) * W)), int(min(H, (y + h) * H))
    if x1 - x0 < 16 or y1 - y0 < 16:
        return False
    # o recorte da câmera ampliado: rosto de câmera pequena some na imagem inteira
    esc = max(1.0, 320 / (x1 - x0))
    tam = (int((x1 - x0) * esc), int((y1 - y0) * esc))
    det = cv2.FaceDetectorYN.create("onnx", np.frombuffer(modelo, np.uint8), np.zeros(0, np.uint8), tam, 0.6, 0.3, 10)
    achou = 0
    for q in quadros:
        rec = cv2.resize(q[y0:y1, x0:x1], tam, interpolation=cv2.INTER_CUBIC)
        _, fs = det.detect(rec)
        achou += fs is not None and len(fs) > 0
    return achou >= 0.4 * len(quadros)
