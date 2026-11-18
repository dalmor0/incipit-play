"""Fala do clipe em texto, palavra por palavra, no PC da pessoa (faster-whisper, MIT).

O modelo baixa na primeira vez, de um endereço fixo (commit fixo no Hugging Face), e cada arquivo
só vale se o SHA-256 bater com o que está escrito aqui. Placa NVIDIA com as bibliotecas do CUDA
presentes: roda na placa; senão, no processador.
"""
import hashlib
import os
import sys
import types
import urllib.request
from pathlib import Path

from .base import Falha

MODELOS = {
    "medium": {
        "repo": "Systran/faster-whisper-medium",
        "rev": "08e178d48790749d25932bbc082711ddcfdfbc4f",
        "arquivos": {
            "config.json": (2257, "3622a2ddc41ec0e0fd4e68c13c6830f03b90c38d89aaad184de02c8c642cf807"),
            "tokenizer.json": (2203239, "fb7b63191e9bb045082c79fd742a3106a12c99513ab30df4a0d47fa6cb6fd0ab"),
            "vocabulary.txt": (459861, "34ce3fe1c5041027b3f8d42912270993f986dbc4bb34cf27f951e34a1e453913"),
            "model.bin": (1527906378, "9b45e1009dcc4ab601eff815b61d80e60ce3fd8c74c1a14f4a282258286b51ae"),
        },
    },
    "small": {
        "repo": "Systran/faster-whisper-small",
        "rev": "536b0662742c02347bc0e980a01041f333bce120",
        "arquivos": {
            "config.json": (2370, "b55496ac7940a7ae47d2c01eab40edfd8701feec1229d9cce3b40014383fb828"),
            "tokenizer.json": (2203239, "fb7b63191e9bb045082c79fd742a3106a12c99513ab30df4a0d47fa6cb6fd0ab"),
            "vocabulary.txt": (459861, "34ce3fe1c5041027b3f8d42912270993f986dbc4bb34cf27f951e34a1e453913"),
            "model.bin": (483546902, "3e305921506d8872816023e4c273e75d2419fb89b24da97b4fe7bce14170d671"),
        },
    },
    "base": {
        "repo": "Systran/faster-whisper-base",
        "rev": "ebe41f70d5b6dfa9166e2c581c45c9c0cfc57b66",
        "arquivos": {
            "config.json": (2309, "56a6d8110d311f19c8f0471e562832c7527f146b567275bfca59fcf7c184da9a"),
            "tokenizer.json": (2203239, "fb7b63191e9bb045082c79fd742a3106a12c99513ab30df4a0d47fa6cb6fd0ab"),
            "vocabulary.txt": (459861, "34ce3fe1c5041027b3f8d42912270993f986dbc4bb34cf27f951e34a1e453913"),
            "model.bin": (145217532, "d01c3014881c9c6f3133c182f3d2887eb6ca1c789a7538c5c007196857a0a6a9"),
        },
    },
}
PADRAO = "medium"   # 17/11: nos clipes de teste escreveu bem melhor que o small no mesmo tempo de CPU

# o Whisper erra menos fala de jogador com o vocabulário na mão
PROMPT = {"pt": "Gameplay comentada em português do Brasil, com gíria de jogo: mano, caralho, porra, clipa, kill, mata, corre, pegou.",
          "en": "Gameplay commentary with gamer slang: bro, clip it, kill, run, let's go."}


def pasta_modelos():
    base = os.environ.get("INCIPIT_EDICAO_MODELOS")
    if base:
        return Path(base)
    la = os.environ.get("LOCALAPPDATA") or str(Path.home())
    return Path(la) / "Incipit" / "Incipit Play" / "modelos"


def _sha(p):
    h = hashlib.sha256()
    with open(p, "rb") as f:
        for b in iter(lambda: f.read(1 << 20), b""):
            h.update(b)
    return h.hexdigest()


def _confere(p, tam, sha):
    return p.is_file() and p.stat().st_size == tam and _sha(p) == sha


