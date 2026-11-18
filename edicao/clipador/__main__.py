"""Clipador do Incipit Play: um clipe de jogo vira um vertical pronto pra postar.

  python -I -m clipador editar --clipe C --saida PASTA [--pedido TEXTO] [--layout auto|camera|centro|desfocado]
         [--estilo creme|amarela|destaque|limpa] [--camera x,y,w,h] [--inicio S --fim S] [--titulo T]
         [--sem-legenda] [--zoom 0|0.5|1|2] [--musica PASTA] [--idioma pt|auto] [--modelo medium|small|base]
  python -I -m clipador pedido "texto"      mostra o que o leitor entendeu (teste)

A saída é uma linha JSON por evento (ver base.py). Tudo roda neste PC.
"""
import argparse
import hashlib
import re
import json
import os
import sys
import time
from pathlib import Path

from . import analise, camera as cam_mod, legenda, momento, pedido as ped, render
from .base import Andamento, Falha, avisar, conferir_clipe, medir, pasta_trabalho, prioridade_baixa

VERSAO = "1.0.2"
_cancelar = {"v": False}


def cancelado():
    return _cancelar["v"]


def _vigia_cancelar():
    """O Play pode mandar "cancelar" pela entrada; com INCIPIT_EDICAO_ENTRADA=1, a entrada fechada (Play fechou) também cancela."""
    import threading

    def ler():
        try:
            for linha in sys.stdin:
                if linha.strip() == "cancelar":
                    _cancelar["v"] = True
                    return
        except (OSError, ValueError):
            pass
        if os.environ.get("INCIPIT_EDICAO_ENTRADA") == "1":
            _cancelar["v"] = True   # o Play fechou: para
    threading.Thread(target=ler, daemon=True).start()


def pasta_cache():
    la = os.environ.get("LOCALAPPDATA") or str(Path.home())
    p = Path(os.environ.get("INCIPIT_EDICAO_CACHE") or Path(la) / "Incipit" / "Incipit Play" / "edicao-cache")
    p.mkdir(parents=True, exist_ok=True)
    # a fala lida fica guardada 30 dias (refazer sai rápido); depois some
    agora = time.time()
    for velho in p.glob("*.json"):
        try:
            if agora - velho.stat().st_mtime > 30 * 86400:
                velho.unlink()
        except OSError:
            pass
    return p


def chave(clipe):
    st = clipe.stat()
    return hashlib.sha1(f"{clipe.resolve()}|{st.st_size}|{int(st.st_mtime)}|{VERSAO}".encode("utf-8")).hexdigest()[:20]


NOME_GERADO = re.compile(r"(\d{4}-\d{2}-\d{2}|\d{2}-\d{2}-\d{2}|[0-9a-f]{8}-[0-9a-f]{4}|^screen|^clip|^replay|^video|^gravacao|^recording)", re.I)


def assunto_do_nome(clipe):
    """Palavras do nome do arquivo quando a pessoa deu um nome de verdade (não o automático do gravador)."""
    nome = clipe.stem
    if NOME_GERADO.search(nome):
        return []
    from .pedido import PARADAS, JOGOS, sem_acento
    ws = re.findall(r"[a-zA-ZÀ-ÿ]{4,}", sem_acento(nome.lower()))
    return [w for w in ws if w not in PARADAS and w not in JOGOS and w not in ("editado", "final", "corte")][:4]


def nome_saida(pasta, clipe):
    pasta.mkdir(parents=True, exist_ok=True)
    base = clipe.stem + " editado"
    d = pasta / f"{base}.mp4"
    k = 2
    while d.exists():
        d = pasta / f"{base} ({k}).mp4"
        k += 1
    return d


