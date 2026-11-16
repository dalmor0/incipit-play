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
    function adicionar() { Chiaki.addManualHost(escolha, endereco.text.trim()); voltar(); }
    Keys.onEscapePressed: voltar()
    StackView.onActivated: endereco.campo.forceActiveFocus()

    ColumnLayout {
        width: Math.min(mn.width - 80, 720)
        x: (mn.width - width) / 2
        y: 40
        spacing: 16

        InBotao { tipo: "quieto"; text: "Voltar"; icone: "voltar"; compacto: true; onClicked: mn.voltar(); Layout.leftMargin: -12 }
        InTexto { tipo: "secao"; font.pixelSize: 34; text: "Adicionar por IP" }
        InTexto { Layout.fillWidth: true; tipo: "apoio"; text: "Pra quando a procura na rede não acha o console. No PS5 o IP fica em Configurações > Rede > Status da conexão." }

        InCampo {
            id: endereco
            Layout.fillWidth: true
            rotulo: "Endereço do console"
            placeholderText: "ex.: 192.168.0.20"
            echoMode: Chiaki.settings.streamerMode ? TextInput.Password : TextInput.Normal
            campo.onAccepted: if (text.trim() !== "") mn.adicionar()
        }

        ColumnLayout {
            Layout.fillWidth: true
            spacing: 6
            visible: Chiaki.settings.registeredHosts.length > 0
            InTexto { text: "É um console que já registrei?"; font.weight: Font.DemiBold }
            InEscolha {
                Layout.fillWidth: true
                model: {
                    let m = [];
                    for (let i = 0; i < Chiaki.settings.registeredHosts.length; i++) m.push("Sim: " + Chiaki.settings.registeredHosts[i].name);
                    m.push("Não, registrar na primeira conexão");
                    return m;
                }
                currentIndex: mn.escolha
                onActivated: (i) => mn.escolha = i
            }
        }

        Row {
            Layout.topMargin: 8
            spacing: 10
            InBotao { tipo: "forte"; text: "Adicionar"; icone: "mais"; enabled: endereco.text.trim() !== ""; onClicked: mn.adicionar() }
            InBotao { text: "Cancelar"; onClicked: mn.voltar() }
        }
    }
}
