"""Folha de quadros de um vídeo (conferência): python testes/folha.py video.mp4 saida.jpg [n] [--origem]"""
import subprocess, sys
import numpy as np, cv2
from pathlib import Path

def quadros(video, n, w, h):
    out = []
    dur = float(subprocess.run(["ffprobe", "-v", "error", "-show_entries", "format=duration", "-of", "csv=p=0", video],
                               capture_output=True, text=True).stdout.strip())
    for k in range(n):
        t = dur * (k + 0.5) / n
        b = subprocess.run(["ffmpeg", "-v", "error", "-ss", f"{t:.2f}", "-i", video, "-frames:v", "1", "-vf", f"scale={w}:{h}",
                            "-f", "rawvideo", "-pix_fmt", "bgr24", "-"], capture_output=True).stdout
        img = np.frombuffer(b[:w * h * 3], np.uint8).reshape(h, w, 3).copy() if len(b) >= w * h * 3 else np.zeros((h, w, 3), np.uint8)
        cv2.putText(img, f"{t:.1f}s", (8, 30), cv2.FONT_HERSHEY_SIMPLEX, 0.9, (0, 255, 255), 2)
        out.append(img)
    return out

if __name__ == "__main__":
    v, saida = sys.argv[1], sys.argv[2]
    n = int(sys.argv[3]) if len(sys.argv) > 3 and sys.argv[3].isdigit() else 8
    origem = "--origem" in sys.argv
    w, h = (480, 270) if origem else (270, 480)
    q = quadros(v, n, w, h)
    cols = 4 if origem else 8
    linhas = [np.hstack(q[i:i + cols] + [np.zeros_like(q[0])] * (cols - len(q[i:i + cols]))) for i in range(0, len(q), cols)]
    ok, jpg = cv2.imencode(".jpg", np.vstack(linhas), [cv2.IMWRITE_JPEG_QUALITY, 88])
    Path(saida).write_bytes(jpg.tobytes())
