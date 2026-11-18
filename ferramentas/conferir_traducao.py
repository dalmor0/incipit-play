"""Confere a tradução do Incipit Play: todo texto em root.t("...") dos QML precisa ter a versão em inglês no
dicionário de gui/src/qml/Lingua.qml, e o dicionário não deve guardar texto que ninguém usa mais.

uso: python ferramentas/conferir_traducao.py [--listar]   (--listar imprime os textos sem tradução, um por linha)
Também confere as mensagens que vêm do C++ (gravador de clipes e OBS), que a tela traduz com root.t(motivo).
"""
import io
import os
import re
import sys

AQUI = os.path.dirname(os.path.abspath(__file__))
QML = os.path.join(AQUI, "..", "gui", "src", "qml")
CPP = os.path.join(AQUI, "..", "gui", "src", "cliprecorder.cpp")
CHAMADA = re.compile(r'root\.tk?\("((?:[^"\\]|\\.)*)"\)')
CHAVE = re.compile(r'^\s*"((?:[^"\\]|\\.)*)"\s*:\s*"((?:[^"\\]|\\.)*)"\s*,?\s*$')


# textos do C++ que não aparecem na tela (formato de data, caminho, o pedido que vai pra edição em português)
IGNORAR = {"O clipe não salvou: ", "/Incipit Play", r"[^\\w\\- ]", "yyyy-MM-dd HH-mm", "yyyy-MM-dd HH-mm-ss", "Clipe: ", r"\nPedido: "}


def usados():
    achou = {}
    for nome in sorted(os.listdir(QML)):
        if nome.endswith(".qml") and nome != "Lingua.qml":
            for i, linha in enumerate(io.open(os.path.join(QML, nome), encoding="utf-8")):
                for m in CHAMADA.finditer(linha):
                    achou.setdefault(m.group(1), f"{nome}:{i + 1}")
    # mensagens do C++ que chegam na tela (clipFailed e obsStatus): todo QStringLiteral com espaço; o começo
    # "O clipe não salvou: " o Lingua.qml traduz à parte, junto com o motivo
    for m in re.finditer(r'QStringLiteral\("([^"]* [^"]*)"\)', io.open(CPP, encoding="utf-8").read()):
        if m.group(1) not in IGNORAR:
            achou.setdefault(m.group(1), "cliprecorder.cpp")
    # edição automática: motivos e etapas do C++ (incipitedicao.cpp) e do clipador (Python), que a tela passa por
    # root.t(Edicao.motivo), root.t(Edicao.etapa) e root.t(entendi)
    ed_cpp = os.path.join(AQUI, "..", "gui", "src", "incipitedicao.cpp")
    for m in re.finditer(r'QStringLiteral\("([^"%]* [^"%]*)"\)', io.open(ed_cpp, encoding="utf-8").read()):
        t = m.group(1)
        if t[:1].isupper() and not t.startswith(("Incipit", "PYTHON")) and "/" not in t and ":" not in t[-2:]:
            achou.setdefault(t, "incipitedicao.cpp")
    clip = os.path.join(AQUI, "..", "edicao", "clipador")
    for nome in sorted(os.listdir(clip)):
        if nome.endswith(".py"):
            txt = io.open(os.path.join(clip, nome), encoding="utf-8").read()
            for m in re.finditer(r'(?:Falha\(|entendi\.append\(|motivo=|aviso = )"([^"{}]+)"', txt):
                achou.setdefault(m.group(1), "clipador/" + nome)
            for m in re.finditer(r'\("[a-z]+", "([^"]+)", [0-9.a-z_]+', txt):
                achou.setdefault(m.group(1), "clipador/" + nome)
            for m in re.finditer(r'\{"amarela": "([^"]+)", "destaque": "([^"]+)",\s*"limpa": "([^"]+)", "creme": "([^"]+)"\}', txt):
                for g in m.groups():
                    achou.setdefault(g, "clipador/" + nome)
    # nomes das cores de destaque (Tema.qml), que a tela passa por root.t(modelData.nome)
    for m in re.finditer(r'nome: "([^"]+)", escuro:', io.open(os.path.join(QML, "Tema.qml"), encoding="utf-8").read()):
        achou.setdefault(m.group(1), "Tema.qml")
    return achou


def dicionario():
    pares, dentro = {}, False
    for linha in io.open(os.path.join(QML, "Lingua.qml"), encoding="utf-8"):
        if "readonly property var ingles" in linha:
            dentro = True
            continue
        if dentro and linha.strip().startswith("})"):
            break
        m = CHAVE.match(linha) if dentro else None
        if m:
            pares[m.group(1)] = m.group(2)
    return pares


if __name__ == "__main__":
    u, d = usados(), dicionario()
    faltam = [k for k in u if k not in d]
    sobram = [k for k in d if k not in u and not k.startswith("@")]
    if "--listar" in sys.argv:
        for k in faltam:
            print(k)
        sys.exit(0)
    print(f"{len(u)} textos na tela, {len(d)} no dicionário")
    for k in faltam:
        print(f"FALTA  {u[k]}: {k}")
    for k in sobram:
        print(f"SOBRA  {k}")
    sys.exit(1 if faltam else 0)
