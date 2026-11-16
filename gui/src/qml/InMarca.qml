// A porta-I da Incipit (mesmo desenho do Hub), em degradê da cor do tema.
import QtQuick
import QtQuick.Shapes

Item {
    id: m
    property real altura: 28
    readonly property var tema: root.tema
    implicitHeight: altura
    implicitWidth: altura * 39.58 / 96

    Shape {
        anchors.fill: parent
        // o CurveRenderer deixava a abertura 7 s mais lenta; o comum com 4 amostras fica liso e rápido
        layer.enabled: true
        layer.samples: 4
        ShapePath {
            strokeWidth: -1
            scale: Qt.size(m.width / 39.58, m.height / 96)
            fillGradient: LinearGradient {
                x1: 0; y1: 96; x2: 0; y2: 0
                GradientStop { position: 0; color: m.tema.porta1 }
                GradientStop { position: 0.55; color: m.tema.porta2 }
                GradientStop { position: 1; color: m.tema.porta3 }
            }
            PathSvg { path: "M0 0H39.58V16.32H0Z M0 79.68H39.58V96H0Z M9.37 79.68V34.36A20.83 20.83 0 0 1 19.79 16.32A20.83 20.83 0 0 1 30.21 34.36V79.68Z" }
        }
    }
}
