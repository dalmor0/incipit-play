// Lista de escolha (ComboBox) no desenho Incipit: canto reto, 44 px, borda 3:1, foco visível.
import QtQuick
import QtQuick.Controls.Basic as B

B.ComboBox {
    id: c
    readonly property var tema: root.tema
    implicitHeight: 44
    implicitWidth: 260
    font.family: tema.sans
    font.pixelSize: 15
    hoverEnabled: true

    background: Rectangle {
        color: c.tema.fundo
        border.width: 1
        border.color: c.hovered || c.popup.visible ? c.tema.texto : c.tema.borda
        Rectangle {
            visible: c.visualFocus
            anchors.fill: parent; anchors.margins: -4
            color: "transparent"; border.width: 2; border.color: c.tema.texto
        }
    }
    contentItem: Text {
        leftPadding: 14
        rightPadding: 40
        text: c.displayText
        font: c.font
        color: c.tema.texto
        verticalAlignment: Text.AlignVCenter
        elide: Text.ElideRight
    }
    indicator: InIcone {
        x: c.width - width - 14
        y: (c.height - height) / 2
        nome: "abaixo"
        tamanho: 18
        cor: c.tema.texto2
    }
    delegate: B.ItemDelegate {
        required property var modelData
        required property int index
        width: c.width
        height: 40
        highlighted: c.highlightedIndex === index
        contentItem: Text {
            leftPadding: 4
            text: modelData
            font: c.font
            color: c.tema.texto
            verticalAlignment: Text.AlignVCenter
            elide: Text.ElideRight
        }
        background: Rectangle { color: highlighted ? c.tema.destaqueFraco : c.tema.sup }
    }
    popup: B.Popup {
        y: c.height + 4
        width: c.width
        implicitHeight: Math.min(lista.contentHeight + 2, 320)
        padding: 1
        background: Rectangle { color: c.tema.sup; border.width: 1; border.color: c.tema.borda }
        contentItem: ListView {
            id: lista
            clip: true
            implicitHeight: contentHeight
            model: c.popup.visible ? c.delegateModel : null
            currentIndex: c.highlightedIndex
        }
    }
}
