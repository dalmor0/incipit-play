// Cartão: superfície por degrau de tom, sem borda, canto reto, 24 px de respiro.
// marcado: o fio de luz no alto (degradê do logo com um brilho curto), pra quando a coisa está pronta ou ligada.
// corFio: uma faixa fina à esquerda, pra quando o cartão pede atenção (erro); sobrepõe o marcado.
import QtQuick
import QtQuick.Layouts

Rectangle {
    id: c
    property real respiro: 24
    property bool marcado: false
    property color corFio: "transparent"
    default property alias conteudo: dentro.data
    readonly property var tema: root.tema
    Layout.fillWidth: true
    implicitHeight: dentro.implicitHeight + respiro * 2
    color: corFio.a > 0 ? tema.erroFundo : tema.sup

    Rectangle {
        visible: c.marcado && c.corFio.a === 0
        anchors { left: parent.left; right: parent.right; top: parent.top }
        height: 2
        gradient: Gradient {
            orientation: Gradient.Horizontal
            GradientStop { position: 0; color: c.tema.luz1 }
            GradientStop { position: 1; color: c.tema.luz2 }
        }
    }
    Rectangle {
        visible: c.marcado && c.corFio.a === 0
        anchors { left: parent.left; right: parent.right; top: parent.top; topMargin: 2 }
        height: 14
        gradient: Gradient {
            GradientStop { position: 0; color: c.tema.brilho }
            GradientStop { position: 1; color: "transparent" }
        }
        opacity: 0.5
    }
    Rectangle {
        visible: c.corFio.a > 0
        anchors { left: parent.left; top: parent.top; bottom: parent.bottom }
        width: 3
        color: c.corFio
    }

    ColumnLayout {
        id: dentro
        anchors { left: parent.left; right: parent.right; top: parent.top; margins: c.respiro }
        spacing: 12
    }
}
