// Registrar um PlayStation (uma vez só). Mesma chamada do chiaki-ng (Chiaki.registerHost), outra cara.
import QtQuick
import QtQuick.Layouts
import QtQuick.Controls

import org.streetpea.chiaking

Rectangle {
    id: rg
    property string host: ""
    property bool ps5: true
    readonly property var tema: root.tema
    color: tema.fundo

    property int alvo: ps5 ? 1000100 : 1000          // 1000100 PS5, 1000 PS4 8+, 900 PS4 7.x, 800 PS4 antes do 7
    property bool registrando: false
    property bool terminou: false
    property bool deuCerto: false
    property string relato: ""
    readonly property bool contaPronta: alvo === 800 ? onlineId.text.trim() !== "" : contaId.text.trim() !== ""
    readonly property bool podeRegistrar: !registrando && endereco.text.trim() !== "" && codigo.acceptableInput && pinConsole.acceptableInput && contaPronta

    function voltar() { root.closeDialog(); }
    Keys.onEscapePressed: voltar()
    StackView.onActivated: {
        if (Chiaki.settings.psnAccountId) contaId.text = Chiaki.settings.psnAccountId;
        codigo.campo.forceActiveFocus();
    }
    Connections {
        target: Chiaki.settings
        function onPsnAccountIdChanged() { if (Chiaki.settings.psnAccountId) contaId.text = Chiaki.settings.psnAccountId; }
    }

    function registrar() {
        relato = "";
        terminou = false;
        deuCerto = false;
        const conta = alvo === 800 ? onlineId.text.trim() : contaId.text.trim();
        const ok = Chiaki.registerHost(endereco.text.trim(), conta, codigo.text.trim(), pinConsole.text.trim(),
            endereco.text.trim() === "255.255.255.255", alvo, function (msg, sucesso, fim) {
                if (!fim) { rg.relato += msg + "\n"; return; }
                rg.registrando = false;
                rg.terminou = true;
                rg.deuCerto = sucesso;
            });
        registrando = ok;
        if (!ok) { terminou = true; deuCerto = false; relato = "Não deu pra começar o registro. Confira o endereço e o código."; }
    }

    Flickable {
        anchors.fill: parent
        contentHeight: coluna.implicitHeight + 80
        clip: true
        boundsBehavior: Flickable.StopAtBounds
        ScrollBar.vertical: ScrollBar {}

        ColumnLayout {
            id: coluna
            width: Math.min(rg.width - 80, 720)
            x: (rg.width - width) / 2
            y: 40
            spacing: 16

            InBotao { tipo: "quieto"; text: "Voltar"; icone: "voltar"; compacto: true; onClicked: rg.voltar(); Layout.leftMargin: -12 }

            Row {
                spacing: 14
                InMarca { altura: 34; anchors.verticalCenter: parent.verticalCenter }
                InTexto { tipo: "secao"; font.pixelSize: 34; text: rg.ps5 ? "Registrar o PS5" : "Registrar o PS4"; anchors.verticalCenter: parent.verticalCenter }
            }
            InTexto {
                Layout.fillWidth: true
                tipo: "apoio"
                text: "Uma vez só. Depois é só clicar em Jogar."
            }

            InCartao {
                marcado: true
                InTexto { tipo: "rotulo"; text: "No console" }
                InTexto {
                    Layout.fillWidth: true
                    text: rg.ps5
                        ? "Configurações > Sistema > Uso remoto > Vincular dispositivo. Aparece um código de 8 números."
                        : "Configurações > Configurações da conexão do Uso remoto > Adicionar dispositivo. Aparece um código de 8 números."
                }
            }

            InCampo {
                id: codigo
                Layout.fillWidth: true
                rotulo: "Código de 8 números"
                placeholderText: "00000000"
                tamanhoFonte: 26
                maximumLength: 8
                inputMethodHints: Qt.ImhDigitsOnly
                validator: RegularExpressionValidator { regularExpression: /[0-9]{8}/ }
                dica: "O código vale por uns minutos. Se vencer, gere outro no console."
            }

            ColumnLayout {
                Layout.fillWidth: true
                spacing: 6
                InTexto { text: "Console"; font.weight: Font.DemiBold }
                Flow {
                    Layout.fillWidth: true
                    spacing: 10
                    Repeater {
                        model: [[1000100, "PS5"], [1000, "PS4 (sistema 8 ou mais)"], [900, "PS4 (sistema 7)"], [800, "PS4 (antes do 7)"]]
                        delegate: InOpcao {
                            required property var modelData
                            texto: modelData[1]
                            marcada: rg.alvo === modelData[0]
                            onClicked: rg.alvo = modelData[0]
                        }
                    }
                }
            }

            InCampo {
                id: contaId
                visible: rg.alvo !== 800
                Layout.fillWidth: true
                rotulo: "ID da conta PSN"
                placeholderText: "preenche sozinho ao conectar a PSN"
                echoMode: Chiaki.settings.streamerMode ? TextInput.Password : TextInput.Normal
                dica: Chiaki.settings.psnAccountId ? "Veio da conta PSN conectada." : "É o código da conta, não o nome de usuário."
            }
            InBotao {
                visible: rg.alvo !== 800 && !Chiaki.settings.psnAccountId
                text: "Conectar PSN pra preencher"
                icone: "pessoa"
                onClicked: root.showPSNTokenDialog(false)
            }
            InCampo {
                id: onlineId
                visible: rg.alvo === 800
                Layout.fillWidth: true
                rotulo: "Nome de usuário PSN"
                placeholderText: "igual ao do console, com maiúsculas"
            }

            RowLayout {
                Layout.fillWidth: true
                spacing: 16
                InCampo {
                    id: endereco
                    Layout.fillWidth: true
                    rotulo: "Endereço do console"
                    text: rg.host
                    echoMode: Chiaki.settings.streamerMode ? TextInput.Password : TextInput.Normal
                }
                InCampo {
                    id: pinConsole
                    Layout.preferredWidth: 220
                    rotulo: "PIN do console"
                    placeholderText: "opcional"
                    maximumLength: 4
                    validator: RegularExpressionValidator { regularExpression: /^$|[0-9]{4}/ }
                }
            }

            Row {
                Layout.topMargin: 8
                spacing: 10
                InBotao {
                    tipo: "forte"
                    text: rg.registrando ? "Registrando..." : "Registrar"
                    icone: "chave"
                    enabled: rg.podeRegistrar
                    onClicked: rg.registrar()
                }
                InBotao { text: rg.terminou && rg.deuCerto ? "Pronto, voltar" : "Cancelar"; onClicked: rg.voltar() }
            }

            InCartao {
                visible: rg.registrando || rg.terminou
                marcado: rg.terminou
                border.color: rg.terminou ? (rg.deuCerto ? root.tema.ok : root.tema.alerta) : root.tema.linha
                InTexto {
                    tipo: "titulo"
                    text: rg.registrando ? "Falando com o console..." : rg.deuCerto ? "Registrado. Já dá pra jogar." : "Não registrou"
                    color: rg.terminou ? (rg.deuCerto ? root.tema.ok : root.tema.alerta) : root.tema.texto
                }
                InTexto {
                    Layout.fillWidth: true
                    visible: rg.terminou && !rg.deuCerto
                    tipo: "apoio"
                    text: "Confira o código (gere um novo se passou do tempo), se o console está na mesma rede e se o ID da conta é o da conta do console."
                }
                InTexto { Layout.fillWidth: true; tipo: "pequeno"; text: rg.relato.trim(); visible: rg.relato.trim() !== ""; font.family: "Consolas" }
            }
        }
    }
}
