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
    // a margem vem da janela (não da página): com ou sem a coluna da direita, o título não pula ao trocar de aba
    readonly property real margem: (root.width || width) >= 1600 ? 56 : 40
    readonly property real largura: Math.min(width - margem * 2, 1280)

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

            // título e apoio à esquerda, ações à direita; na janela pequena as ações descem pra baixo do apoio
            GridLayout {
                readonly property bool estreito: pg.largura < 900
                Layout.fillWidth: true
                Layout.bottomMargin: 28
                columns: estreito ? 1 : 3
                columnSpacing: 24
                rowSpacing: 16
                ColumnLayout {
                    // encolhe quando os botões precisam do espaço (1280 e menor) e para em 720 px em tela larga
                    Layout.fillWidth: true
                    Layout.minimumWidth: 200
                    Layout.maximumWidth: 720
                    spacing: 8
                    Text {
                        text: pg.titulo
                        font.family: pg.tema.serif
                        font.pixelSize: 36
                        color: pg.tema.texto
                    }
                    Text {
                        Layout.fillWidth: true
                        Layout.maximumWidth: 680
                        visible: pg.apoio !== ""
                        text: pg.apoio
                        wrapMode: Text.WordWrap
                        font.family: pg.tema.sans
                        font.pixelSize: 16
                        lineHeight: 1.35
                        color: pg.tema.texto2
                    }
                }
                Item { visible: !parent.estreito; Layout.fillWidth: true; Layout.minimumWidth: 0 }
                Row {
                    id: acoesRow
                    Layout.alignment: parent.estreito ? (Qt.AlignTop | Qt.AlignLeft) : (Qt.AlignTop | Qt.AlignRight)
                    Layout.topMargin: parent.estreito ? 0 : 6
                    spacing: 12
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
