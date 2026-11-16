// Aba PlayStation: o motor do chiaki-ng (descoberta, registro, acordar, jogar) com a cara da Incipit.
import QtQuick
import QtQuick.Layouts
import QtQuick.Controls

import org.streetpea.chiaking

InPagina {
    id: ps
    titulo: "PlayStation"
    apoio: "PS5 e PS4 da sua rede aparecem aqui, ligados ou em repouso."

    readonly property bool psnConectada: !!(Chiaki.settings.psnAuthToken && Chiaki.settings.psnAccountId)
    readonly property int visiveis: {
        let n = 0;
        for (let i = 0; i < Chiaki.hosts.length; i++) if (Chiaki.hosts[i].display) n++;
        return n;
    }

    acoes: [
        Row {
            visible: Chiaki.discoveryEnabled
            height: 44
            spacing: 12
            Item {
                width: 14; height: 14
                anchors.verticalCenter: parent.verticalCenter
                Rectangle { anchors.fill: parent; radius: 7; color: "transparent"; border.width: 2; border.color: root.tema.linha }
                Item {
                    anchors.fill: parent
                    clip: true
                    RotationAnimation on rotation { from: 0; to: 360; duration: 1100; loops: Animation.Infinite; running: Chiaki.discoveryEnabled }
                    Rectangle { width: 14; height: 14; radius: 7; color: "transparent"; border.width: 2; border.color: root.tema.texto2
                        Rectangle { anchors { left: parent.left; right: parent.right; bottom: parent.bottom } height: 8; color: root.tema.fundo } }
                }
            }
            InTexto {
                text: ps.visiveis > 0 ? "Procurando outros consoles" : "Procurando consoles na rede"
                tipo: "apoio"; wrapMode: Text.NoWrap; lineHeight: 1.0
                height: 44; verticalAlignment: Text.AlignVCenter
                anchors.verticalCenter: parent.verticalCenter
            }
            Item { width: 6; height: 1 }
        },
        InBotao {
            visible: !Chiaki.discoveryEnabled
            text: "Procurar de novo"
            icone: "busca"
            onClicked: Chiaki.discoveryEnabled = true
        },
        InBotao {
            text: "Adicionar por IP"
            icone: "mais"
            onClicked: root.showManualHostDialog()
        }
    ]

    // ------------------------------------------------------------ lista de consoles
    Repeater {
        model: Chiaki.hosts
        delegate: InCartao {
            id: cartao
            required property var modelData
            required property int index
            visible: modelData.display
            Layout.preferredHeight: visible ? implicitHeight : 0

            readonly property bool ligado: modelData.discovered && modelData.state === "ready"
            readonly property bool repouso: modelData.state === "standby"
            readonly property bool registrado: modelData.registered
            readonly property string situacao: {
                if (modelData.duid && !modelData.discovered) return "Pela PSN, fora da rede de casa";
                if (!registrado) return modelData.discovered ? "Encontrado, falta registrar" : "Adicionado por IP";
                if (ligado) return modelData.app ? "Ligado · " + modelData.app : "Ligado";
                if (repouso) return "Em repouso";
                return modelData.discovered ? "Na rede" : "Fora do ar agora";
            }
            readonly property color corSituacao: !registrado ? root.tema.quente : ligado ? root.tema.ok : repouso ? root.tema.quente : root.tema.texto2

            function jogar() {
                if (modelData.discovered) Chiaki.connectToHost(index, modelData.name);
                else Chiaki.connectToHost(index);
            }

            RowLayout {
                Layout.fillWidth: true
                spacing: 20

                Rectangle {
                    Layout.preferredWidth: 56
                    Layout.preferredHeight: 56
                    color: root.tema.fundo
                    border.width: 1
                    border.color: root.tema.linha
                    InIcone { anchors.centerIn: parent; nome: "controle"; tamanho: 28; cor: cartao.ligado ? root.tema.destaque : root.tema.texto2 }
                }

                ColumnLayout {
                    Layout.fillWidth: true

                    Layout.maximumWidth: Number.POSITIVE_INFINITY   // a coluna estica mesmo com parágrafo de 680 px; o botão fica na borda
                    spacing: 6
                    InTexto {
                        Layout.fillWidth: true
                        tipo: "titulo"
                        text: modelData.name || (modelData.ps5 ? "PS5" : "PS4")
                        elide: Text.ElideRight
                        wrapMode: Text.NoWrap
                    }
                    Row {
                        spacing: 8
                        Rectangle { width: 8; height: 8; radius: 4; color: cartao.corSituacao; anchors.verticalCenter: parent.verticalCenter }
                        InTexto { tipo: "apoio"; text: cartao.situacao; wrapMode: Text.NoWrap }
                    }
                    InTexto {
                        tipo: "pequeno"
                        visible: !!modelData.address
                        text: (modelData.ps5 ? "PS5" : "PS4") + " · " + (Chiaki.settings.streamerMode ? "endereço oculto" : modelData.address)
                    }
                }

                Row {
                    Layout.alignment: Qt.AlignVCenter
                    spacing: 12

                    InBotao {
                        visible: modelData.manual || (modelData.discovered && !modelData.registered)
                        tipo: "normal"
                        text: modelData.manual ? "Apagar" : "Ocultar"
                        onClicked: {
                            if (modelData.manual)
                                root.showConfirmDialog("Apagar console", "Tirar este console da lista? Dá pra adicionar de novo pelo IP.", () => Chiaki.deleteHost(index));
                            else
                                root.showConfirmDialog("Ocultar console", "Ocultar este console? Ele volta em Configurações > Mais ajustes > Consoles.", () => Chiaki.hideHost(modelData.mac, modelData.name));
                        }
                    }
                    InBotao {
                        visible: cartao.registrado
                        tipo: "quieto"
                        text: "PIN do console"
                        onClicked: root.showConsolePinDialog(index)
                    }
                    InBotao {
                        visible: cartao.registrado && !modelData.discovered && !modelData.duid
                        text: "Ligar"
                        icone: "energia"
                        onClicked: Chiaki.wakeUpHost(index)
                    }
                    InBotao {
                        tipo: "forte"
                        text: cartao.registrado ? "Jogar" : "Registrar"
                        icone: cartao.registrado ? "jogar" : "chave"
                        onClicked: cartao.jogar()
                    }
                }
            }
        }
    }

    // ------------------------------------------------------------ vazio
    InCartao {
        visible: ps.visiveis === 0
        InTexto { tipo: "titulo"; text: Chiaki.discoveryEnabled ? "Procurando consoles na sua rede" : "A procura na rede está desligada"; Layout.bottomMargin: -8 }
        InTexto {
            Layout.fillWidth: true
            tipo: "apoio"
            text: Chiaki.discoveryEnabled
                ? "Deixe o PS5 ligado ou em repouso, no mesmo Wi-Fi ou cabo deste PC. Ele aparece em alguns segundos. Se não aparecer, adicione pelo IP (no PS5: Configurações > Rede > Status da conexão)."
                : "Ligue a procura pra achar o console sozinho, ou adicione pelo IP."
        }
        Row {
            Layout.topMargin: 8
            spacing: 12
            InBotao { tipo: "forte"; visible: !Chiaki.discoveryEnabled; text: "Procurar na rede"; icone: "busca"; onClicked: Chiaki.discoveryEnabled = true }
            InBotao { text: "Adicionar por IP"; icone: "mais"; onClicked: root.showManualHostDialog() }
        }
    }

    // ------------------------------------------------------------ conta PSN
    InCartao {
        Layout.topMargin: 8
        RowLayout {
            Layout.fillWidth: true
            spacing: 20
            ColumnLayout {
                Layout.fillWidth: true
                Layout.maximumWidth: Number.POSITIVE_INFINITY   // a coluna estica mesmo com parágrafo de 680 px; o botão fica na borda
                spacing: 4
                InTexto { tipo: "titulo"; text: ps.psnConectada ? "Conta PSN conectada" : "Conta PSN" }
                InTexto {
                    Layout.fillWidth: true
                    tipo: "apoio"
                    text: ps.psnConectada
                        ? "Registro automático e jogo fora de casa liberados."
                        : "Conectar libera o registro automático e jogar fora de casa sem mexer no roteador."
                }
            }
            InBotao {
                visible: ps.psnConectada
                text: "Atualizar consoles"
                icone: "atualizar"
                onClicked: Chiaki.refreshPsnToken()
            }
            InBotao {
                visible: !ps.psnConectada
                text: "Conectar PSN"
                icone: "pessoa"
                onClicked: root.showPSNTokenDialog(false)
            }
        }
    }
}
