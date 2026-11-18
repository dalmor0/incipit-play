// Incipit Play · cor e tema. Tokens da família Incipit (azul-marinho #121624, degraus de superfície, azul do logo no
// botão forte); o destaque escolhido vale pra aba ativa, o logo e os detalhes. A escolha fica salva neste PC.
import QtQuick
import QtCore

QtObject {
    id: t

    // ------------------------------------------------------------ preferência
    property string modo: guardado.modo            // "dark" | "light" | "system"
    property string destaqueId: guardado.destaque

    property Settings guardado: Settings {
        category: "aparencia"
        property string modo: "dark"
        property string destaque: "hora-azul"
    }
    function escolherModo(m) { modo = m; guardado.modo = m; }
    function escolherDestaque(id) { destaqueId = id; guardado.destaque = id; }

    readonly property var destaques: [
        { id: "hora-azul", nome: "Hora azul", escuro: "#7DB0FF", claro: "#2F5FC8" },
        { id: "ceu", nome: "Céu", escuro: "#62C8FF", claro: "#0B6597" },
        { id: "porcelana", nome: "Porcelana", escuro: "#97D4F4", claro: "#1D6E96" },
        { id: "anil", nome: "Anil", escuro: "#8FA8E8", claro: "#2F4A8C" },
        { id: "turquesa", nome: "Turquesa", escuro: "#4FD1C5", claro: "#0F766E" },
        { id: "menta", nome: "Menta", escuro: "#7EDC9E", claro: "#1F7A45" },
        { id: "lima", nome: "Lima", escuro: "#C3E06A", claro: "#5B7A12" },
        { id: "luz", nome: "Luz de porta", escuro: "#E0703F", claro: "#B9472A" },
        { id: "ambar", nome: "Âmbar", escuro: "#F2A24E", claro: "#8A5A12" },
        { id: "sol", nome: "Sol", escuro: "#F5CF4E", claro: "#8A6A00" },
        { id: "coral", nome: "Coral", escuro: "#FF8A7A", claro: "#B23A2C" },
        { id: "rubi", nome: "Rubi", escuro: "#F2667A", claro: "#A3213A" },
        { id: "rosa", nome: "Rosa", escuro: "#F59BC8", claro: "#A8336F" },
        { id: "violeta", nome: "Violeta", escuro: "#B9A2FF", claro: "#6342C7" },
        { id: "uva", nome: "Uva", escuro: "#D08CF0", claro: "#7E2FA8" },
        { id: "grafite", nome: "Grafite", escuro: "#C9CED6", claro: "#3E4552" }
    ]

    // ------------------------------------------------------------ escuro agora
    // Qt.styleHints.colorScheme: 0 desconhecido, 1 claro, 2 escuro
    readonly property bool escuro: modo === "system" ? Qt.styleHints.colorScheme !== 1 : modo !== "light"

    // ------------------------------------------------------------ contas de cor
    function hexRgb(h) { h = String(h); return [1, 3, 5].map(i => parseInt(h.slice(i, i + 2), 16)); }
    function rgbHex(r) { return "#" + r.map(v => Math.max(0, Math.min(255, Math.round(v))).toString(16).padStart(2, "0")).join("").toUpperCase(); }
    function misturar(a, b, k) { const x = hexRgb(a), y = hexRgb(b); return rgbHex(x.map((v, i) => v + (y[i] - v) * k)); }
    function lum(h) { const n = hexRgb(h).map(v => v / 255).map(v => (v <= 0.03928 ? v / 12.92 : Math.pow((v + 0.055) / 1.055, 2.4))); return 0.2126 * n[0] + 0.7152 * n[1] + 0.0722 * n[2]; }
    function contraste(a, b) { const x = lum(a), y = lum(b); return (Math.max(x, y) + 0.05) / (Math.min(x, y) + 0.05); }
    function ajustarAte(cor, fundo, alvo) {
        let c = cor; const escuroFundo = lum(fundo) < 0.2;
        for (let i = 0; i < 24 && contraste(c, fundo) < alvo; i++) c = misturar(c, escuroFundo ? "#FFFFFF" : "#000000", 0.08);
        return c;
    }
    // Identidade da família Incipit (18/11, "Hall" com o brilho do "Andar aceso"): azul-marinho da marca, superfície
    // por degrau de tom, o botão forte sempre no azul do logo (qualquer destaque escolhido) e o degradê do logo só
    // onde a pessoa ganhou alguma coisa (aba acesa, cartão pronto, barra de progresso).
    function calcular(id, esc) {
        const b = esc
            ? { papel: "#121624", sup: "#171C2C", sup2: "#1D2335", sup3: "#252C42", tinta: "#E8EDF7", tinta2: "#A3ADC2",
                tinta3: "#8590A8", linha: "#262D41", forte: "#5A6685" }
            : { papel: "#E9EDF5", sup: "#F8F9FC", sup2: "#FFFFFF", sup3: "#DDE3EF", tinta: "#121624", tinta2: "#4A5470",
                tinta3: "#5C6680", linha: "#D0D7E5", forte: "#77819C" };
        const d = destaques.find(x => x.id === id) || destaques[0];
        const base = d.id === "hora-azul" ? (esc ? "#8FB4FF" : "#3D63D4") : (esc ? d.escuro : d.claro);
        const dest = ajustarAte(base, b.papel, 4.5);
        const cands = esc ? [b.papel, "#0B0D12", "#FFFFFF"] : ["#FFFFFF", b.papel, "#0B0D12"];
        const sobre = cands.find(c => contraste(dest, c) >= 4.5) || cands.reduce((m, c) => (contraste(dest, c) > contraste(dest, m) ? c : m), cands[0]);
        let porta;
        if (d.id === "hora-azul") porta = ["#C4E3FF", "#7FA6F0", "#3D63D4"];
        else porta = esc ? [misturar(dest, "#FFFFFF", 0.6), dest, misturar(dest, "#000000", 0.35)]
                         : [misturar(dest, "#FFFFFF", 0.15), dest, misturar(dest, "#000000", 0.32)];
        return {
            fundo: b.papel, sup: b.sup, sup2: b.sup2, sup3: b.sup3,
            texto: b.tinta, texto2: b.tinta2, texto3: b.tinta3, linha: b.linha, borda: ajustarAte(b.forte, b.papel, 3),
            destaque: dest, sobreDestaque: sobre,
            destaqueFraco: misturar(b.papel, dest, esc ? 0.14 : 0.10),
            ok: ajustarAte(esc ? "#6FCF97" : "#1B7048", b.papel, 4.5),
            quente: ajustarAte(esc ? "#F2B45C" : "#8A5A12", b.papel, 4.5),
            alerta: ajustarAte(esc ? "#F27D70" : "#B42318", b.papel, 4.5),
            erroFundo: esc ? "#2A1A22" : "#FBEAEA",
            porta1: porta[0], porta2: porta[1], porta3: porta[2],
            // a luz do sistema: no claro, o fim claro do degradê some no papel, então vai até o azul médio
            luz1: "#3D63D4", luz2: esc ? "#C4E3FF" : "#7FA6F0",
            foco: esc ? "#C4E3FF" : "#3D63D4"
        };
    }

    readonly property var p: calcular(destaqueId, escuro)
    readonly property color fundo: p.fundo
    readonly property color sup: p.sup
    readonly property color sup2: p.sup2
    readonly property color sup3: p.sup3
    readonly property color texto3: p.texto3
    readonly property color erroFundo: p.erroFundo
    readonly property color luz1: p.luz1
    readonly property color luz2: p.luz2
    readonly property color foco: p.foco
    // botão forte: o azul do logo em qualquer destaque e nos dois temas (branco em cima: 5,1:1 a 5,6:1)
    readonly property color forte1: "#4467D8"
    readonly property color forte2: "#3A5DCC"
    readonly property color forteMouse: "#4C72E0"
    readonly property color fortePreso: "#3354BC"
    readonly property color sobreForte: "#FFFFFF"
    readonly property color brilho: Qt.rgba(127 / 255, 166 / 255, 240 / 255, escuro ? 0.45 : 0.35)
    readonly property color texto: p.texto
    readonly property color texto2: p.texto2
    readonly property color linha: p.linha
    readonly property color borda: p.borda
    readonly property color destaque: p.destaque
    readonly property color sobreDestaque: p.sobreDestaque
    readonly property color destaqueFraco: p.destaqueFraco
    readonly property color ok: p.ok
    readonly property color quente: p.quente
    readonly property color alerta: p.alerta
    readonly property color porta1: p.porta1
    readonly property color porta2: p.porta2
    readonly property color porta3: p.porta3

    // ------------------------------------------------------------ tipografia
    readonly property string sans: archivo.name
    readonly property string serif: youngSerif.name
    readonly property string mono: plexMono.name       // só número, hora, versão, endereço e atalho
    property FontLoader archivo: FontLoader { source: Qt.resolvedUrl("fonts/Archivo-Regular.ttf") }
    property FontLoader archivoSemi: FontLoader { source: Qt.resolvedUrl("fonts/Archivo-SemiBold.ttf") }
    property FontLoader archivoBold: FontLoader { source: Qt.resolvedUrl("fonts/Archivo-Bold.ttf") }
    property FontLoader youngSerif: FontLoader { source: Qt.resolvedUrl("fonts/YoungSerif-Regular.ttf") }
    property FontLoader plexMono: FontLoader { source: Qt.resolvedUrl("fonts/IBMPlexMono-Medium.ttf") }
}
