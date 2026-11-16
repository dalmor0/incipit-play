// Esqueleto de página: título em Young Serif, uma linha de apoio, ações à direita e o conteúdo rolando embaixo.
import QtQuick
import QtQuick.Layouts
import QtQuick.Controls

Item {
    id: pg
    property string titulo
    property string apoio
    property alias acoes: acoesRow.data
    default property alias conteudo: coluna.data
    readonly property var tema: root.tema
    readonly property real margem: width >= 1400 ? 56 : 40
    readonly property real largura: Math.min(width - margem * 2, 1080)

    Flickable {
        id: rolagem
        anchors.fill: parent
        contentWidth: width
        contentHeight: corpo.implicitHeight + 64
        clip: true
        boundsBehavior: Flickable.StopAtBounds
        ScrollBar.vertical: ScrollBar { policy: rolagem.contentHeight > rolagem.height ? ScrollBar.AsNeeded : ScrollBar.AlwaysOff }

        ColumnLayout {
            id: corpo
            x: pg.margem
            y: 40
            width: pg.largura
            spacing: 0

            RowLayout {
                Layout.fillWidth: true
                Layout.bottomMargin: 28
                spacing: 24
                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 8
                    Text {
                        text: pg.titulo
                        font.family: pg.tema.serif
                        font.pixelSize: 36
                        color: pg.tema.texto
                    }
                    Text {
                        Layout.fillWidth: true
                        visible: pg.apoio !== ""
                        text: pg.apoio
                        wrapMode: Text.WordWrap
                        font.family: pg.tema.sans
                        font.pixelSize: 16
                        lineHeight: 1.35
                        color: pg.tema.texto2
                    }
                }
                Row {
                    id: acoesRow
                    Layout.alignment: Qt.AlignTop | Qt.AlignRight
                    Layout.topMargin: 6
                    spacing: 10
                }
            }

            ColumnLayout {
                id: coluna
                Layout.fillWidth: true
                spacing: 16
            }
        }
    }
}
