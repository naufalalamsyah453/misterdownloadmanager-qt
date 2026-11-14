import QtQuick
import QtQuick.Controls

// One download: name, state, a progress bar, and what it has done so far.
Rectangle {
    id: row
    required property var theme
    required property int index
    required property string name
    required property string url
    required property real size
    required property real done
    required property real progress
    required property real speed
    required property real eta
    required property string status
    required property string error
    property bool selected: false

    signal clicked()
    signal contextRequested(real x, real y)
    signal opened()

    height: theme.rowHeight
    radius: theme.radius
    color: selected ? theme.hover : (hover.hovered ? Qt.alpha(theme.hover, 0.5) : "transparent")
    border.color: selected ? theme.accent : "transparent"

    HoverHandler { id: hover }
    TapHandler {
        onTapped: row.clicked()
        onDoubleTapped: row.opened()
    }
    TapHandler {
        acceptedButtons: Qt.RightButton
        onTapped: (point) => { row.clicked(); row.contextRequested(point.position.x, point.position.y) }
    }

    Rectangle {
        id: badge
        anchors { left: parent.left; leftMargin: 12; verticalCenter: parent.verticalCenter }
        width: 40; height: 40
        radius: theme.radius
        color: theme.edge
        Label {
            anchors.centerIn: parent
            text: row.name.indexOf(".") > 0 ? row.name.split(".").pop().toUpperCase().slice(0, 4) : "FILE"
            font { pixelSize: 11; bold: true }
            color: theme.muted
        }
    }

    Column {
        anchors { left: badge.right; leftMargin: 12; right: parent.right; rightMargin: 12; verticalCenter: parent.verticalCenter }
        spacing: 5

        Row {
            width: parent.width
            Label {
                width: parent.width - stateLabel.width
                text: row.name
                elide: Text.ElideMiddle
                font.bold: true
            }
            Label {
                id: stateLabel
                text: theme.statusLabel(row.status)
                color: theme.statusColor(row.status)
            }
        }

        ProgressBar {
            id: bar
            width: parent.width
            height: 6
            from: 0; to: 1
            value: row.progress
            indeterminate: row.progress < 0 && (row.status === "downloading" || row.status === "connecting")
            visible: row.status !== "complete"
            background: Rectangle { radius: 3; color: theme.edge }
            contentItem: Item {
                Rectangle {
                    width: bar.visualPosition * parent.width
                    height: parent.height
                    radius: 3
                    color: row.status === "failed" ? theme.bad : theme.accent
                    visible: !bar.indeterminate
                }
            }
        }

        Label {
            width: parent.width
            font.pixelSize: 12
            color: row.status === "failed" ? theme.bad : theme.muted
            elide: Text.ElideRight
            text: {
                if (row.status === "failed" && row.error !== "") return row.error
                var parts = []
                if (row.status === "complete") parts.push(theme.formatSize(row.size))
                else if (row.size >= 0) parts.push(theme.formatSize(row.done) + " / " + theme.formatSize(row.size))
                else parts.push(theme.formatSize(row.done))
                if (row.speed > 0) parts.push(theme.formatSpeed(row.speed))
                if (row.eta >= 0) parts.push(theme.formatEta(row.eta))
                return parts.join("   ·   ")
            }
        }
    }
}
