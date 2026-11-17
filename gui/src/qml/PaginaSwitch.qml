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
    apoio: root.t("A Nintendo não tem Remote Play. Dá pra jogar pela placa de captura ligada no PC.")

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
        return f ? root.t("%1×%2 a %3 quadros").arg(f.resolution.width).arg(f.resolution.height).arg(Math.round(f.maxFrameRate)) : "";
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
        recorder: gravador
    }

    // ------------------------------------------------------------ clipes da placa
    // Enquanto a placa está aberta e os clipes ligados, grava em pedaços de 5 min numa pasta temporária. O atalho
    // fecha o pedaço atual, corta o fim dos dois últimos (sem recodificar) e começa outro.
    property int pedaco: 0
    property var pedacos: []
    property bool salvarAoParar: false
    readonly property bool gravar: sw.ligada && sw.temPlaca && root.clipes.ligado
    function arquivoPedaco(n) { return Clips.tempCaptureDir() + "/placa-" + n + ".mkv"; }
    function comecarPedaco() {
        pedaco++;
        const f = arquivoPedaco(pedaco);
        pedacos = pedacos.concat([f]);
        while (pedacos.length > 3) { Clips.removeTemp(pedacos[0]); pedacos = pedacos.slice(1); }
        gravador.outputLocation = "file:///" + f;
        gravador.record();
    }
    onGravarChanged: {
        if (gravar) Qt.callLater(comecarPedaco);
        else if (gravador.recorderState !== MediaRecorder.StoppedState) gravador.stop();
    }
    MediaRecorder {
        id: gravador
        quality: MediaRecorder.HighQuality
        mediaFormat {
            fileFormat: MediaFormat.Matroska
            videoCodec: MediaFormat.VideoCodec.H264
            audioCodec: MediaFormat.AudioCodec.AAC
        }
        onRecorderStateChanged: {
            if (recorderState !== MediaRecorder.StoppedState) return;
            if (sw.salvarAoParar) {
                sw.salvarAoParar = false;
                Clips.saveTailOfFiles(sw.pedacos.slice(-2), root.clipes.segundos, "Switch");
            }
            if (sw.gravar) Qt.callLater(sw.comecarPedaco);
        }
    }
    Timer { interval: 300000; repeat: true; running: sw.gravar; onTriggered: gravador.stop() }
    Connections {
        target: Clips
        function onClipRequested() {
            if (gravador.recorderState === MediaRecorder.RecordingState) { sw.salvarAoParar = true; gravador.stop(); }
        }
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
        InTexto { tipo: "titulo"; text: root.t("Nenhuma placa de captura ligada"); Layout.bottomMargin: -8 }
        InTexto {
            Layout.fillWidth: true
            tipo: "apoio"
            text: root.t("Ligue o Switch na placa pelo HDMI e a placa no USB do PC. Placa UVC aparece aqui sozinha.")
        }
    }

    // ------------------------------------------------------------ com placa
    InCartao {
        visible: sw.temPlaca
        marcado: true

        GridLayout {
            Layout.fillWidth: true
            columns: 2
            columnSpacing: 20
            rowSpacing: 14

            InTexto { text: root.t("Placa"); font.weight: Font.DemiBold; Layout.preferredWidth: 120; Layout.alignment: Qt.AlignVCenter }
            InEscolha {
                Layout.fillWidth: true
                model: sw.nomes(sw.placas, "")
                currentIndex: Math.min(sw.placaIdx, sw.placas.length - 1)
                onActivated: (i) => { sw.placaIdx = i; sw.somIdx = -2; }
            }

            InTexto { text: root.t("Som"); font.weight: Font.DemiBold; Layout.alignment: Qt.AlignVCenter }
            InEscolha {
                Layout.fillWidth: true
                model: sw.nomes(sw.sons, root.t("Sem som"))
                currentIndex: sw.somEscolhido + 1
                onActivated: (i) => sw.somIdx = i - 1
            }

            InTexto { text: root.t("Imagem"); font.weight: Font.DemiBold; visible: sw.formatoTexto !== "" }
            InTexto { tipo: "apoio"; text: sw.formatoTexto; visible: sw.formatoTexto !== "" }
        }

        Row {
            Layout.topMargin: 12
            spacing: 12
            InBotao { tipo: "forte"; text: root.t("Jogar em tela cheia"); icone: "telacheia"; onClicked: sw.telaCheia = true }
            InBotao { text: sw.testando ? root.t("Parar o teste") : root.t("Testar a imagem"); icone: "olho"; onClicked: sw.testando = !sw.testando }
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
                text: root.t("A placa não mandou imagem: %1").arg(camera.errorString)
            }
        }
    }

    InTexto {
        visible: sw.temPlaca
        Layout.topMargin: 8
        Layout.fillWidth: true
        tipo: "pequeno"
        text: root.t("Na tela cheia: Esc ou dois cliques pra sair. Pra menos atraso, use a placa no USB 3 e deixe o Switch em 1080p.")
    }

    // ------------------------------------------------------------ tela cheia
    Window {
        id: janelaCheia
        visibility: sw.telaCheia ? Window.FullScreen : Window.Hidden
        color: "black"
        title: root.t("Incipit Play · Switch")
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
            Text { id: dicaTexto; anchors.centerIn: parent; color: "white"; font.family: root.tema.sans; font.pixelSize: 15; text: root.t("Esc ou dois cliques pra sair") }
        }
        Timer { id: dicaTempo; interval: 2500; onTriggered: dica.opacity = 0 }
    }
}
