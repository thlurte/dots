import QtQuick
import QtQuick.Layouts
import Quickshell
import qs.Commons
import qs.Services.UI
import qs.Widgets

Item {
  id: root

  property var pluginApi: null
  property ShellScreen screen
  property string widgetId: ""
  property string section: ""
  property int sectionWidgetIndex: -1
  property int sectionWidgetsCount: 0

  property var cfg: pluginApi?.pluginSettings || ({})
  property var defaults: pluginApi?.manifest?.metadata?.defaultSettings || ({})

  readonly property string iconColorKey: cfg.iconColor ?? defaults.iconColor
  readonly property bool showErrorBadge: cfg.showErrorBadge ?? defaults.showErrorBadge ?? true
  readonly property var main: pluginApi?.mainInstance ?? null

  readonly property string barPosition: Settings.getBarPositionForScreen(screen?.name)
  readonly property bool isVertical: barPosition === "left" || barPosition === "right"
  readonly property real capsuleHeight: Style.getCapsuleHeightForScreen(screen?.name)

  implicitWidth: isVertical ? capsuleHeight : contentRow.implicitWidth + Style.marginM * 2
  implicitHeight: isVertical ? contentRow.implicitHeight + Style.marginM * 2 : capsuleHeight

  NPopupContextMenu {
    id: contextMenu
    model: [
      { "label": pluginApi?.tr("menu.settings"), "action": "settings", "icon": "settings" }
    ]
    onTriggered: function(action) {
      contextMenu.close();
      PanelService.closeContextMenu(screen);
      if (action === "settings") {
        BarService.openPluginSettings(root.screen, pluginApi.manifest);
      }
    }
  }

  MouseArea {
    anchors.fill: parent
    hoverEnabled: true
    cursorShape: Qt.PointingHandCursor
    acceptedButtons: Qt.LeftButton | Qt.RightButton
    onClicked: mouse => {
      if (mouse.button === Qt.RightButton) {
        PanelService.showContextMenu(contextMenu, root, screen);
      } else {
        if (pluginApi) pluginApi.openPanel(root.screen, root);
      }
    }
  }

  RowLayout {
    id: contentRow
    anchors.centerIn: parent
    spacing: Style.marginS

    NIcon {
      icon: "topology-star-3"
      pointSize: Style.fontSizeL
      color: {
        if (root.showErrorBadge && root.main?.hasCriticalPod) return Color.mError;
        return Color.resolveColorKey(root.iconColorKey);
      }
    }

    NText {
      visible: !root.isVertical && root.main?.activeContext !== undefined && root.main?.activeContext !== ""
      text: {
        var ctx = root.main?.activeContext ?? "";
        var ns = root.main?.activeNamespace ?? "";
        if (ctx === "") return "";
        if (ns === "") return ctx;
        return ctx + " / " + ns;
      }
      pointSize: Style.fontSizeS
      color: Color.mOnSurface
      elide: Text.ElideRight
      Layout.maximumWidth: capsuleHeight * 3
    }

    // Error badge dot
    Rectangle {
      visible: root.showErrorBadge && (root.main?.hasCriticalPod ?? false)
      width: Math.round(Style.fontSizeS * 0.6)
      height: width
      radius: width / 2
      color: Color.mError
      Layout.alignment: Qt.AlignVCenter
    }
  }
}
