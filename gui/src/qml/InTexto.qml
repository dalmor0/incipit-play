// Texto do Incipit Play. tipo: "corpo" (16), "apoio" (15, cor 2), "titulo" (20, seminegrito),
// "secao" (Young Serif 24), "rotulo" (13, maiúsculas espaçadas), "pequeno" (13, cor 2)
import QtQuick
import QtQuick.Layouts

Text {
    property string tipo: "corpo"
    readonly property var tema: root.tema
    wrapMode: Text.WordWrap
    textFormat: Text.PlainText
    font.family: tipo === "secao" ? tema.serif : tema.sans
    font.pixelSize: tipo === "titulo" ? 20 : tipo === "secao" ? 24 : tipo === "apoio" ? 15 : tipo === "rotulo" ? 15 : tipo === "pequeno" ? 14 : 16
    font.weight: tipo === "titulo" || tipo === "rotulo" ? Font.DemiBold : Font.Normal
    Layout.maximumWidth: (tipo === "apoio" || tipo === "corpo" || tipo === "pequeno") ? 680 : Number.POSITIVE_INFINITY
    lineHeight: tipo === "corpo" || tipo === "apoio" ? 1.35 : 1.0
    color: tipo === "apoio" || tipo === "pequeno" ? tema.texto2 : tema.texto
}
