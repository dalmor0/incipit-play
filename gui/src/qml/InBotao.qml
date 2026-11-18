// Botão do Incipit Play: botão de verdade, canto reto, 44 px de altura mínima, foco visível.
// tipo: "forte" (ação principal, um por tela, no azul do logo), "normal" (contorno), "quieto" (sem borda, ação de linha)
// ou "perigo" (apagar, desconectar: contorno e texto no vermelho, longe do forte)
import QtQuick
import QtQuick.Templates as T

T.AbstractButton {
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
    Keys.onReturnPressed: clicked()
    Keys.onEnterPressed: clicked()
    Accessible.name: text

    readonly property bool forte: tipo === "forte"
    background: Rectangle {
        // forte: o azul do logo, sem borda; contorno: borda de controle; quieto: só o fundo ao passar o mouse
        gradient: b.forte ? fundoForte : null
        color: b.forte ? "transparent" : b.tipo === "perigo" ? (b.hovered || b.down ? b.tema.erroFundo : "transparent")
             : b.down ? b.tema.linha : (b.hovered ? b.tema.sup3 : "transparent")
        border.width: b.forte || b.tipo === "quieto" ? 0 : 1
        border.color: b.tipo === "perigo" ? b.tema.alerta : b.hovered ? b.tema.texto2 : b.tema.borda
        opacity: b.enabled ? 1 : 0.45
        Gradient {
            id: fundoForte
            GradientStop { position: 0; color: b.down ? b.tema.fortePreso : b.hovered ? b.tema.forteMouse : b.tema.forte1 }
            GradientStop { position: 1; color: b.down ? b.tema.fortePreso : b.hovered ? b.tema.forteMouse : b.tema.forte2 }
        }
        Rectangle {
            visible: b.visualFocus
            anchors.fill: parent
            anchors.margins: -4
            color: "transparent"
            border.width: 2
            border.color: b.tema.foco
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
                cor: b.forte ? b.tema.sobreForte : b.tipo === "perigo" ? b.tema.alerta : b.tema.texto
                anchors.verticalCenter: parent.verticalCenter
            }
            Text {
                visible: b.text !== ""
                text: b.text
                font: b.font
                color: b.forte ? b.tema.sobreForte : b.tipo === "perigo" ? b.tema.alerta : b.tema.texto
                opacity: b.enabled ? 1 : 0.7
                anchors.verticalCenter: parent.verticalCenter
            }
        }
    }
}
