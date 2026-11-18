"""Monta o pacote de edição do Incipit Play (o que o Play baixa na primeira vez que alguém manda um clipe pra edição).

  python edicao/pacote/montar_pacote.py <pasta-de-trabalho>

Sai <pasta>/IncipitPlay-Edicao-<versão>.zip e o SHA-256 dele, que vai escrito no Play (incipitedicao.cpp).
Dentro do zip:
  python/          Python 3.12 embutido oficial (python.org, assinado pela PSF)
  site-packages/   faster-whisper e o que ele usa, numpy, OpenCV (sem PyAV nem huggingface_hub)
  bin/ffmpeg.exe   build "essentials" do gyan.dev (GPL v3; o Play já é AGPL v3)
  clipador/ fontes/ modelos/   o motor (este repositório), as fontes OFL e o detector de rosto
  LICENCAS/        licença de cada parte
Tudo com versão e hash fixos: o mesmo comando monta o mesmo pacote.
"""
import hashlib
import os
import shutil
import subprocess
import sys
import urllib.request
import zipfile
from pathlib import Path

VERSAO = "1.0.4"
PY = ("https://www.python.org/ftp/python/3.12.10/python-3.12.10-embed-amd64.zip", "4acbed6dd1c744b0376e3b1cf57ce906f9dc9e95e68824584c8099a63025a3c3")
FFMPEG = ("https://www.gyan.dev/ffmpeg/builds/packages/ffmpeg-9.0.2-essentials_build.zip", "60f467265b1e312373dbcd92200c2618a74850f98d3d078e94296bb3fa2047ba")
PACOTES = ["faster-whisper==1.2.1", "ctranslate2==4.8.2", "onnxruntime==1.30.0", "tokenizers==0.23.2",
           "opencv-python-headless==5.0.0.93", "numpy==2.5.3", "tqdm==4.70.1", "colorama", "pyyaml",
           "flatbuffers", "packaging", "protobuf"]
FORA = ["av", "huggingface_hub", "requests", "urllib3", "certifi", "idna", "charset_normalizer", "fsspec",
        "filelock", "hf_xet", "typing_extensions", "pip", "setuptools", "sympy", "mpmath"]
EDICAO = Path(__file__).resolve().parent.parent


def sha(p):
    h = hashlib.sha256()
    with open(p, "rb") as f:
        for b in iter(lambda: f.read(1 << 20), b""):
            h.update(b)
    return h.hexdigest()


def baixar(url, destino, esperado):
    if not destino.exists():
        print("baixando", url)
        with urllib.request.urlopen(urllib.request.Request(url, headers={"User-Agent": "IncipitPlay-build"})) as r, open(destino, "wb") as f:
            shutil.copyfileobj(r, f)
    h = sha(destino)
    print(destino.name, h)
    if h != esperado:
        destino.unlink()
        raise SystemExit(f"{destino.name}: SHA-256 diferente do fixado ({h}); nada foi montado")
    return destino


def main():
    trab = Path(sys.argv[1]).resolve()
    trab.mkdir(parents=True, exist_ok=True)
    raiz = trab / f"IncipitPlay-Edicao-{VERSAO}"
    if raiz.exists():
        shutil.rmtree(raiz)
    raiz.mkdir()
    # Python embutido
    pz = baixar(PY[0], trab / "python-embed.zip", PY[1])
    with zipfile.ZipFile(pz) as z:
        z.extractall(raiz / "python")
    (raiz / "python" / "python312._pth").write_text("python312.zip\n.\n..\n..\\site-packages\n", encoding="ascii")
    # bibliotecas (só wheel pronta, pra Windows x64 e Python 3.12)
    env = dict(os.environ, PIP_CACHE_DIR=str(trab / "pip-cache"))
    subprocess.check_call([sys.executable, "-m", "pip", "install", "--quiet", "--no-compile", "--only-binary=:all:",
                           "--platform", "win_amd64", "--python-version", "3.12", "--implementation", "cp",
                           "--target", str(raiz / "site-packages"), *PACOTES], env=env)
    for nome in os.listdir(raiz / "site-packages"):
        base = nome.split("-")[0].lower().removesuffix(".libs")   # "av.libs" (as DLL do PyAV) sai junto
        if base in FORA or base.replace("_", "-") in FORA:
            p = raiz / "site-packages" / nome
            shutil.rmtree(p) if p.is_dir() else p.unlink()
    shutil.rmtree(raiz / "site-packages" / "bin", ignore_errors=True)
    # ffmpeg
    fz = baixar(FFMPEG[0], trab / "ffmpeg-essentials.zip", FFMPEG[1])
    (raiz / "bin").mkdir()
    with zipfile.ZipFile(fz) as z:
        for n in z.namelist():
            if n.endswith("/bin/ffmpeg.exe"):
                (raiz / "bin" / "ffmpeg.exe").write_bytes(z.read(n))
            if n.endswith("/LICENSE"):
                (raiz / "LICENCAS").mkdir(exist_ok=True)
                (raiz / "LICENCAS" / "ffmpeg-GPLv3.txt").write_bytes(z.read(n))
    # o motor, as fontes e o detector de rosto
    shutil.copytree(EDICAO / "clipador", raiz / "clipador", ignore=shutil.ignore_patterns("__pycache__"))
    shutil.copytree(EDICAO / "fontes", raiz / "fontes")
    shutil.copytree(EDICAO / "modelos", raiz / "modelos")
    (raiz / "LICENCAS").mkdir(exist_ok=True)
    shutil.copy(EDICAO / "LICENCAS-DO-PACOTE.md", raiz / "LICENCAS" / "LEIA.md")
    for f in (EDICAO / "fontes").glob("OFL-*.txt"):
        shutil.copy(f, raiz / "LICENCAS" / f.name)
    (raiz / "VERSAO.txt").write_text(VERSAO, encoding="ascii")
    # zip
    saida = trab / f"IncipitPlay-Edicao-{VERSAO}.zip"
    if saida.exists():
        saida.unlink()
    with zipfile.ZipFile(saida, "w", zipfile.ZIP_DEFLATED, compresslevel=6) as z:
        for p in sorted(raiz.rglob("*")):
            if p.is_file():
                z.write(p, p.relative_to(raiz).as_posix())
    print("PACOTE", saida, saida.stat().st_size, sha(saida))


if __name__ == "__main__":
    main()
