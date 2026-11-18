// Marcar onde fica a câmera do jogador no clipe (o quadradinho do rosto, no OBS). Vale pra todos os clipes até mudar.
// Arraste um retângulo em cima do quadro; Salvar guarda em fração do quadro (0 a 1).
import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import QtQuick.Templates as T

import org.streetpea.chiaking

T.Dialog {
    id: d
    property var clipe: ({})
    readonly property var tema: root.tema
    readonly property var cfg: root.clipes
    property real x0: -1
    property real y0: -1
    property real x1: -1
    property real y1: -1
    readonly property bool temCaixa: x0 >= 0 && Math.abs(x1 - x0) > 0.03 && Math.abs(y1 - y0) > 0.03

    parent: Overlay.overlay
    x: Math.round((root.width - width) / 2)
    y: Math.max(16, Math.round((root.height - height) / 2))
    width: Math.min(880, root.width - 48, (root.height - 32 - 260) * 16 / 9 + 56)
    height: corpo.implicitHeight + topPadding + bottomPadding
    padding: 28
    topPadding: 24
    modal: true
    dim: true
    onOpened: {
        const c = cfg.camera;
        if (c.length === 4) { x0 = c[0]; y0 = c[1]; x1 = c[0] + c[2]; y1 = c[1] + c[3]; }
        else { x0 = y0 = x1 = y1 = -1; }
    }

    background: Rectangle { color: d.tema.sup; border.width: 1; border.color: d.tema.borda }
    Overlay.modal: Rectangle { color: Qt.rgba(0, 0, 0, 0.55) }

    contentItem: ColumnLayout {
        id: corpo
        spacing: 16
        Keys.onEscapePressed: d.close()
        Text {
            Layout.fillWidth: true
            text: root.t("Onde fica sua câmera?")
            textFormat: Text.PlainText
            wrapMode: Text.WordWrap
            font.family: d.tema.serif
            font.pixelSize: 26
            color: d.tema.texto
        }
        InTexto { Layout.fillWidth: true; tipo: "apoio"; text: root.t("Arraste um retângulo em volta da sua câmera. Ela vai pra parte de cima do vídeo e o jogo fica embaixo.") }

        Rectangle {
            id: quadro
            Layout.fillWidth: true
            Layout.preferredHeight: width * 9 / 16
            color: "black"
            Image {
                id: img
                anchors.fill: parent
                source: Edicao.quadroDoClipe(d.clipe.caminho || "")
                fillMode: Image.Stretch
                asynchronous: true
            }
            InTexto {
                anchors.centerIn: parent
                visible: img.status !== Image.Ready
                color: "white"
                text: root.t("Sem imagem desse clipe")
            }
            Rectangle {
                visible: d.x0 >= 0
                x: Math.min(d.x0, d.x1) * quadro.width
                y: Math.min(d.y0, d.y1) * quadro.height
                width: Math.abs(d.x1 - d.x0) * quadro.width
                height: Math.abs(d.y1 - d.y0) * quadro.height
                color: Qt.rgba(0.49, 0.69, 1, 0.18)
                border.width: 3
                border.color: d.tema.destaque
            }
            MouseArea {
                anchors.fill: parent
                cursorShape: Qt.CrossCursor
                function fx(v) { return Math.max(0, Math.min(1, v / quadro.width)); }
                function fy(v) { return Math.max(0, Math.min(1, v / quadro.height)); }
                onPressed: (m) => { d.x0 = d.x1 = fx(m.x); d.y0 = d.y1 = fy(m.y); }
                onPositionChanged: (m) => { if (pressed) { d.x1 = fx(m.x); d.y1 = fy(m.y); } }
            }
        }

        RowLayout {
            Layout.fillWidth: true
            spacing: 12
            InBotao {
                tipo: "quieto"
                visible: d.cfg.camera.length === 4
                text: root.t("Não tenho câmera")
                onClicked: { d.cfg.marcarCamera([]); d.close(); }
            }
            Item { Layout.fillWidth: true }
            InBotao { text: root.t("Cancelar"); onClicked: d.close() }
            InBotao {
                tipo: "forte"
                enabled: d.temCaixa
                text: root.t("Salvar câmera")
                onClicked: {
                    d.cfg.marcarCamera([Math.min(d.x0, d.x1), Math.min(d.y0, d.y1), Math.abs(d.x1 - d.x0), Math.abs(d.y1 - d.y0)]);
                    d.close();
                }
            }
        }
    }
}
