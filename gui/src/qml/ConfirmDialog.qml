// Confirmação (Incipit Play): título, uma frase e dois botões que dizem o que fazem. Mesma API do chiaki-ng
// (title, text, callback, rejectCallback, restoreFocusItem, open()).
import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import QtQuick.Templates as T

T.Dialog {
    id: dialog
    property alias text: label.text
    property string textoSim: "Sim"
    property string textoNao: "Não"
    property var callback
    property var rejectCallback
    property bool newDialogOpen: false
    property Item restoreFocusItem
    readonly property var tema: root.tema
    parent: Overlay.overlay
    x: Math.round((root.width - width) / 2)
    y: Math.round((root.height - height) / 2)
    width: Math.min(520, root.width - 64)
    padding: 28
    topPadding: 24
    modal: true
    onOpened: { newDialogOpen = false; sim.forceActiveFocus(Qt.TabFocusReason); }
    onAccepted: {
        newDialogOpen = true;
        restoreFocus();
        callback();
    }
    onClosed: if (!newDialogOpen) { restoreFocus() }
    onRejected: {
        if (rejectCallback) {
            newDialogOpen = true;
            restoreFocus();
            rejectCallback();
        }
    }

    function restoreFocus() {
        if (restoreFocusItem)
            restoreFocusItem.forceActiveFocus(Qt.TabFocusReason);
    }

    background: Rectangle { color: dialog.tema.sup; border.width: 1; border.color: dialog.tema.borda }
    Overlay.modal: Rectangle { color: Qt.rgba(0, 0, 0, 0.55) }

    contentItem: ColumnLayout {
        spacing: 12
        Keys.onEscapePressed: dialog.reject()

        Text {
            Layout.fillWidth: true
            text: dialog.title
            textFormat: Text.PlainText
            wrapMode: Text.WordWrap
            font.family: dialog.tema.serif
            font.pixelSize: 26
            color: dialog.tema.texto
        }
        Text {
            id: label
            Layout.fillWidth: true
            textFormat: Text.PlainText
            wrapMode: Text.WordWrap
            font.family: dialog.tema.sans
            font.pixelSize: 16
            lineHeight: 1.35
            color: dialog.tema.texto2
        }
        Row {
            Layout.alignment: Qt.AlignRight
            Layout.topMargin: 12
            spacing: 10
            InBotao { text: dialog.textoNao; onClicked: dialog.reject(); Keys.onReturnPressed: dialog.reject() }
            InBotao { id: sim; tipo: "forte"; text: dialog.textoSim; onClicked: dialog.accept(); Keys.onReturnPressed: dialog.accept() }
        }
    }
}
