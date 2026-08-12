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

  property bool installed: true
  property bool connected: false
  property bool needsLogin: false
  property bool busy: false
  property string backend: ""
  property string ip: ""
  property string hostName: ""
  property string exitNode: ""
  property int onlinePeers: 0
  property int totalPeers: 0

  readonly property real _width: Math.round(288 * widgetScale)
  readonly property real _pad: Math.round(Style.marginL * widgetScale)

  implicitWidth: _width
  implicitHeight: Math.round(contentCol.implicitHeight + _pad * 2)
  width: implicitWidth
  height: implicitHeight

  readonly property color statusColor: {
    if (!installed || needsLogin)
      return Color.mError;
    if (connected)
      return Color.mPrimary;
    return Color.mOnSurfaceVariant;
  }

  readonly property string statusIcon: {
    if (!installed || needsLogin)
      return "shield-exclamation";
    if (connected)
      return "shield-check";
    return "shield-off";
  }

  readonly property string statusText: {
    if (!installed)
      return pluginApi?.tr("widget.missing") ?? "tailscale not installed";
    if (needsLogin)
      return pluginApi?.tr("widget.needs-login") ?? "Needs login";
    if (connected)
      return pluginApi?.tr("widget.online") ?? "Connected";
    if (backend !== "")
      return backend;
    return pluginApi?.tr("widget.offline") ?? "Disconnected";
  }

  function firstIpv4(ips) {
    if (!ips || !ips.length)
      return "";
    for (var i = 0; i < ips.length; i++) {
      if (String(ips[i]).indexOf(".") !== -1 && String(ips[i]).indexOf(":") === -1)
        return ips[i];
    }
    return ips[0] || "";
  }

  function isMullvad(peer) {
    var tags = peer && peer.Tags;
    if (!tags)
      return false;
    for (var i = 0; i < tags.length; i++) {
      if (tags[i] === "tag:mullvad-exit-node")
        return true;
    }
    return false;
  }

  function applyStatus(data) {
    root.backend = data.BackendState || "";
    root.connected = data.BackendState === "Running";
    root.needsLogin = data.BackendState === "NeedsLogin";
    root.ip = firstIpv4(data.TailscaleIPs);
    root.hostName = "";
    root.exitNode = "";
    root.onlinePeers = 0;
    root.totalPeers = 0;

    if (data.Self) {
      root.hostName = data.Self.HostName || "";
      if (!root.ip)
        root.ip = firstIpv4(data.Self.TailscaleIPs);
    }

    var peers = data.Peer || {};
    for (var key in peers) {
      var peer = peers[key];
      if (!peer || isMullvad(peer))
        continue;
      root.totalPeers += 1;
      if (peer.Online)
        root.onlinePeers += 1;
      if (peer.ExitNode)
        root.exitNode = peer.HostName || root.exitNode;
    }
  }

  function copyIp() {
    if (!root.ip)
      return;
    var escaped = root.ip.replace(/'/g, "'\\''");
    Quickshell.execDetached(["sh", "-c", "printf '%s' '" + escaped + "' | wl-copy"]);
    ToastService.showNotice("Tailscale", pluginApi?.tr("widget.copied").arg(root.ip) ?? ("Copied " + root.ip));
  }

  Process {
    id: statusProc
    command: ["tailscale", "status", "--json"]
    stdout: StdioCollector {}
    stderr: StdioCollector {}

    onExited: function (exitCode) {
      var raw = String(statusProc.stdout.text || "").trim();
      if (!raw) {
        root.installed = exitCode === 0;
        root.connected = false;
        root.ip = "";
        return;
      }
      try {
        root.installed = true;
        root.applyStatus(JSON.parse(raw));
      } catch (e) {
        root.connected = false;
      }
    }
  }

  Process {
    id: whichProc
    command: ["sh", "-c", "command -v tailscale"]
    stdout: StdioCollector {}

    onExited: function (exitCode) {
      root.installed = exitCode === 0;
      if (root.installed)
        statusProc.running = true;
    }
  }

  Process {
    id: toggleProc
    stdout: StdioCollector {}
    stderr: StdioCollector {}

    onExited: function () {
      root.busy = false;
      statusProc.running = true;
    }
  }

  Timer {
    interval: 5000
    running: true
    repeat: true
    triggeredOnStart: true
    onTriggered: whichProc.running = true
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
        icon: root.statusIcon
        color: root.statusColor
        pointSize: Style.fontSizeXL * widgetScale
      }

      NText {
        text: pluginApi?.tr("widget.title") ?? "Tailscale"
        color: Color.mOnSurface
        font.weight: Style.fontWeightBold
        pointSize: Style.fontSizeL * widgetScale
        Layout.fillWidth: true
      }
    }

    NText {
      text: root.statusText
      color: root.statusColor
      pointSize: Style.fontSizeS * widgetScale
    }

    NText {
      id: ipLabel
      text: root.ip || (pluginApi?.tr("widget.no-ip") ?? "—")
      color: root.connected ? Color.mPrimary : Color.mOnSurfaceVariant
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

    NText {
      visible: root.hostName !== ""
      text: root.hostName
      color: Color.mOnSurfaceVariant
      pointSize: Style.fontSizeS * widgetScale
    }

    NText {
      visible: root.installed
      text: (pluginApi?.tr("widget.peers") ?? "%1 online · %2 peers").arg(root.onlinePeers).arg(root.totalPeers)
      color: Color.mOnSurfaceVariant
      pointSize: Style.fontSizeS * widgetScale
    }

    NText {
      visible: root.exitNode !== ""
      text: (pluginApi?.tr("widget.exit-node") ?? "Exit · %1").arg(root.exitNode)
      color: Color.mTertiary
      pointSize: Style.fontSizeS * widgetScale
    }

    NButton {
      visible: root.installed
      text: root.connected
            ? (pluginApi?.tr("widget.disconnect") ?? "Disconnect")
            : (pluginApi?.tr("widget.connect") ?? "Connect")
      enabled: !root.busy && !root.needsLogin
      outlined: root.connected
      backgroundColor: root.connected ? Color.mSecondary : Color.mPrimary
      Layout.topMargin: Math.round(Style.marginXS * widgetScale)
      onClicked: {
        root.busy = true;
        toggleProc.command = ["tailscale", root.connected ? "down" : "up"];
        toggleProc.running = true;
      }
    }
  }
}
