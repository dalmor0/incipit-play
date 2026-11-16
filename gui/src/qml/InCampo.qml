// Campo de texto Incipit: rótulo em cima, caixa de 48 px, borda 3:1, foco visível, dica embaixo.
import QtQuick
import QtQuick.Layouts
import QtQuick.Controls.Basic as B

ColumnLayout {
    id: cp
    property string rotulo
    property string dica: ""
    property alias text: campo.text
    property alias placeholderText: campo.placeholderText
    property alias validator: campo.validator
    property alias echoMode: campo.echoMode
    property alias acceptableInput: campo.acceptableInput
    property alias inputMethodHints: campo.inputMethodHints
    property alias maximumLength: campo.maximumLength
    property alias campo: campo
    property real tamanhoFonte: 16
    readonly property var tema: root.tema
    spacing: 6

    InTexto { text: cp.rotulo; font.weight: Font.DemiBold; visible: cp.rotulo !== "" }
    B.TextField {
        id: campo
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
            border.width: campo.activeFocus ? 2 : 1
            border.color: campo.activeFocus ? cp.tema.texto : (campo.hovered ? cp.tema.texto2 : cp.tema.borda)
        }
    }
    InTexto { Layout.fillWidth: true; tipo: "pequeno"; text: cp.dica; visible: cp.dica !== "" }
}
