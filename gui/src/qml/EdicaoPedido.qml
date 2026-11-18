// "Mandar pra edição": a caixa onde a pessoa descreve o que quer (opcional) e escolhe o enquadramento e a legenda.
// Em branco, sai o padrão: câmera em cima e jogo embaixo (quando tem câmera), legenda, zoom nos picos e o melhor trecho.
import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import QtQuick.Controls.Basic as B
import QtQuick.Templates as T

import org.streetpea.chiaking

T.Dialog {
    id: d
    property var clipe: ({})                 // item da biblioteca: caminho, miniatura, segundos, criado
    readonly property var tema: root.tema
    readonly property var cfg: root.clipes
    signal marcarCamera(var clipe)

    parent: Overlay.overlay
    x: Math.round((root.width - width) / 2)
    y: Math.max(16, Math.round((root.height - height) / 2))
    width: Math.min(640, root.width - 48)
    height: Math.min(corpo.implicitHeight + topPadding + bottomPadding, root.height - 32)
    padding: 28
    topPadding: 24
    modal: true
    dim: true
    focus: true
    property string ultimoClipe: ""
    // volta da marcação da câmera com o texto que a pessoa já escreveu; clipe novo começa em branco
    onOpened: {
        if (clipe.caminho !== ultimoClipe) { pedido.text = ""; ultimoClipe = clipe.caminho || ""; }
        pedido.forceActiveFocus();
    }

    readonly property var layouts: [
        { id: "auto", nome: root.t("Automático") },
        { id: "camera", nome: root.t("Câmera em cima, jogo embaixo") },
        { id: "centro", nome: root.t("Jogo no centro, tela cheia") },
        { id: "desfocado", nome: root.t("Jogo inteiro, fundo desfocado") }
    ]
    readonly property var estilos: [
        { id: "creme", nome: root.t("Creme, palavra por palavra") },
        { id: "amarela", nome: root.t("Amarela, uma palavra por vez") },
        { id: "destaque", nome: root.t("Branca com a palavra dita em azul") },
        { id: "limpa", nome: root.t("Simples, frase inteira") },
        { id: "nenhuma", nome: root.t("Sem legenda") }
    ]
    readonly property var exemplos: [root.t("só a parte da fuga"), root.t("mais zoom"), root.t("título: FUGI DA POLÍCIA"), root.t("30 segundos")]

    function enviar() {
        const est = estilos[estilo.currentIndex].id;
        const ok = Edicao.editar(d.clipe.caminho, {
            pedido: pedido.text,
            layout: layouts[layout.currentIndex].id,
            estilo: est === "nenhuma" ? "" : est,
            semLegenda: est === "nenhuma",
            camera: cfg.camera,
            musica: cfg.guardado.edMusica
        });
        cfg.guardado.edLayout = layouts[layout.currentIndex].id;
        cfg.guardado.edEstilo = est;
        if (ok) d.close();
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

    contentItem: Flickable {
        implicitHeight: corpo.implicitHeight
        contentHeight: corpo.implicitHeight
        clip: true
        boundsBehavior: Flickable.StopAtBounds
        ScrollBar.vertical: ScrollBar { policy: contentHeight > height ? ScrollBar.AsNeeded : ScrollBar.AlwaysOff }

        ColumnLayout {
            id: corpo
            width: parent.width
            spacing: 16
            Keys.onEscapePressed: d.close()

            RowLayout {
                Layout.fillWidth: true
                spacing: 16
                Rectangle {
                    Layout.preferredWidth: 128
                    Layout.preferredHeight: 72
                    color: "black"
                    Image { anchors.fill: parent; source: d.clipe.miniatura || ""; fillMode: Image.PreserveAspectCrop; asynchronous: true; sourceSize.width: 256 }
                }
                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 4
                    Text {
                        Layout.fillWidth: true
                        text: root.t("Mandar pra edição")
                        textFormat: Text.PlainText
                        wrapMode: Text.WordWrap
                        font.family: d.tema.serif
                        font.pixelSize: 26
                        color: d.tema.texto
                    }
                    InTexto {
                        Layout.fillWidth: true
                        tipo: "pequeno"
                        text: d.clipe.criado ? Qt.formatDateTime(d.clipe.criado, root.lingua.en ? "MM/dd HH:mm" : "dd/MM HH:mm") + " · " + Math.round(d.clipe.segundos || 0) + " s" : ""
                    }
                }
            }

            ColumnLayout {
                Layout.fillWidth: true
                spacing: 6
                InTexto { text: root.t("Descreva o que você quer nesse vídeo"); font.weight: Font.DemiBold }
                B.TextArea {
                    id: pedido
                    Layout.fillWidth: true
                    Layout.preferredHeight: 96
                    wrapMode: TextEdit.Wrap
                    leftPadding: 14; rightPadding: 14; topPadding: 12; bottomPadding: 12
                    font.family: d.tema.sans
                    font.pixelSize: 16
                    color: d.tema.texto
                    placeholderText: root.t("Opcional. Ex.: só a parte da fuga, mais zoom, título: FUGI DA POLÍCIA")
                    placeholderTextColor: d.tema.texto2
                    selectionColor: d.tema.destaque
                    selectedTextColor: d.tema.sobreDestaque
                    Accessible.name: root.t("Descreva o que você quer nesse vídeo")
                    KeyNavigation.priority: KeyNavigation.BeforeItem
                    KeyNavigation.tab: layout
                    Keys.onReturnPressed: (e) => { if (e.modifiers & Qt.ControlModifier) d.enviar(); else e.accepted = false; }
                    onTextChanged: if (length > 500) remove(500, length)
                    background: Rectangle {
                        color: d.tema.fundo
                        border.width: pedido.activeFocus ? 2 : 1
                        border.color: pedido.activeFocus ? d.tema.texto : d.tema.borda
                    }
                }
                InTexto { Layout.fillWidth: true; tipo: "pequeno"; text: root.t("Em branco: o melhor trecho, legenda, zoom nos picos e sua câmera em cima.") }
                Flow {
                    Layout.fillWidth: true
                    spacing: 8
                    Repeater {
                        model: d.exemplos
                        delegate: InBotao {
                            required property string modelData
                            compacto: true
                            tipo: "quieto"
                            text: modelData
                            onClicked: { pedido.text = pedido.text.trim() === "" ? modelData : pedido.text.trim() + ", " + modelData; pedido.forceActiveFocus(); pedido.cursorPosition = pedido.length; }
                        }
                    }
                }
            }

            GridLayout {
                Layout.fillWidth: true
                columns: d.width > 560 ? 2 : 1
                columnSpacing: 16
                rowSpacing: 12
                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 6
                    InTexto { text: root.t("Enquadramento"); font.weight: Font.DemiBold }
                    InEscolha {
                        id: layout
                        Layout.fillWidth: true
                        model: d.layouts.map(x => x.nome)
                        currentIndex: Math.max(0, d.layouts.findIndex(x => x.id === d.cfg.guardado.edLayout))
                    }
                }
                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 6
                    InTexto { text: root.t("Legenda"); font.weight: Font.DemiBold }
                    InEscolha {
                        id: estilo
                        Layout.fillWidth: true
                        model: d.estilos.map(x => x.nome)
                        currentIndex: Math.max(0, d.estilos.findIndex(x => x.id === d.cfg.guardado.edEstilo))
                    }
                }
            }

            RowLayout {
                Layout.fillWidth: true
                spacing: 12
                InTexto {
                    Layout.fillWidth: true
                    tipo: "pequeno"
                    text: d.cfg.camera.length === 4 ? root.t("Sua câmera está marcada.") : root.t("O Play acha sua câmera sozinho. Se errar, marque.")
                }
                InBotao { text: d.cfg.camera.length === 4 ? root.t("Mudar câmera") : root.t("Marcar câmera"); icone: "video"; onClicked: { d.close(); d.marcarCamera(d.clipe); } }
            }

            InTexto {
                Layout.fillWidth: true
                visible: !Edicao.pacotePronto
                tipo: "pequeno"
                text: root.t("Na primeira vez o Play baixa o editor e o leitor de fala (uns 2 GB). Tudo fica e roda neste PC.")
            }

            RowLayout {
                Layout.fillWidth: true
                Layout.topMargin: 4
                spacing: 12
                Item { Layout.fillWidth: true }
                InBotao { text: root.t("Cancelar"); onClicked: d.close() }
                InBotao { tipo: "forte"; text: root.t("Editar"); icone: "video"; onClicked: d.enviar() }
            }
        }
    }
}