def editar(a):
    t_ini = time.time()
    prioridade_baixa()
    clipe = conferir_clipe(a.clipe)
    plano, entendi = ped.ler(a.pedido or "")
    # controles da tela valem como base; o pedido escrito manda por cima
    if a.sem_legenda:
        plano["legenda"] = False
    if a.titulo and not plano["titulo"]:
        plano["titulo"] = a.titulo.strip()[:60]
    if a.estilo and not plano["estilo"]:
        plano["estilo"] = a.estilo
    if a.zoom is not None and plano["zoom"] == ped.PADRAO["zoom"]:
        plano["zoom"] = a.zoom
    if a.inicio is not None and a.fim is not None and a.fim > a.inicio:
        plano["trecho"] = [a.inicio, a.fim]
    layout_tela = a.layout if a.layout and a.layout != "auto" else None
    if layout_tela and not plano["layout"]:
        plano["layout"] = layout_tela
    if plano["musica"] is None:
        plano["musica"] = False   # música desligada por padrão

    precisa_fala = bool(plano["legenda"] or plano["foco"] or plano["foco_tipo"] in ("risada", "fala", "grito") or plano["censura"])
    # na primeira vez o download do leitor de fala (1,5 GB) é a parte mais longa: a barra anda com ele
    from . import fala as _fala
    peso_modelo = 60 if precisa_fala and not _fala.modelo_presente(a.modelo) else 0.5
    etapas = [("preparar", "Preparando", 3), ("modelo", "Baixando o leitor de fala (só na primeira vez)", peso_modelo),
              ("ouvir", "Ouvindo o clipe", 4), ("olhar", "Olhando a imagem", 6),
              ("fala", "Lendo a fala", 30 if precisa_fala else 0.5), ("momento", "Escolhendo o melhor momento", 2),
              ("montar", "Montando o vertical", 50), ("fim", "Salvando", 1)]
    and_ = Andamento(etapas)
    and_.etapa("preparar")
    meta = medir(clipe)
    trabalho = pasta_trabalho()
    try:
        cache_arq = pasta_cache() / f"{chave(clipe)}.json"
        cache = {}
        if cache_arq.is_file():
            try:
                cache = json.loads(cache_arq.read_text(encoding="utf-8"))
            except (OSError, ValueError):
                cache = {}

        import numpy as np
        and_.etapa("ouvir")
        aud = analise.audio(clipe, meta)
        db = analise.volume_db(aud)
        if cancelado():
            raise Falha("Cancelado.")
        and_.etapa("olhar")
        mov = analise.movimento(clipe, meta, cancelado)
        if cancelado():
            raise Falha("Cancelado.")
        n = max(1, int(np.ceil(meta["duracao"] / analise.PASSO)))
        energia = analise.para_passo(mov["energia"], analise.FPS_MOV, n)
        corte = analise.para_passo(mov["corte"], analise.FPS_MOV, n)

        palavras = cache.get("palavras")
        idioma = cache.get("idioma")
        onde = cache.get("onde")
        silencio = float(np.max(db)) < -50 if len(db) else True
        if precisa_fala and palavras is None and not silencio:
            from . import fala
            and_.etapa("modelo")
            pm = fala.garantir_modelo(a.modelo, lambda f, t: and_.etapa("modelo", f, t), cancelado)
            and_.etapa("fala")
            palavras, idioma, onde = fala.transcrever(aud, pm, a.idioma, lambda f, t: and_.etapa("fala", f, t), cancelado)
            cache.update(palavras=palavras, idioma=idioma, onde=onde)
        palavras = analise.alinhar_falas(palavras or [], aud)
        par = analise.para_passo(analise.parado(mov["energia"]), analise.FPS_MOV, n)
        # clipe que é quase todo menu ou tela parada, sem ninguém falando, não vira vídeo
        if float((par > 0.5).mean()) > 0.75 and not palavras and plano["trecho"] is None and not plano["inteiro"]:
            raise Falha("Esse clipe é quase todo menu ou tela parada. Não achei jogada pra cortar.")
        # o nome que a pessoa deu ao arquivo ("fuga da policia.mp4") vira assunto quando não tem pedido
        if not plano["foco"]:
            plano["foco_nome"] = assunto_do_nome(clipe)

        # câmera: a marcada pela pessoa vale; senão procura uma vez e guarda
        caixa = None
        if a.camera:
            try:
                caixa = [float(x) for x in a.camera.split(",")]
                if len(caixa) != 4 or not all(0 <= x <= 1 for x in caixa) or caixa[2] < 0.03 or caixa[3] < 0.03:
                    caixa = None
            except ValueError:
                caixa = None
            # marcada pra todos os clipes: num clipe sem câmera (o do PS5, por exemplo) ela não vale
            if caixa and plano["layout"] != "camera" and a.inicio is None:
                chave_cam = "confere:" + ",".join(f"{v:.4f}" for v in caixa)
                if chave_cam not in cache:
                    cache[chave_cam] = cam_mod.confere(clipe, meta["duracao"], caixa)
                if not cache[chave_cam]:
                    caixa = None
        if caixa is None and plano["layout"] not in ("centro", "desfocado", "sem_camera"):
            if "camera" not in cache:
                cache["camera"] = cam_mod.achar(clipe, meta["duracao"])
            caixa = cache["camera"]
        try:
            cache_arq.write_text(json.dumps(cache), encoding="utf-8")
        except OSError:
            pass

        # enquadramento (antes do momento: com câmera, o que pesa é a reação de quem está nela)
        aviso = None
        lay = plano["layout"]
        if lay == "camera" and not caixa:
            aviso = "Não achei sua câmera nesse clipe. Marque a área dela uma vez em Ajustar."
            lay = None
        if lay in (None, "sem_camera"):
            if caixa and lay is None:
                lay = "camera"
            else:
                col = mov["colunas"]
                w = len(col)
                meio = col[int(w * 0.342):int(w * 0.658)].sum() / max(1e-6, col.sum())
                lay = "centro" if meio >= 0.24 else "desfocado"

        and_.etapa("momento")
        com_cam = lay == "camera" and bool(caixa)
        rea = analise.reacao_na_camera(mov, caixa) if com_cam else None
        rea = analise.para_passo(rea, analise.FPS_MOV, n) if rea is not None else None
        s = momento.sinais(meta["duracao"], db, energia, corte, palavras, plano, reacao=rea, parado=par)
        ini, fim = momento.escolher(meta["duracao"], s, palavras, plano, com_cam)
        imp = momento.impactos(ini, fim, s, plano, com_cam)
        cx = render.seguir_acao(mov.get("col_t"), analise.FPS_MOV, ini, fim,
                                render.SH * render.LARG / (render.ALT - (render.CAM_ALT if lay == "camera" else 0)))

        ass, n_pal = legenda.montar(palavras if plano["legenda"] else [], ini, fim, plano["estilo"], plano["maiuscula"],
                                    plano["censura"], plano["titulo"], lay)
        cens = legenda.trechos_censurados(palavras, ini, fim) if plano["censura"] else []
        # o começo de cada bloco de legenda que foi pro vídeo (conferência: legenda no tempo da voz)
        blocos_leg = []
        if plano["legenda"]:
            est = legenda.ESTILOS.get(plano["estilo"] or legenda.PADRAO, legenda.ESTILOS[legenda.PADRAO])
            dentro = [dict(w, i=w["i"] - ini, f=w["f"] - ini) for w in palavras if w["f"] > ini + 0.05 and w["i"] < fim - 0.05]
            blocos_leg = [[round(max(0.0, g[0]["i"]), 3), " ".join(w["p"] for w in g)] for g in legenda.blocos(dentro, est)]
        destino = nome_saida(Path(a.saida), clipe)
        and_.etapa("montar")
        info = render.render(clipe, meta, ini, fim, lay, caixa if lay == "camera" else None, imp, plano["zoom"], cx, ass,
                             cens, a.musica if plano["musica"] else None, destino,
                             lambda f: and_.etapa("montar", f), cancelado, trabalho)
        and_.etapa("fim")
        resumo = {
            "arquivo": str(destino), "miniatura": str(destino.with_suffix(".jpg")), "origem": str(clipe),
            "inicio": ini, "fim": fim, "duracao": round(fim - ini, 2), "duracao_origem": round(meta["duracao"], 2),
            "layout": lay, "camera": caixa, "estilo": plano["estilo"] or legenda.PADRAO, "legenda": plano["legenda"],
            "palavras_na_legenda": n_pal, "titulo": plano["titulo"], "zoom": plano["zoom"], "impactos": imp,
            "musica": info["musica"], "entendi": entendi, "aviso": aviso, "pedido": a.pedido or "",
            "onda": analise.onda(db), "legendas": blocos_leg[:400], "fala_em": onde, "idioma": idioma, "segundos": round(time.time() - t_ini, 1),
            "versao": VERSAO,
        }
        destino.with_suffix(".json").write_text(json.dumps(resumo, ensure_ascii=False, indent=1), encoding="utf-8")
        avisar("pronto", **resumo)
    finally:
        import shutil
        shutil.rmtree(trabalho, ignore_errors=True)


