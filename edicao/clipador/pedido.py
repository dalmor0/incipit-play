"""Lê o que a pessoa escreveu em "Descreva o que você quer nesse vídeo" e vira um plano de edição.

Leitor de regras e palavras, em português (com um pouco de inglês de jogador). Roda na hora, sem
baixar nada. A escolha contra um modelo de linguagem local está em RADAR/casos/2026-11-17-clipador.
"""
import re
import unicodedata

PADRAO = {
    "duracao": None,       # segundos pedidos; None = o clipador decide (até 45 s)
    "inteiro": False,      # usar o clipe todo, sem cortar
    "trecho": None,        # [inicio, fim] em segundos, quando a pessoa diz
    "legenda": True,
    "estilo": None,        # creme | amarela | destaque | limpa (None = o da tela)
    "maiuscula": None,
    "titulo": None,
    "zoom": 1.0,           # 0 sem, 0.5 leve, 1 normal, 2 forte
    "layout": None,        # camera | centro | desfocado | sem_camera
    "foco": [],            # palavras do assunto que a pessoa quer ("fuga")
    "foco_tipo": None,     # grito | risada | acao | fala | inicio | fim
    "musica": None,        # True/False quando a pessoa fala
    "censura": False,      # tirar palavrão
}


def sem_acento(t):
    return "".join(c for c in unicodedata.normalize("NFD", t) if unicodedata.category(c) != "Mn")


def _n(t):
    t = sem_acento(t.lower())
    t = re.sub(r"\bq\b", "que", t)
    t = re.sub(r"\b(qnd|qdo|qd|qndo)\b", "quando", t)
    t = re.sub(r"\b(mto|mt|mta|mtos|mtas)\b", "muito", t)
    t = re.sub(r"\bwithout\b", "sem", t)
    t = re.sub(r"\bvc\b", "voce", t)
    t = re.sub(r"\bpq\b", "porque", t)
    t = re.sub(r"\bzoon\b", "zoom", t)
    t = re.sub(r"\bzum\b", "zoom", t)
    t = re.sub(r"\bseg\b|\bsegs\b|\bsec\b", "segundos", t)
    t = re.sub(r"\bcam\b|\bfacecam\b|\bwebcam\b", "camera", t)
    t = re.sub(r"\bmusic\b", "musica", t)
    t = re.sub(r"\blegendas\b|\bsubtitles?\b|\bcaptions?\b", "legenda", t)
    # inglês de jogador: "no music", "no zoom", "no captions", "no cam"
    t = re.sub(r"\bno\s+(musica|zoom|legenda|camera)\b", r"sem \1", t)
    t = re.sub(r"\bmore zoom\b", "mais zoom", t)
    t = re.sub(r"\bseconds?\b", "segundos", t)
    t = re.sub(r"\bonly the (\w+(?: \w+)?) part\b", r"so a parte da \1", t)
    t = re.sub(r"\bthe part (?:where|when|with)\b", "a parte que", t)
    return t


PARADAS = set("""a o as os um uma uns umas de da do das dos em na no nas nos que e eu meu minha
me pra para por com sem so somente apenas parte hora momento vez quando onde tipo bem mais quero queria
coloca poe bota deixa faz fazer faca pega pegar foca focar mostra mostrar video clipe corte isso esse essa
aquele aquela aqui ali la ta to tava estava fico fica ai entao ja ate sobre falo falei fala falando gente
cara mano vei mesmo the and of only part pro pros muito aparece aparecer acontece rola rolou edit brabo pfv favor
tiktok reels shorts insta instagram youtube""".split())

# nome de jogo e placar de rodada dizem onde a pessoa estava, não o assunto do trecho
JOGOS = set("""valorant fortnite gta fifa fc cod warzone minecraft lol cs csgo cs2 freefire free fire roblox apex
pubg overwatch dbd dead daylight rocket league genshin elden ring dota rainbow r6 lethal fall guys among
tarkov arc raiders battlefield bf""".split())

