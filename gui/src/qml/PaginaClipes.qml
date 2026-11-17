// Aba Clipes: o atalho que guarda os últimos segundos, a biblioteca e o caminho pra edição.
import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import QtQuick.Dialogs
import QtQuick.Templates as T

import org.streetpea.chiaking

InPagina {
    id: cl
    titulo: root.t("Clipes")
    apoio: root.t("Apertou o atalho, o app guarda os últimos %1 s do jogo, sem perder qualidade.").arg(root.clipes.segundos)

    readonly property var cfg: root.clipes
    property var lista: Clips.library()
    property string aviso: ""
    property bool avisoBom: true
    property bool mostrarOpcoes: false
    function recarregar() { lista = Clips.library(); }
    function avisar(t, bom) { aviso = t; avisoBom = bom; }

    Connections {
        target: Clips
        function onLibraryChanged() { cl.recarregar(); }
        function onClipFailed(r) { cl.avisar(root.t(r), false); }
        function onObsStatus(t, ok) { cl.avisar(root.t(t), ok); }
    }

    acoes: [
        InBotao { text: cl.mostrarOpcoes ? root.t("Fechar opções") : root.t("Opções"); icone: "engrenagem"; onClicked: cl.mostrarOpcoes = !cl.mostrarOpcoes }
    ]

    // ------------------------------------------------------------ estado do atalho
    InCartao {
        marcado: cl.cfg.ligado && Clips.hotkeyActive
        RowLayout {
            Layout.fillWidth: true
            spacing: 20
            Rectangle {
                Layout.preferredWidth: tecla.implicitWidth + 28
                Layout.preferredHeight: 44
                color: root.tema.fundo
                border.width: 1
                border.color: Clips.hotkeyActive ? root.tema.destaque : root.tema.borda
                InTexto { id: tecla; anchors.centerIn: parent; text: cl.cfg.atalho; font.weight: Font.Bold; wrapMode: Text.NoWrap }
            }
            ColumnLayout {
                Layout.fillWidth: true
                Layout.maximumWidth: Number.POSITIVE_INFINITY   // a coluna estica mesmo com parágrafo de 680 px; o botão fica na borda
                spacing: 4
                InTexto {
                    Layout.fillWidth: true
                    tipo: "titulo"
                    text: !cl.cfg.ligado ? root.t("Clipes desligados")
                        : !Clips.hotkeyActive ? root.t("%1 já é de outro programa").arg(cl.cfg.atalho)
                        : Clips.streaming ? root.t("Gravando o jogo agora") : root.t("Pronto pra clipar")
                }
                InTexto {
                    Layout.fillWidth: true
                    tipo: "apoio"
                    text: !cl.cfg.ligado ? root.t("Ligue pra o atalho funcionar.")
                        : !Clips.hotkeyActive ? root.t("O app do NVIDIA usa Alt+F10 pro replay dele. Escolha outro atalho em Opções.")
                        : Clips.streaming ? root.t("No PlayStation o vídeo fica guardado na memória (agora %1 MB). Na aba Switch, a placa grava enquanto está aberta.").arg(Clips.bufferMegabytes)
                        : (cl.cfg.guardado.obs ? root.t("Funciona com o app minimizado, durante o jogo do PlayStation e da placa de captura e no OBS.") : root.t("Funciona com o app minimizado, durante o jogo do PlayStation e da placa de captura."))
                }
            }
            InBotao {
                visible: Clips.streaming
                tipo: "forte"
                text: root.t("Salvar agora")
                icone: "video"
                onClicked: Clips.saveNow()
            }
            InBotao {
                text: cl.cfg.ligado ? root.t("Desligar") : root.t("Ligar")
                tipo: cl.cfg.ligado ? "quieto" : "forte"
                onClicked: cl.cfg.ligar(!cl.cfg.ligado)
            }
        }
        InTexto {
            Layout.fillWidth: true
            visible: cl.aviso !== ""
            tipo: "pequeno"
            color: cl.avisoBom ? root.tema.ok : root.tema.alerta
            text: cl.aviso
        }
    }

    // ------------------------------------------------------------ opções
    InCartao {
        visible: cl.mostrarOpcoes
        GridLayout {
            Layout.fillWidth: true
            columns: 2
            columnSpacing: 24
            rowSpacing: 14

            InTexto { text: root.t("Atalho"); font.weight: Font.DemiBold; Layout.preferredWidth: 180; Layout.alignment: Qt.AlignVCenter }
            InEscolha {
                Layout.preferredWidth: 320
                model: cl.cfg.atalhos
                currentIndex: Math.max(0, cl.cfg.atalhos.indexOf(cl.cfg.atalho))
                onActivated: (i) => {
                    const ok = cl.cfg.mudarAtalho(cl.cfg.atalhos[i]);
                    cl.avisar(ok ? root.t("Atalho trocado pra %1.").arg(cl.cfg.atalhos[i]) : root.t("%1 já é de outro programa. Escolha outro.").arg(cl.cfg.atalhos[i]), ok);
                }
            }

            InTexto { text: root.t("Quanto guardar"); font.weight: Font.DemiBold; Layout.alignment: Qt.AlignVCenter }
            InEscolha {
                Layout.preferredWidth: 320
                model: cl.cfg.duracoes.map(s => (s < 60 ? root.t("%1 segundos").arg(s) : s === 60 ? root.t("1 minuto") : root.t("%1 minutos").arg(s % 60 ? root.numero((s / 60).toFixed(1)) : s / 60)) + (s === 90 ? " " + root.t("(padrão)") : ""))
                currentIndex: Math.max(0, cl.cfg.duracoes.indexOf(cl.cfg.segundos))
                onActivated: (i) => cl.cfg.mudarSegundos(cl.cfg.duracoes[i])
            }

            InTexto { text: root.t("Pasta dos clipes"); font.weight: Font.DemiBold; Layout.alignment: Qt.AlignVCenter }
            RowLayout {
                spacing: 12
                InTexto { Layout.maximumWidth: 420; text: Clips.clipsDir(); tipo: "apoio"; elide: Text.ElideMiddle; wrapMode: Text.NoWrap }
                InBotao { text: root.t("Trocar"); onClicked: { escolhaPasta.paraEdicao = false; escolhaPasta.open(); } }
            }

            InTexto { text: root.t("Pasta da edição"); font.weight: Font.DemiBold; Layout.alignment: Qt.AlignVCenter }
            RowLayout {
                spacing: 12
                InTexto { Layout.maximumWidth: 420; text: cl.cfg.pastaEdicao || root.t("ainda não escolhida"); tipo: "apoio"; elide: Text.ElideMiddle; wrapMode: Text.NoWrap }
                InBotao { text: root.t("Escolher"); onClicked: { escolhaPasta.paraEdicao = true; escolhaPasta.open(); } }
            }
        }

        Rectangle { Layout.fillWidth: true; Layout.topMargin: 8; height: 1; color: root.tema.linha }

        InTexto { tipo: "titulo"; text: root.t("Lives no OBS") }
        InTexto {
            Layout.fillWidth: true
            tipo: "apoio"
            text: root.t("Com o OBS aberto, o mesmo atalho também salva o Replay Buffer dele. No OBS: Ferramentas > Configurações do servidor WebSocket > Habilitar, e ligue o Replay Buffer em Controles.")
        }
        RowLayout {
            Layout.fillWidth: true
            spacing: 12
            InOpcao { texto: root.t("Salvar no OBS também"); marcada: cl.cfg.guardado.obs; onClicked: cl.cfg.mudarObs(!cl.cfg.guardado.obs, Number(porta.text) || 4455, senha.text) }
            InCampo { id: porta; Layout.preferredWidth: 120; placeholderText: "porta"; text: String(cl.cfg.guardado.obsPorta); validator: IntValidator { bottom: 1; top: 65535 } }
            InCampo { id: senha; Layout.preferredWidth: 240; placeholderText: root.t("senha do WebSocket"); text: Clips.obsPassword(); echoMode: TextInput.Password }
            InBotao { text: root.t("Testar"); onClicked: { cl.cfg.mudarObs(cl.cfg.guardado.obs, Number(porta.text) || 4455, senha.text); Clips.testObs(); } }
        }

    }

    // ------------------------------------------------------------ biblioteca, por transmissão
    readonly property int total: {
        let n = 0;
        for (let i = 0; i < lista.length; i++) n += lista[i].clipes.length;
        return n;
    }

    InCartao {
        Layout.topMargin: 12
        visible: cl.total === 0
        InTexto { tipo: "titulo"; text: root.t("Nenhum clipe ainda"); Layout.bottomMargin: -8 }
        InTexto {
            Layout.fillWidth: true
            tipo: "apoio"
            text: root.t("Durante o jogo, aperte %1. O clipe vai pra sua pasta e aparece aqui.").arg(cl.cfg.atalho)
        }
    }

    Repeater {
        model: cl.total > 0 ? cl.lista : []
        delegate: ColumnLayout {
            id: sessao
            required property var modelData
            Layout.fillWidth: true
            Layout.topMargin: 12
            visible: modelData.clipes.length > 0
            spacing: 12

            RowLayout {
                Layout.fillWidth: true
                spacing: 12
                InTexto {
                    tipo: "rotulo"
                    Layout.alignment: Qt.AlignBaseline
                    wrapMode: Text.NoWrap
                    text: {
                        if (sessao.modelData.atual) return root.t("Clipes desta transmissão");
                        const m = /^(\d{4})-(\d{2})-(\d{2}) (\d{2})-(\d{2}) (.*)$/.exec(sessao.modelData.nome);
                        return m ? (root.lingua.en ? m[2] + "/" + m[3] : m[3] + "/" + m[2]) + " " + m[4] + ":" + m[5] + " · " + m[6] : root.t(sessao.modelData.nome);
                    }
                }
                InTexto { tipo: "pequeno"; Layout.alignment: Qt.AlignBaseline; lineHeight: 1.0; lineHeightMode: Text.ProportionalHeight; wrapMode: Text.NoWrap; text: (sessao.modelData.clipes.length === 1 ? root.t("1 clipe") : root.t("%1 clipes").arg(sessao.modelData.clipes.length)) }
                Item { Layout.fillWidth: true }
                InBotao { tipo: "quieto"; text: root.t("Abrir pasta"); icone: "externo"; onClicked: Qt.openUrlExternally("file:///" + sessao.modelData.pasta) }
            }

            GridLayout {
                id: grade
                Layout.fillWidth: true
                columns: Math.max(1, Math.floor((cl.largura + 16) / 340))
                readonly property real larguraCartao: (cl.largura - (columns - 1) * columnSpacing) / columns
                columnSpacing: 16
                rowSpacing: 16
                Repeater {
                    model: sessao.modelData.clipes
                    delegate: Rectangle {
                        id: item
                        required property var modelData
                        Layout.preferredWidth: grade.larguraCartao
                        Layout.alignment: Qt.AlignTop
                        implicitHeight: col.implicitHeight
                        color: root.tema.sup
                        border.width: 1
                        border.color: root.tema.linha
                        ColumnLayout {
                            id: col
                            anchors { left: parent.left; right: parent.right }
                            spacing: 0
                            Rectangle {
                                Layout.fillWidth: true
                                Layout.preferredHeight: width * 9 / 16
                                Layout.margins: 1
                                color: "black"
                                Image {
                                    anchors.fill: parent
                                    source: item.modelData.miniatura || ""
                                    fillMode: Image.PreserveAspectCrop
                                    asynchronous: true
                                    sourceSize.width: 480
                                }
                                Rectangle {
                                    anchors { right: parent.right; bottom: parent.bottom; margins: 8 }
                                    width: dur.implicitWidth + 12; height: 24
                                    color: Qt.rgba(0, 0, 0, 0.75)
                                    visible: !!item.modelData.segundos
                                    Text { id: dur; anchors.centerIn: parent; color: "white"; font.family: root.tema.sans; font.pixelSize: 13; font.weight: Font.DemiBold
                                        text: { const s = Math.round(item.modelData.segundos || 0); return Math.floor(s / 60) + ":" + String(s % 60).padStart(2, "0"); } }
                                }
                                MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: Qt.openUrlExternally("file:///" + item.modelData.caminho) }
                            }
                            ColumnLayout {
                                Layout.fillWidth: true
                                Layout.maximumWidth: Number.POSITIVE_INFINITY   // a coluna estica mesmo com parágrafo de 680 px; o botão fica na borda
                                Layout.margins: 16
                                spacing: 4
                                InTexto { Layout.fillWidth: true; text: Qt.formatDateTime(item.modelData.criado, "HH:mm"); font.weight: Font.DemiBold; elide: Text.ElideRight; wrapMode: Text.NoWrap }
                                InTexto { tipo: "pequeno"; text: root.numero(item.modelData.tamanhoMb) + " MB" + (item.modelData.enviado ? " · " + root.t("já foi pra edição") : "") }
                                RowLayout {
                                    Layout.topMargin: 10
                                    spacing: 8
                                    InBotao {
                                        tipo: item.modelData.enviado ? "normal" : "forte"
                                        text: item.modelData.enviado ? root.t("Mandar de novo") : root.t("Mandar pra edição")
                                        onClicked: pedido.abrir(item.modelData.caminho)
                                    }
                                    Item { Layout.fillWidth: true }
                                    InBotao {
                                        tipo: "quieto"; icone: "lixo"
                                        Accessible.name: root.t("Apagar clipe")
                                        ToolTip.visible: hovered; ToolTip.text: root.t("Apagar (vai pra Lixeira)")
                                        onClicked: root.showConfirmDialog(root.t("Apagar clipe"), root.t("Mandar este clipe pra Lixeira do Windows? Dá pra recuperar de lá."), () => Clips.trash(item.modelData.caminho))
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }
    }

    // ------------------------------------------------------------ pedido pra edição
    T.Dialog {
        id: pedido
        property string caminho: ""
        function abrir(c) { caminho = c; texto.text = ""; open(); }
        function mandar() {
            if (!cl.cfg.pastaEdicao) { escolhaPasta.paraEdicao = true; escolhaPasta.pendente = caminho; escolhaPasta.pedido = texto.text; close(); escolhaPasta.open(); return; }
            const d = Clips.sendToEditing(caminho, cl.cfg.pastaEdicao, texto.text);
            cl.avisar(d ? root.t("Mandado pra edição, com o seu pedido.") : root.t("Não deu pra copiar pra pasta da edição."), !!d);
            close();
        }
        parent: Overlay.overlay
        modal: true
        width: Math.min(560, root.width - 64)
        x: Math.round((root.width - width) / 2)
        y: Math.round((root.height - height) / 2)
        padding: 28
        background: Rectangle { color: root.tema.sup; border.width: 1; border.color: root.tema.borda }
        Overlay.modal: Rectangle { color: Qt.rgba(0, 0, 0, 0.55) }
        onOpened: texto.forceActiveFocus()
        contentItem: ColumnLayout {
            spacing: 12
            InTexto { tipo: "secao"; text: root.t("Mandar pra edição") }
            InTexto { Layout.fillWidth: true; tipo: "apoio"; text: root.t("O que você quer nesse clipe? Vai junto, num arquivo ao lado do vídeo.") }
            TextArea {
                id: texto
                Layout.fillWidth: true
                Layout.preferredHeight: 120
                wrapMode: TextEdit.Wrap
                placeholderText: root.t("ex.: corta do grito até a risada, legenda grande, vertical pro TikTok")
                placeholderTextColor: root.tema.texto2
                color: root.tema.texto
                font.family: root.tema.sans
                font.pixelSize: 16
                selectionColor: root.tema.destaque
                selectedTextColor: root.tema.sobreDestaque
                background: Rectangle { color: root.tema.fundo; border.width: texto.activeFocus ? 2 : 1; border.color: texto.activeFocus ? root.tema.texto : root.tema.borda }
                Keys.onPressed: (e) => { if (text.length >= 2000 && e.text.length && e.key !== Qt.Key_Backspace && e.key !== Qt.Key_Delete) e.accepted = true; }
            }
            InTexto { tipo: "pequeno"; text: root.t("Pasta da edição: %1").arg(cl.cfg.pastaEdicao || root.t("escolha no próximo passo")); elide: Text.ElideMiddle; wrapMode: Text.NoWrap; Layout.fillWidth: true }
            Row {
                Layout.alignment: Qt.AlignRight
                Layout.topMargin: 8
                spacing: 12
                InBotao { text: root.t("Cancelar"); onClicked: pedido.close() }
                InBotao { tipo: "forte"; text: root.t("Mandar"); icone: "seta"; onClicked: pedido.mandar() }
            }
        }
    }

    FolderDialog {
        id: escolhaPasta
        property bool paraEdicao: false
        property string pendente: ""
        property string pedido: ""
        title: paraEdicao ? root.t("Pasta da edição") : root.t("Pasta dos clipes")
        onAccepted: {
            let p = decodeURIComponent(selectedFolder.toString().replace(/^file:\/{3}/, ""));
            if (paraEdicao) {
                cl.cfg.mudarPastaEdicao(p);
                if (pendente) {
                    const d = Clips.sendToEditing(pendente, p, pedido);
                    cl.avisar(d ? root.t("Mandado pra edição.") : root.t("Não deu pra copiar pra pasta da edição."), !!d);
                    pendente = "";
                }
            } else {
                cl.cfg.mudarPasta(p);
                cl.recarregar();
            }
        }
    }
}
