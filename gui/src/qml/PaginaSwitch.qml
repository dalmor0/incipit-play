// Aba Switch: a Nintendo não tem Remote Play. Aqui o jogo chega pela placa de captura (qualquer placa USB UVC)
// e abre em tela cheia, sem gravar nada.
import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import QtQuick.Window
import QtMultimedia

import org.streetpea.chiaking

InPagina {
    id: sw
    titulo: "Switch"
    apoio: "A Nintendo não tem Remote Play. Dá pra jogar pela placa de captura ligada no PC."

    MediaDevices { id: aparelhos }

    property int placaIdx: 0
    property int somIdx: -2        // -2 ainda não escolhido, -1 sem som
    property bool testando: false
    property bool telaCheia: false
    readonly property var placas: aparelhos.videoInputs
    readonly property var sons: aparelhos.audioInputs
    readonly property bool temPlaca: placas.length > 0
    readonly property var placa: temPlaca ? placas[Math.min(placaIdx, placas.length - 1)] : null

    // o melhor formato pra jogar: 60 quadros primeiro, depois até 1080p
    function melhorFormato(dev) {
        if (!dev) return undefined;
        let melhor = undefined, nota = -1;
        const fs = dev.videoFormats;
        for (let i = 0; i < fs.length; i++) {
            const f = fs[i];
            const n = Math.min(f.maxFrameRate, 60) * 10000 + Math.min(f.resolution.height, 1080);
            if (n > nota) { nota = n; melhor = f; }
        }
        return melhor;
    }
    // o som da placa costuma ter o mesmo nome dela ("USB Video" e "Digital Audio Interface (USB Video)")
    function somDaPlaca() {
        if (!placa) return -1;
        const nome = placa.description.toLowerCase();
        for (let i = 0; i < sons.length; i++) {
            const s = sons[i].description.toLowerCase();
            if (s.indexOf(nome) >= 0 || nome.indexOf(s) >= 0) return i;
        }
        return -1;
    }
    readonly property int somEscolhido: somIdx === -2 ? somDaPlaca() : somIdx
    readonly property string formatoTexto: {
        const f = melhorFormato(placa);
        return f ? f.resolution.width + "×" + f.resolution.height + " a " + Math.round(f.maxFrameRate) + " quadros" : "";
    }
    readonly property bool ligada: testando || telaCheia

    CaptureSession {
        id: sessao
        camera: Camera {
            id: camera
            active: sw.ligada && sw.temPlaca
            cameraDevice: sw.placa ? sw.placa : aparelhos.defaultVideoInput
        }
        audioInput: (sw.ligada && sw.somEscolhido >= 0) ? entrada : null
        audioOutput: (sw.ligada && sw.somEscolhido >= 0) ? saida : null
        videoOutput: sw.telaCheia ? videoCheio : videoTeste
    }
    Binding {
        target: camera
        property: "cameraFormat"
        when: sw.melhorFormato(sw.placa) !== undefined
        value: sw.melhorFormato(sw.placa)
    }
    function nomes(lista, antes) {
        let m = antes ? [antes] : [];
        for (let i = 0; i < lista.length; i++) m.push(lista[i].description);
        return m;
    }
    AudioInput { id: entrada; device: sw.somEscolhido >= 0 ? sw.sons[sw.somEscolhido] : aparelhos.defaultAudioInput }
    AudioOutput { id: saida }

    // ------------------------------------------------------------ sem placa
    InCartao {
        visible: !sw.temPlaca
        respiro: 32
        InTexto { tipo: "titulo"; text: "Nenhuma placa de captura ligada" }
        InTexto {
            Layout.fillWidth: true
            tipo: "apoio"
            text: "Ligue o Switch na placa pelo HDMI e a placa no USB do PC. Qualquer placa que funcione sem programa próprio (UVC) aparece aqui sozinha, sem reabrir o app."
        }
    }

    // ------------------------------------------------------------ com placa
    InCartao {
        visible: sw.temPlaca
        respiro: 32
        marcado: true

        GridLayout {
            Layout.fillWidth: true
            columns: 2
            columnSpacing: 20
            rowSpacing: 14

            InTexto { text: "Placa"; font.weight: Font.DemiBold; Layout.preferredWidth: 120 }
            InEscolha {
                Layout.fillWidth: true
                model: sw.nomes(sw.placas, "")
                currentIndex: Math.min(sw.placaIdx, sw.placas.length - 1)
                onActivated: (i) => { sw.placaIdx = i; sw.somIdx = -2; }
            }

            InTexto { text: "Som"; font.weight: Font.DemiBold }
            InEscolha {
                Layout.fillWidth: true
                model: sw.nomes(sw.sons, "Sem som")
                currentIndex: sw.somEscolhido + 1
                onActivated: (i) => sw.somIdx = i - 1
            }

            InTexto { text: "Imagem"; font.weight: Font.DemiBold; visible: sw.formatoTexto !== "" }
            InTexto { tipo: "apoio"; text: sw.formatoTexto; visible: sw.formatoTexto !== "" }
        }

        Row {
            Layout.topMargin: 12
            spacing: 10
            InBotao { tipo: "forte"; text: "Jogar em tela cheia"; icone: "telacheia"; onClicked: sw.telaCheia = true }
            InBotao { text: sw.testando ? "Parar o teste" : "Testar a imagem"; icone: "olho"; onClicked: sw.testando = !sw.testando }
        }
    }

    InCartao {
        visible: sw.temPlaca && sw.testando
        respiro: 0
        Rectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: (sw.largura) * 9 / 16
            color: "black"
            VideoOutput { id: videoTeste; anchors.fill: parent; fillMode: VideoOutput.PreserveAspectFit }
            InTexto {
                anchors.centerIn: parent
                visible: camera.error !== Camera.NoError
                color: "white"
                text: "A placa não mandou imagem: " + camera.errorString
            }
        }
    }

    InTexto {
        Layout.topMargin: 8
        Layout.fillWidth: true
        tipo: "pequeno"
        text: "Na tela cheia: Esc ou dois cliques pra sair. Pra menos atraso, use a placa no USB 3 e deixe o Switch em 1080p."
    }

    // ------------------------------------------------------------ tela cheia
    Window {
        id: janelaCheia
        visibility: sw.telaCheia ? Window.FullScreen : Window.Hidden
        color: "black"
        title: "Incipit Play · Switch"
        onClosing: sw.telaCheia = false
        onVisibleChanged: if (visible) { requestActivate(); dica.opacity = 1; dicaTempo.restart(); }

        VideoOutput { id: videoCheio; anchors.fill: parent; fillMode: VideoOutput.PreserveAspectFit }

        Item {
            anchors.fill: parent
            focus: true
            Keys.onEscapePressed: sw.telaCheia = false
            MouseArea { anchors.fill: parent; onDoubleClicked: sw.telaCheia = false; cursorShape: dica.opacity > 0 ? Qt.ArrowCursor : Qt.BlankCursor }
        }

        Rectangle {
            id: dica
            anchors { top: parent.top; horizontalCenter: parent.horizontalCenter; topMargin: 32 }
            width: dicaTexto.implicitWidth + 40; height: 44
            color: Qt.rgba(0, 0, 0, 0.7)
            Behavior on opacity { NumberAnimation { duration: 400 } }
            Text { id: dicaTexto; anchors.centerIn: parent; color: "white"; font.family: root.tema.sans; font.pixelSize: 15; text: "Esc ou dois cliques pra sair" }
        }
        Timer { id: dicaTempo; interval: 2500; onTriggered: dica.opacity = 0 }
    }
}