# assunto -> radicais que aparecem na fala (a pessoa escreve "fuga", o jogador fala "fugi", "corre")
PARENTES = {
    "fug": ["fug", "corr", "escap", "sai", "vaza", "acelera"],
    "escap": ["escap", "fug", "corr", "run", "vaza"],
    "polic": ["polic", "viatura", "pm", "cana", "giroflex", "sirene", "cop"],
    "mort": ["morr", "mort", "mat", "dead", "kill"],
    "mat": ["mat", "kill", "abat", "morr", "mort"],
    "kill": ["kill", "mat", "abat"],
    "tiro": ["tiro", "atir", "bala", "headshot", "hs", "dispar"],
    "arma": ["arma", "fuzil", "pistola", "shotgun", "doze", "sniper", "rifle"],
    "carr": ["carr", "nave", "moto", "pneu"],
    "bat": ["bat", "capot", "acident", "pancada"],
    "explo": ["explo", "bomba", "granada", "c4"],
    "boss": ["boss", "chefe", "chefao"],
    "gol": ["gol", "golaco", "chute"],
    "vit": ["vit", "ganh", "win", "venc", "booyah"],
    "derrot": ["perd", "derrot", "lose"],
    "sust": ["sust", "medo", "jumpscare", "assust"],
    "bug": ["bug", "glitch", "trav"],
}

GRITO = re.compile(r"\b(grit\w*|berr\w*|surt\w*|scream\w*|desesper\w*)")
RISADA = re.compile(r"\b(ri|rio|rindo|risada\w*|rir|kk+|haha\w*|rs+|engracad\w*|zoeira|zuera|lol)\b")
ACAO = re.compile(r"\b(acao|tiro\w*|kill\w*|clutch|explos\w*|lance|jogada|play|ace|headshot|combo|porrada|briga|luta)\b")
SUSTO = re.compile(r"\b(sust\w*|jumpscare|medo|assust\w*)")


def _tempo(txt):
    """'1:20' -> 80, '20' -> 20, '20s' -> 20."""
    txt = txt.strip()
    if ":" in txt:
        m, s = txt.split(":", 1)
        return int(m) * 60 + float(s)
    return float(re.sub(r"[^\d.]", "", txt) or 0)


def _titulo(original):
    """O título vem do texto original (com acento e maiúscula)."""
    padroes = [
        r"(?:t[ií]tulo|gancho|chamada|texto\s+(?:no|em)\s+cima|escrev[ea]|frase)\s*(?:de|com|tipo|assim)?\s*[:=\-]?\s*[\"“”'‘’]([^\"“”'‘’]{1,80})[\"“”'‘’]",
        r"(?:t[ií]tulo|title|gancho|chamada)\s*[:=\-]\s*([^\n.;,]{1,80})",
        r"(?:p[oõ]e|coloca|bota|com|usa)\s+(?:o\s+)?t[ií]tulo\s+([A-ZÁÉÍÓÚÂÊÔÃÕÇ0-9][^\n.;,]{0,79})",
    ]
    for p in padroes:
        m = re.search(p, original, re.I)
        if m:
            t = m.group(1).strip()
            # corta o resto do pedido grudado ("título: FUGI e mais zoom")
            t = re.split(r"\s+(?:e|com|sem|mas)\s+(?=[a-záéíóúâêôãõç])", t)[0].strip()
            return t[:60] or None
    return None


def _foco(n):
    """Assunto pedido: 'só a parte da fuga', 'quando eu falo da arma nova', 'foca no boss'."""
    marcas = r"(?:parte|hora|momento|trecho|pedaco)\s+(?:da|do|de|das|dos|em que|que|onde|q)\s+|quando\s+|foca(?:r)?\s+(?:na|no|nas|nos|em)\s+|sobre\s+(?:a|o)?\s*|falo\s+(?:da|do|de)\s+"
    achados = []
    for m in re.finditer(marcas, n):
        resto = n[m.end():]
        resto = re.split(r"[,.;!?\n]|\s+(?:e|com|sem|mas|titulo|legenda|zoom|bota|coloca|poe|deixa)\b", resto)[0]
        for w in re.findall(r"[a-z0-9]+", resto):
            if w not in PARADAS and w not in JOGOS and len(w) >= 3 and not re.fullmatch(r"\d+v\d+", w):
                achados.append(w)
    return list(dict.fromkeys(achados))[:6]


