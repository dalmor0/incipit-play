"""Peças comuns do clipador: aviso de andamento, ffmpeg, prioridade e caminhos.

O Incipit Play lê a saída deste programa linha por linha. Cada linha é um JSON:
  {"tipo": "etapa", "etapa": "transcrever", "texto": "Lendo a fala", "pct": 42}
  {"tipo": "pronto", "arquivo": "...mp4", ...}
  {"tipo": "erro", "motivo": "texto curto pra pessoa", "detalhe": "..."}
Nada é mandado pra fora do PC.
"""
import json
import os
import re
import subprocess
import sys
from pathlib import Path

RAIZ = Path(__file__).resolve().parent.parent          # pasta edicao/ (no pacote, a raiz do pacote)
FONTES = RAIZ / "fontes"
MODELOS = RAIZ / "modelos"

# formatos de entrada aceitos e protocolos: só arquivo local, nada de rede, concat ou playlist
FORMATOS = "mov,mp4,m4a,3gp,3g2,mj2,matroska,webm,mpegts,flv,avi"
PROTOCOLOS = "file,pipe"
DURACAO_MAX = 60 * 60       # um clipe de mais de 1 h não é clipe
TAMANHO_MAX = 8 * 1024 ** 3  # 8 GB


class Falha(Exception):
    """Erro com motivo que a pessoa entende."""

    def __init__(self, motivo, detalhe=""):
        super().__init__(motivo)
        self.motivo = motivo
        self.detalhe = detalhe


try:
    sys.stdout.reconfigure(encoding="utf-8", errors="replace")   # o Play lê UTF-8, nunca a página de código do Windows
except (AttributeError, ValueError):
    pass
_saida = sys.stdout


def avisar(tipo, **campos):
    campos["tipo"] = tipo
    try:
        _saida.write(json.dumps(campos, ensure_ascii=False) + "\n")
        _saida.flush()
    except (OSError, ValueError):
        pass


class Andamento:
    """Etapas com peso; manda o pct geral de 0 a 100."""

    def __init__(self, etapas):
        self.etapas = etapas            # [(chave, texto, peso)]
        self.total = sum(p for _, _, p in etapas)
        self.feito = 0.0
        self.atual = None

    def etapa(self, chave, frac=0.0, texto=None):
        antes = 0.0
        for k, t, p in self.etapas:
            if k == chave:
                pct = 100.0 * (antes + p * max(0.0, min(1.0, frac))) / self.total
                avisar("etapa", etapa=k, texto=texto or t, pct=round(pct, 1))
                return
            antes += p


def ffmpeg_exe():
    """ffmpeg do pacote; na falta (desenvolvimento), o do PATH."""
    for nome in ("ffmpeg.exe", "ffmpeg"):
        p = RAIZ / "bin" / nome
        if p.exists():
            return str(p)
    from shutil import which
    w = which("ffmpeg")
    if not w:
        raise Falha("O pacote de edição está incompleto (falta o ffmpeg).", "ffmpeg não achado")
    return w


SEM_JANELA = 0x08000000 if os.name == "nt" else 0


def entrada(arquivo, inicio=None, duracao=None):
    """Argumentos de entrada do ffmpeg com as travas de formato e protocolo."""
    a = ["-protocol_whitelist", PROTOCOLOS, "-format_whitelist", FORMATOS]
    if inicio is not None and inicio > 0:
        a += ["-ss", f"{inicio:.3f}"]
    if duracao is not None:
        a += ["-t", f"{duracao:.3f}"]
    return a + ["-i", str(arquivo)]


def rodar(args, cwd=None, entrada_bytes=None):
    p = subprocess.run([ffmpeg_exe(), "-hide_banner", "-nostdin", *args], cwd=cwd,
                       input=entrada_bytes, capture_output=True, creationflags=SEM_JANELA)
    return p.returncode, p.stdout, p.stderr.decode("utf-8", "replace")


