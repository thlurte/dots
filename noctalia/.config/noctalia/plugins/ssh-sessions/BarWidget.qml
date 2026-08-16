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

  readonly property string screenName: screen?.name ?? ""
  readonly property string barPosition: Settings.getBarPositionForScreen(screenName)
  readonly property bool isBarVertical: barPosition === "left" || barPosition === "right"
  readonly property real capsuleHeight: Style.getCapsuleHeightForScreen(screenName)
  readonly property real barFontSize: Style.getBarFontSizeForScreen(screenName)

  readonly property var mainInstance: pluginApi?.mainInstance
  readonly property int activeCount: mainInstance?.activeCount ?? 0

  readonly property real contentWidth: capsuleRow.implicitWidth + Style.marginM * 2
  readonly property real contentHeight: capsuleHeight

  implicitWidth: isBarVertical ? capsuleHeight : contentWidth
  implicitHeight: isBarVertical ? contentHeight : capsuleHeight

  NPopupContextMenu {
    id: contextMenu
    model: [
      { "label": pluginApi?.tr("context.refresh"), "action": "refresh", "icon": "refresh" },
      { "label": pluginApi?.tr("context.settings"), "action": "settings", "icon": "settings" }
    ]
    onTriggered: action => {
      contextMenu.close()
      PanelService.closeContextMenu(screen)
      if (action === "refresh") {
        root.mainInstance?.fullRefresh()
      } else if (action === "settings") {
        if (pluginApi) BarService.openPluginSettings(screen, pluginApi.manifest)
      }
    }
  }

  Rectangle {
    id: visualCapsule
    x: Style.pixelAlignCenter(parent.width, width)
    y: Style.pixelAlignCenter(parent.height, height)
    width: root.contentWidth
    height: root.contentHeight
    color: mouseArea.containsMouse ? Color.mHover : Style.capsuleColor
    radius: Style.radiusL
    border.color: Style.capsuleBorderColor
    border.width: Style.capsuleBorderWidth

    RowLayout {
      id: capsuleRow
      anchors.centerIn: parent
      spacing: Style.marginS

      NIcon {
        icon: "terminal"
        color: mouseArea.containsMouse ? Color.mOnHover : (root.activeCount > 0 ? Color.mPrimary : Color.mOnSurface)
        applyUiScale: true
      }

      NText {
        visible: root.activeCount > 0
        text: root.activeCount.toString()
        color: mouseArea.containsMouse ? Color.mOnHover : Color.mPrimary
        pointSize: root.barFontSize
        applyUiScale: false
        font.weight: Font.Normal
      }
    }
  }

  MouseArea {
    id: mouseArea
    anchors.fill: parent
    acceptedButtons: Qt.LeftButton | Qt.RightButton | Qt.MiddleButton
    hoverEnabled: true

    onClicked: mouse => {
      if (mouse.button === Qt.LeftButton) {
        if (pluginApi) pluginApi.togglePanel(root.screen, root)
      } else if (mouse.button === Qt.RightButton) {
        PanelService.showContextMenu(contextMenu, root, screen)
      } else if (mouse.button === Qt.MiddleButton) {
        root.mainInstance?.fullRefresh()
      }
    }

    onEntered: {
      var m = root.mainInstance
      if (!m) {
        TooltipService.show(root, pluginApi?.tr("widget.tooltip"), BarService.getTooltipDirection())
        return
      }
      var tip = ""
      if (root.activeCount === 0) {
        tip = pluginApi?.tr("bar.noSessions")
      } else if (root.activeCount === 1) {
        tip = pluginApi?.tr("bar.oneSession")
      } else {
        tip = root.activeCount + " " + pluginApi?.tr("bar.multipleSessions")
      }
      if (root.activeCount > 0) {
        tip += "\n───────────────"
        for (var i = 0; i < m.activeSessions.length; i++) {
          var s = m.activeSessions[i]
          tip += "\n" + (s.matchedHost || s.target)
        }
      }
      TooltipService.show(root, tip, BarService.getTooltipDirection())
    }

    onExited: {
      TooltipService.hide()
    }
  }
}
