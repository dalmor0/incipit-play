// Registrar um PlayStation (uma vez só). Mesma chamada do chiaki-ng (Chiaki.registerHost), outra cara.
import QtQuick
import QtQuick.Layouts
import QtQuick.Controls

import org.streetpea.chiaking

Rectangle {
    id: rg
    objectName: "incipitRegist"
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
        Qt.callLater(() => rolagem.contentY = Math.max(0, rolagem.contentHeight - rolagem.height));
        if (!ok) { terminou = true; deuCerto = false; relato = root.t("Não deu pra começar o registro. Confira o endereço e o código."); }
    }

    Flickable {
        id: rolagem
        anchors { top: parent.top; left: parent.left; right: parent.right; bottom: pe.top }
        contentHeight: coluna.implicitHeight + 64
        clip: true
        boundsBehavior: Flickable.StopAtBounds
        ScrollBar.vertical: ScrollBar { policy: rolagem.contentHeight > rolagem.height ? ScrollBar.AlwaysOn : ScrollBar.AlwaysOff }

        ColumnLayout {
            id: coluna
            width: Math.min(rg.width - 80, 720)
            x: (rg.width - width) / 2
            y: 32
            spacing: 16

            InBotao { tipo: "quieto"; text: root.t("Voltar"); icone: "voltar"; compacto: true; onClicked: rg.voltar(); Layout.leftMargin: -12 }

            InTexto { tipo: "secao"; font.pixelSize: 34; text: rg.ps5 ? root.t("Registrar o PS5") : root.t("Registrar o PS4") }
            InTexto {
                Layout.fillWidth: true
                tipo: "apoio"
                text: (rg.ps5
                    ? root.t("No PS5: Configurações > Sistema > Uso remoto > Vincular dispositivo.")
                    : root.t("No PS4: Configurações > Configurações da conexão do Uso remoto > Adicionar dispositivo."))
                    + " " + root.t("Digite aqui o código de 8 números que aparecer. É uma vez só.")
            }

            InCampo {
                id: codigo
                Layout.fillWidth: true
                rotulo: root.t("Código de 8 números")
                placeholderText: "00000000"
                tamanhoFonte: 26
                maximumLength: 8
                inputMethodHints: Qt.ImhDigitsOnly
                validator: RegularExpressionValidator { regularExpression: /[0-9]{8}/ }
                dica: root.t("O código vale por uns minutos. Se vencer, gere outro no console.")
            }

            ColumnLayout {
                Layout.fillWidth: true
                spacing: 6
                InTexto { text: root.t("Console"); font.weight: Font.DemiBold }
                Flow {
                    Layout.fillWidth: true
                    spacing: 12
                    Repeater {
                        model: [[1000100, "PS5"], [1000, root.t("PS4 (sistema 8 ou mais)")], [900, root.t("PS4 (sistema 7)")], [800, root.t("PS4 (antes do 7)")]]
                        delegate: InOpcao {
                            required property var modelData
                            texto: modelData[1]
                            marcada: rg.alvo === modelData[0]
                            onClicked: rg.alvo = modelData[0]
                        }
                    }
                }
            }

            Row {
                visible: rg.alvo !== 800 && !!Chiaki.settings.psnAccountId
                spacing: 12
                InIcone { nome: "check"; tamanho: 18; cor: root.tema.ok; anchors.verticalCenter: parent.verticalCenter }
                InTexto { text: root.t("Conta PSN conectada: o ID da conta vai junto."); anchors.verticalCenter: parent.verticalCenter }
            }
            InCampo {
                id: contaId
                visible: rg.alvo !== 800 && !Chiaki.settings.psnAccountId
                Layout.fillWidth: true
                rotulo: root.t("ID da conta PSN")
                placeholderText: root.t("preenche sozinho ao conectar a PSN")
                echoMode: Chiaki.settings.streamerMode ? TextInput.Password : TextInput.Normal
                dica: root.t("É o código da conta, não o nome de usuário.")
            }
            InBotao {
                visible: rg.alvo !== 800 && !Chiaki.settings.psnAccountId
                text: root.t("Conectar PSN pra preencher")
                icone: "pessoa"
                onClicked: root.showPSNTokenDialog(false)
            }
            InCampo {
                id: onlineId
                visible: rg.alvo === 800
                Layout.fillWidth: true
                rotulo: root.t("Nome de usuário PSN")
                placeholderText: root.t("igual ao do console, com maiúsculas")
            }

            RowLayout {
                Layout.fillWidth: true
                spacing: 16
                InCampo {
                    id: endereco
                    Layout.fillWidth: true
                    rotulo: root.t("Endereço do console")
                    text: rg.host
                    echoMode: Chiaki.settings.streamerMode ? TextInput.Password : TextInput.Normal
                }
                InCampo {
                    id: pinConsole
                    Layout.preferredWidth: 160
                    rotulo: root.t("PIN do console")
                    placeholderText: "opcional"
                    maximumLength: 4
                    validator: RegularExpressionValidator { regularExpression: /^$|[0-9]{4}/ }
                }
            }

            InCartao {
                visible: rg.registrando || rg.terminou
                marcado: rg.terminou
                border.color: rg.terminou ? (rg.deuCerto ? root.tema.ok : root.tema.alerta) : root.tema.linha
                InTexto {
                    tipo: "titulo"
                    text: rg.registrando ? root.t("Falando com o console...") : rg.deuCerto ? root.t("Registrado. Já dá pra jogar.") : root.t("Não registrou")
                    color: rg.terminou ? (rg.deuCerto ? root.tema.ok : root.tema.alerta) : root.tema.texto
                }
                InTexto {
                    Layout.fillWidth: true
                    visible: rg.terminou && !rg.deuCerto
                    tipo: "apoio"
                    text: root.t("Confira o código (gere um novo se passou do tempo), se o console está na mesma rede e se o ID da conta é o da conta do console.")
                }
                InTexto { Layout.fillWidth: true; tipo: "pequeno"; text: rg.relato.trim(); visible: rg.relato.trim() !== ""; font.family: "Consolas" }
            }
        }
    }

    // pé fixo: o botão que conclui fica sempre à vista
    Rectangle {
        id: pe
        anchors { left: parent.left; right: parent.right; bottom: parent.bottom }
        height: 76
        color: root.tema.sup
        Rectangle { anchors { left: parent.left; right: parent.right; top: parent.top } height: 1; color: root.tema.linha }
        RowLayout {
            width: coluna.width
            x: coluna.x
            anchors.verticalCenter: parent.verticalCenter
            spacing: 12
            InTexto {
                Layout.fillWidth: true
                tipo: "apoio"
                elide: Text.ElideRight
                wrapMode: Text.NoWrap
                color: rg.terminou ? (rg.deuCerto ? root.tema.ok : root.tema.alerta) : root.tema.texto2
                text: rg.registrando ? root.t("Falando com o console...")
                    : rg.terminou ? (rg.deuCerto ? root.t(root.t("Registrado. Já dá pra jogar.")) : root.t("Não registrou. Veja o motivo acima."))
                    : !codigo.acceptableInput ? root.t("Falta o código de 8 números.")
                    : !rg.contaPronta ? root.t("Falta a conta PSN.")
                    : endereco.text.trim() === "" ? root.t("Falta o endereço do console.")
                    : root.t("Tudo certo pra registrar.")
            }
            InBotao { text: rg.terminou && rg.deuCerto ? root.t("Pronto, voltar") : root.t("Cancelar"); onClicked: rg.voltar() }
            InBotao {
                tipo: "forte"
                text: rg.registrando ? root.t("Registrando...") : root.t("Registrar")
                icone: "chave"
                enabled: rg.podeRegistrar
                onClicked: rg.registrar()
            }
        }
    }
}
