// Opção de escolha única (tema, cor): caixa com borda, marcada com borda dupla do texto e o visto.
import QtQuick
import QtQuick.Templates as T

T.AbstractButton {
    id: o
    property string texto
    property string amostra: ""
    property bool marcada: false
    property bool caixa: false          // liga e desliga (caixa de marcar à esquerda) em vez de escolha única
    readonly property var tema: root.tema
    implicitHeight: caixa ? 48 : 44
    implicitWidth: linha.implicitWidth + 28 + 26
    focusPolicy: Qt.StrongFocus
    hoverEnabled: true
    checkable: false
    Accessible.role: caixa ? Accessible.CheckBox : Accessible.RadioButton
    Keys.onReturnPressed: clicked()
    Keys.onEnterPressed: clicked()
    Accessible.name: texto
    Accessible.checked: marcada

    background: Rectangle {
        color: o.caixa ? (o.hovered ? o.tema.sup3 : "transparent") : o.tema.fundo
        border.width: o.caixa ? 0 : o.marcada ? 2 : 1
        border.color: o.marcada && !o.caixa ? o.tema.texto : (o.hovered ? o.tema.borda : o.tema.linha)
        Rectangle { visible: o.visualFocus; anchors.fill: parent; anchors.margins: -4; color: "transparent"; border.width: 2; border.color: o.tema.texto }
    }
    contentItem: Item {
        Row {
            id: linha
            anchors.verticalCenter: parent.verticalCenter
            x: (o.caixa ? 0 : 14) - o.leftPadding   // a caixa de marcar não tem moldura: encosta na coluna dos rótulos
            spacing: 12
            Rectangle {
                visible: o.caixa
                width: 18; height: 18
                color: o.marcada ? o.tema.forte2 : "transparent"
                border.width: o.marcada ? 0 : 1
                border.color: o.tema.borda
                anchors.verticalCenter: parent.verticalCenter
                InIcone { anchors.centerIn: parent; visible: o.marcada; nome: "check"; tamanho: 14; cor: o.tema.sobreForte }
            }
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
            visible: o.marcada && !o.caixa
            nome: "check"
            tamanho: 16
            cor: o.tema.texto
            anchors.right: parent.right
            anchors.rightMargin: 12 - o.rightPadding
            anchors.verticalCenter: parent.verticalCenter
        }
    }
}
