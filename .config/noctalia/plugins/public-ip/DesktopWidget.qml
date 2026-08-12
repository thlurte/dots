import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import qs.Commons
import qs.Modules.DesktopWidgets
import qs.Services.UI
import qs.Widgets

DraggableDesktopWidget {
  id: root
  property var pluginApi: null

  property string ip: ""
  property bool loading: false
  property bool failed: false

  readonly property real _width: Math.round(288 * widgetScale)
  readonly property real _pad: Math.round(Style.marginL * widgetScale)

  implicitWidth: _width
  implicitHeight: Math.round(contentCol.implicitHeight + _pad * 2)
  width: implicitWidth
  height: implicitHeight

  readonly property string displayIp: {
    if (loading && ip === "")
      return pluginApi?.tr("widget.loading") ?? "Looking up…";
    if (failed && ip === "")
      return pluginApi?.tr("widget.error") ?? "Unavailable";
    return ip || (pluginApi?.tr("widget.error") ?? "Unavailable");
  }

  function copyIp() {
    if (!root.ip)
      return;
    var escaped = root.ip.replace(/'/g, "'\\''");
    Quickshell.execDetached(["sh", "-c", "printf '%s' '" + escaped + "' | wl-copy"]);
    ToastService.showNotice("Public IP", pluginApi?.tr("widget.copied").arg(root.ip) ?? ("Copied " + root.ip));
  }

  function refresh() {
    if (ipProc.running)
      return;
    root.loading = true;
    root.failed = false;
    ipProc.running = true;
  }

  Process {
    id: ipProc
    command: ["curl", "-4", "-fsS", "--max-time", "5", "https://ifconfig.me/ip"]
    stdout: StdioCollector {}
    stderr: StdioCollector {}

    onExited: function (exitCode) {
      var raw = String(ipProc.stdout.text || "").trim();
      root.loading = false;
      if (exitCode === 0 && raw !== "") {
        root.ip = raw.split(/\s+/)[0];
        root.failed = false;
      } else {
        root.failed = true;
      }
    }
  }

  Timer {
    interval: 60000
    running: true
    repeat: true
    triggeredOnStart: true
    onTriggered: root.refresh()
  }

  ColumnLayout {
    id: contentCol
    anchors.fill: parent
    anchors.margins: root._pad
    spacing: Math.round(Style.marginXS * widgetScale)

    RowLayout {
      Layout.fillWidth: true
      spacing: Math.round(Style.marginS * widgetScale)

      NIcon {
        icon: root.failed ? "world-off" : "world"
        color: root.failed ? Color.mError : Color.mPrimary
        pointSize: Style.fontSizeXL * widgetScale
      }

      NText {
        text: pluginApi?.tr("widget.title") ?? "Public IP"
        color: Color.mOnSurface
        font.weight: Style.fontWeightBold
        pointSize: Style.fontSizeL * widgetScale
        Layout.fillWidth: true
      }
    }

    NText {
      text: root.displayIp
      color: root.failed ? Color.mError : Color.mPrimary
      font.weight: Style.fontWeightBold
      font.family: Settings.data.ui.fontFixed
      pointSize: Style.fontSizeXXL * widgetScale
      Layout.fillWidth: true

      MouseArea {
        anchors.fill: parent
        cursorShape: root.ip ? Qt.PointingHandCursor : Qt.ArrowCursor
        enabled: root.ip !== ""
        onClicked: root.copyIp()
      }
    }

    NButton {
      text: pluginApi?.tr("widget.refresh") ?? "Refresh"
      enabled: !root.loading
      outlined: true
      Layout.topMargin: Math.round(Style.marginXS * widgetScale)
      onClicked: root.refresh()
    }
  }
}
