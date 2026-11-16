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
    Keys.onPressed: (e) => {
        if (e.key === Qt.Key_F11) { telaCheia(Chiaki.window.visibility !== Window.FullScreen); e.accepted = true; }
    }
    Keys.onEscapePressed: {
        if (Chiaki.window.visibility === Window.FullScreen) telaCheia(false);
        else if (aba !== "playstation") irPara("playstation");
    }

    readonly property var abas: [
        { id: "playstation", nome: "PlayStation", icone: "controle" },
        { id: "xbox", nome: "Xbox", icone: "tela" },
        { id: "switch", nome: "Switch", icone: "placa" },
        { id: "clipes", nome: "Clipes", icone: "video" }
    ]

    // ------------------------------------------------------------ trilho
    Rectangle {
        id: trilho
        width: hub.width >= 1600 ? 264 : 232
        anchors { top: parent.top; bottom: parent.bottom; left: parent.left }
        color: hub.tema.sup

        Rectangle { anchors { top: parent.top; bottom: parent.bottom; right: parent.right } width: 1; color: hub.tema.linha }

        ColumnLayout {
            anchors { fill: parent; topMargin: 28; bottomMargin: 20 }
            spacing: 0

            Row {
                Layout.leftMargin: 24
                Layout.bottomMargin: 36
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
                texto: "Configurações"
                icone: "engrenagem"
                ativo: hub.aba === "config"
                onClicked: hub.irPara("config")
            }
        }
    }

    // ------------------------------------------------------------ página
    Item {
        id: pagina
        anchors { top: parent.top; bottom: parent.bottom; left: trilho.right; right: parent.right }

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

    component ItemTrilho: AbstractButton {
        id: it
        property string texto
        property string icone
        property bool ativo
        implicitHeight: 48
        focusPolicy: Qt.StrongFocus
        hoverEnabled: true
        Accessible.name: texto
        background: Rectangle {
            color: it.ativo ? hub.tema.fundo : (it.hovered ? hub.tema.destaqueFraco : "transparent")
            Rectangle { visible: it.ativo; width: 3; anchors { top: parent.top; bottom: parent.bottom; left: parent.left } color: hub.tema.destaque }
            Rectangle {
                visible: it.visualFocus
                anchors.fill: parent; anchors.margins: 2
                color: "transparent"; border.width: 2; border.color: hub.tema.texto
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
