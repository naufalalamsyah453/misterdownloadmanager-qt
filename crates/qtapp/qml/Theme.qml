import QtQuick

// Every colour, size and text format the window uses. Colours follow the system palette, so
// the window is light or dark with the desktop; the accent is MDM's blue.
QtObject {
    id: theme

    property SystemPalette sys: SystemPalette { colorGroup: SystemPalette.Active }

    readonly property bool dark: sys.window.hsvValue < 0.5
    readonly property color window: sys.window
    readonly property color surface: dark ? Qt.lighter(sys.window, 1.18) : Qt.lighter(sys.window, 1.04)
    readonly property color sidebar: dark ? Qt.darker(sys.window, 1.2) : Qt.darker(sys.window, 1.03)
    readonly property color text: sys.windowText
    readonly property color muted: Qt.tint(sys.windowText, dark ? "#80808080" : "#a0ffffff")
    readonly property color edge: dark ? Qt.lighter(sys.window, 1.5) : Qt.darker(sys.window, 1.15)
    readonly property color accent: "#2a78d6"
    readonly property color accentText: "#ffffff"
    readonly property color hover: Qt.rgba(accent.r, accent.g, accent.b, dark ? 0.22 : 0.12)
    readonly property color ok: dark ? "#5fbf7a" : "#238a47"
    readonly property color bad: dark ? "#ef7a7a" : "#c0392b"

    readonly property int radius: 6
    readonly property int gap: 8
    readonly property int rowHeight: 64

    function formatSize(bytes) {
        if (bytes < 0) return qsTr("unknown")
        var units = ["B", "KB", "MB", "GB", "TB"]
        var v = bytes, i = 0
        while (v >= 1024 && i < units.length - 1) { v /= 1024; i++ }
        return (i === 0 ? v.toFixed(0) : v.toFixed(v < 10 ? 2 : 1)) + " " + units[i]
    }

    function formatSpeed(bytesPerSecond) {
        return bytesPerSecond > 0 ? formatSize(bytesPerSecond) + "/s" : ""
    }

    function formatEta(seconds) {
        if (seconds < 0) return ""
        if (seconds < 60) return qsTr("%1 s").arg(seconds)
        if (seconds < 3600) return qsTr("%1 min %2 s").arg(Math.floor(seconds / 60)).arg(seconds % 60)
        return qsTr("%1 h %2 min").arg(Math.floor(seconds / 3600)).arg(Math.floor(seconds % 3600 / 60))
    }

    function statusLabel(status) {
        switch (status) {
        case "queued": return qsTr("Queued")
        case "connecting": return qsTr("Connecting…")
        case "downloading": return qsTr("Downloading")
        case "finishing": return qsTr("Finishing…")
        case "paused": return qsTr("Paused")
        case "complete": return qsTr("Complete")
        case "failed": return qsTr("Failed")
        }
        return status
    }

    function statusColor(status) {
        if (status === "complete") return ok
        if (status === "failed") return bad
        return muted
    }
}
