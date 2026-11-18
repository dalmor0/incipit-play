// Aba Clipes · edição automática: o andamento ("o trenzinho"), o resultado pronto pra postar com o ajuste
// (trecho na linha do tempo, enquadramento, legenda, título) e os vídeos já editados.
import QtQuick
import QtQuick.Layouts
import QtQuick.Controls

import org.streetpea.chiaking

ColumnLayout {
    id: ed
    Layout.fillWidth: true
    spacing: 12
    readonly property var tema: root.tema
    readonly property var cfg: root.clipes
    readonly property string estado: Edicao.estado
    readonly property var res: Edicao.resultado
    property bool ajustando: false
    readonly property bool estragado: /corrompido|estragado|não é um vídeo/i.test(Edicao.motivo)
    readonly property bool soMenu: /menu ou tela parada/i.test(Edicao.motivo)
    property var editados: Edicao.editados(8)
    property real largura: 900
    signal pedirEdicao(var clipe)

    Connections {
        target: Edicao
        function onEditadosMudaram() { ed.editados = Edicao.editados(8); }
        function onTerminou(ok) { ed.ajustando = false; }
    }
    // a pasta dos clipes chega das Opções depois que a tela nasce: relê os editados quando a biblioteca muda
    Connections {
        target: Clips
        function onLibraryChanged() { ed.editados = Edicao.editados(8); }
    }
    Component.onCompleted: Qt.callLater(() => { ed.editados = Edicao.editados(8); })

    function nomeLayout(l) {
        return l === "camera" ? root.t("Câmera em cima, jogo embaixo") : l === "centro" ? root.t("Jogo no centro, tela cheia") : root.t("Jogo inteiro, fundo desfocado");
    }
    function tempo(s) { s = Math.max(0, Math.round(s || 0)); return Math.floor(s / 60) + ":" + String(s % 60).padStart(2, "0"); }

    // ------------------------------------------------------------ sem nada rodando: explica em uma linha
    InCartao {
        visible: ed.estado === "livre"
        RowLayout {
            Layout.fillWidth: true
            spacing: 16
            InIcone { nome: "video"; tamanho: 24; cor: ed.tema.destaque; Layout.alignment: Qt.AlignTop }
            ColumnLayout {
                Layout.fillWidth: true
                Layout.maximumWidth: Number.POSITIVE_INFINITY
                spacing: 4
                RowLayout {
                    spacing: 10
                    InTexto { tipo: "titulo"; text: root.t("Edição automática"); wrapMode: Text.NoWrap }
                    // primeira versão: a escolha do trecho e a legenda ainda erram em parte dos clipes
                    Rectangle {
                        Layout.alignment: Qt.AlignVCenter
                        implicitWidth: seloBeta.implicitWidth + 16
                        implicitHeight: 24
                        color: ed.tema.destaqueFraco
                        border.width: 1
                        border.color: ed.tema.destaque
                        Text { id: seloBeta; anchors.centerIn: parent; text: "Beta"; color: ed.tema.texto; font.family: ed.tema.sans; font.pixelSize: 13; font.weight: Font.Bold }
                    }
                }
                InTexto { Layout.fillWidth: true; tipo: "apoio"; text: root.t("Em qualquer clipe, clique em Mandar pra edição. Sai na vertical, com legenda, zoom nos picos e o melhor trecho, pronto pro Reels, TikTok e Shorts.") }
            }
        }
    }

    // ------------------------------------------------------------ andamento
    InCartao {
        visible: ed.estado === "baixando" || ed.estado === "editando" || ed.estado === "fila"
        RowLayout {
            Layout.fillWidth: true
            spacing: 16
            ColumnLayout {
                Layout.fillWidth: true
                Layout.maximumWidth: Number.POSITIVE_INFINITY
                spacing: 4
                InTexto {
                    Layout.fillWidth: true
                    tipo: "titulo"
                    text: ed.estado === "fila" ? root.t("Na fila da edição") : ed.estado === "baixando" ? root.t("Preparando o editor") : root.t("Editando seu clipe")
                }
                InTexto {
                    Layout.fillWidth: true
                    tipo: "apoio"
                    text: ed.estado === "fila" ? root.t("A edição começa quando você sair do jogo, pra não pesar na transmissão.") : root.t(Edicao.etapa)
                }
            }
            InTexto {
                // durante o download do leitor de fala o texto já diz os MB; a % geral confundia (banca r1)
                visible: ed.estado !== "fila" && !String(Edicao.etapa).startsWith("Baixando o leitor")
                tipo: "titulo"
                text: Math.floor(Edicao.pct) + "%"
                Layout.alignment: Qt.AlignVCenter
            }
            InBotao { visible: ed.estado === "fila"; text: root.t("Editar agora mesmo assim"); Layout.alignment: Qt.AlignVCenter; onClicked: Edicao.editarAgora() }
            InBotao { text: root.t("Cancelar"); Layout.alignment: Qt.AlignVCenter; enabled: Edicao.etapa !== "Cancelando"; onClicked: Edicao.cancelar() }
        }
        Rectangle {
            visible: ed.estado !== "fila"
            Layout.fillWidth: true
            Layout.preferredHeight: 8
            color: ed.tema.fundo
            border.width: 1
            border.color: ed.tema.linha
            Rectangle {
                anchors { left: parent.left; top: parent.top; bottom: parent.bottom; margins: 1 }
                width: Math.max(0, (parent.width - 2) * Edicao.pct / 100)
                color: ed.tema.destaque
                Behavior on width { enabled: !root.semMovimento; NumberAnimation { duration: 250 } }
            }
            Accessible.role: Accessible.ProgressBar
            Accessible.name: root.t("Andamento da edição")
        }
    }

    // ------------------------------------------------------------ erro
    InCartao {
        visible: ed.estado === "erro"
        corFio: ed.soMenu ? "transparent" : ed.tema.alerta
        RowLayout {
            Layout.fillWidth: true
            spacing: 16
            InIcone { nome: ed.soMenu ? "info" : "alerta"; tamanho: 24; cor: ed.soMenu ? ed.tema.destaque : ed.tema.alerta; Layout.alignment: Qt.AlignTop }
            ColumnLayout {
                Layout.fillWidth: true
                Layout.maximumWidth: Number.POSITIVE_INFINITY
                spacing: 4
                InTexto { Layout.fillWidth: true; tipo: "titulo"; text: ed.soMenu ? root.t("Esse clipe não tem jogada pra cortar") : root.t("Não deu pra editar") }
                InTexto { Layout.fillWidth: true; tipo: "apoio"; text: root.t(Edicao.motivo) }
                InTexto {
                    Layout.fillWidth: true
                    tipo: "pequeno"
                    visible: Edicao.clipe !== "" && !ed.soMenu
                    text: root.t("Se o clipe não abre no seu player, ele veio estragado e não dá pra editar. Se abre, tente de novo.")
                }
            }
            InBotao { text: root.t("Fechar"); Layout.alignment: Qt.AlignTop; onClicked: Edicao.fechar() }
            InBotao { visible: Edicao.clipe !== ""; Layout.alignment: Qt.AlignTop; tipo: ed.estragado ? "forte" : "normal"; text: root.t("Abrir pasta do clipe"); icone: "externo"; onClicked: Edicao.abrirPasta(String(Edicao.clipe).replace(/[\\\/][^\\\/]*$/, "")) }
            InBotao { tipo: ed.estragado ? "normal" : "forte"; Layout.alignment: Qt.AlignTop; text: root.t("Tentar de novo"); visible: Edicao.clipe !== "" && !ed.soMenu; onClicked: { Edicao.fechar(); ed.pedirEdicao({ caminho: Edicao.clipe, miniatura: Edicao.quadroDoClipe(Edicao.clipe) }); } }
        }
    }

    // ------------------------------------------------------------ pronto
    InCartao {
        visible: ed.estado === "pronto"
        RowLayout {
            Layout.fillWidth: true
            spacing: 24
            Rectangle {
                Layout.alignment: Qt.AlignTop
                Layout.preferredWidth: 162
                Layout.preferredHeight: 288
                color: "black"
                Image {
                    anchors.fill: parent
                    source: ed.res.miniaturaUrl || ""
                    fillMode: Image.PreserveAspectFit
                    asynchronous: true
                    cache: false
                }
                Rectangle {
                    anchors.centerIn: parent
                    width: 56; height: 56; radius: 28
                    color: Qt.rgba(0, 0, 0, 0.6)
                    InIcone { anchors.centerIn: parent; nome: "jogar"; tamanho: 26; cor: "white" }
                }
                MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: Edicao.abrirVideo(ed.res.arquivo) }
                Accessible.role: Accessible.Button
                Accessible.name: root.t("Assistir o vídeo editado")
            }
            ColumnLayout {
                Layout.fillWidth: true
                Layout.fillHeight: true
                Layout.maximumWidth: Number.POSITIVE_INFINITY
                Layout.alignment: Qt.AlignTop
                spacing: 8
                InTexto { Layout.fillWidth: true; tipo: "titulo"; text: root.t("Pronto pra postar") }
                InTexto {
                    Layout.fillWidth: true
                    tipo: "apoio"
                    text: root.t("%1 s, de %2 a %3 do clipe. %4.").arg(Math.round(ed.res.duracao || 0)).arg(ed.tempo(ed.res.inicio)).arg(ed.tempo(ed.res.fim)).arg(ed.nomeLayout(ed.res.layout))
                }
                InTexto {
                    Layout.fillWidth: true
                    tipo: "pequeno"
                    visible: !!ed.res.entendi && ed.res.entendi.length > 0
                    text: root.t("Do seu pedido: ") + (ed.res.entendi || []).map(x => root.t(x)).join(" · ")
                }
                InTexto {
                    Layout.fillWidth: true
                    tipo: "pequeno"
                    visible: !!ed.res.aviso
                    color: ed.tema.alerta
                    text: root.t(ed.res.aviso || "")
                }
                InTexto { Layout.fillWidth: true; tipo: "pequeno"; text: root.t("MP4 1080x1920, H.264, áudio no volume das redes. Salvo em %1").arg(String(ed.res.arquivo || "").replace(/[\\\/][^\\\/]*$/, "")); elide: Text.ElideMiddle; wrapMode: Text.NoWrap }
                Item { Layout.fillHeight: true }
                Flow {
                    Layout.fillWidth: true
                    spacing: 12
                    InBotao { tipo: ed.ajustando ? "normal" : "forte"; text: root.t("Abrir pasta"); icone: "externo"; onClicked: Edicao.mostrarNaPasta(ed.res.arquivo) }
                    InBotao { text: root.t("Assistir"); icone: "jogar"; onClicked: Edicao.abrirVideo(ed.res.arquivo) }
                    InBotao { text: ed.ajustando ? root.t("Fechar ajuste") : root.t("Ajustar"); icone: "pincel"; onClicked: ed.ajustando = !ed.ajustando }
                    InBotao { tipo: "quieto"; text: root.t("Concluir"); onClicked: Edicao.fechar() }
                }
            }
        }

        // ---------------- ajuste: trecho na linha do tempo, enquadramento, legenda e título
        ColumnLayout {
            id: aj
            visible: ed.ajustando
            Layout.fillWidth: true
            Layout.topMargin: 8
            spacing: 14
            readonly property real total: ed.res.duracao_origem || 1
            property real ini: ed.res.inicio || 0
            property real fim: ed.res.fim || total
            onVisibleChanged: if (visible) { ini = ed.res.inicio || 0; fim = ed.res.fim || total; titulo.text = ed.res.titulo || ""; }

            Rectangle { Layout.fillWidth: true; height: 1; color: ed.tema.linha }
            RowLayout {
                Layout.fillWidth: true
                InTexto { text: root.t("Trecho"); font.weight: Font.DemiBold }
                Item { Layout.fillWidth: true }
                InTexto { tipo: "pequeno"; text: ed.tempo(aj.ini) + " a " + ed.tempo(aj.fim) + " · " + Math.round(aj.fim - aj.ini) + " s" }
            }
            // linha do tempo: volume do clipe inteiro, com o trecho escolhido e duas alças
            Item {
                id: linha
                Layout.fillWidth: true
                Layout.preferredHeight: 64
                readonly property var onda: ed.res.onda || []
                Rectangle { anchors.fill: parent; color: ed.tema.fundo; border.width: 1; border.color: ed.tema.linha }
                Row {
                    anchors { fill: parent; margins: 1 }
                    Repeater {
                        model: linha.onda.length
                        delegate: Item {
                            required property int index
                            width: (linha.width - 2) / Math.max(1, linha.onda.length)
                            height: linha.height - 2
                            readonly property real t: (index + 0.5) / linha.onda.length * aj.total
                            Rectangle {
                                anchors.bottom: parent.bottom
                                anchors.horizontalCenter: parent.horizontalCenter
                                width: Math.max(1, parent.width - 1)
                                height: Math.max(2, linha.onda[index] * (parent.height - 6))
                                color: (parent.t >= aj.ini && parent.t <= aj.fim) ? ed.tema.destaque : ed.tema.borda
                            }
                        }
                    }
                }
                Rectangle {
                    x: aj.ini / aj.total * linha.width
                    width: (aj.fim - aj.ini) / aj.total * linha.width
                    height: linha.height
                    color: "transparent"
                    border.width: 2
                    border.color: ed.tema.texto
                }
                Repeater {
                    model: 2
                    delegate: Rectangle {
                        required property int index
                        readonly property bool comeco: index === 0
                        x: Math.max(0, Math.min(linha.width - width, (comeco ? aj.ini : aj.fim) / aj.total * linha.width - width / 2))
                        y: -6
                        width: 20
                        height: linha.height + 12
                        color: ed.tema.texto
                        Accessible.role: Accessible.Slider
                        Accessible.name: comeco ? root.t("Começo do trecho") : root.t("Fim do trecho")
                        activeFocusOnTab: true
                        Keys.onLeftPressed: mover(-0.5)
                        Keys.onRightPressed: mover(0.5)
                        Rectangle { visible: parent.activeFocus; anchors.fill: parent; anchors.margins: -4; color: "transparent"; border.width: 2; border.color: ed.tema.destaque }
                        function mover(d) {
                            if (comeco) aj.ini = Math.max(0, Math.min(aj.fim - 3, aj.ini + d));
                            else aj.fim = Math.min(aj.total, Math.max(aj.ini + 3, aj.fim + d));
                        }
                        MouseArea {
                            anchors.fill: parent
                            anchors.margins: -8
                            cursorShape: Qt.SizeHorCursor
                            onPositionChanged: (m) => {
                                if (!pressed) return;
                                const p = parent.mapToItem(linha, m.x, 0).x / linha.width * aj.total;
                                if (parent.comeco) aj.ini = Math.max(0, Math.min(aj.fim - 3, p));
                                else aj.fim = Math.min(aj.total, Math.max(aj.ini + 3, p));
                            }
                        }
                    }
                }
            }
            GridLayout {
                Layout.fillWidth: true
                columns: ed.largura > 760 ? 3 : 1
                columnSpacing: 16
                rowSpacing: 12
                ColumnLayout {
                    Layout.fillWidth: true
                    Layout.preferredWidth: 1
                    Layout.alignment: Qt.AlignTop
                    spacing: 6
                    InTexto { text: root.t("Enquadramento"); font.weight: Font.DemiBold }
                    InEscolha {
                        id: ajLayout
                        Layout.fillWidth: true
                        implicitHeight: 48
                        readonly property var ids: ["camera", "centro", "desfocado"]
                        model: ids.map(x => ed.nomeLayout(x))
                        currentIndex: Math.max(0, ids.indexOf(ed.res.layout))
                    }
                }
                ColumnLayout {
                    Layout.fillWidth: true
                    Layout.preferredWidth: 1
                    Layout.alignment: Qt.AlignTop
                    spacing: 6
                    InTexto { text: root.t("Legenda"); font.weight: Font.DemiBold }
                    InEscolha {
                        id: ajEstilo
                        Layout.fillWidth: true
                        implicitHeight: 48
                        readonly property var ids: ["creme", "amarela", "destaque", "limpa", "nenhuma"]
                        model: [root.t("Creme (padrão)"), root.t("Amarela"), root.t("Palavra em azul"), root.t("Simples"), root.t("Sem legenda")]
                        currentIndex: ed.res.legenda === false ? 4 : Math.max(0, ids.indexOf(ed.res.estilo))
                    }
                }
                InCampo {
                    id: titulo
                    Layout.fillWidth: true
                    Layout.preferredWidth: 1
                    Layout.alignment: Qt.AlignTop
                    tamanhoFonte: 15
                    rotulo: root.t("Título na tela")
                    placeholderText: root.t("Opcional")
                    maximumLength: 60
                }
            }
            RowLayout {
                Layout.fillWidth: true
                spacing: 12
                InTexto { Layout.fillWidth: true; Layout.maximumWidth: Number.POSITIVE_INFINITY; tipo: "pequeno"; text: root.t("Refazer usa a fala já lida: sai bem mais rápido.") }
                InBotao {
                    tipo: "forte"
                    text: root.t("Refazer")
                    icone: "video"
                    onClicked: {
                        const est = ajEstilo.ids[ajEstilo.currentIndex];
                        Edicao.editar(ed.res.origem, {
                            pedido: ed.res.pedido || "",
                            layout: ajLayout.ids[ajLayout.currentIndex],
                            estilo: est === "nenhuma" ? "" : est,
                            semLegenda: est === "nenhuma",
                            titulo: titulo.text,
                            inicio: aj.ini, fim: aj.fim,
                            camera: ed.res.camera && ed.res.camera.length === 4 ? ed.res.camera : ed.cfg.camera,
                            musica: ed.cfg.guardado.edMusica
                        });
                    }
                }
            }
        }
    }

    // ------------------------------------------------------------ editados
    ColumnLayout {
        Layout.fillWidth: true
        Layout.topMargin: 12
        visible: ed.editados.length > 0
        spacing: 12
        RowLayout {
            Layout.fillWidth: true
            spacing: 12
            InTexto { tipo: "rotulo"; text: root.t("Editados"); Layout.alignment: Qt.AlignBaseline; wrapMode: Text.NoWrap }
            InTexto { tipo: "pequeno"; Layout.alignment: Qt.AlignBaseline; text: ed.editados.length === 1 ? root.t("1 vídeo") : root.t("%1 vídeos").arg(ed.editados.length); wrapMode: Text.NoWrap }
            Item { Layout.fillWidth: true }
            InBotao { tipo: "quieto"; text: root.t("Pasta dos editados"); icone: "externo"; onClicked: Edicao.mostrarNaPasta("") }
        }
        Flow {
            Layout.fillWidth: true
            spacing: 16
            Repeater {
                // uma linha só: os mais novos que cabem na largura; o resto fica em "Abrir pasta"
                model: ed.editados.slice(0, Math.max(1, Math.floor((ed.largura + 16) / 228)))
                delegate: Rectangle {
                    id: ce
                    required property var modelData
                    // os cartões enchem a linha inteira (sem sobra de 72 px no fim)
                    readonly property int nCartoes: Math.max(1, Math.floor((ed.largura + 16) / 228))
                    width: Math.floor((ed.largura - 16 * (nCartoes - 1)) / nCartoes)
                    height: colE.implicitHeight
                    color: ed.tema.sup
                    border.width: 1
                    border.color: ed.tema.linha
                    ColumnLayout {
                        id: colE
                        width: parent.width
                        spacing: 0
                        Rectangle {
                            Layout.fillWidth: true
                            Layout.preferredHeight: width * 16 / 9
                            Layout.margins: 1
                            color: "black"
                            Image { anchors.fill: parent; source: ce.modelData.miniatura || ""; fillMode: Image.PreserveAspectCrop; asynchronous: true; sourceSize.width: 360; cache: false }
                            MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: Edicao.abrirVideo(ce.modelData.arquivo) }
                        }
                        RowLayout {
                            Layout.fillWidth: true
                            Layout.margins: 8
                            spacing: 8
                            InTexto { Layout.fillWidth: true; tipo: "pequeno"; text: Math.round(ce.modelData.duracao || 0) + " s · " + Qt.formatDateTime(ce.modelData.criado, "HH:mm"); wrapMode: Text.NoWrap; elide: Text.ElideRight }
                            InBotao {
                                tipo: "quieto"; icone: "externo"
                                Accessible.name: root.t("Mostrar na pasta")
                                ToolTip.visible: hovered; ToolTip.text: root.t("Mostrar na pasta")
                                onClicked: Edicao.mostrarNaPasta(ce.modelData.arquivo)
                            }
                            InBotao {
                                tipo: "quieto"; icone: "lixo"
                                Accessible.name: root.t("Apagar vídeo editado")
                                ToolTip.visible: hovered; ToolTip.text: root.t("Apagar (vai pra Lixeira)")
                                onClicked: root.showConfirmDialog(root.t("Apagar vídeo editado"), root.t("Mandar este vídeo editado pra Lixeira do Windows? O clipe original fica."), () => Edicao.apagarEditado(ce.modelData.arquivo))
                            }
                        }
                    }
                }
            }
        }
    }
}
