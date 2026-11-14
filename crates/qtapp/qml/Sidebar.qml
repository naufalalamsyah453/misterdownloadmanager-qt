import QtQuick
import QtQuick.Controls

// The categories. `current` is "all", a category key, or "active" / "finished".
Rectangle {
    id: root
    required property var theme
    property string current: "all"
    // The download model; its countOf(key, revision) says how many rows an entry holds.
    required property var model
    signal picked(string key)

    color: theme.sidebar
    implicitWidth: 200

    readonly property var entries: [
        { key: "all", label: qsTr("All downloads"), icon: "▤" },
        { key: "active", label: qsTr("In progress"), icon: "⇣" },
        { key: "finished", label: qsTr("Finished"), icon: "✓" },
        { key: "-" },
        { key: "compressed", label: qsTr("Compressed"), icon: "▦" },
        { key: "documents", label: qsTr("Documents"), icon: "▭" },
        { key: "music", label: qsTr("Music"), icon: "♪" },
        { key: "programs", label: qsTr("Programs"), icon: "⚙" },
        { key: "video", label: qsTr("Video"), icon: "▶" },
        { key: "other", label: qsTr("Other"), icon: "…" }
    ]

    Rectangle {
        anchors { top: parent.top; bottom: parent.bottom; right: parent.right }
        width: 1
        color: root.theme.edge
    }

    Column {
        anchors { fill: parent; topMargin: root.theme.gap; rightMargin: 1 }
        spacing: 2

        Repeater {
            model: root.entries
            delegate: Item {
                id: entry
                required property var modelData
                width: parent.width
                height: modelData.key === "-" ? root.theme.gap * 2 : 36

                Rectangle {
                    visible: entry.modelData.key === "-"
                    anchors { verticalCenter: parent.verticalCenter; left: parent.left; right: parent.right; margins: 12 }
                    height: 1
                    color: root.theme.edge
                }

                Rectangle {
                    visible: entry.modelData.key !== "-"
                    anchors { fill: parent; leftMargin: 6; rightMargin: 6 }
                    radius: root.theme.radius
                    color: root.current === entry.modelData.key ? root.theme.accent
                         : area.containsMouse ? root.theme.hover : "transparent"

                    Row {
                        anchors { verticalCenter: parent.verticalCenter; left: parent.left; leftMargin: 10 }
                        spacing: 10
                        Label {
                            text: entry.modelData.icon ?? ""
                            width: 18
                            horizontalAlignment: Text.AlignHCenter
                            color: root.current === entry.modelData.key ? root.theme.accentText : root.theme.muted
                        }
                        Label {
                            text: entry.modelData.label ?? ""
                            color: root.current === entry.modelData.key ? root.theme.accentText : root.theme.text
                        }
                    }
                    Label {
                        anchors { verticalCenter: parent.verticalCenter; right: parent.right; rightMargin: 10 }
                        text: entry.modelData.key === "-" ? "" : (root.model.countOf(entry.modelData.key, root.model.revision) || "")
                        font.pixelSize: 11
                        color: root.current === entry.modelData.key ? root.theme.accentText : root.theme.muted
                    }
                    MouseArea {
                        id: area
                        anchors.fill: parent
                        hoverEnabled: true
                        onClicked: root.picked(entry.modelData.key)
                    }
                }
            }
        }
    }
}
