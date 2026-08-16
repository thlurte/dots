import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import qs.Commons
import qs.Modules.DesktopWidgets
import qs.Widgets

DraggableDesktopWidget {
  id: root
  property var pluginApi: null
  property var vaults: []
  property string status: "loading"
  property string statusMsg: ""

  readonly property var cfg: pluginApi?.pluginSettings || ({})
  readonly property string configPathRaw: cfg.obsidianConfigPath ?? "~/.config/obsidian/obsidian.json"
  readonly property bool showPath: cfg.showPath ?? true
  readonly property int maxVaults: cfg.maxVaults ?? 12
  readonly property string configPath: configPathRaw.replace(/~/g, Quickshell.env("HOME") || "")
  readonly property real _width: Math.round(300 * widgetScale)
  readonly property real _pad: Math.round(Style.marginL * widgetScale)
  readonly property int shownCount: Math.min(root.vaults.length, root.maxVaults)

  implicitWidth: _width
  implicitHeight: Math.round(contentCol.implicitHeight + _pad * 2)
  width: implicitWidth
  height: implicitHeight

  function openVault(entry) {
    if (!entry)
      return;
    // Prefer path URI — unique even if folder names collide
    var uri = entry.path
        ? ("obsidian://open?path=" + encodeURIComponent(entry.path))
        : ("obsidian://open?vault=" + encodeURIComponent(entry.name));
    Qt.openUrlExternally(uri);
  }

  function parseVaults(raw) {
    try {
      var data = JSON.parse(raw || "{}");
      var map = data.vaults || {};
      var list = [];
      for (var id in map) {
        var v = map[id];
        if (!v || !v.path)
          continue;
        var parts = String(v.path).split("/").filter(function (s) { return !!s; });
        var name = parts.length ? parts[parts.length - 1] : v.path;
        list.push({
          id: id,
          path: v.path,
          name: name,
          ts: v.ts || 0,
          isOpen: !!v.open
        });
      }
      list.sort(function (a, b) { return (b.ts || 0) - (a.ts || 0); });
      root.vaults = list;
      root.status = list.length ? "ok" : "empty";
      root.statusMsg = list.length ? "" : "No vaults in obsidian.json";
    } catch (e) {
      root.vaults = [];
      root.status = "error";
      root.statusMsg = "Failed to parse obsidian.json";
    }
  }

  function reload() {
    configFile.reload();
  }

  FileView {
    id: configFile
    path: root.configPath
    watchChanges: true
    onFileChanged: reload()
    onLoaded: root.parseVaults(text())
    onLoadFailed: err => {
      root.vaults = [];
      root.status = "error";
      root.statusMsg = "Missing " + root.configPath;
    }
  }

  Component.onCompleted: configFile.reload()

  ColumnLayout {
    id: contentCol
    anchors.fill: parent
    anchors.margins: root._pad
    spacing: Math.round(Style.marginXS * widgetScale)

    RowLayout {
      Layout.fillWidth: true
      spacing: Math.round(Style.marginS * widgetScale)

      NIcon {
        icon: "notebook"
        color: root.status === "error" ? Color.mError : Color.mPrimary
        pointSize: Style.fontSizeXL * widgetScale
      }

      NText {
        text: "Obsidian"
        color: Color.mOnSurface
        font.weight: Style.fontWeightBold
        pointSize: Style.fontSizeL * widgetScale
        Layout.fillWidth: true
      }

      NText {
        text: String(root.vaults.length)
        color: Color.mPrimary
        font.family: Settings.data.ui.fontFixed
        pointSize: Style.fontSizeS * widgetScale
      }

      NIconButton {
        icon: "refresh"
        tooltipText: "Reload vault list"
        baseSize: Style.baseWidgetSize * 0.7 * widgetScale
        onClicked: root.reload()
      }
    }

    Repeater {
      model: root.shownCount

      delegate: MouseArea {
        id: itemArea
        required property int index
        Layout.fillWidth: true
        implicitHeight: row.implicitHeight
        cursorShape: Qt.PointingHandCursor
        hoverEnabled: true
        onClicked: root.openVault(root.vaults[index])

        Rectangle {
          anchors.fill: parent
          anchors.margins: -Math.round(3 * widgetScale)
          radius: Style.radiusS
          color: itemArea.containsMouse ? Color.mSurfaceVariant : Color.transparent
          opacity: 0.55
        }

        ColumnLayout {
          id: row
          anchors.left: parent.left
          anchors.right: parent.right
          spacing: Math.round(1 * widgetScale)

          RowLayout {
            Layout.fillWidth: true
            spacing: Math.round(Style.marginS * widgetScale)

            Rectangle {
              width: Math.round(8 * widgetScale)
              height: Math.round(8 * widgetScale)
              radius: width / 2
              color: root.vaults[index]?.isOpen ? Color.mPrimary : Color.mOnSurfaceVariant
            }

            NText {
              text: root.vaults[index]?.name || ""
              color: itemArea.containsMouse ? Color.mPrimary : Color.mOnSurface
              font.weight: root.vaults[index]?.isOpen ? Style.fontWeightBold : Style.fontWeightMedium
              pointSize: Style.fontSizeS * widgetScale
              Layout.fillWidth: true
              elide: Text.ElideRight
            }
          }

          NText {
            visible: root.showPath
            text: root.vaults[index]?.path || ""
            color: Color.mOnSurfaceVariant
            pointSize: Style.fontSizeXS * widgetScale
            Layout.fillWidth: true
            elide: Text.ElideMiddle
            leftPadding: Math.round(16 * widgetScale)
          }
        }
      }
    }

    NText {
      visible: root.vaults.length === 0
      text: root.statusMsg || "No vaults"
      color: root.status === "error" ? Color.mError : Color.mOnSurfaceVariant
      pointSize: Style.fontSizeS * widgetScale
      Layout.fillWidth: true
      wrapMode: Text.Wrap
    }

    NText {
      visible: root.vaults.length > root.maxVaults
      text: "+" + (root.vaults.length - root.maxVaults) + " more in settings max"
      color: Color.mOnSurfaceVariant
      pointSize: Style.fontSizeXS * widgetScale
    }
  }
}
