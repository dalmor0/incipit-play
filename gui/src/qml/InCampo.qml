// Campo de texto Incipit: rótulo em cima, caixa de 48 px, borda 3:1, foco visível, dica embaixo.
import QtQuick
import QtQuick.Layouts
import QtQuick.Controls.Basic as B

ColumnLayout {
    id: cp
    property string rotulo
    property string dica: ""
    property alias text: caixa.text
    property alias placeholderText: caixa.placeholderText
    property alias validator: caixa.validator
    property alias echoMode: caixa.echoMode
    property alias acceptableInput: caixa.acceptableInput
    property alias inputMethodHints: caixa.inputMethodHints
    property alias maximumLength: caixa.maximumLength
    property alias campo: caixa
    property real tamanhoFonte: 16
    readonly property var tema: root.tema
    spacing: 6

    InTexto { text: cp.rotulo; font.weight: Font.DemiBold; visible: cp.rotulo !== "" }
    B.TextField {
        id: caixa
        Layout.fillWidth: true
        implicitHeight: 48
        leftPadding: 14
        rightPadding: 14
        font.family: cp.tema.sans
        font.pixelSize: cp.tamanhoFonte
        color: cp.tema.texto
        placeholderTextColor: cp.tema.texto2
        selectionColor: cp.tema.destaque
        selectedTextColor: cp.tema.sobreDestaque
        Accessible.name: cp.rotulo
        background: Rectangle {
            color: cp.tema.fundo
            border.width: caixa.activeFocus ? 2 : 1
            border.color: caixa.activeFocus ? cp.tema.texto : (caixa.hovered ? cp.tema.texto2 : cp.tema.borda)
        }
    }
    InTexto { Layout.fillWidth: true; tipo: "pequeno"; text: cp.dica; visible: cp.dica !== "" }
}
