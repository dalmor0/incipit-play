// Aba Xbox: Remote Play oficial da Microsoft (xbox.com/play/consoles) numa janela própria, sem barra de navegador.
// A Microsoft tirou o Remote Play do app do Xbox no PC e deixou só na web; o login e a senha ficam na página dela.
import QtQuick
import QtQuick.Layouts
import QtQuick.Controls

import org.streetpea.chiaking

InPagina {
    id: xb
    titulo: "Xbox"
    apoio: "Jogue no Xbox da sua casa pelo Remote Play oficial da Microsoft, numa janela própria."

    readonly property string endereco: "https://www.xbox.com/pt-BR/play/consoles"
    readonly property string perfil: Chiaki.localDataPath() + "/xbox-web"
    readonly property string edge: {
        const c = ["C:/Program Files (x86)/Microsoft/Edge/Application/msedge.exe", "C:/Program Files/Microsoft/Edge/Application/msedge.exe"];
        for (let i = 0; i < c.length; i++) if (Chiaki.pathExists(c[i])) return c[i];
        return "";
    }
    readonly property bool jaEntrou: Chiaki.pathExists(perfil + "/Default")
    property string aviso: ""

    function abrir(url) {
        if (edge !== "" && Chiaki.launchDetached(edge, ["--app=" + url, "--user-data-dir=" + perfil, "--no-first-run",
                "--no-default-browser-check", "--window-size=1280,800"])) {
            aviso = "Abriu numa janela nova. Se pedir, entre com a conta Microsoft do Xbox.";
            return;
        }
        Qt.openUrlExternally(url);
        aviso = "Abriu no navegador padrão (o Edge não foi achado neste PC).";
    }

    acoes: [
        InBotao {
            text: "Abrir no navegador padrão"
            icone: "externo"
            onClicked: { Qt.openUrlExternally(xb.endereco); xb.aviso = "Abriu no navegador padrão."; }
        }
    ]

    InCartao {
        respiro: 32
        marcado: true
        RowLayout {
            Layout.fillWidth: true
            spacing: 24
            ColumnLayout {
                Layout.fillWidth: true
                spacing: 6
                InTexto { tipo: "titulo"; text: xb.jaEntrou ? "Pronto pra jogar" : "Primeira vez aqui" }
                InTexto {
                    Layout.fillWidth: true
                    tipo: "apoio"
                    text: xb.jaEntrou
                        ? "O login da conta Microsoft fica guardado só neste PC. Abra e escolha o console."
                        : "Abra, entre com a conta Microsoft do Xbox (a senha você digita na página da Microsoft) e escolha o console."
                }
            }
            InBotao {
                tipo: "forte"
                text: "Abrir Remote Play do Xbox"
                icone: "jogar"
                onClicked: xb.abrir(xb.endereco)
            }
        }
        InTexto {
            Layout.fillWidth: true
            visible: xb.aviso !== ""
            tipo: "pequeno"
            color: root.tema.destaque
            text: xb.aviso
        }
    }

    InTexto { Layout.topMargin: 16; tipo: "rotulo"; text: "Antes da primeira vez, no console" }

    InCartao {
        Repeater {
            model: [
                ["1", "Ative os recursos remotos", "No Xbox: Configurações > Dispositivos e conexões > Recursos remotos > Habilitar recursos remotos."],
                ["2", "Deixe em Modo instantâneo ou ligado", "Em Configurações > Geral > Modo de energia, escolha Modo de suspensão (o Xbox acorda sozinho quando você abre)."],
                ["3", "Use a mesma conta", "A conta Microsoft que entra aqui precisa ser a mesma do console. Controle no USB ou Bluetooth funciona direto."]
            ]
            delegate: RowLayout {
                required property var modelData
                Layout.fillWidth: true
                Layout.bottomMargin: 6
                spacing: 16
                Rectangle {
                    Layout.preferredWidth: 32; Layout.preferredHeight: 32
                    Layout.alignment: Qt.AlignTop
                    color: "transparent"; border.width: 1; border.color: root.tema.borda
                    InTexto { anchors.centerIn: parent; text: modelData[0]; font.weight: Font.DemiBold }
                }
                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 2
                    InTexto { Layout.fillWidth: true; text: modelData[1]; font.weight: Font.DemiBold }
                    InTexto { Layout.fillWidth: true; tipo: "apoio"; text: modelData[2] }
                }
            }
        }
    }

    InCartao {
        RowLayout {
            Layout.fillWidth: true
            spacing: 20
            ColumnLayout {
                Layout.fillWidth: true
                spacing: 4
                InTexto { tipo: "titulo"; text: "Sem Xbox na conta?" }
                InTexto {
                    Layout.fillWidth: true
                    tipo: "apoio"
                    text: "A lista da Microsoft aparece vazia e mostra como ligar um console. Nada quebra aqui: quando tiver um Xbox, é só abrir de novo."
                }
            }
        }
    }
}
