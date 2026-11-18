// Incipit Play · tela inicial: trilho à esquerda (PlayStation, Xbox, Switch, Configurações) e a página da aba.
import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import QtCore
import QtQuick.Window

import org.streetpea.chiaking

Rectangle {
    id: hub
    readonly property var tema: root.tema
    color: tema.fundo

    // a aba fica guardada: abre onde a pessoa parou
    Settings {
        id: lembrar
        category: "hub"
        property string aba: "playstation"
    }
    property string aba: lembrar.aba
    function irPara(nome) { aba = nome; lembrar.aba = nome; }

    StackView.onActivated: {
        hub.forceActiveFocus(Qt.TabFocusReason);
        root.initialAsk = true;   // as perguntas de primeira abertura do chiaki-ng (Steam, PSN) não aparecem: viram botão
    }

    // F11 entra e sai da tela cheia; Esc sai da tela cheia ou volta pra aba PlayStation
    function telaCheia(ligar) { Chiaki.window.visibility = ligar ? Window.FullScreen : Window.Windowed; }
    // setas (e o direcional do controle, que o motor transforma em setas) andam o foco; Enter aperta
    function andar(frente) {
        const atual = Window.activeFocusItem || hub;
        const prox = atual.nextItemInFocusChain(frente);
        if (prox) prox.forceActiveFocus(Qt.TabFocusReason);
    }
    Keys.onPressed: (e) => {
        if (e.key === Qt.Key_F11) { telaCheia(Chiaki.window.visibility !== Window.FullScreen); e.accepted = true; }
        else if (e.key === Qt.Key_Down || e.key === Qt.Key_Right) { andar(true); e.accepted = true; }
        else if (e.key === Qt.Key_Up || e.key === Qt.Key_Left) { andar(false); e.accepted = true; }
    }
    Keys.onEscapePressed: {
        if (Chiaki.window.visibility === Window.FullScreen) telaCheia(false);
        else if (aba !== "playstation") irPara("playstation");
    }

    readonly property var abas: [
        { id: "playstation", nome: "PlayStation", icone: "controle" },
        { id: "xbox", nome: "Xbox", icone: "tela" },
        { id: "switch", nome: "Switch", icone: "placa" },
        { id: "clipes", nome: root.t("Clipes"), icone: "video" }
    ]

    // ------------------------------------------------------------ trilho
    Rectangle {
        id: trilho
        width: hub.width >= 1600 ? 264 : 232
        anchors { top: parent.top; bottom: parent.bottom; left: parent.left }
        color: hub.tema.sup

        Rectangle { anchors { top: parent.top; bottom: parent.bottom; right: parent.right } width: 1; color: hub.tema.linha }

        // a faixa da hora azul (a mesma pintura do site), fina no alto do menu, descendo pro tom do trilho
        Image {
            id: faixa
            anchors { top: parent.top; left: parent.left; right: parent.right; rightMargin: 1 }
            height: 56
            source: "imagens/hora-azul.jpg"
            fillMode: Image.PreserveAspectCrop
            asynchronous: true
            opacity: hub.tema.escuro ? 0.9 : 0.8
            Rectangle {
                anchors.fill: parent
                gradient: Gradient {
                    GradientStop { position: 0.35; color: "transparent" }
                    GradientStop { position: 1; color: hub.tema.sup }
                }
            }
        }

        ColumnLayout {
            anchors { fill: parent; topMargin: 76; bottomMargin: 20 }
            spacing: 0

            Row {
                Layout.leftMargin: 24
                Layout.bottomMargin: 28
                spacing: 12
                InMarca { altura: 30; anchors.verticalCenter: parent.verticalCenter }
                Text {
                    text: "Incipit Play"
                    font.family: hub.tema.serif
                    font.pixelSize: 22
                    color: hub.tema.texto
                    anchors.verticalCenter: parent.verticalCenter
                }
            }

            Repeater {
                model: hub.abas
                delegate: ItemTrilho {
                    required property var modelData
                    Layout.fillWidth: true
                    texto: modelData.nome
                    icone: modelData.icone
                    ativo: hub.aba === modelData.id
                    onClicked: hub.irPara(modelData.id)
                }
            }

            Item { Layout.fillHeight: true }

            ItemTrilho {
                Layout.fillWidth: true
                texto: root.t("Configurações")
                icone: "engrenagem"
                ativo: hub.aba === "config"
                onClicked: hub.irPara("config")
            }
        }
    }

    // ------------------------------------------------------------ página
    Item {
        id: pagina
        anchors { top: parent.top; bottom: parent.bottom; left: trilho.right; right: recentes.visible ? recentes.left : parent.right }

        Loader {
            anchors.fill: parent
            sourceComponent: hub.aba === "xbox" ? xbox : hub.aba === "switch" ? nintendo : hub.aba === "clipes" ? clipes : hub.aba === "config" ? config : playstation
        }
        Component { id: playstation; PaginaPlayStation {} }
        Component { id: xbox; PaginaXbox {} }
        Component { id: nintendo; PaginaSwitch {} }
        Component { id: config; PaginaConfig {} }
        Component { id: clipes; PaginaClipes {} }
    }

    // ------------------------------------------------------------ clipes recentes (tela larga, abas de jogar)
    // de 1680 px pra cima a coluna da página não enche a janela: os dois últimos clipes ocupam a direita
    property var ultimos: []
    function lerUltimos() {
        const l = Clips.library(), r = [];
        for (let i = 0; i < l.length && r.length < 2; i++)
            for (let j = 0; j < l[i].clipes.length && r.length < 2; j++) r.push(l[i].clipes[j]);
        ultimos = r;
    }
    Component.onCompleted: lerUltimos()
    Connections { target: Clips; function onLibraryChanged() { hub.lerUltimos(); } }

    Rectangle {
        id: recentes
        visible: hub.width >= 1680 && (hub.aba === "playstation" || hub.aba === "xbox" || hub.aba === "switch")
        width: 360
        anchors { top: parent.top; bottom: parent.bottom; right: parent.right }
        color: hub.tema.fundo
        Rectangle { anchors { top: parent.top; bottom: parent.bottom; left: parent.left } width: 1; color: hub.tema.linha }

        ColumnLayout {
            anchors { left: parent.left; right: parent.right; top: parent.top; leftMargin: 32; rightMargin: 40; topMargin: 46 }
            spacing: 16
            Text {
                text: root.t("Clipes recentes")
                font.family: hub.tema.serif
                font.pixelSize: 24
                color: hub.tema.texto
                Layout.bottomMargin: 8
            }
            InTexto {
                Layout.fillWidth: true
                visible: hub.ultimos.length === 0
                tipo: "apoio"
                text: root.t("Nenhum clipe ainda. Durante o jogo, aperte %1.").arg(root.clipes.atalho)
            }
            Repeater {
                model: hub.ultimos
                delegate: ColumnLayout {
                    id: rc
                    required property var modelData
                    Layout.fillWidth: true
                    spacing: 8
                    AbstractButton {
                        id: vid
                        Layout.fillWidth: true
                        implicitHeight: width * 9 / 16
                        hoverEnabled: true
                        focusPolicy: Qt.StrongFocus
                        Accessible.name: root.t("Assistir")
                        onClicked: Edicao.abrirVideo(rc.modelData.caminho)
                        Keys.onReturnPressed: clicked()
                        Keys.onEnterPressed: clicked()
                        background: Rectangle {
                            color: "black"
                            Image {
                                anchors.fill: parent
                                source: rc.modelData.miniatura || ""
                                fillMode: Image.PreserveAspectCrop
                                asynchronous: true
                                sourceSize.width: 576
                                opacity: vid.hovered ? 0.85 : 1
                            }
                            Rectangle {
                                anchors { right: parent.right; bottom: parent.bottom; margins: 8 }
                                width: durR.implicitWidth + 12; height: 24
                                color: Qt.rgba(18 / 255, 22 / 255, 36 / 255, 0.85)
                                visible: !!rc.modelData.segundos
                                Text { id: durR; anchors.centerIn: parent; color: "white"; font.family: hub.tema.mono; font.pixelSize: 13
                                    text: { const s = Math.round(rc.modelData.segundos || 0); return Math.floor(s / 60) + ":" + String(s % 60).padStart(2, "0"); } }
                            }
                            Rectangle {
                                visible: vid.visualFocus
                                anchors.fill: parent; anchors.margins: -4
                                color: "transparent"; border.width: 2; border.color: hub.tema.foco
                            }
                        }
                    }
                    Text {
                        Layout.bottomMargin: 8
                        text: Qt.formatDateTime(rc.modelData.criado, root.lingua.en ? "MM/dd HH:mm" : "dd/MM HH:mm")
                        font.family: hub.tema.mono
                        font.pixelSize: 13
                        color: hub.tema.texto2
                    }
                }
            }
            InBotao {
                Layout.topMargin: 4
                visible: hub.ultimos.length > 0
                text: root.t("Ver todos os clipes")
                onClicked: hub.irPara("clipes")
            }
        }
    }

    component ItemTrilho: AbstractButton {
        id: it
        property string texto
        property string icone
        property bool ativo
        implicitHeight: 48
        focusPolicy: Qt.StrongFocus
        hoverEnabled: true
        Accessible.name: texto
        Keys.onReturnPressed: clicked()
        Keys.onEnterPressed: clicked()
        // a aba de agora é o andar aceso: luz azul vindo da esquerda, fio no degradê do logo com brilho curto
        background: Rectangle {
            color: it.ativo ? "transparent" : (it.hovered ? hub.tema.sup3 : "transparent")
            Rectangle {
                visible: it.ativo
                anchors.fill: parent
                gradient: Gradient {
                    orientation: Gradient.Horizontal
                    GradientStop { position: 0; color: Qt.rgba(61 / 255, 99 / 255, 212 / 255, hub.tema.escuro ? 0.34 : 0.18) }
                    GradientStop { position: 1; color: Qt.rgba(61 / 255, 99 / 255, 212 / 255, hub.tema.escuro ? 0.05 : 0.03) }
                }
            }
            Rectangle {
                visible: it.ativo
                width: 18
                anchors { top: parent.top; bottom: parent.bottom; left: parent.left }
                gradient: Gradient {
                    orientation: Gradient.Horizontal
                    GradientStop { position: 0; color: hub.tema.brilho }
                    GradientStop { position: 1; color: "transparent" }
                }
            }
            Rectangle {
                visible: it.ativo
                width: 3
                anchors { top: parent.top; bottom: parent.bottom; left: parent.left }
                gradient: Gradient {
                    GradientStop { position: 0; color: hub.tema.luz2 }
                    GradientStop { position: 1; color: hub.tema.luz1 }
                }
            }
            Rectangle {
                visible: it.visualFocus
                anchors.fill: parent; anchors.margins: 2
                color: "transparent"; border.width: 2; border.color: hub.tema.foco
            }
        }
        contentItem: Row {
            leftPadding: 24
            spacing: 14
            InIcone {
                nome: it.icone; tamanho: 20
                cor: it.ativo ? hub.tema.destaque : hub.tema.texto2
                anchors.verticalCenter: parent.verticalCenter
            }
            Text {
                text: it.texto
                font.family: hub.tema.sans
                font.pixelSize: 16
                font.weight: it.ativo ? Font.DemiBold : Font.Normal
                color: it.ativo ? hub.tema.texto : hub.tema.texto2
                anchors.verticalCenter: parent.verticalCenter
            }
        }
    }
}