def radicais(palavra):
    """Radicais pra procurar na fala: o da palavra e os parentes."""
    w = sem_acento(palavra.lower())
    base = w[:5] if len(w) > 5 else w[:4] if len(w) > 3 else w
    r = {base}
    for k, v in PARENTES.items():
        if w.startswith(k) or base.startswith(k):
            r.update(v)
    return sorted(r)


def ler(texto):
    plano = dict(PADRAO)
    plano["foco"] = []
    entendi = []
    original = (texto or "").strip()[:500]
    if not original:
        return plano, []
    n = _n(original)

    # título primeiro, e tira ele do texto pra não confundir o resto
    t = _titulo(original)
    if t:
        plano["titulo"] = t
        entendi.append(f'Título na tela: "{t}"')
        n = n.replace(_n(t), " ")

    # trecho com tempo: "do 0:20 ao 0:45", "de 10 a 40 segundos", "a partir do 15"
    m = re.search(r"\b(?:do|de|entre)\s+(\d{1,2}:\d{2}|\d{1,4})\s*(?:s|segundos)?\s*(?:ao|a|ate|e|pro|pra)\s+(?:o\s+)?(\d{1,2}:\d{2}|\d{1,4})\s*(?:s|segundos)?\b", n)
    if m and (":" in m.group(1) + m.group(2) or re.search(r"cort|trecho|pega|segundo|minuto|do\s", n)):
        a, b = _tempo(m.group(1)), _tempo(m.group(2))
        if b > a:
            plano["trecho"] = [a, b]
            entendi.append(f"Trecho de {int(a // 60)}:{int(a % 60):02d} a {int(b // 60)}:{int(b % 60):02d}")
            n = n[:m.start()] + " " + n[m.end():]
    else:
        m = re.search(r"\b(?:a partir d[oa]|comeca(?:ndo)?\s+(?:no|em|do|aos))\s+(\d{1,2}:\d{2}|\d{1,4})", n)
        if m:
            a = _tempo(m.group(1))
            plano["trecho"] = [a, None]
            entendi.append(f"Começa em {int(a // 60)}:{int(a % 60):02d}")

    # duração
    m = re.search(r"\b(\d{1,3})\s*(?:s|segundos|segundinhos)\b", n)
    if m and not plano["trecho"]:
        plano["duracao"] = max(5, min(180, int(m.group(1))))
    m2 = re.search(r"\b(\d{1,2})\s*(?:min|minutos?)\b", n)
    if m2 and not plano["trecho"]:
        plano["duracao"] = max(5, min(180, int(m2.group(1)) * 60))
    if re.search(r"\bmeio minuto\b", n):
        plano["duracao"] = 30
    elif re.search(r"\bum minuto\b", n):
        plano["duracao"] = 60
    if plano["duracao"] is None and re.search(r"\b(curtinho|bem curto|rapidinho|curto)\b", n):
        plano["duracao"] = 15
    if re.search(r"\b(clipe|video)\s+(todo|inteiro)\b|\b(nao corta|sem cortar|tudo)\b", n):
        plano["inteiro"] = True
        entendi.append("Usa o clipe inteiro")
    if plano["duracao"]:
        entendi.append(f"Duração de uns {plano['duracao']} s")

    # legenda
    if re.search(r"\bsem legenda\b|\b(tira|tirar|remove|nao (?:quero|coloca|bota|poe))\s+(?:a\s+)?legenda\b|\blegenda\s+nao\b", n):
        plano["legenda"] = False
        entendi.append("Sem legenda")
    else:
        if re.search(r"legenda\s+amarel|\bamarel", n):
            plano["estilo"] = "amarela"
        elif re.search(r"legenda\s+(azul|colorida)|\bdestac", n):
            plano["estilo"] = "destaque"
        elif re.search(r"legenda\s+(branca|simples|limpa|normal|discreta|pequena)", n):
            plano["estilo"] = "limpa"
        elif re.search(r"legenda\s+(creme|padrao|classica)|estilo\s+(do\s+)?gustavo|legenda\s+(do\s+)?gustavo", n):
            plano["estilo"] = "creme"
        if re.search(r"maiuscul|caixa alta|caps", n):
            plano["maiuscula"] = True
        elif re.search(r"minuscul", n):
            plano["maiuscula"] = False
        if plano["estilo"]:
            entendi.append({"amarela": "Legenda amarela", "destaque": "Legenda com a palavra em destaque",
                            "limpa": "Legenda simples", "creme": "Legenda padrão"}[plano["estilo"]])
        if plano["maiuscula"]:
            entendi.append("Legenda em maiúscula")
    if re.search(r"\b(sem palavrao|censura\w*|tira\w* (?:os? )?palavr\w+|sem xingamento)", n):
        plano["censura"] = True
        entendi.append("Palavrão cortado")

    # zoom
    if re.search(r"\bsem zoom\b|\b(tira|tirar|nada de|nenhum)\s+(?:o\s+)?zoom\b|\bzoom\s+nao\b", n):
        plano["zoom"] = 0.0
        entendi.append("Sem zoom")
    elif re.search(r"\b(mais|muito|bastante|varios|monte de|forte|exagera\w*)\s+(?:de\s+)?zoom|zoom\s+(forte|exagerado|em tudo|toda hora)|\bdinamic", n):
        plano["zoom"] = 2.0
        entendi.append("Mais zoom")
    elif re.search(r"\b(menos|pouco|leve|suave)\s+(?:de\s+)?zoom|zoom\s+(leve|suave|de leve)", n):
        plano["zoom"] = 0.5
        entendi.append("Zoom leve")

    # enquadramento
    if re.search(r"\bsem (?:a\s+|minha\s+)?camera\b|\bsem (?:a\s+)?minha cara\b|\bso (?:o\s+)?jogo\b|\besconde (?:a\s+)?camera\b|\btira (?:a\s+)?camera\b", n):
        plano["layout"] = "sem_camera"
        entendi.append("Sem a câmera")
    elif re.search(r"camera (?:em )?cima|minha cara (?:em )?cima|\bcom (?:a\s+)?(?:minha\s+)?camera\b|\bcom minha cara\b", n):
        plano["layout"] = "camera"
        entendi.append("Câmera em cima, jogo embaixo")
    if re.search(r"fundo (?:desfocado|borrado)|\bdesfoc|\bborrad|jogo inteiro|tela (?:toda|inteira)|sem cortar o jogo|\bhud\b|\bmapa\b", n):
        plano["layout"] = "desfocado" if plano["layout"] != "camera" else "camera"
        if plano["layout"] == "desfocado":
            entendi.append("Jogo inteiro com fundo desfocado")
    elif re.search(r"jogo no (?:centro|meio)|tela cheia|preench|close no jogo", n) and plano["layout"] != "camera":
        plano["layout"] = "centro"
        entendi.append("Jogo no centro, tela cheia")

    # música
    if re.search(r"\bsem musica\b|\b(tira|nao)\s+(?:poe|coloca|bota\s+)?(?:a\s+)?musica\b", n):
        plano["musica"] = False
        entendi.append("Sem música")
    elif re.search(r"\bmusica\b", n):
        plano["musica"] = True
        entendi.append("Música da sua pasta")

    # momento
    if SUSTO.search(n):
        plano["foco_tipo"] = "grito"
        entendi.append("O momento do susto")
    elif GRITO.search(n):
        plano["foco_tipo"] = "grito"
        entendi.append("O momento do grito")
    elif RISADA.search(n):
        plano["foco_tipo"] = "risada"
        entendi.append("O momento da risada")
    elif ACAO.search(n):
        plano["foco_tipo"] = "acao"
        entendi.append("O momento de mais ação")
    if re.search(r"\b(comeco|inicio)\s+do\s+(clipe|video)|\b(pega|quero|mostra|deixa|so)\s+(so\s+)?o\s+(comeco|inicio)\b", n):
        plano["foco_tipo"] = "inicio"
        entendi.append("O começo do clipe")
    elif re.search(r"\b(final|fim)\s+do\s+(clipe|video)|\b(pega|quero|mostra|deixa|so)\s+(so\s+)?o\s+(final|fim)\b", n):
        plano["foco_tipo"] = "fim"
        entendi.append("O final do clipe")
    plano["foco"] = [w for w in _foco(n) if not GRITO.match(w) and not RISADA.match(w)]
    if plano["foco"]:
        entendi.append("A parte de: " + ", ".join(plano["foco"]))
    return plano, entendi
