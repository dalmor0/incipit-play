// Texto do Incipit Play. tipo: "corpo" (16), "apoio" (15, cor 2), "titulo" (20, seminegrito),
// "secao" (Young Serif 24), "rotulo" (13, maiúsculas espaçadas), "pequeno" (13, cor 2)
import QtQuick

Text {
    property string tipo: "corpo"
    readonly property var tema: root.tema
    wrapMode: Text.WordWrap
    textFormat: Text.PlainText
    font.family: tipo === "secao" ? tema.serif : tema.sans
    font.pixelSize: tipo === "titulo" ? 20 : tipo === "secao" ? 24 : tipo === "apoio" ? 15 : (tipo === "rotulo" || tipo === "pequeno") ? 13 : 16
    font.weight: tipo === "titulo" || tipo === "rotulo" ? Font.DemiBold : Font.Normal
    font.letterSpacing: tipo === "rotulo" ? 0.8 : 0
    font.capitalization: tipo === "rotulo" ? Font.AllUppercase : Font.MixedCase
    lineHeight: tipo === "corpo" || tipo === "apoio" ? 1.35 : 1.0
    color: tipo === "apoio" || tipo === "pequeno" || tipo === "rotulo" ? tema.texto2 : tema.texto
}
