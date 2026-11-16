// Configurações: Contas conectadas, Personalizar, Vídeo e Sobre. O resto dos ajustes do motor do PlayStation fica
// em "Mais ajustes", a tela completa do chiaki-ng.
import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import QtCore

import org.streetpea.chiaking

InPagina {
    id: cfg
    titulo: "Configurações"
    apoio: ""

    Settings { id: lembrar; category: "hub"; property string secao: "contas" }
    property string secao: lembrar.secao
    function ir(s) { secao = s; lembrar.secao = s; }

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
            model: [["contas", "Contas conectadas"], ["personalizar", "Personalizar"], ["video", "Vídeo"], ["sobre", "Sobre"]]
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
            RowLayout {
                Layout.fillWidth: true
                spacing: 12
                ColumnLayout {
                    Layout.fillWidth: true
                    Layout.maximumWidth: Number.POSITIVE_INFINITY   // a coluna estica mesmo com parágrafo de 680 px; o botão fica na borda
                    spacing: 4
                    InTexto { tipo: "titulo"; text: "PlayStation Network" }
                    InTexto {
                        Layout.fillWidth: true
                        tipo: "apoio"
                        text: cfg.psnConectada
                            ? (Chiaki.settings.streamerMode ? "Conectada." : "Conectada · conta terminada em " + String(Chiaki.settings.psnAccountId).slice(-4))
                            : "Não conectada. Conectar libera o registro automático e jogar fora de casa."
                    }
                }
                InBotao {
                    visible: cfg.psnConectada
                    tipo: "quieto"
                    text: "Desconectar"
                    onClicked: root.showConfirmDialog("Desconectar PSN", "Tirar a conta PSN do Incipit Play? Os consoles registrados continuam funcionando em casa.", () => {
                        Chiaki.settings.psnRefreshToken = "";
                        Chiaki.settings.psnAuthToken = "";
                        Chiaki.settings.psnAuthTokenExpiry = "";
                        Chiaki.settings.psnAccountId = "";
                    })
                }
                InBotao {
                    implicitWidth: Math.max(120, implicitContentWidth + 36)
                    text: cfg.psnConectada ? "Conectar de novo" : "Conectar"
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
                    InTexto { tipo: "titulo"; text: "Conta Microsoft (Xbox)" }
                    InTexto {
                        Layout.fillWidth: true
                        tipo: "apoio"
                        text: cfg.xboxEntrou
                            ? "O login fica guardado só neste PC, na janela do Xbox do Incipit Play."
                            : "Ainda não entrou. A senha você digita na página da Microsoft, nunca aqui."
                    }
                }
                InBotao {
                    visible: cfg.xboxEntrou
                    tipo: "quieto"
                    text: "Sair da conta"
                    onClicked: cfg.abrirMicrosoft("https://login.live.com/logout.srf")
                }
                InBotao {
                    implicitWidth: Math.max(120, implicitContentWidth + 36)
                    text: cfg.xboxEntrou ? "Abrir conta" : "Conectar"
                    onClicked: cfg.abrirMicrosoft("https://www.xbox.com/pt-BR/play/consoles")
                }
            }
        }

        InTexto {
            Layout.fillWidth: true
            tipo: "pequeno"
            text: "Switch não tem conta aqui: a imagem vem da placa de captura."
        }
    }

    // ============================================================ PERSONALIZAR
    ColumnLayout {
        visible: cfg.secao === "personalizar"
        Layout.fillWidth: true
        spacing: 16

        InCartao {
            InTexto { tipo: "titulo"; text: "Tema" }
            Row {
                spacing: 12
                Repeater {
                    model: [["dark", "Escuro"], ["light", "Claro"], ["system", "Do Windows"]]
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
            InTexto { tipo: "titulo"; text: "Cor de destaque"; Layout.bottomMargin: -8 }
            InTexto { Layout.fillWidth: true; tipo: "apoio"; text: "Vale pros botões, a aba ativa e a porta da marca. O padrão é Hora azul." }
            GridLayout {
                Layout.fillWidth: true
                Layout.topMargin: 4
                columns: 4
                uniformCellWidths: true
                Layout.maximumWidth: 920
                columnSpacing: 10
                rowSpacing: 10
                Repeater {
                    model: root.tema.destaques
                    delegate: InOpcao {
                        required property var modelData
                        Layout.fillWidth: true
                        texto: modelData.nome
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
            InTexto { tipo: "titulo"; text: "PlayStation em casa"; Layout.bottomMargin: 8 }
            GridLayout {
                Layout.fillWidth: true
                columns: 2
                columnSpacing: 24
                rowSpacing: 12

                InTexto { text: "Resolução"; font.weight: Font.DemiBold; Layout.preferredWidth: 180; Layout.preferredHeight: 44; verticalAlignment: Text.AlignVCenter }
                InEscolha {
                    Layout.preferredWidth: 320
                    model: ["360p", "540p", "720p", "1080p (padrão)"]
                    currentIndex: Chiaki.settings.resolutionLocalPS5 - 1
                    onActivated: (i) => Chiaki.settings.resolutionLocalPS5 = i + 1
                }

                InTexto { text: "Quadros por segundo"; font.weight: Font.DemiBold; Layout.preferredHeight: 44; verticalAlignment: Text.AlignVCenter }
                InEscolha {
                    Layout.preferredWidth: 320
                    model: ["30", "60 (padrão)"]
                    currentIndex: Chiaki.settings.fpsLocalPS5 >= 60 ? 1 : 0
                    onActivated: (i) => Chiaki.settings.fpsLocalPS5 = (i + 1) * 30
                }

                InTexto { text: "Formato do vídeo"; font.weight: Font.DemiBold; Layout.preferredHeight: 44; verticalAlignment: Text.AlignVCenter }
                InEscolha {
                    Layout.preferredWidth: 320
                    model: ["H.264 (PC mais antigo)", "H.265 (padrão)", "H.265 HDR"]
                    currentIndex: Chiaki.settings.codecLocalPS5
                    onActivated: (i) => Chiaki.settings.codecLocalPS5 = i
                }

                InTexto { text: "Qualidade (bitrate)"; font.weight: Font.DemiBold; Layout.preferredHeight: 44; verticalAlignment: Text.AlignVCenter }
                InEscolha {
                    Layout.preferredWidth: 320
                    readonly property var valores: [0, 10000, 20000, 30000, 40000, 50000]
                    model: ["Automática (padrão)", "10 Mbps", "20 Mbps", "30 Mbps", "40 Mbps", "50 Mbps"]
                    currentIndex: Math.max(0, valores.indexOf(Chiaki.settings.bitrateLocalPS5))
                    onActivated: (i) => Chiaki.settings.bitrateLocalPS5 = valores[i]
                }
            }
            InTexto {
                Layout.fillWidth: true
                Layout.topMargin: 4
                tipo: "pequeno"
                text: "Muda na próxima vez que você jogar. HDR precisa de tela com HDR ligado no Windows."
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
                    InTexto { tipo: "titulo"; text: "Mais ajustes" }
                    InTexto { Layout.fillWidth: true; tipo: "apoio"; text: "Fora de casa, controle, áudio, renderização e consoles ocultos, na tela do motor." }
                }
                InBotao { text: "Abrir mais ajustes"; icone: "engrenagem"; onClicked: root.showSettingsDialog() }
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
                    InTexto { tipo: "pequeno"; text: "Versão " + Chiaki.appVersion() }
                }
            }
            InTexto {
                Layout.fillWidth: true
                Layout.topMargin: 6
                tipo: "apoio"
                text: "Feito sobre o chiaki-ng (Street Pea e colaboradores), que nasceu do Chiaki de Florian Markl. O motor de PlayStation é deles; o desenho e o hub são da Incipit. PlayStation, Xbox e Switch são marcas dos seus donos e aparecem aqui só pra dizer o console."
            }
            InTexto {
                Layout.fillWidth: true
                tipo: "apoio"
                text: "Licença AGPL-3.0: quem recebe o Incipit Play tem direito ao código-fonte, inclusive das mudanças."
            }
            Row {
                Layout.topMargin: 8
                spacing: 12
                InBotao { text: "Código do Incipit Play"; icone: "externo"; onClicked: Qt.openUrlExternally("https://github.com/dalmor0/incipit-play") }
                InBotao { text: "chiaki-ng"; icone: "externo"; onClicked: Qt.openUrlExternally("https://github.com/streetpea/chiaki-ng") }
                InBotao { text: "Licença"; icone: "externo"; onClicked: Qt.openUrlExternally("https://www.gnu.org/licenses/agpl-3.0.html") }
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
