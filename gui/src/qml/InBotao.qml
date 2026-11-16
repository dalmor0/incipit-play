// Botão do Incipit Play: botão de verdade, canto reto, 44 px de altura mínima, foco visível.
// tipo: "forte" (ação principal, cor de destaque), "normal" (borda) ou "quieto" (sem borda, pra ação de linha)
import QtQuick
import QtQuick.Controls.Basic as B

B.AbstractButton {
    id: b
    property string tipo: "normal"
    property string icone: ""
    property bool compacto: false
    readonly property var tema: root.tema

    implicitHeight: compacto ? 36 : 44
    implicitWidth: Math.max(compacto ? 36 : 44, linha.implicitWidth + (compacto ? 24 : 36))
    focusPolicy: Qt.StrongFocus
    hoverEnabled: true
    font.family: tema.sans
    font.pixelSize: compacto ? 14 : 15
    font.weight: Font.DemiBold
    Accessible.name: text

    background: Rectangle {
        color: b.tipo === "forte" ? (b.down ? Qt.darker(b.tema.destaque, 1.08) : b.tema.destaque)
             : b.down ? b.tema.linha : (b.hovered && b.tipo === "quieto" ? b.tema.destaqueFraco : "transparent")
        border.width: b.tipo === "quieto" ? 0 : 1
        border.color: b.tipo === "forte" ? b.tema.destaque : (b.hovered ? b.tema.texto : b.tema.borda)
        opacity: b.enabled ? 1 : 0.45
        Rectangle {
            visible: b.visualFocus
            anchors.fill: parent
            anchors.margins: -4
            color: "transparent"
            border.width: 2
            border.color: b.tema.texto
        }
    }

    contentItem: Item {
        implicitWidth: linha.implicitWidth
        implicitHeight: linha.implicitHeight
        Row {
            id: linha
            anchors.centerIn: parent
            spacing: 8
            InIcone {
                visible: b.icone !== ""
                nome: b.icone
                tamanho: b.compacto ? 16 : 18
                cor: b.tipo === "forte" ? b.tema.sobreDestaque : b.tema.texto
                anchors.verticalCenter: parent.verticalCenter
            }
            Text {
                visible: b.text !== ""
                text: b.text
                font: b.font
                color: b.tipo === "forte" ? b.tema.sobreDestaque : b.tema.texto
                opacity: b.enabled ? 1 : 0.7
                anchors.verticalCenter: parent.verticalCenter
            }
        }
    }
}
