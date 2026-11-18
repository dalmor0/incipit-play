"""Fala do clipe em texto, palavra por palavra, no PC da pessoa (faster-whisper, MIT).

O modelo baixa na primeira vez, de um endereço fixo (commit fixo no Hugging Face), e cada arquivo
só vale se o SHA-256 bater com o que está escrito aqui. Placa NVIDIA com as bibliotecas do CUDA
presentes: roda na placa; senão, no processador.
"""
import hashlib
import re
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
PROMPT = {"pt": "Gameplay comentada em português do Brasil, com gíria de jogo: mano, clipa, kill, mata, corre, pegou, loop.",
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


def modelo_presente(nome):
    """O leitor de fala já está baixado e conferido neste PC?"""
    info = MODELOS[nome]
    pasta = pasta_modelos() / f"whisper-{nome}"
    esperado = "\n".join(f"{a} {s}" for a, (_, s) in sorted(info["arquivos"].items()))
    marca = pasta / "conferido.txt"
    return marca.is_file() and marca.read_text(encoding="utf-8") == esperado and all(
        (pasta / a).is_file() and (pasta / a).stat().st_size == t for a, (t, _) in info["arquivos"].items())


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


VOCAB_JOGO = {
    "dead by daylight": "Dead by Daylight: Wesker, pallet, gen, gerador, loop, gancho, sobrevivente, assassino.",
    "gta": "GTA: polícia, viatura, fuga, assalto, carro, estrela, procurado.",
    "fortnite": "Fortnite: build, edita, tempestade, zona, loot, vitória real.",
    "valorant": "Valorant: clutch, spike, ult, ace, plant, defuse.",
    "call of duty": "Call of Duty: kill, killstreak, sniper, quickscope, loadout.",
    "minecraft": "Minecraft: creeper, bloco, diamante, nether, mob.",
}


def prompt_do_jogo(idioma, nome_jogo, palavras_nome):
    """Prompt do Whisper com a gíria, o vocabulário do jogo (achado pelo nome do clipe) e as palavras do nome."""
    p = PROMPT.get(idioma, "")
    n = (nome_jogo or "").lower().replace("_", " ")
    n = re.sub(r"(?<=[a-z])(?=[A-Z])", " ", nome_jogo or "").lower().replace("_", " ") if nome_jogo else ""
    for chave, voc in VOCAB_JOGO.items():
        if chave in n or chave.replace(" ", "") in n.replace(" ", "") or (chave == "dead by daylight" and "dbd" in n.split()):
            p = (p + " " + voc).strip()
            break
    if palavras_nome:
        p = (p + " " + ", ".join(palavras_nome) + ".").strip()
    return p or None


def transcrever(audio, pasta_modelo, idioma, progresso, cancelado, prompt=None):
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

    buracos.__defaults__[0][0] = audio
    buracos.__defaults__[1][0] = prompt
    _ESTADO.update(audio=audio, prompt=prompt or PROMPT.get(idioma), idioma=idioma)

    def rodar(modelo):
        segs, info = modelo.transcribe(
            audio, language=None if idioma == "auto" else idioma, word_timestamps=True, vad_filter=True,
            vad_parameters={"min_silence_duration_ms": 400}, beam_size=5, condition_on_previous_text=False,
            initial_prompt=prompt or PROMPT.get(idioma), no_speech_threshold=0.5, compression_ratio_threshold=2.2)
        palavras = []
        for s in segs:
            if cancelado():
                raise Falha("Cancelado.")
            for w in s.words or []:
                t = w.word.strip()
                if t:
                    palavras.append({"p": t, "i": round(w.start, 3), "f": round(w.end, 3), "prob": round(w.probability, 3)})
            progresso(min(1.0, s.end / dur), "Lendo a fala")
        palavras = buracos(modelo, palavras, idioma, cancelado)
        _ESTADO["modelo"] = modelo
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
    out = [w for k, w in enumerate(palavras) if k not in fora and w["prob"] >= 0.08]
    # mesma frase de 3+ palavras duas vezes em sequência, a segunda começando em até 0,5 s do fim da primeira e com
    # tempos sobrepostos ou quase: é emenda de passadas, não fala repetida
    norm2 = [re.sub(r"[^\w]", "", w["p"].lower()) for w in out]
    tirar = set()
    for n in range(6, 2, -1):
        for i in range(len(out) - 2 * n + 1):
            if any(k in tirar for k in range(i, i + 2 * n)):
                continue
            if norm2[i:i + n] == norm2[i + n:i + 2 * n] and out[i + n]["i"] - out[i + n - 1]["f"] < 0.15 and out[i + n]["i"] < out[i]["i"] + 0.3 + (out[i + n - 1]["f"] - out[i]["i"]) * 0.5:
                tirar.update(range(i + n, i + 2 * n))
    out = [w for k, w in enumerate(out) if k not in tirar]
    # a mesma palavra duas vezes começando a menos de 0,3 s uma da outra é a mesma fala lida duas vezes
    limpo = []
    for w in out:
        if limpo and _norm(w["p"]) == _norm(limpo[-1]["p"]) and (w["i"] - limpo[-1]["i"] < 0.3 or w["i"] < limpo[-1]["f"] + 0.12):
            continue
        limpo.append(w)
    return limpo


_ESTADO = {"modelo": None, "audio": None, "prompt": None, "idioma": "pt"}
GIRIA = re.compile(r"^(mano+|caralh\w*|porra|puta\w*|safad\w*|pariu|kk+|ha(ha)+|nossa|caraca|eita|vei|velho|brabo|pegou|clipa\w*|bora|vamo|toma|vsf|pqp|krl|meu deus|que isso|cara)$")


def _transcrever_pedaco(modelo, audio, i, f, idioma, prompt):
    sr = 16000
    a0, a1 = max(0, int((i - 0.2) * sr)), min(len(audio), int((f + 0.2) * sr))
    if a1 - a0 < sr * 0.3:
        return []
    segs, _ = modelo.transcribe(audio[a0:a1], language=None if idioma == "auto" else idioma, word_timestamps=True,
                                vad_filter=False, beam_size=5, condition_on_previous_text=False, initial_prompt=prompt)
    base = a0 / sr
    out = []
    for sg in segs:
        for w in sg.words or []:
            t = w.word.strip()
            if t and w.probability >= 0.3:
                out.append({"p": t, "i": round(base + w.start, 3), "f": round(base + w.end, 3), "prob": round(w.probability, 3)})
    return [w for w in out if w["f"] > i - 0.05 and w["i"] < f + 0.05]


def _norm(p):
    return re.sub(r"[^\w]", "", p.lower())


def _trocar(saida, i, f, novas):
    """Troca as palavras de [i, f] pelas novas, sem deixar palavra igual piscando na emenda (até 1 s)."""
    fora = [w for w in saida if not (w["f"] > i and w["i"] < f)]
    juntas = []
    for w in fora:
        if any(_norm(w["p"]) == _norm(n["p"]) and abs(w["i"] - n["i"]) < 1.0 for n in novas):
            continue
        juntas.append(w)
    return sorted(juntas + novas, key=lambda w: w["i"])


def _regioes_de_voz(audio, max_s=8.0):
    from faster_whisper.vad import VadOptions, get_speech_timestamps
    sr = 16000
    out = []
    for r in get_speech_timestamps(audio, VadOptions(min_silence_duration_ms=300)):
        i, f = r["start"] / sr, r["end"] / sr
        while f - i > max_s:
            out.append((i, i + max_s))
            i += max_s
        if f - i >= 0.6:
            out.append((i, f))
    return out


def buracos(modelo, palavras, idioma, cancelado, audio_ref=[None], prompt_ref=[None]):
    """Segunda passada: dentro de cada pedaço com voz, intervalo de mais de 0,8 s sem palavra é fala que o Whisper
    pulou (muito comum com outra voz por cima). Transcreve só o intervalo e encaixa."""
    audio = audio_ref[0]
    if audio is None:
        return palavras
    try:
        regioes = _regioes_de_voz(audio)
    except Exception:
        return palavras
    saida = list(palavras)
    usados = [0]
    for i, f in regioes:
        if cancelado():
            break
        dentro = sorted([w for w in saida if w["f"] > i and w["i"] < f], key=lambda w: w["i"])
        marcos = [i] + [x for w in dentro for x in (w["i"], w["f"])] + [f]
        vaos = [(marcos[k], marcos[k + 1]) for k in range(0, len(marcos) - 1, 2) if marcos[k + 1] - marcos[k] > 0.8]
        for vi, vf in vaos:
            usados[0] += 1
            if usados[0] > 40:      # clipe longo: no máximo 40 releituras (tempo de CPU)
                break
            novas = _transcrever_pedaco(modelo, audio, vi, vf, idioma, prompt_ref[0] or PROMPT.get(idioma))
            novas = [w for w in novas if w["i"] >= vi - 0.1 and w["f"] <= vf + 0.1]
            if novas:
                saida = _trocar(saida, vi, vf, novas)
    return saida


def refinar(palavras, ini, fim, cancelado=lambda: False):
    """No trecho escolhido (barato: até uns 40 s), cada pedaço de voz é lido de novo sozinho. Onde as duas leituras
    discordam, fica a que tem mais da fala de quem joga (gíria, palavrão, risada): a primeira passada às vezes
    escreve a voz de fundo (vídeo assistido, personagem do jogo) por cima da dele."""
    modelo, audio = _ESTADO["modelo"], _ESTADO["audio"]
    if modelo is None or audio is None:
        return palavras
    sr = 16000
    try:
        regioes = [(i, f) for i, f in _regioes_de_voz(audio[int(ini * sr):int(fim * sr)])]
    except Exception:
        return palavras
    saida = list(palavras)
    for i, f in regioes:
        if cancelado():
            break
        i, f = i + ini, f + ini
        velhas = [w for w in saida if w["f"] > i and w["i"] < f]
        novas = _transcrever_pedaco(modelo, audio, i, f, _ESTADO["idioma"], _ESTADO["prompt"])
        if not novas:
            continue
        pv = sum(1 for w in velhas if GIRIA.match(_norm(w["p"])))
        pn = sum(1 for w in novas if GIRIA.match(_norm(w["p"])))
        if pn > pv or (pn == pv and len(novas) > len(velhas) * 1.25):
            saida = _trocar(saida, i, f, novas)
    return limpar(saida)


VOCAB_JOGO = {
    "dead by daylight": "Dead by Daylight: Wesker, pallet, gen, gerador, loop, gancho, sobrevivente, assassino.",
    "gta": "GTA: polícia, viatura, fuga, assalto, carro, estrela, procurado.",
    "fortnite": "Fortnite: build, edita, tempestade, zona, loot, vitória real.",
    "valorant": "Valorant: clutch, spike, ult, ace, plant, defuse.",
    "call of duty": "Call of Duty: kill, killstreak, sniper, quickscope, loadout.",
    "minecraft": "Minecraft: creeper, bloco, diamante, nether, mob.",
}


def prompt_do_jogo(idioma, nome_jogo, palavras_nome):
    """Prompt do Whisper com a gíria, o vocabulário do jogo (achado pelo nome do clipe) e as palavras do nome."""
    p = PROMPT.get(idioma, "")
    n = (nome_jogo or "").lower().replace("_", " ")
    n = re.sub(r"(?<=[a-z])(?=[A-Z])", " ", nome_jogo or "").lower().replace("_", " ") if nome_jogo else ""
    for chave, voc in VOCAB_JOGO.items():
        if chave in n or chave.replace(" ", "") in n.replace(" ", "") or (chave == "dead by daylight" and "dbd" in n.split()):
            p = (p + " " + voc).strip()
            break
    if palavras_nome:
        p = (p + " " + ", ".join(palavras_nome) + ".").strip()
    return p or None


def transcrever(audio, pasta_modelo, idioma, progresso, cancelado, prompt=None):
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

    buracos.__defaults__[0][0] = audio
    buracos.__defaults__[1][0] = prompt
    _ESTADO.update(audio=audio, prompt=prompt or PROMPT.get(idioma), idioma=idioma)

    def rodar(modelo):
        segs, info = modelo.transcribe(
            audio, language=None if idioma == "auto" else idioma, word_timestamps=True, vad_filter=True,
            vad_parameters={"min_silence_duration_ms": 400}, beam_size=5, condition_on_previous_text=False,
            initial_prompt=prompt or PROMPT.get(idioma), no_speech_threshold=0.5, compression_ratio_threshold=2.2)
        palavras = []
        for s in segs:
            if cancelado():
                raise Falha("Cancelado.")
            for w in s.words or []:
                t = w.word.strip()
                if t:
                    palavras.append({"p": t, "i": round(w.start, 3), "f": round(w.end, 3), "prob": round(w.probability, 3)})
            progresso(min(1.0, s.end / dur), "Lendo a fala")
        palavras = buracos(modelo, palavras, idioma, cancelado)
        _ESTADO["modelo"] = modelo
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
    out = [w for k, w in enumerate(palavras) if k not in fora and w["prob"] >= 0.08]
    # mesma frase de 3+ palavras duas vezes em sequência, a segunda começando em até 0,5 s do fim da primeira e com
    # tempos sobrepostos ou quase: é emenda de passadas, não fala repetida
    norm2 = [re.sub(r"[^\w]", "", w["p"].lower()) for w in out]
    tirar = set()
    for n in range(6, 2, -1):
        for i in range(len(out) - 2 * n + 1):
            if any(k in tirar for k in range(i, i + 2 * n)):
                continue
            if norm2[i:i + n] == norm2[i + n:i + 2 * n] and out[i + n]["i"] - out[i + n - 1]["f"] < 0.15 and out[i + n]["i"] < out[i]["i"] + 0.3 + (out[i + n - 1]["f"] - out[i]["i"]) * 0.5:
                tirar.update(range(i + n, i + 2 * n))
    out = [w for k, w in enumerate(out) if k not in tirar]
    # a mesma palavra duas vezes começando a menos de 0,3 s uma da outra é a mesma fala lida duas vezes
    limpo = []
    for w in out:
        if limpo and _norm(w["p"]) == _norm(limpo[-1]["p"]) and (w["i"] - limpo[-1]["i"] < 0.3 or w["i"] < limpo[-1]["f"] + 0.12):
            continue
        limpo.append(w)
    return limpo


def buracos(modelo, palavras, idioma, cancelado, audio_ref=[None], prompt_ref=[None]):
    """Segunda passada: onde tem voz e poucas palavras (menos de 1,2 por segundo de voz, quando a fala normal dá
    2 a 3), transcreve o pedaço sozinho (até 8 s) e, se sair mais fala, ele SUBSTITUI as palavras daquele pedaço.
    É o caso da voz do jogador por cima de outra voz (vídeo assistido, jogo falando): a primeira passada perde."""
    audio = audio_ref[0]
    if audio is None:
        return palavras
    try:
        from faster_whisper.vad import VadOptions, get_speech_timestamps
    except Exception:
        return palavras
    sr = 16000
    regioes = []
    for r in get_speech_timestamps(audio, VadOptions(min_silence_duration_ms=300)):
        i, f = r["start"] / sr, r["end"] / sr
        while f - i > 8.0:              # pedaço grande vira pedaços de 8 s
            regioes.append((i, i + 8.0))
            i += 8.0
        if f - i >= 0.8:
            regioes.append((i, f))
    saida = list(palavras)
    for i, f in regioes:
        if cancelado():
            break
        dentro = [w for w in saida if w["f"] > i and w["i"] < f]
        if len(dentro) / (f - i) >= 1.2:
            continue
        a0, a1 = max(0, int((i - 0.2) * sr)), min(len(audio), int((f + 0.2) * sr))
        segs, _ = modelo.transcribe(audio[a0:a1], language=None if idioma == "auto" else idioma, word_timestamps=True,
                                    vad_filter=False, beam_size=5, condition_on_previous_text=False,
                                    initial_prompt=prompt_ref[0] or PROMPT.get(idioma))
        base = a0 / sr
        novas = []
        for sg in segs:
            for w in sg.words or []:
                t = w.word.strip()
                if t and w.probability >= 0.3:
                    novas.append({"p": t, "i": round(base + w.start, 3), "f": round(base + w.end, 3), "prob": round(w.probability, 3)})
        if len(novas) > len(dentro):
            saida = [w for w in saida if not (w["f"] > i and w["i"] < f)] + novas
            saida.sort(key=lambda w: w["i"])
    return saida
