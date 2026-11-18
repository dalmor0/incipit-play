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
    // câmera de canto, do tamanho comum de overlay (22% da largura, 16:9): cx/cy 0 = esquerda/cima, 1 = direita/baixo
    function canto(cx, cy) {
        const w = 0.22, h = 0.22;   // caixa 16:9 dentro de um quadro 16:9: mesma fração nos dois eixos
        x0 = cx ? 1 - w - 0.01 : 0.01; y0 = cy ? 1 - h - 0.02 : 0.02; x1 = x0 + w; y1 = y0 + h;
    }

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
    // véu próprio atrás da caixa: o da camada de diálogos não aparecia em todas as placas de vídeo
    property Item veu: Rectangle {
        parent: root.contentItem || root
        anchors.fill: parent
        z: 9000
        visible: d.visible
        color: Qt.rgba(0, 0, 0, 0.55)
    }

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
        InTexto { Layout.fillWidth: true; tipo: "apoio"; text: root.t("Arraste um retângulo em volta da sua câmera, ou escolha o canto. Ela vai pra parte de cima do vídeo e o jogo fica embaixo.") }

        Rectangle {
            id: quadro
            Layout.fillWidth: true
            Layout.preferredHeight: width * 9 / 16
            color: "black"
            // teclado: Tab chega aqui; setas movem a caixa e Shift+setas mudam o tamanho (passo de 1%)
            activeFocusOnTab: true
            Accessible.role: Accessible.Graphic
            Accessible.name: root.t("Área da câmera. Setas movem, Shift e setas mudam o tamanho.")
            function garantir() { if (d.x0 < 0) d.canto(1, 1); }
            function mover(dx, dy, tamanho) {
                garantir();
                const x = Math.min(d.x0, d.x1), y = Math.min(d.y0, d.y1);
                let w = Math.abs(d.x1 - d.x0), h = Math.abs(d.y1 - d.y0);
                if (tamanho) { w = Math.max(0.04, Math.min(1 - x, w + dx)); h = Math.max(0.04, Math.min(1 - y, h + dy)); d.x0 = x; d.y0 = y; d.x1 = x + w; d.y1 = y + h; }
                else { const nx = Math.max(0, Math.min(1 - w, x + dx)), ny = Math.max(0, Math.min(1 - h, y + dy)); d.x0 = nx; d.y0 = ny; d.x1 = nx + w; d.y1 = ny + h; }
            }
            Keys.onLeftPressed: (e) => mover(-0.01, 0, e.modifiers & Qt.ShiftModifier)
            Keys.onRightPressed: (e) => mover(0.01, 0, e.modifiers & Qt.ShiftModifier)
            Keys.onUpPressed: (e) => mover(0, -0.01, e.modifiers & Qt.ShiftModifier)
            Keys.onDownPressed: (e) => mover(0, 0.01, e.modifiers & Qt.ShiftModifier)
            Rectangle { visible: parent.activeFocus; anchors.fill: parent; anchors.margins: -4; color: "transparent"; border.width: 2; border.color: d.tema.texto }
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

        Flow {
            Layout.fillWidth: true
            spacing: 8
            InTexto { tipo: "pequeno"; text: root.t("Ou escolha o canto:"); height: 36; verticalAlignment: Text.AlignVCenter }
            InBotao { compacto: true; text: root.t("Em cima à esquerda"); onClicked: d.canto(0, 0) }
            InBotao { compacto: true; text: root.t("Em cima à direita"); onClicked: d.canto(1, 0) }
            InBotao { compacto: true; text: root.t("Embaixo à esquerda"); onClicked: d.canto(0, 1) }
            InBotao { compacto: true; text: root.t("Embaixo à direita"); onClicked: d.canto(1, 1) }
        }

        RowLayout {
            Layout.fillWidth: true
            spacing: 12
            InBotao {
                tipo: "quieto"
                text: d.cfg.camera.length === 4 ? root.t("Não tenho câmera") : root.t("Deixar o Play achar")
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
