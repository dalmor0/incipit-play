// Cartão: superfície do tema, fio de 1 px, canto reto, 24 px de respiro.
import QtQuick
import QtQuick.Layouts

Rectangle {
    id: c
    property real respiro: 24
    property bool marcado: false
    default property alias conteudo: dentro.data
    readonly property var tema: root.tema
    Layout.fillWidth: true
    implicitHeight: dentro.implicitHeight + respiro * 2
    color: tema.sup
    border.width: 1
    border.color: marcado ? tema.destaque : tema.linha

    ColumnLayout {
        id: dentro
        anchors { left: parent.left; right: parent.right; top: parent.top; margins: c.respiro }
        spacing: 12
    }
}