def garantir_modelo(nome, progresso, cancelado):
    """Devolve a pasta do modelo, baixando o que faltar. progresso(frac, texto)."""
    info = MODELOS[nome]
    pasta = pasta_modelos() / f"whisper-{nome}"
    pasta.mkdir(parents=True, exist_ok=True)
    marca = pasta / "conferido.txt"
    esperado = "\n".join(f"{a} {s}" for a, (_, s) in sorted(info["arquivos"].items()))
    if marca.is_file() and marca.read_text(encoding="utf-8") == esperado and all(
            (pasta / a).is_file() and (pasta / a).stat().st_size == t for a, (t, _) in info["arquivos"].items()):
        return pasta
    total = sum(t for t, _ in info["arquivos"].values())
    feito = 0
    for arq, (tam, sha) in info["arquivos"].items():
        destino = pasta / arq
        if _confere(destino, tam, sha):
            feito += tam
            continue
        url = f"https://huggingface.co/{info['repo']}/resolve/{info['rev']}/{arq}"
        parcial = destino.with_suffix(destino.suffix + ".baixando")
        h = hashlib.sha256()
        lido = 0
        try:
            req = urllib.request.Request(url, headers={"User-Agent": "IncipitPlay"})
            with urllib.request.urlopen(req, timeout=30) as r, open(parcial, "wb") as f:
                if not r.geturl().startswith("https://"):
                    raise Falha("O download do modelo foi desviado. Tente de novo mais tarde.", r.geturl())
                while True:
                    if cancelado():
                        raise Falha("Cancelado.")
                    b = r.read(1 << 20)
                    if not b:
                        break
                    lido += len(b)
                    if lido > tam:
                        raise Falha("O arquivo do modelo veio maior que o esperado. Nada foi usado.", arq)
                    h.update(b)
                    f.write(b)
                    progresso((feito + lido) / total,
                              f"Baixando o leitor de fala ({(feito + lido) / 1e6:.0f} de {total / 1e6:.0f} MB, só na primeira vez)")
        except Falha:
            parcial.unlink(missing_ok=True)
            raise
        except OSError as e:
            parcial.unlink(missing_ok=True)
            raise Falha("Não deu pra baixar o leitor de fala. Confira a internet e tente de novo.", repr(e))
        if lido != tam or h.hexdigest() != sha:
            parcial.unlink(missing_ok=True)
            raise Falha("O arquivo baixado não bate com o original e foi descartado. Tente de novo.", arq)
        os.replace(parcial, destino)
        feito += tam
    marca.write_text(esperado, encoding="utf-8")
    return pasta


def _sem_dependencias_extras():
    """O faster-whisper importa PyAV e huggingface_hub no topo, mas o clipador não usa nenhum dos dois
    (o áudio já chega decodificado e o modelo vem de pasta local). Módulos vazios evitam levar os dois."""
    for nome in ("av", "huggingface_hub"):
        if nome not in sys.modules:
            try:
                __import__(nome)
            except ImportError:
                m = types.ModuleType(nome)
                if nome == "av":
                    m.audio = types.SimpleNamespace(resampler=None)
                sys.modules[nome] = m


def _cuda_ok():
    try:
        import ctranslate2
        return ctranslate2.get_cuda_device_count() > 0
    except Exception:
        return False


def transcrever(audio, pasta_modelo, idioma, progresso, cancelado):
    """Lista de palavras {"p", "i", "f", "prob"} com tempos em segundos."""
    _sem_dependencias_extras()
    from faster_whisper import WhisperModel

    modelo = None
    onde = "cpu"
    if _cuda_ok():
        try:
            modelo = WhisperModel(str(pasta_modelo), device="cuda", compute_type="float16")
            onde = "placa de vídeo"
        except Exception:
            modelo = None
    if modelo is None:
        threads = max(2, min(8, (os.cpu_count() or 4) - 2))
        modelo = WhisperModel(str(pasta_modelo), device="cpu", compute_type="int8", cpu_threads=threads)
    dur = max(0.1, len(audio) / 16000)

    def rodar(modelo):
        segs, info = modelo.transcribe(
            audio, language=None if idioma == "auto" else idioma, word_timestamps=True, vad_filter=True,
            vad_parameters={"min_silence_duration_ms": 400}, beam_size=5, condition_on_previous_text=False,
            initial_prompt=PROMPT.get(idioma), no_speech_threshold=0.5, compression_ratio_threshold=2.2)
        palavras = []
        for s in segs:
            if cancelado():
                raise Falha("Cancelado.")
            for w in s.words or []:
                t = w.word.strip()
                if t:
                    palavras.append({"p": t, "i": round(w.start, 3), "f": round(w.end, 3), "prob": round(w.probability, 3)})
            progresso(min(1.0, s.end / dur), "Lendo a fala")
        return limpar(palavras), info.language

    try:
        return (*rodar(modelo), onde)
    except Falha:
        raise
    except Exception:
        if onde == "cpu":
            raise
        # placa sem a biblioteca certa no meio do caminho: volta pro processador
        modelo = WhisperModel(str(pasta_modelo), device="cpu", compute_type="int8")
        onde = "cpu"
        return (*rodar(modelo), onde)


def limpar(palavras):
    """Tira o que o Whisper inventa: a mesma palavra mais de 3 vezes seguidas, o mesmo trecho de 2 a 6 palavras
    repetido mais de 2 vezes, e palavra que ele mesmo dá como quase certamente errada."""
    import re
    norm = [re.sub(r"[^\w]", "", w["p"].lower()) for w in palavras]
    fora = set()
    i = 0
    while i < len(palavras):
        j = i
        while j + 1 < len(palavras) and norm[j + 1] == norm[i] and norm[i]:
            j += 1
        if j - i >= 3:
            fora.update(range(i + 3, j + 1))
        i = j + 1
    for n in range(2, 7):
        i = 0
        while i + n <= len(palavras):
            reps = 1
            while i + (reps + 1) * n <= len(palavras) and norm[i + reps * n:i + (reps + 1) * n] == norm[i:i + n]:
                reps += 1
            if reps > 2:
                fora.update(range(i + 2 * n, i + reps * n))
                i += reps * n
            else:
                i += 1
    return [w for k, w in enumerate(palavras) if k not in fora and w["prob"] >= 0.08]
