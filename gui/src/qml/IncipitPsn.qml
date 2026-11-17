// Conectar a conta PSN com a cara do Incipit Play. O login acontece na página da Sony, numa janela do Edge aberta só
// pra isso (InPrivate: nada do login fica salvo no PC). O Play acompanha a janela pela porta de depuração local do
// Edge, pega o código da volta do login sozinho, fecha a janela e mostra o resultado: "Conta PSN conectada" e a volta
// pra Configurações > Contas conectadas. Sem Edge, abre no navegador padrão e pede pra colar o endereço final.
import QtQuick
import QtQuick.Layouts
import QtQuick.Controls

import org.streetpea.chiaking

Rectangle {
    id: pn
    property bool expirada: false
    property string origem: "config"        // "config" volta pra Configurações > Contas; "registro" volta pro registro
    readonly property var tema: root.tema
    color: tema.fundo

    readonly property bool conectada: !!(Chiaki.settings.psnAuthToken && Chiaki.settings.psnAccountId)
    // "ja" já conectada · "abrindo" · "esperando" janela da Sony aberta · "conectando" · "ok" · "erro" · "colar" sem Edge
    property string estado: "abrindo"
    property string erro: ""
    property bool erroSemJanela: false
    property string fimId: ""
    readonly property string volta: "https://remoteplay.dl.playstation.net/remoteplay/redirect"

    // ------------------------------------------------------------ janela da Sony (Edge com porta de depuração local)
    readonly property string edge: {
        // Edge da máquina ou instalado só pro usuário (AppData\Local\Microsoft\Edge)
        const local = String(Chiaki.localDataPath()).replace(/[\/]Incipit[\/]Incipit Play$/, "");
        const c = ["C:/Program Files (x86)/Microsoft/Edge/Application/msedge.exe", "C:/Program Files/Microsoft/Edge/Application/msedge.exe",
                   local + "/Microsoft/Edge/Application/msedge.exe"];
        for (let i = 0; i < c.length; i++) if (Chiaki.pathExists(c[i])) return c[i];
        return "";
    }
    property int porta: 0
    property string paginaId: ""
    property bool viuJanela: false
    property bool pegou: false
    property bool pedindo: false
    property int esperas: 0

    function urlLogin() {
        const local = root.lingua.en ? "en_US" : "pt_BR";
        return String(Chiaki.psnLoginUrl()).replace("request_locale=en_US", "request_locale=" + local).replace(/ /g, "%20");
    }
    // cada abertura da janela é uma tentativa; resposta de tentativa velha (ou depois de sair da tela) é ignorada
    property int tentativa: 0
    property bool saindo: false
    property var pedidoAberto: null
    function pedir(caminho, aoTerminar) {
        const x = new XMLHttpRequest();
        const minha = tentativa;
        x.onreadystatechange = function () {
            if (x.readyState !== XMLHttpRequest.DONE) return;
            if (pn.pedidoAberto === x) pn.pedidoAberto = null;
            if (pn.saindo || minha !== pn.tentativa) return;
            if (aoTerminar) aoTerminar(x.status, x.responseText);
        };
        x.open("GET", "http://127.0.0.1:" + porta + caminho);
        x.timeout = 1500;
        pedidoAberto = x;
        x.send();
    }
    function cancelarPedido() {
        const x = pedidoAberto;
        pedidoAberto = null;
        pedindo = false;
        if (x) x.abort();
    }
    // o C++ guarda o processo do Edge: fechar mata a árvore toda e apaga o perfil (nada da tentativa fica no disco)
    function fecharJanela() { Chiaki.psnLoginClose(); }
    property double abertaEm: 0
    function abrirSony() {
        vigia.stop();
        tentativa++;
        cancelarPedido();
        fecharJanela();
        erro = ""; erroSemJanela = false;
        pegou = false; viuJanela = false; pedindo = false; esperas = 0; paginaId = "";
        if (edge === "") { abrirNoNavegador(); return; }
        estado = "abrindo";
        porta = 41000 + Math.floor(Math.random() * 8000);
        const w = 520, h = 760;
        const x = Math.max(0, Math.round(Chiaki.window.x + (Chiaki.window.width - w) / 2));
        const y = Math.max(0, Math.round(Chiaki.window.y + (Chiaki.window.height - h) / 2));
        const ok = Chiaki.psnLoginOpen(edge, [
            "--remote-debugging-port=" + porta,
            "--inprivate", "--no-first-run", "--no-default-browser-check",
            "--window-size=" + w + "," + h, "--window-position=" + x + "," + y,
            "--app=" + urlLogin()
        ]);
        if (!ok) { abrirNoNavegador(); return; }
        abertaEm = Date.now();
        vigia.start();
    }
    property double pedidoEm: 0
    function olhar() {
        if (pegou) return;
        // a pessoa fechou a janela da Sony: o processo some na hora (a porta fechada demora uns segundos pra responder)
        if (viuJanela && !Chiaki.psnLoginAlive()) {
            vigia.stop();
            fecharJanela();
            falhar(root.tk("A janela da Sony fechou antes de o login terminar."), false);
            return;
        }
        // 20 s de relógio sem a página responder
        if (!viuJanela && Date.now() - abertaEm > 20000) {
            vigia.stop();
            cancelarPedido();
            fecharJanela();
            falhar(root.tk("A página de login da Sony não abriu."), true);
            return;
        }
        if (pedindo && Date.now() - pedidoEm < 2000) return;
        if (pedindo) cancelarPedido();
        pedindo = true;
        pedidoEm = Date.now();
        pedir("/json", function (status, corpo) {
            pn.pedindo = false;
            if (pn.pegou) return;
            let lista = null;
            if (status === 200) { try { lista = JSON.parse(corpo); } catch (e) { lista = null; } }
            if (!lista) {
                if (pn.viuJanela) {             // a janela fechou antes de o login voltar
                    vigia.stop();
                    pn.fecharJanela();
                    pn.falhar(root.tk("A janela da Sony fechou antes de o login terminar."), false);
                }
                return;
            }
            const paginas = lista.filter(p => p.type === "page" && String(p.url).startsWith("http"));
            if (paginas.length === 0) return;
            pn.viuJanela = true;
            pn.paginaId = paginas[0].id;
            const achou = paginas.find(p => String(p.url).startsWith(pn.volta));
            if (achou) {
                pn.pegou = true;
                vigia.stop();
                pn.fecharJanela();
                pn.conectar(achou.url);
            } else if (pn.estado === "abrindo") {
                pn.estado = "esperando";
            }
        });
    }
    Timer { id: vigia; interval: 500; repeat: true; onTriggered: pn.olhar() }

    // ------------------------------------------------------------ sem Edge: navegador padrão e colar o endereço
    function abrirNoNavegador() {
        vigia.stop();
        erro = ""; erroSemJanela = false;
        estado = "colar";
        Qt.openUrlExternally(urlLogin());
        Qt.callLater(() => { if (colado.campo) colado.campo.forceActiveFocus(); });
    }

    // ------------------------------------------------------------ resultado
    function conectar(url) {
        estado = "conectando";
        Chiaki.initPsnAuth(url, function (msg, ok, fim) {
            if (!fim || pn.saindo) return;
            if (ok) pn.conectou();
            else pn.falhar(pn.motivo(msg), false);
        });
    }
    function motivo(msg) {
        const m = String(msg || "");
        if (m.indexOf("Invalid URL") >= 0 || m.indexOf("Invalid code") >= 0)
            return root.tk("Esse endereço não é o da volta do login. Copie o endereço inteiro da barra do navegador.");
        if (/server replied/i.test(m))          // a Sony respondeu e recusou (código vencido ou usado)
            return root.tk("A Sony não confirmou o login.");
        if (/timed out|not found|refused|unreachable|resolve|ssl|closed|temporar|offline/i.test(m))
            return root.tk("Não deu pra falar com a PSN. Confira a internet.");
        return root.tk("A Sony não confirmou o login.");
    }
    function falhar(texto, semJanela) {
        console.warn("Incipit Play: PSN não conectou:", texto);
        erro = texto;
        erroSemJanela = semJanela;
        estado = "erro";
    }
    function conectou() {
        Chiaki.settings.remotePlayAsk = false;
        // o motor grava a conta direto no arquivo de config; regravar pelo QML avisa as telas abertas
        const id = Chiaki.settings.psnAccountId;
        Chiaki.settings.psnAccountId = id;
        Chiaki.settings.psnAuthToken = Chiaki.settings.psnAuthToken;
        fimId = root.fimIdPsn(id);
        estado = "ok";
        Chiaki.window.raise();
        Chiaki.window.requestActivate();
        // com "mostrar animações" desligado no Windows, a tela espera o clique (sem barra andando nem volta sozinha)
        if (!root.semMovimento) contagem.restart();
    }
    function concluir() {
        contagem.stop();
        root.psnRecemConectada = true;
        if (origem === "registro") root.closeDialog();
        else root.irParaConfig("contas");
    }
    function voltar() {
        saindo = true;
        vigia.stop();
        cancelarPedido();
        contagem.stop();
        fecharJanela();
        root.closeDialog();
    }
    Timer { id: contagem; interval: 3500; onTriggered: pn.concluir() }
    Component.onDestruction: { saindo = true; vigia.stop(); cancelarPedido(); fecharJanela(); }

    // durante "conectando" o motor já está falando com a Sony: sair agora gravaria a conta sem ninguém ver
    Keys.onEscapePressed: estado === "ok" ? concluir() : estado === "conectando" ? undefined : voltar()
    // o foco vai pro botão principal de cada resultado (teclado e leitor de tela chegam direto nele)
    onEstadoChanged: Qt.callLater(() => {
        if (estado === "ok") botaoOk.forceActiveFocus(Qt.TabFocusReason);
        else if (estado === "erro") botaoDeNovo.forceActiveFocus(Qt.TabFocusReason);
        else if (estado === "ja") botaoJa.forceActiveFocus(Qt.TabFocusReason);
        else if (estado === "esperando" || estado === "abrindo" || estado === "conectando") pn.forceActiveFocus();
    })
    StackView.onActivated: {
        if (estado !== "abrindo") return;
        if (conectada && !expirada) { fimId = root.fimIdPsn(Chiaki.settings.psnAccountId); estado = "ja"; }
        else abrirSony();
        pn.forceActiveFocus();
    }

    // ============================================================ tela
    ColumnLayout {
        width: Math.min(pn.width - 80, 680)
        x: (pn.width - width) / 2
        y: 32
        spacing: 16

        // uma saída por estado: o Voltar do topo some quando o cartão já tem a saída (esperando, conectando, ok)
        InBotao {
            readonly property bool usado: pn.estado === "ja" || pn.estado === "erro" || pn.estado === "colar"
            opacity: usado ? 1 : 0
            enabled: usado
            tipo: "quieto"; text: root.t("Voltar"); icone: "voltar"
            onClicked: pn.voltar()
        }
        InTexto {
            opacity: pn.estado === "ok" ? 0 : 1
            tipo: "secao"; font.pixelSize: 34
            text: pn.estado === "ok" || pn.estado === "ja" ? root.t("Conta PSN")
                : pn.expirada ? root.t("Entrar de novo na PSN") : root.t("Conectar conta PSN")
        }
        InTexto {
            visible: pn.estado !== "ok" && pn.estado !== "ja"
            Layout.fillWidth: true
            tipo: "apoio"
            text: pn.expirada
                ? root.t("A conexão com a PSN venceu. Entre de novo pra continuar jogando fora de casa.")
                : root.t("Conectar libera o registro automático e jogar fora de casa sem mexer no roteador.")
        }

        // ------------------------------------------------ esperando o login (abrindo, esperando, conectando)
        InCartao {
            visible: pn.estado === "abrindo" || pn.estado === "esperando" || pn.estado === "conectando"
            Layout.topMargin: 8
            respiro: 28
            InTexto {
                tipo: "titulo"
                text: pn.estado === "conectando" ? root.t("Conectando sua conta…")
                    : pn.estado === "esperando" ? root.t("Entre na janela da Sony") : root.t("Abrindo a página da Sony…")
            }
            InTexto {
                Layout.fillWidth: true
                tipo: "apoio"
                text: pn.estado === "conectando" ? root.t("A Sony confirmou o login. Falta só guardar a chave de acesso.")
                    : root.t("A página de login da PlayStation abre numa janela à parte.") + "\n" + root.t("Quando você terminar, o Incipit Play conecta sozinho.")
            }
            BarraAndando { visible: !root.semMovimento; Layout.fillWidth: true; Layout.topMargin: 4 }
            InTexto {
                Layout.fillWidth: true
                tipo: "pequeno"
                text: root.t("A senha fica com a Sony. O Incipit Play guarda só a chave de acesso, cifrada neste PC.")
            }
            Row {
                visible: pn.estado !== "conectando"
                Layout.topMargin: 8
                spacing: 12
                InBotao {
                    text: root.t("Mostrar a janela da Sony"); icone: "externo"
                    enabled: pn.estado === "esperando"
                    onClicked: if (pn.paginaId !== "") pn.pedir("/json/activate/" + pn.paginaId, null)
                }
                InBotao { tipo: "quieto"; text: root.t("Cancelar"); onClicked: pn.voltar() }
            }
        }

        // ------------------------------------------------ conectou
        InCartao {
            id: cartaoOk
            visible: pn.estado === "ok"
            Layout.topMargin: 8
            respiro: 40
            marcado: true
            border.color: root.tema.ok
            ColumnLayout {
                Layout.fillWidth: true
                Layout.maximumWidth: Number.POSITIVE_INFINITY   // ocupa o cartão inteiro: o conteúdo centra no meio dele
                spacing: 0
                Selo { Layout.alignment: Qt.AlignHCenter; tamanho: 72 }
                Text {
                    Layout.alignment: Qt.AlignHCenter
                    Layout.topMargin: 20
                    text: root.t("Conta PSN conectada")
                    Accessible.role: Accessible.AlertMessage
                    Accessible.name: text
                    font.family: root.tema.serif
                    font.pixelSize: 30
                    color: root.tema.texto
                }
                InTexto {
                    Layout.alignment: Qt.AlignHCenter
                    Layout.topMargin: 8
                    visible: pn.fimId !== "" && !Chiaki.settings.streamerMode
                    tipo: "apoio"
                    text: root.t("ID terminado em %1").arg(pn.fimId)
                }
                InTexto {
                    Layout.alignment: Qt.AlignHCenter
                    Layout.topMargin: 4
                    horizontalAlignment: Text.AlignHCenter
                    tipo: "apoio"
                    text: root.t("Registro automático e jogo fora de casa liberados.")
                }
                Rectangle {
                    id: trilhoContagem
                    visible: !root.semMovimento
                    Layout.alignment: Qt.AlignHCenter
                    Layout.topMargin: 20
                    Layout.preferredWidth: 280
                    Layout.preferredHeight: 3
                    color: root.tema.linha
                    Rectangle {
                        height: parent.height
                        color: root.tema.ok
                        width: 0
                        NumberAnimation on width {
                            running: pn.estado === "ok"
                            from: 0; to: trilhoContagem.width; duration: contagem.interval
                        }
                    }
                }
                InTexto {
                    Layout.alignment: Qt.AlignHCenter
                    Layout.topMargin: 8
                    tipo: "pequeno"
                    visible: !root.semMovimento
                    text: pn.origem === "registro" ? root.t("Voltando pro registro…") : root.t("Voltando pra Configurações…")
                }
                InBotao {
                    id: botaoOk
                    Layout.alignment: Qt.AlignHCenter
                    Layout.topMargin: 20
                    tipo: "forte"
                    text: pn.origem === "registro" ? root.t("Voltar pro registro") : root.t("Ir pra Configurações agora")
                    icone: "seta"
                    onClicked: pn.concluir()
                }
            }
        }

        // ------------------------------------------------ já estava conectada
        InCartao {
            visible: pn.estado === "ja"
            Layout.topMargin: 8
            respiro: 28
            border.color: root.tema.ok
            RowLayout {
                Layout.fillWidth: true
                spacing: 20
                Selo { tamanho: 48; Layout.alignment: Qt.AlignTop }
                ColumnLayout {
                    Layout.fillWidth: true
                    Layout.maximumWidth: Number.POSITIVE_INFINITY
                    spacing: 6
                    InTexto { tipo: "titulo"; text: root.t("Sua conta PSN já está conectada") }
                    InTexto {
                        Layout.fillWidth: true
                        tipo: "apoio"
                        text: (pn.fimId !== "" && !Chiaki.settings.streamerMode ? root.t("ID terminado em %1.").arg(pn.fimId) + " " : "")
                              + root.t("Não precisa conectar de novo.")
                    }
                    Row {
                        Layout.topMargin: 10
                        spacing: 12
                        InBotao { id: botaoJa; text: root.t("Trocar de conta"); icone: "pessoa"; onClicked: pn.abrirSony() }
                    }
                }
            }
        }

        // ------------------------------------------------ erro
        InCartao {
            visible: pn.estado === "erro"
            Layout.topMargin: 8
            respiro: 28
            border.color: root.tema.alerta
            RowLayout {
                Layout.fillWidth: true
                spacing: 16
                InIcone { nome: "alerta"; tamanho: 28; cor: root.tema.alerta; Layout.alignment: Qt.AlignTop; Layout.topMargin: 1 }
                ColumnLayout {
                    Layout.fillWidth: true
                    Layout.maximumWidth: Number.POSITIVE_INFINITY
                    spacing: 6
                    InTexto { tipo: "titulo"; text: root.t("Não deu pra conectar a conta") }
                    InTexto { Layout.fillWidth: true; tipo: "apoio"; text: root.t(pn.erro); Accessible.role: Accessible.AlertMessage; Accessible.name: text }
                    Row {
                        Layout.topMargin: 10
                        spacing: 12
                        InBotao { id: botaoDeNovo; tipo: "forte"; text: root.t("Tentar de novo"); icone: "atualizar"; onClicked: pn.abrirSony() }
                        InBotao { visible: pn.erroSemJanela; text: root.t("Abrir no navegador"); icone: "externo"; onClicked: pn.abrirNoNavegador() }
                    }
                }
            }
        }

        // ------------------------------------------------ sem Edge: colar o endereço
        InCartao {
            visible: pn.estado === "colar"
            Layout.topMargin: 8
            respiro: 28
            InTexto { tipo: "titulo"; text: root.t("Entre no navegador e cole o endereço final") }
            InTexto {
                Layout.fillWidth: true
                tipo: "apoio"
                text: root.t("A página da Sony abriu no seu navegador. Depois do login ela fica em branco: copie o endereço inteiro da barra e cole aqui.")
            }
            InCampo {
                id: colado
                Layout.fillWidth: true
                rotulo: root.t("Endereço depois do login")
                placeholderText: "https://remoteplay.dl.playstation.net/remoteplay/redirect?code=..."
                echoMode: Chiaki.settings.streamerMode ? TextInput.Password : TextInput.Normal
            }
            Row {
                Layout.topMargin: 8
                spacing: 12
                InBotao { tipo: "forte"; text: root.t("Conectar"); enabled: colado.text.trim() !== ""; onClicked: pn.conectar(colado.text.trim()) }
                InBotao { text: root.t("Abrir a página de novo"); icone: "externo"; onClicked: Qt.openUrlExternally(pn.urlLogin()) }
            }
        }
    }

    // ------------------------------------------------------------ peças
    component Selo: Rectangle {
        property real tamanho: 72
        implicitWidth: tamanho
        implicitHeight: tamanho
        Layout.preferredWidth: tamanho
        Layout.preferredHeight: tamanho
        radius: tamanho / 2
        color: root.tema.ok
        InIcone { anchors.centerIn: parent; nome: "check"; tamanho: parent.tamanho * 0.55; cor: root.tema.fundo }
    }
    component BarraAndando: Rectangle {
        id: barra
        implicitHeight: 3
        color: root.tema.linha
        clip: true
        Rectangle {
            id: pedaco
            width: barra.width * 0.3
            height: parent.height
            color: root.tema.destaque
            SequentialAnimation on x {
                running: barra.visible
                loops: Animation.Infinite
                NumberAnimation { from: -pedaco.width; to: barra.width; duration: 1400; easing.type: Easing.InOutQuad }
            }
        }
    }
}
