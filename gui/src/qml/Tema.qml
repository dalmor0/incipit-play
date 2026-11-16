// Incipit Play · cor e tema. As mesmas contas do Incipit Hub (INCIPIT-HUB-CLIENTE/app/tema.js):
// padrão Hora azul no escuro Grafite; claro Névoa. A escolha fica salva neste PC (QSettings do app).
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
    // Application.styleHints.colorScheme: 0 desconhecido, 1 claro, 2 escuro
    readonly property bool escuro: modo === "system" ? Application.styleHints.colorScheme !== 1 : modo !== "light"

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
    function calcular(id, esc) {
        const b = esc
            ? { papel: "#111318", tinta: "#E7EAF0", sup: "#1A1D24", tinta2: "#A0A7B4", linha: "#2C313B", forte: "#626B7A" }
            : { papel: "#ECEEF2", tinta: "#111318", sup: "#F7F8FA", tinta2: "#4F5663", linha: "#CDD2DB", forte: "#7E8695" };
        const d = destaques.find(x => x.id === id) || destaques[0];
        const dest = ajustarAte(esc ? d.escuro : d.claro, b.papel, 4.5);
        const cands = esc ? [b.papel, "#0B0D12", "#FFFFFF"] : ["#FFFFFF", b.papel, "#0B0D12"];
        const sobre = cands.find(c => contraste(dest, c) >= 4.5) || cands.reduce((m, c) => (contraste(dest, c) > contraste(dest, m) ? c : m), cands[0]);
        let porta;
        if (d.id === "hora-azul") porta = esc ? ["#CCE0FF", "#7DB0FF", "#3F6FD6"] : ["#4A7FE0", "#2F5FC8", "#1D3D8A"];
        else porta = esc ? [misturar(dest, "#FFFFFF", 0.6), dest, misturar(dest, "#000000", 0.35)]
                         : [misturar(dest, "#FFFFFF", 0.15), dest, misturar(dest, "#000000", 0.32)];
        return {
            fundo: b.papel, sup: b.sup, sup2: esc ? misturar(b.sup, b.tinta, 0.04) : "#FFFFFF",
            texto: b.tinta, texto2: b.tinta2, linha: b.linha, borda: ajustarAte(b.forte, b.papel, 3),
            destaque: dest, sobreDestaque: sobre,
            destaqueFraco: misturar(b.papel, dest, esc ? 0.14 : 0.10),
            ok: ajustarAte(esc ? "#7FD1A0" : "#1B7048", b.papel, 4.5),
            quente: esc ? "#F2B872" : "#8A5A12",
            alerta: ajustarAte(esc ? "#FF5C5C" : "#B42318", b.papel, 4.5),
            porta1: porta[0], porta2: porta[1], porta3: porta[2]
        };
    }

    readonly property var p: calcular(destaqueId, escuro)
    readonly property color fundo: p.fundo
    readonly property color sup: p.sup
    readonly property color sup2: p.sup2
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
    property FontLoader archivo: FontLoader { source: Qt.resolvedUrl("fonts/Archivo-Regular.ttf") }
    property FontLoader archivoSemi: FontLoader { source: Qt.resolvedUrl("fonts/Archivo-SemiBold.ttf") }
    property FontLoader archivoBold: FontLoader { source: Qt.resolvedUrl("fonts/Archivo-Bold.ttf") }
    property FontLoader youngSerif: FontLoader { source: Qt.resolvedUrl("fonts/YoungSerif-Regular.ttf") }
}