def main(argv=None):
    p = argparse.ArgumentParser(prog="clipador")
    sub = p.add_subparsers(dest="cmd", required=True)
    e = sub.add_parser("editar")
    e.add_argument("--clipe", required=True)
    e.add_argument("--saida", required=True)
    e.add_argument("--pedido", default="")
    e.add_argument("--layout", default="auto", choices=["auto", "camera", "centro", "desfocado"])
    e.add_argument("--estilo", default=None, choices=list(legenda.ESTILOS))
    e.add_argument("--camera", default=None)
    e.add_argument("--inicio", type=float, default=None)
    e.add_argument("--fim", type=float, default=None)
    e.add_argument("--titulo", default=None)
    e.add_argument("--sem-legenda", action="store_true")
    e.add_argument("--zoom", type=float, default=None, choices=[0.0, 0.5, 1.0, 2.0])
    e.add_argument("--musica", default=None)
    e.add_argument("--idioma", default="pt")
    e.add_argument("--modelo", default="medium", choices=["medium", "small", "base"])
    sub.add_parser("versao")
    t = sub.add_parser("pedido")
    t.add_argument("texto")
    a = p.parse_args(argv)
    if a.cmd == "versao":
        avisar("versao", versao=VERSAO)
        return 0
    if a.cmd == "pedido":
        plano, entendi = ped.ler(a.texto)
        avisar("pedido", plano=plano, entendi=entendi)
        return 0
    _vigia_cancelar()
    try:
        editar(a)
        return 0
    except Falha as f:
        avisar("erro", motivo=f.motivo, detalhe=str(f.detalhe)[-800:], cancelado=f.motivo == "Cancelado.")
        return 2 if f.motivo == "Cancelado." else 1
    except OSError as ex:
        import errno
        if ex.errno == errno.ENOSPC:
            avisar("erro", motivo="Sem espaço no disco pra salvar o vídeo.", detalhe=repr(ex))
            return 1
        import traceback
        avisar("erro", motivo="Algo deu errado na edição. Tente de novo; se repetir, o detalhe está no log.",
               detalhe=traceback.format_exc()[-1500:])
        return 1
    except Exception as ex:  # erro inesperado: motivo curto pra pessoa, detalhe pro log
        import traceback
        avisar("erro", motivo="Algo deu errado na edição. Tente de novo; se repetir, o detalhe está no log.",
               detalhe=traceback.format_exc()[-1500:])
        return 1


if __name__ == "__main__":
    sys.exit(main())
