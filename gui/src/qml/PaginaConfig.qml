// Configurações: Contas conectadas, Personalizar, Vídeo e Sobre. O resto dos ajustes do motor do PlayStation fica
// em "Mais ajustes", a tela completa do chiaki-ng.
import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import QtCore

import org.streetpea.chiaking

InPagina {
    id: cfg
    titulo: root.t("Configurações")
    apoio: ""

    Settings { id: lembrar; category: "hub"; property string secao: "contas" }
    property string secao: lembrar.secao
    function ir(s) { secao = s; lembrar.secao = s; }
    // pedido de outra tela (ex.: depois de conectar a PSN, abre direto em Contas conectadas)
    function atenderPedido() { if (root.configSecao !== "") { ir(root.configSecao); root.configSecao = ""; } }
    Component.onCompleted: atenderPedido()
    Connections { target: root; function onConfigSecaoChanged() { cfg.atenderPedido(); } }
    // o cartão da PSN fica marcado em verde uns segundos depois de conectar
    Timer { running: root.psnRecemConectada; interval: 8000; onTriggered: root.psnRecemConectada = false }

    readonly property bool psnConectada: !!(Chiaki.settings.psnAuthToken && Chiaki.settings.psnAccountId)
    readonly property string perfilXbox: Chiaki.localDataPath() + "/xbox-web"
    readonly property bool xboxEntrou: Chiaki.pathExists(perfilXbox + "/Default")
    readonly property string edge: {
        const c = ["C:/Program Files (x86)/Microsoft/Edge/Application/msedge.exe", "C:/Program Files/Microsoft/Edge/Application/msedge.exe"];
        for (let i = 0; i < c.length; i++) if (Chiaki.pathExists(c[i])) return c[i];
        return "";
    }
    function abrirMicrosoft(url) {
        if (!(edge !== "" && Chiaki.launchDetached(edge, ["--app=" + url, "--user-data-dir=" + perfilXbox, "--no-first-run", "--no-default-browser-check", "--window-size=1100,760"])))
            Qt.openUrlExternally(url);
    }

    // ------------------------------------------------------------ seções
    Item {
        Layout.fillWidth: true
        Layout.bottomMargin: 8
        implicitHeight: 44
        Rectangle { anchors { left: parent.left; right: parent.right; bottom: parent.bottom } height: 1; color: root.tema.linha }
    Row {
        spacing: 0
        Repeater {
            model: [["contas", root.t("Contas conectadas")], ["personalizar", root.t("Personalizar")], ["video", root.t("Vídeo")], ["sobre", root.t("Sobre")]]
            delegate: AbstractButton {
                id: aba
                required property var modelData
                readonly property bool ativa: cfg.secao === modelData[0]
                implicitHeight: 44
                implicitWidth: medida.advanceWidth + 40
                TextMetrics { id: medida; text: aba.modelData[1]; font.family: root.tema.sans; font.pixelSize: 15; font.weight: Font.DemiBold }
                focusPolicy: Qt.StrongFocus
                hoverEnabled: true
                Accessible.name: modelData[1]
                onClicked: cfg.ir(modelData[0])
                background: Rectangle {
                    color: aba.hovered && !aba.ativa ? root.tema.destaqueFraco : "transparent"
                    Rectangle { visible: aba.ativa; anchors { left: parent.left; right: parent.right; bottom: parent.bottom } height: 3; color: root.tema.destaque }
                    Rectangle { visible: aba.visualFocus; anchors.fill: parent; anchors.margins: 2; color: "transparent"; border.width: 2; border.color: root.tema.texto }
                }
                contentItem: Text {
                    id: rot
                    text: aba.modelData[1]
                    horizontalAlignment: Text.AlignHCenter
                    verticalAlignment: Text.AlignVCenter
                    font.family: root.tema.sans; font.pixelSize: 15
                    font.weight: aba.ativa ? Font.DemiBold : Font.Normal
                    color: aba.ativa ? root.tema.texto : root.tema.texto2
                }
            }
        }
    }
    }

    // ============================================================ CONTAS
    ColumnLayout {
        visible: cfg.secao === "contas"
        Layout.fillWidth: true
        spacing: 16

        InCartao {
            // sem borda como os outros cartões; logo depois de conectar, um fio verde por uns segundos
            border.width: root.psnRecemConectada ? 2 : 0
            border.color: root.tema.ok
            RowLayout {
                Layout.fillWidth: true
                spacing: 12
                ColumnLayout {
                    Layout.fillWidth: true
                    Layout.maximumWidth: Number.POSITIVE_INFINITY   // a coluna estica mesmo com parágrafo de 680 px; o botão fica na borda
                    spacing: 4
                    InTexto { tipo: "titulo"; text: root.t("PlayStation Network") }
                    RowLayout {
                        visible: cfg.psnConectada
                        spacing: 8
                        InIcone { nome: "check"; tamanho: 18; cor: root.tema.ok; Layout.alignment: Qt.AlignVCenter }
                        InTexto { text: root.t("Conectada"); font.pixelSize: 15; font.weight: Font.DemiBold; color: root.tema.ok; Layout.alignment: Qt.AlignVCenter }
                        InTexto {
                            visible: !Chiaki.settings.streamerMode && root.fimIdPsn(Chiaki.settings.psnAccountId) !== ""
                            tipo: "apoio"
                            text: "· " + root.t("ID terminado em %1").arg(root.fimIdPsn(Chiaki.settings.psnAccountId))
                            Layout.alignment: Qt.AlignVCenter
                        }
                    }
                    InTexto {
                        visible: !cfg.psnConectada
                        Layout.fillWidth: true
                        tipo: "apoio"
                        text: root.t("Não conectada. Conectar libera o registro automático e jogar fora de casa.")
                    }
                }
                InBotao {
                    visible: cfg.psnConectada
                    tipo: "quieto"
                    text: root.t("Desconectar")
                    onClicked: root.showConfirmDialog(root.t("Desconectar PSN"), root.t("Tirar a conta PSN do Incipit Play? Os consoles registrados continuam funcionando em casa."), () => {
                        Chiaki.settings.psnRefreshToken = "";
                        Chiaki.settings.psnAuthToken = "";
                        Chiaki.settings.psnAuthTokenExpiry = "";
                        Chiaki.settings.psnAccountId = "";
                    }, null, root.t("Desconectar"), true)
                }
                InBotao {
                    implicitWidth: Math.max(120, implicitContentWidth + 36)
                    text: cfg.psnConectada ? root.t("Trocar de conta") : root.t("Conectar")
                    onClicked: root.showPSNTokenDialog(false)
                }
            }
        }

        InCartao {
            RowLayout {
                Layout.fillWidth: true
                spacing: 12
                ColumnLayout {
                    Layout.fillWidth: true
                    Layout.maximumWidth: Number.POSITIVE_INFINITY   // a coluna estica mesmo com parágrafo de 680 px; o botão fica na borda
                    spacing: 4
                    InTexto { tipo: "titulo"; text: root.t("Conta Microsoft (Xbox)") }
                    InTexto {
                        Layout.fillWidth: true
                        tipo: "apoio"
                        text: cfg.xboxEntrou
                            ? root.t("O login fica guardado só neste PC, na janela do Xbox do Incipit Play.")
                            : root.t("Ainda não entrou. A senha você digita na página da Microsoft, nunca aqui.")
                    }
                }
                InBotao {
                    visible: cfg.xboxEntrou
                    tipo: "quieto"
                    text: root.t("Sair da conta")
                    onClicked: cfg.abrirMicrosoft("https://login.live.com/logout.srf")
                }
                InBotao {
                    implicitWidth: Math.max(120, implicitContentWidth + 36)
                    text: cfg.xboxEntrou ? root.t("Abrir conta") : root.t("Conectar")
                    onClicked: cfg.abrirMicrosoft("https://www.xbox.com/pt-BR/play/consoles")
                }
            }
        }

        InTexto {
            Layout.fillWidth: true
            tipo: "pequeno"
            text: root.t("Switch não tem conta aqui: a imagem vem da placa de captura.")
        }
    }

    // ============================================================ PERSONALIZAR
    ColumnLayout {
        visible: cfg.secao === "personalizar"
        Layout.fillWidth: true
        spacing: 16

        InCartao {
            InTexto { tipo: "titulo"; text: root.t("Idioma"); Layout.bottomMargin: -8 }
            InTexto { Layout.fillWidth: true; tipo: "apoio"; text: root.t("Troca o texto do app inteiro na hora e abre o login da Sony no mesmo idioma.") }
            Row {
                Layout.topMargin: 4
                spacing: 12
                Repeater {
                    model: [["pt", "Português"], ["en", "English"]]
                    delegate: InOpcao {
                        required property var modelData
                        texto: modelData[1]
                        marcada: root.lingua.idioma === modelData[0]
                        onClicked: root.lingua.escolher(modelData[0])
                    }
                }
            }
        }

        InCartao {
            InTexto { tipo: "titulo"; text: root.t("Tema") }
            Row {
                spacing: 12
                Repeater {
                    model: [["dark", root.t("Escuro")], ["light", root.t("Claro")], ["system", root.t("Do Windows")]]
                    delegate: InOpcao {
                        required property var modelData
                        texto: modelData[1]
                        marcada: root.tema.modo === modelData[0]
                        onClicked: root.tema.escolherModo(modelData[0])
                    }
                }
            }
        }

        InCartao {
            InTexto { tipo: "titulo"; text: root.t("Cor de destaque"); Layout.bottomMargin: -8 }
            InTexto { Layout.fillWidth: true; tipo: "apoio"; text: root.t("Vale pra aba ativa, o logo e os detalhes. O padrão é Hora azul.") }
            GridLayout {
                Layout.fillWidth: true
                Layout.topMargin: 4
                columns: width >= 1200 ? 8 : 4
                uniformCellWidths: true
                columnSpacing: 10
                rowSpacing: 10
                Repeater {
                    model: root.tema.destaques
                    delegate: InOpcao {
                        required property var modelData
                        Layout.fillWidth: true
                        texto: root.t(modelData.nome)
                        amostra: root.tema.escuro ? modelData.escuro : modelData.claro
                        marcada: root.tema.destaqueId === modelData.id
                        onClicked: root.tema.escolherDestaque(modelData.id)
                    }
                }
            }
        }
    }

    // ============================================================ VÍDEO
    ColumnLayout {
        visible: cfg.secao === "video"
        Layout.fillWidth: true
        spacing: 16

        InCartao {
            InTexto { tipo: "titulo"; text: root.t("PlayStation em casa"); Layout.bottomMargin: 8 }
            GridLayout {
                Layout.fillWidth: true
                columns: 2
                columnSpacing: 24
                rowSpacing: 12

                InTexto { text: root.t("Resolução"); font.weight: Font.DemiBold; Layout.preferredWidth: 180; Layout.preferredHeight: 44; verticalAlignment: Text.AlignVCenter }
                InEscolha {
                    Layout.preferredWidth: 320
                    model: ["360p", "540p", "720p", root.t("1080p (padrão)")]
                    currentIndex: Chiaki.settings.resolutionLocalPS5 - 1
                    onActivated: (i) => Chiaki.settings.resolutionLocalPS5 = i + 1
                }

                InTexto { text: root.t("Quadros por segundo"); font.weight: Font.DemiBold; Layout.preferredHeight: 44; verticalAlignment: Text.AlignVCenter }
                InEscolha {
                    Layout.preferredWidth: 320
                    model: ["30", root.t("60 (padrão)")]
                    currentIndex: Chiaki.settings.fpsLocalPS5 >= 60 ? 1 : 0
                    onActivated: (i) => Chiaki.settings.fpsLocalPS5 = (i + 1) * 30
                }

                InTexto { text: root.t("Formato do vídeo"); font.weight: Font.DemiBold; Layout.preferredHeight: 44; verticalAlignment: Text.AlignVCenter }
                InEscolha {
                    Layout.preferredWidth: 320
                    model: [root.t("H.264 (PC mais antigo)"), root.t("H.265 (padrão)"), root.t("H.265 HDR")]
                    currentIndex: Chiaki.settings.codecLocalPS5
                    onActivated: (i) => Chiaki.settings.codecLocalPS5 = i
                }

                InTexto { text: root.t("Qualidade (bitrate)"); font.weight: Font.DemiBold; Layout.preferredHeight: 44; verticalAlignment: Text.AlignVCenter }
                InEscolha {
                    Layout.preferredWidth: 320
                    readonly property var valores: [0, 10000, 20000, 30000, 40000, 50000]
                    model: [root.t("Automática (padrão)"), root.t("10 Mbps"), root.t("20 Mbps"), root.t("30 Mbps"), root.t("40 Mbps"), root.t("50 Mbps")]
                    currentIndex: Math.max(0, valores.indexOf(Chiaki.settings.bitrateLocalPS5))
                    onActivated: (i) => Chiaki.settings.bitrateLocalPS5 = valores[i]
                }
            }
            InTexto {
                Layout.fillWidth: true
                Layout.topMargin: 4
                tipo: "pequeno"
                text: root.t("Muda na próxima vez que você jogar. HDR precisa de tela com HDR ligado no Windows.")
            }
        }

        InCartao {
            RowLayout {
                Layout.fillWidth: true
                spacing: 12
                ColumnLayout {
                    Layout.fillWidth: true
                    Layout.maximumWidth: Number.POSITIVE_INFINITY   // a coluna estica mesmo com parágrafo de 680 px; o botão fica na borda
                    spacing: 4
                    InTexto { tipo: "titulo"; text: root.t("Mais ajustes") }
                    InTexto { Layout.fillWidth: true; tipo: "apoio"; text: root.t("Fora de casa, controle, áudio, renderização e consoles ocultos, na tela do motor.") }
                }
                InBotao { text: root.t("Abrir mais ajustes"); icone: "engrenagem"; onClicked: root.showSettingsDialog() }
            }
        }
    }

    // ============================================================ SOBRE
    ColumnLayout {
        visible: cfg.secao === "sobre"
        Layout.fillWidth: true
        spacing: 16

        InCartao {
            Row {
                spacing: 14
                InMarca { altura: 40; anchors.verticalCenter: parent.verticalCenter }
                Column {
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 2
                    InTexto { tipo: "secao"; text: "Incipit Play" }
                    InTexto { tipo: "pequeno"; text: root.t("Versão %1").arg(Chiaki.appVersion()) }
                }
            }
            InTexto {
                Layout.fillWidth: true
                Layout.topMargin: 6
                tipo: "apoio"
                text: root.t("Feito sobre o chiaki-ng (Street Pea e colaboradores), que nasceu do Chiaki de Florian Markl. O motor de PlayStation é deles; o desenho e o hub são da Incipit. PlayStation, Xbox e Switch são marcas dos seus donos e aparecem aqui só pra dizer o console.")
            }
            InTexto {
                Layout.fillWidth: true
                tipo: "apoio"
                text: root.t("Licença AGPL-3.0: quem recebe o Incipit Play tem direito ao código-fonte, inclusive das mudanças.")
            }
            Row {
                Layout.topMargin: 8
                spacing: 12
                InBotao { text: root.t("Código do Incipit Play"); icone: "externo"; onClicked: Qt.openUrlExternally("https://github.com/dalmor0/incipit-play") }
                InBotao { text: "chiaki-ng"; icone: "externo"; onClicked: Qt.openUrlExternally("https://github.com/streetpea/chiaki-ng") }
                InBotao { text: root.t("Licença"); icone: "externo"; onClicked: Qt.openUrlExternally("https://www.gnu.org/licenses/agpl-3.0.html") }
            }
        }
    }

    component SelosConta: Rectangle {
        property string sigla
        property bool ligado
        Layout.preferredWidth: 52
        Layout.preferredHeight: 52
        color: root.tema.fundo
        border.width: 1
        border.color: ligado ? root.tema.ok : root.tema.linha
        InTexto { anchors.centerIn: parent; text: parent.sigla; font.weight: Font.Bold; color: parent.ligado ? root.tema.ok : root.tema.texto2 }
    }
}
