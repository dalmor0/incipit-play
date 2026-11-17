// Adicionar um console pelo endereço (quando a procura na rede não acha).
import QtQuick
import QtQuick.Layouts
import QtQuick.Controls

import org.streetpea.chiaking

Rectangle {
    id: mn
    readonly property var tema: root.tema
    color: tema.fundo
    property int escolha: Chiaki.settings.registeredHosts.length    // último = registrar na primeira conexão

    function voltar() { root.closeDialog(); }
    property string erro: ""
    readonly property bool enderecoOk: /^(\d{1,3}\.){3}\d{1,3}$/.test(endereco.text.trim()) || /^[A-Za-z0-9.-]+\.[A-Za-z]{2,}$/.test(endereco.text.trim())
    function adicionar() {
        if (!enderecoOk) { erro = root.t("Digite os 4 números separados por ponto, como 192.168.0.20 (ou o nome do console na rede)."); return; }
        Chiaki.addManualHost(escolha, endereco.text.trim());
        voltar();
    }
    Keys.onEscapePressed: voltar()
    StackView.onActivated: endereco.campo.forceActiveFocus()

    ColumnLayout {
        width: Math.min(mn.width - 80, 720)
        x: (mn.width - width) / 2
        y: 32
        spacing: 16

        InBotao { tipo: "quieto"; text: root.t("Voltar"); icone: "voltar"; compacto: true; onClicked: mn.voltar(); Layout.leftMargin: -12 }
        InTexto { tipo: "secao"; font.pixelSize: 34; text: root.t("Adicionar por IP") }
        InTexto { Layout.fillWidth: true; tipo: "apoio"; text: root.t("Pra quando a procura na rede não acha o console. No PS5 o IP fica em Configurações > Rede > Status da conexão.") }

        InCampo {
            id: endereco
            Layout.fillWidth: true
            rotulo: root.t("Endereço do console")
            placeholderText: root.t("ex.: 192.168.0.20")
            echoMode: Chiaki.settings.streamerMode ? TextInput.Password : TextInput.Normal
            maximumLength: 253
            onMudou: mn.erro = ""
        }
        InTexto { Layout.fillWidth: true; visible: mn.erro !== ""; tipo: "apoio"; color: root.tema.alerta; text: mn.erro }
        Connections {
            target: endereco.campo
            function onAccepted() { mn.adicionar(); }
        }

        ColumnLayout {
            Layout.fillWidth: true
            spacing: 6
            visible: Chiaki.settings.registeredHosts.length > 0
            InTexto { text: root.t("É um console que já registrei?"); font.weight: Font.DemiBold }
            InEscolha {
                Layout.fillWidth: true
                model: {
                    let m = [];
                    for (let i = 0; i < Chiaki.settings.registeredHosts.length; i++) m.push(root.t("Sim: %1").arg(Chiaki.settings.registeredHosts[i].name));
                    m.push(root.t("Não, registrar na primeira conexão"));
                    return m;
                }
                currentIndex: mn.escolha
                onActivated: (i) => mn.escolha = i
            }
        }

        Row {
            Layout.topMargin: 8
            spacing: 12
            InBotao { tipo: "forte"; text: root.t("Adicionar"); icone: "mais"; onClicked: mn.adicionar() }
            InBotao { text: root.t("Cancelar"); onClicked: mn.voltar() }
        }
    }
}
