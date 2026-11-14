import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

Dialog {
    id: dialog
    required property var theme
    required property string folder
    signal submitted(string url)

    title: qsTr("Add a download")
    modal: true
    anchors.centerIn: parent
    width: Math.min(parent.width - 48, 520)
    standardButtons: Dialog.NoButton
    property string problem: ""

    function openWith(text) {
        field.text = text
        problem = ""
        open()
        field.forceActiveFocus()
        field.selectAll()
    }

    function submit() {
        var url = field.text.trim()
        if (url === "") { problem = qsTr("Paste an address first."); return }
        dialog.submitted(url)
    }

    background: Rectangle {
        color: theme.surface
        radius: theme.radius * 1.5
        border.color: theme.edge
    }

    contentItem: ColumnLayout {
        spacing: theme.gap

        Label { text: qsTr("Address"); color: theme.muted; font.pixelSize: 12 }
        TextField {
            id: field
            Layout.fillWidth: true
            placeholderText: "https://example.com/file.zip"
            selectByMouse: true
            onAccepted: dialog.submit()
            onTextEdited: dialog.problem = ""
        }
        Label {
            visible: dialog.problem !== ""
            text: dialog.problem
            color: theme.bad
            wrapMode: Text.Wrap
            Layout.fillWidth: true
        }
        Label {
            text: qsTr("Saved to %1").arg(dialog.folder)
            color: theme.muted
            font.pixelSize: 12
            elide: Text.ElideMiddle
            Layout.fillWidth: true
        }
        RowLayout {
            Layout.alignment: Qt.AlignRight
            spacing: theme.gap
            Button { text: qsTr("Cancel"); onClicked: dialog.close() }
            Button {
                text: qsTr("Download")
                highlighted: true
                onClicked: dialog.submit()
            }
        }
    }
}
