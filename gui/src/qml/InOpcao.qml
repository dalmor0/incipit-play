// Opção de escolha única (tema, cor): caixa com borda, marcada com borda dupla do texto e o visto.
import QtQuick
import QtQuick.Templates as T

T.AbstractButton {
    id: o
    property string texto
    property string amostra: ""
    property bool marcada: false
    readonly property var tema: root.tema
    implicitHeight: 44
    implicitWidth: linha.implicitWidth + 28 + 26
    focusPolicy: Qt.StrongFocus
    hoverEnabled: true
    checkable: false
    Accessible.role: Accessible.RadioButton
    Keys.onReturnPressed: clicked()
    Keys.onEnterPressed: clicked()
    Accessible.name: texto
    Accessible.checked: marcada

    background: Rectangle {
        color: o.tema.fundo
        border.width: o.marcada ? 2 : 1
        border.color: o.marcada ? o.tema.texto : (o.hovered ? o.tema.borda : o.tema.linha)
        Rectangle { visible: o.visualFocus; anchors.fill: parent; anchors.margins: -4; color: "transparent"; border.width: 2; border.color: o.tema.texto }
    }
    contentItem: Item {
        Row {
            id: linha
            anchors.verticalCenter: parent.verticalCenter
            x: 14 - o.leftPadding
            spacing: 12
            Rectangle {
                visible: o.amostra !== ""
                width: 18; height: 18
                color: o.amostra
                anchors.verticalCenter: parent.verticalCenter
            }
            Text {
                text: o.texto
                font.family: o.tema.sans
                font.pixelSize: 15
                font.weight: o.marcada ? Font.DemiBold : Font.Normal
                color: o.tema.texto
                anchors.verticalCenter: parent.verticalCenter
            }
        }
        InIcone {
            visible: o.marcada
            nome: "check"
            tamanho: 16
            cor: o.tema.texto
            anchors.right: parent.right
            anchors.rightMargin: 12 - o.rightPadding
            anchors.verticalCenter: parent.verticalCenter
        }
    }
}
