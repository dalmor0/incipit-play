// Preferências dos clipes, guardadas no app e aplicadas ao gravador assim que o Incipit Play abre.
import QtQuick
import QtCore

import org.streetpea.chiaking

QtObject {
    id: c
    property Settings guardado: Settings {
        category: "clipes"
        property bool ligado: true
        property int segundos: 90
        property string atalho: "Alt+F10"
        property string pasta: ""
        property string pastaEdicao: ""
        property bool obs: false
        property int obsPorta: 4455
        property string obsSenha: ""
    }
    readonly property bool ligado: guardado.ligado
    readonly property int segundos: guardado.segundos
    readonly property string atalho: guardado.atalho
    readonly property string pastaEdicao: guardado.pastaEdicao
    readonly property var atalhos: ["Alt+F10", "Alt+F9", "Alt+F8", "Ctrl+Alt+C", "F8"]
    readonly property var duracoes: [30, 60, 90, 120, 180, 300]

    function aplicar() {
        Clips.setSeconds(guardado.segundos);
        if (guardado.pasta !== "") Clips.setClipsDir(guardado.pasta);
        Clips.setObs(guardado.obs, guardado.obsPorta, guardado.obsSenha);
        Clips.setHotkey(guardado.ligado ? guardado.atalho : "");
    }
    function ligar(v) { guardado.ligado = v; aplicar(); }
    function mudarSegundos(s) { guardado.segundos = s; Clips.setSeconds(s); }
    function mudarAtalho(a) { guardado.atalho = a; return Clips.setHotkey(guardado.ligado ? a : ""); }
    function mudarPasta(p) { guardado.pasta = p; Clips.setClipsDir(p); }
    function mudarPastaEdicao(p) { guardado.pastaEdicao = p; }
    function mudarObs(ligar, porta, senha) { guardado.obs = ligar; guardado.obsPorta = porta; guardado.obsSenha = senha; Clips.setObs(ligar, porta, senha); }

    Component.onCompleted: aplicar()
}
