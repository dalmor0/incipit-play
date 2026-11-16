// Ícones de traço do Incipit Play, desenhados em Shape (grade 24, traço 1,75). Sem logo de marca nenhuma:
// "controle", "tela", "placa", "engrenagem" e o resto são desenhos genéricos.
import QtQuick
import QtQuick.Shapes

Item {
    id: ic
    property string nome: ""
    property real tamanho: 20
    property color cor: "white"
    implicitWidth: tamanho
    implicitHeight: tamanho

    readonly property var caminhos: ({
        // controle genérico
        "controle": "M7 8h10a4 4 0 0 1 4 4v1.5a3.5 3.5 0 0 1-6.3 2.1L13.5 14h-3l-1.2 1.6A3.5 3.5 0 0 1 3 13.5V12a4 4 0 0 1 4-4z M7.5 10.5v3 M6 12h3 M15.5 11h.01 M17.5 13h.01",
        // monitor com seta de transmissão
        "tela": "M3 5h18v11H3z M8 20h8 M12 16v4",
        // placa de captura: caixa com cabo
        "placa": "M4 8h12v8H4z M16 12h4 M20 9v6 M7 11h3",
        "engrenagem": "M12 9a3 3 0 1 1 0 6a3 3 0 0 1 0-6z M12 2.5v3 M12 18.5v3 M2.5 12h3 M18.5 12h3 M5.3 5.3l2.1 2.1 M16.6 16.6l2.1 2.1 M5.3 18.7l2.1-2.1 M16.6 7.4l2.1-2.1",
        "mais": "M12 5v14 M5 12h14",
        "busca": "M10.5 4a6.5 6.5 0 1 1 0 13a6.5 6.5 0 0 1 0-13z M15.5 15.5L20 20",
        "atualizar": "M19 12a7 7 0 1 1-2.05-4.95 M19 4v4h-4",
        "energia": "M12 3v8 M7.05 6.05a7 7 0 1 0 9.9 0",
        "jogar": "M8 5l11 7l-11 7z",
        "externo": "M14 4h6v6 M20 4l-9 9 M18 14v6H4V6h6",
        "pessoa": "M12 4a4 4 0 1 1 0 8a4 4 0 0 1 0-8z M4 20c1.5-3.5 4.5-5 8-5s6.5 1.5 8 5",
        "pincel": "M4 20c3 0 5-1.5 5-4a2.5 2.5 0 0 0-5 0 M8.5 13.5L19 3l2 2l-10.5 10.5",
        "video": "M3 6h13v12H3z M16 10l5-3v10l-5-3",
        "info": "M12 3a9 9 0 1 1 0 18a9 9 0 0 1 0-18z M12 11v6 M12 7.5v.01",
        "fechar": "M6 6l12 12 M18 6L6 18",
        "lixo": "M4 7h16 M9 7V4h6v3 M6 7l1 13h10l1-13",
        "olho": "M2.5 12s3.5-6.5 9.5-6.5s9.5 6.5 9.5 6.5s-3.5 6.5-9.5 6.5S2.5 12 2.5 12z M12 9.5a2.5 2.5 0 1 1 0 5a2.5 2.5 0 0 1 0-5z",
        "chave": "M8 15a4 4 0 1 1 0-8a4 4 0 0 1 0 8z M12 11h9 M18 11v3 M15.5 11v2",
        "seta": "M5 12h14 M13 6l6 6l-6 6",
        "abaixo": "M6 9l6 6l6-6",
        "voltar": "M19 12H5 M11 6l-6 6l6 6",
        "check": "M5 12.5l4.5 4.5L19 7.5",
        "telacheia": "M4 9V4h5 M15 4h5v5 M20 15v5h-5 M9 20H4v-5",
        "som": "M4 9h4l5-4v14l-5-4H4z M16.5 8.5a5 5 0 0 1 0 7 M19 6a8.5 8.5 0 0 1 0 12"
    })

    Shape {
        anchors.fill: parent
        // o CurveRenderer deixava a abertura 7 s mais lenta; o comum com 4 amostras fica liso e rápido
        layer.enabled: true
        layer.samples: 4
        ShapePath {
            strokeColor: ic.cor
            strokeWidth: 1.75
            fillColor: ic.nome === "jogar" ? ic.cor : "transparent"
            capStyle: ShapePath.RoundCap
            joinStyle: ShapePath.RoundJoin
            scale: Qt.size(ic.tamanho / 24, ic.tamanho / 24)
            PathSvg { path: ic.caminhos[ic.nome] || "" }
        }
    }
}