def abrir(args, cwd=None, stdin=None, stdout=subprocess.PIPE):
    return subprocess.Popen([ffmpeg_exe(), "-hide_banner", "-nostdin", "-loglevel", "error", *args], cwd=cwd,
                            stdin=stdin, stdout=stdout, stderr=subprocess.PIPE, creationflags=SEM_JANELA)


def prioridade_baixa():
    """Edição nunca disputa a máquina com o jogo: o processo (e os filhos, que herdam) fica abaixo do normal."""
    if os.name != "nt":
        try:
            os.nice(10)
        except OSError:
            pass
        return
    import ctypes
    BELOW_NORMAL = 0x00004000
    k = ctypes.windll.kernel32
    k.SetPriorityClass(k.GetCurrentProcess(), BELOW_NORMAL)


def conferir_clipe(caminho):
    p = Path(caminho)
    if not p.is_file():
        raise Falha("Não achei o clipe. Ele foi apagado ou movido?", str(p))
    if p.suffix.lower() not in (".mp4", ".mkv", ".mov", ".ts", ".webm", ".flv"):
        raise Falha("Esse arquivo não é um vídeo que o Play edita.", p.suffix)
    if p.stat().st_size > TAMANHO_MAX:
        raise Falha("O clipe é grande demais pra editar (mais de 8 GB).")
    return p


_RE_DUR = re.compile(r"Duration: (\d+):(\d+):(\d+(?:\.\d+)?)")
_RE_VID = re.compile(r"Stream #\S+.*?Video: .*?(\d{2,5})x(\d{2,5})[ ,\[].*?(?:(\d+(?:\.\d+)?) fps|(\d+(?:\.\d+)?) tbr)")
_RE_AUD = re.compile(r"Stream #\S+.*?Audio: ")


def medir(caminho):
    """Duração, tamanho e fps lendo o cabeçalho (sem ffprobe)."""
    _, _, err = rodar(entrada(caminho))
    d = _RE_DUR.search(err)
    v = _RE_VID.search(err)
    if not d or not v:
        raise Falha("Não consegui ler esse vídeo. Pode estar corrompido.", err[-400:])
    dur = int(d.group(1)) * 3600 + int(d.group(2)) * 60 + float(d.group(3))
    if dur <= 0.5:
        raise Falha("O clipe é curto demais pra editar.")
    if dur > DURACAO_MAX:
        raise Falha("O clipe passa de 1 hora. Corte um trecho menor antes.")
    fps = float(v.group(3) or v.group(4) or 30)
    return {"duracao": dur, "w": int(v.group(1)), "h": int(v.group(2)), "fps": fps,
            "audio": bool(_RE_AUD.search(err)), "faixas": max(1, min(8, len(_RE_AUD.findall(err))))}


def audio_de(entrada_idx, faixas):
    """Trecho de filtro que junta todas as faixas de áudio (clipe do Discord e do OBS vem com a voz separada).
    Termina pronto pra emendar o próximo filtro."""
    if faixas <= 1:
        return f"[{entrada_idx}:a:0]"
    ins = "".join(f"[{entrada_idx}:a:{k}]" for k in range(faixas))
    return f"{ins}amix=inputs={faixas}:normalize=0:duration=longest,"


def pasta_trabalho():
    """Pasta temporária sem acento nem espaço no caminho relativo usado pelo ffmpeg (o ffmpeg roda com cwd nela)."""
    import tempfile
    base = Path(os.environ.get("INCIPIT_EDICAO_TMP") or tempfile.gettempdir()) / "incipit-edicao"
    base.mkdir(parents=True, exist_ok=True)
    import shutil
    import time
    for velha in base.glob("job-*"):
        try:
            if time.time() - velha.stat().st_mtime > 2 * 3600:
                shutil.rmtree(velha, ignore_errors=True)
        except OSError:
            pass
    d = Path(tempfile.mkdtemp(prefix="job-", dir=base))
    return d
