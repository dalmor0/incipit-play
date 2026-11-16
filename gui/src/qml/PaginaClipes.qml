// Aba Clipes: o atalho que guarda os últimos segundos, a biblioteca e o caminho pra edição.
import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import QtQuick.Dialogs

import org.streetpea.chiaking

InPagina {
    id: cl
    titulo: "Clipes"
    apoio: "Apertou o atalho, o app guarda os últimos " + root.clipes.segundos + " s do jogo, sem perder qualidade."

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
        function onClipFailed(r) { cl.avisar(r, false); }
        function onObsStatus(t, ok) { cl.avisar(t, ok); }
    }

    acoes: [
        InBotao { text: "Abrir pasta"; icone: "externo"; onClicked: Qt.openUrlExternally("file:///" + Clips.clipsDir()) },
        InBotao { text: cl.mostrarOpcoes ? "Fechar opções" : "Opções"; icone: "engrenagem"; onClicked: cl.mostrarOpcoes = !cl.mostrarOpcoes }
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
                spacing: 4
                InTexto {
                    Layout.fillWidth: true
                    tipo: "titulo"
                    text: !cl.cfg.ligado ? "Clipes desligados"
                        : !Clips.hotkeyActive ? cl.cfg.atalho + " já é de outro programa"
                        : Clips.streaming ? "Gravando o jogo agora" : "Pronto pra clipar"
                }
                InTexto {
                    Layout.fillWidth: true
                    tipo: "apoio"
                    text: !cl.cfg.ligado ? "Ligue pra o atalho funcionar."
                        : !Clips.hotkeyActive ? "O app do NVIDIA usa Alt+F10 pro replay dele. Escolha outro atalho em Opções."
                        : Clips.streaming ? "No PlayStation o vídeo fica guardado na memória (agora " + Clips.bufferMegabytes + " MB). Na aba Switch, a placa grava enquanto está aberta."
                        : "Funciona com o app minimizado, durante o jogo do PlayStation e da placa de captura" + (cl.cfg.guardado.obs ? " e no OBS." : ".")
                }
            }
            InBotao {
                visible: Clips.streaming
                tipo: "forte"
                text: "Salvar agora"
                icone: "video"
                onClicked: Clips.saveNow()
            }
            InBotao {
                text: cl.cfg.ligado ? "Desligar" : "Ligar"
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

            InTexto { text: "Atalho"; font.weight: Font.DemiBold; Layout.preferredWidth: 180; Layout.alignment: Qt.AlignVCenter }
            InEscolha {
                Layout.preferredWidth: 320
                model: cl.cfg.atalhos
                currentIndex: Math.max(0, cl.cfg.atalhos.indexOf(cl.cfg.atalho))
                onActivated: (i) => {
                    const ok = cl.cfg.mudarAtalho(cl.cfg.atalhos[i]);
                    cl.avisar(ok ? "Atalho trocado pra " + cl.cfg.atalhos[i] + "." : cl.cfg.atalhos[i] + " já é de outro programa. Escolha outro.", ok);
                }
            }

            InTexto { text: "Quanto guardar"; font.weight: Font.DemiBold; Layout.alignment: Qt.AlignVCenter }
            InEscolha {
                Layout.preferredWidth: 320
                model: cl.cfg.duracoes.map(s => s < 60 ? s + " segundos" : (s % 60 ? (s / 60).toFixed(1).replace(".", ",") + " minutos" : (s / 60) + (s === 60 ? " minuto" : " minutos")) + (s === 90 ? " (padrão)" : ""))
                currentIndex: Math.max(0, cl.cfg.duracoes.indexOf(cl.cfg.segundos))
                onActivated: (i) => cl.cfg.mudarSegundos(cl.cfg.duracoes[i])
            }

            InTexto { text: "Pasta dos clipes"; font.weight: Font.DemiBold; Layout.alignment: Qt.AlignVCenter }
            RowLayout {
                spacing: 10
                InTexto { Layout.maximumWidth: 420; text: Clips.clipsDir(); tipo: "apoio"; elide: Text.ElideMiddle; wrapMode: Text.NoWrap }
                InBotao { text: "Trocar"; compacto: true; onClicked: { escolhaPasta.paraEdicao = false; escolhaPasta.open(); } }
            }

            InTexto { text: "Pasta da edição"; font.weight: Font.DemiBold; Layout.alignment: Qt.AlignVCenter }
            RowLayout {
                spacing: 10
                InTexto { Layout.maximumWidth: 420; text: cl.cfg.pastaEdicao || "ainda não escolhida"; tipo: "apoio"; elide: Text.ElideMiddle; wrapMode: Text.NoWrap }
                InBotao { text: "Escolher"; compacto: true; onClicked: { escolhaPasta.paraEdicao = true; escolhaPasta.open(); } }
            }
        }

        Rectangle { Layout.fillWidth: true; Layout.topMargin: 8; height: 1; color: root.tema.linha }

        InTexto { tipo: "titulo"; text: "Lives no OBS" }
        InTexto {
            Layout.fillWidth: true
            tipo: "apoio"
            text: "Com o OBS aberto, o mesmo atalho também salva o Replay Buffer dele. No OBS: Ferramentas > Configurações do servidor WebSocket > Habilitar, e ligue o Replay Buffer em Controles."
        }
        RowLayout {
            Layout.fillWidth: true
            spacing: 12
            InOpcao { texto: "Salvar no OBS também"; marcada: cl.cfg.guardado.obs; onClicked: cl.cfg.mudarObs(!cl.cfg.guardado.obs, Number(porta.text) || 4455, senha.text) }
            InCampo { id: porta; Layout.preferredWidth: 120; placeholderText: "porta"; text: String(cl.cfg.guardado.obsPorta); validator: IntValidator { bottom: 1; top: 65535 } }
            InCampo { id: senha; Layout.preferredWidth: 240; placeholderText: "senha do WebSocket"; text: cl.cfg.guardado.obsSenha; echoMode: TextInput.Password }
            InBotao { text: "Testar"; onClicked: { cl.cfg.mudarObs(cl.cfg.guardado.obs, Number(porta.text) || 4455, senha.text); Clips.testObs(); } }
        }

        Rectangle { Layout.fillWidth: true; Layout.topMargin: 8; height: 1; color: root.tema.linha }

        RowLayout {
            Layout.fillWidth: true
            spacing: 20
            ColumnLayout {
                Layout.fillWidth: true
                spacing: 4
                InTexto { tipo: "titulo"; text: "Clipes automáticos" }
                InTexto { Layout.fillWidth: true; tipo: "apoio"; text: "O app acha sozinho o momento bom (grito, kill, risada) e salva. Está sendo estudado." }
            }
            InBotao { text: "Em breve"; enabled: false }
        }
    }

    // ------------------------------------------------------------ biblioteca
    InTexto { Layout.topMargin: 12; tipo: "rotulo"; text: cl.lista.length ? cl.lista.length + (cl.lista.length === 1 ? " clipe" : " clipes") : "Biblioteca" }

    InCartao {
        visible: cl.lista.length === 0
        respiro: 32
        InTexto { tipo: "titulo"; text: "Nenhum clipe ainda" }
        InTexto {
            Layout.fillWidth: true
            tipo: "apoio"
            text: "Durante o jogo, aperte " + cl.cfg.atalho + ". O clipe aparece aqui com miniatura, pronto pra mandar pra edição."
        }
    }

    GridLayout {
        Layout.fillWidth: true
        visible: cl.lista.length > 0
        columns: Math.max(1, Math.floor((cl.largura + 16) / 340))
        uniformCellWidths: true
        columnSpacing: 16
        rowSpacing: 16
        Repeater {
            model: cl.lista
            delegate: Rectangle {
                id: item
                required property var modelData
                Layout.fillWidth: true
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
                        Layout.margins: 16
                        spacing: 4
                        InTexto { Layout.fillWidth: true; text: item.modelData.jogo || "Clipe"; font.weight: Font.DemiBold; elide: Text.ElideRight; wrapMode: Text.NoWrap }
                        InTexto { tipo: "pequeno"; text: Qt.formatDateTime(item.modelData.criado, "dd/MM/yyyy HH:mm") + " · " + String(item.modelData.tamanhoMb).replace(".", ",") + " MB" }
                        RowLayout {
                            Layout.topMargin: 10
                            spacing: 8
                            InBotao {
                                tipo: "forte"; compacto: true; text: "Mandar pra edição"
                                onClicked: {
                                    if (!cl.cfg.pastaEdicao) { escolhaPasta.paraEdicao = true; escolhaPasta.pendente = item.modelData.caminho; escolhaPasta.open(); return; }
                                    const d = Clips.sendToEditing(item.modelData.caminho, cl.cfg.pastaEdicao);
                                    cl.avisar(d ? "Mandado pra edição." : "Não deu pra copiar pra pasta da edição.", !!d);
                                }
                            }
                            Item { Layout.fillWidth: true }
                            InBotao {
                                tipo: "quieto"; compacto: true; icone: "lixo"
                                Accessible.name: "Apagar clipe"
                                ToolTip.visible: hovered; ToolTip.text: "Apagar (vai pra Lixeira)"
                                onClicked: root.showConfirmDialog("Apagar clipe", "Mandar este clipe pra Lixeira do Windows? Dá pra recuperar de lá.", () => Clips.trash(item.modelData.caminho))
                            }
                        }
                    }
                }
            }
        }
    }

    FolderDialog {
        id: escolhaPasta
        property bool paraEdicao: false
        property string pendente: ""
        title: paraEdicao ? "Pasta da edição" : "Pasta dos clipes"
        onAccepted: {
            let p = decodeURIComponent(selectedFolder.toString().replace(/^file:\/{3}/, ""));
            if (paraEdicao) {
                cl.cfg.mudarPastaEdicao(p);
                if (pendente) {
                    const d = Clips.sendToEditing(pendente, p);
                    cl.avisar(d ? "Mandado pra edição." : "Não deu pra copiar pra pasta da edição.", !!d);
                    pendente = "";
                }
            } else {
                cl.cfg.mudarPasta(p);
                cl.recarregar();
            }
        }
    }
}
