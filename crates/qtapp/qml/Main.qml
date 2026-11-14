import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import org.misterdownloadmanager

ApplicationWindow {
    id: window
    visible: true
    width: 1000
    height: 640
    minimumWidth: 640
    minimumHeight: 420
    title: qsTr("Mister Download Manager")
    color: appTheme.window

    Theme { id: appTheme }
    DownloadModel { id: downloads }

    property string category: "all"
    property int selectedRow: -1
    property string notice: ""

    Timer {
        interval: 250
        running: true
        repeat: true
        onTriggered: downloads.poll()
    }

    function matches(status, cat) {
        switch (category) {
        case "all": return true
        case "active": return status !== "complete" && status !== "failed"
        case "finished": return status === "complete"
        default: return cat === category
        }
    }

    function addFromClipboard() {
        addDialog.openWith(clipboardProbe.text)
    }

    // A hidden field only to read the clipboard's text.
    TextField { id: clipboardProbe; visible: false }

    function submitUrl(url) {
        var why = downloads.add(url)
        if (why === "") { addDialog.close(); notice = "" }
        else addDialog.problem = why
    }

    // Command line: --add=<url> starts a download, --dialog opens the Add URL window (the
    // screenshots a pull request shows are taken this way, tools/qt/shots.sh).
    Component.onCompleted: {
        var args = Qt.application.arguments
        for (var i = 0; i < args.length; ++i) {
            if (args[i].indexOf("--add=") === 0) downloads.add(args[i].slice(6))
            else if (args[i] === "--dialog") addDialog.openWith("https://example.com/file.zip")
        }
    }
    function currentRowOk() { return selectedRow >= 0 && selectedRow < downloads.count }

    header: ToolBar {
        background: Rectangle {
            color: appTheme.surface
            Rectangle { anchors.bottom: parent.bottom; width: parent.width; height: 1; color: appTheme.edge }
        }
        RowLayout {
            anchors { fill: parent; leftMargin: appTheme.gap; rightMargin: appTheme.gap }
            spacing: 4
            ToolButton {
                text: "＋  " + qsTr("Add URL")
                onClicked: { clipboardProbe.clear(); clipboardProbe.paste(); window.addFromClipboard() }
                ToolTip.visible: hovered; ToolTip.text: qsTr("Add a download (Ctrl+N)")
            }
            ToolSeparator {}
            ToolButton {
                text: "⏸  " + qsTr("Pause")
                enabled: window.currentRowOk()
                onClicked: downloads.pause(window.selectedRow)
            }
            ToolButton {
                text: "▶  " + qsTr("Resume")
                enabled: window.currentRowOk()
                onClicked: { var why = downloads.resume(window.selectedRow); window.notice = why }
            }
            ToolButton {
                text: "✕  " + qsTr("Remove")
                enabled: window.currentRowOk()
                onClicked: removeDialog.open()
            }
            Item { Layout.fillWidth: true }
            TextField {
                id: search
                Layout.preferredWidth: 220
                placeholderText: qsTr("Search downloads")
                selectByMouse: true
            }
        }
    }

    RowLayout {
        anchors.fill: parent
        spacing: 0

        Sidebar {
            theme: appTheme
            Layout.fillHeight: true
            Layout.preferredWidth: 200
            current: window.category
            model: downloads
            onPicked: key => { window.category = key; window.selectedRow = -1 }
        }

        Item {
            Layout.fillWidth: true
            Layout.fillHeight: true

            ListView {
                id: list
                anchors { fill: parent; margins: appTheme.gap }
                model: downloads
                spacing: 2
                clip: true
                visible: downloads.count > 0
                boundsBehavior: Flickable.StopAtBounds
                ScrollBar.vertical: ScrollBar {}

                delegate: DownloadRow {
                    id: item
                    theme: appTheme
                    width: ListView.view.width - 12
                    selected: window.selectedRow === index
                    readonly property bool shown: window.matches(status, category)
                        && (search.text === "" || name.toLowerCase().indexOf(search.text.toLowerCase()) >= 0)
                    visible: shown
                    height: shown ? appTheme.rowHeight : 0
                    onClicked: window.selectedRow = index
                    onOpened: Qt.openUrlExternally("file://" + downloads.folderOf(index))
                    onContextRequested: (x, y) => { menu.row = index; menu.popup() }
                }
            }

            ColumnLayout {
                anchors.centerIn: parent
                visible: downloads.count === 0
                spacing: appTheme.gap
                Label {
                    Layout.alignment: Qt.AlignHCenter
                    text: "⇣"
                    font.pixelSize: 56
                    color: appTheme.edge
                }
                Label {
                    Layout.alignment: Qt.AlignHCenter
                    text: qsTr("No downloads yet")
                    font { pixelSize: 18; bold: true }
                }
                Label {
                    Layout.alignment: Qt.AlignHCenter
                    text: qsTr("Paste a link to start one.")
                    color: appTheme.muted
                }
                Button {
                    Layout.alignment: Qt.AlignHCenter
                    text: qsTr("Add URL")
                    highlighted: true
                    onClicked: { clipboardProbe.clear(); clipboardProbe.paste(); window.addFromClipboard() }
                }
            }
        }
    }

    footer: Rectangle {
        height: 28
        color: appTheme.surface
        Rectangle { width: parent.width; height: 1; color: appTheme.edge }
        RowLayout {
            anchors { fill: parent; leftMargin: 12; rightMargin: 12 }
            Label {
                text: window.notice !== "" ? window.notice
                    : (downloads.count === 1 ? qsTr("1 download") : qsTr("%1 downloads").arg(downloads.count))
                    + (downloads.activeCount > 0 ? "   ·   " + qsTr("%1 in progress").arg(downloads.activeCount) : "")
                color: window.notice !== "" ? appTheme.bad : appTheme.muted
                font.pixelSize: 12
                Layout.fillWidth: true
                elide: Text.ElideRight
            }
            Label {
                text: downloads.totalSpeed > 0 ? "⇣ " + appTheme.formatSpeed(downloads.totalSpeed) : ""
                color: appTheme.muted
                font.pixelSize: 12
            }
        }
    }

    Menu {
        id: menu
        property int row: -1
        MenuItem { text: qsTr("Pause"); onTriggered: downloads.pause(menu.row) }
        MenuItem { text: qsTr("Resume"); onTriggered: window.notice = downloads.resume(menu.row) }
        MenuItem { text: qsTr("Open folder"); onTriggered: Qt.openUrlExternally("file://" + downloads.folderOf(menu.row)) }
        MenuSeparator {}
        MenuItem { text: qsTr("Remove from list"); onTriggered: downloads.remove(menu.row, false) }
        MenuItem { text: qsTr("Remove and delete file"); onTriggered: { downloads.remove(menu.row, true); window.selectedRow = -1 } }
    }

    AddUrlDialog {
        id: addDialog
        theme: appTheme
        folder: downloads.downloadFolder()
        onSubmitted: url => window.submitUrl(url)
    }

    Dialog {
        id: removeDialog
        title: qsTr("Remove this download?")
        modal: true
        anchors.centerIn: parent
        standardButtons: Dialog.Cancel | Dialog.Ok
        Label { text: qsTr("It leaves the list; its file stays on disk.") }
        onAccepted: { downloads.remove(window.selectedRow, false); window.selectedRow = -1 }
    }

    Shortcut { sequence: "Ctrl+N"; onActivated: { clipboardProbe.clear(); clipboardProbe.paste(); window.addFromClipboard() } }
    Shortcut { sequence: "Delete"; enabled: window.currentRowOk(); onActivated: removeDialog.open() }
    Shortcut { sequence: "Ctrl+F"; onActivated: search.forceActiveFocus() }
}
