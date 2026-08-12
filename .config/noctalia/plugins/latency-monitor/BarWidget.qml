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
  readonly property bool isVertical: barPosition === "left" || barPosition === "right"
  readonly property real capsuleHeight: Style.getCapsuleHeightForScreen(screenName)
  readonly property real barFontSize: Style.getBarFontSizeForScreen(screenName)

  readonly property var mainInstance: pluginApi?.mainInstance
  readonly property var hosts: mainInstance?.hosts
  readonly property var displayHost: mainInstance?.displayHost
  readonly property string status: mainInstance?.status
  readonly property int thresholdGood: mainInstance?.thresholdGood
  readonly property int thresholdWarn: mainInstance?.thresholdWarning
  readonly property int showHostName: mainInstance?.showHostName

  readonly property string displayText: {
    if (!displayHost)
      return "—";
    if (displayHost.timedOut)
      return displayHost?.name;
    const a = displayHost.avg10m >= 0 ? displayHost.avg10m : displayHost.lastRtt >= 0 ? displayHost.lastRtt : -1;
    if (a < 0)
      return showHostName ? displayHost.name : "...";
    const ms = Math.round(a) + "ms";
    return showHostName ? `${displayHost.name} ${ms}` : ms;
  }

  readonly property string verticalLine1: {
    if (!displayHost)
      return "—";
    return showHostName ? displayHost.name : (displayHost.timedOut ? "✕" : "…");
  }

  readonly property string verticalLine2: {
    if (!displayHost || displayHost.timedOut)
      return "";
    const a = displayHost.avg10m >= 0 ? displayHost.avg10m : displayHost.lastRtt;
    return a >= 0 ? Math.round(a) + "ms" : "";
  }

  readonly property color statusColor: {
    switch (status) {
    case "good":
      return mainInstance?.colorGood;
    case "warning":
      return mainInstance?.colorWarning;
    case "critical":
      return mainInstance?.colorCritical;
    default:
      return Color.mOnSurface;
    }
  }

  readonly property int cycleTotal: {
    const base_ms = (mainInstance?.intervalSeconds || 5) * 1000;
    let animation_factor = 1;

    switch (root.status) {
    case "critical":
      animation_factor = 10;
      break;
    case "warning":
      animation_factor = 5;
      break;
    default:
      animation_factor = 1;
      break;
    }

    return Math.round(base_ms / animation_factor);
  }

  readonly property int pulseSpeed: {
    switch (root.status) {
    case "critical":
      return Style.animationFast;
    case "warning":
      return Style.animationNormal;
    default:
      return Style.animationSlowest;
    }
  }

  readonly property int pauseDuration: Math.max(0, cycleTotal - (pulseSpeed * 2))

  readonly property string tooltipText: {
    if (hosts.length === 0)
      return pluginApi?.tr("widget.tooltip.noData");
    if (!showHostName)
      return displayHost?.name;
    return hosts.map(h => {
      const a = h.avg10m >= 0 ? Math.round(h.avg10m) + "ms" : h.timedOut ? pluginApi?.tr("widget.timedOut") : "…";
      return `${h.name}: ${a}`;
    }).join("\n");
  }

  readonly property real iconSize: Style.toOdd(capsuleHeight * 0.55)

  readonly property real contentWidth: {
    if (isVertical)
      return capsuleHeight;
    return iconSize + Style.marginS + labelText.implicitWidth + Style.marginM;
  }
  readonly property real contentHeight: isVertical ? capsuleHeight * 2 : capsuleHeight

  implicitWidth: contentWidth
  implicitHeight: contentHeight

  Rectangle {
    id: capsule
    x: Style.pixelAlignCenter(parent.width, width)
    y: Style.pixelAlignCenter(parent.height, height)
    width: root.contentWidth
    height: root.contentHeight
    radius: Style.radiusL
    color: Style.capsuleColor
    border.color: Style.capsuleBorderColor
    border.width: Style.capsuleBorderWidth

    Behavior on color {
      ColorAnimation {
        duration: Style.animationFast
      }
    }
    Behavior on border.color {
      ColorAnimation {
        duration: Style.animationFast
      }
    }

    RowLayout {
      anchors.fill: parent
      spacing: Style.marginS
      visible: !isVertical

      Rectangle {
        width: Style.toOdd(root.iconSize * 0.55)
        height: width
        radius: width / 2
        color: root.statusColor
        Layout.alignment: Qt.AlignVCenter
        Layout.leftMargin: Style.marginS

        SequentialAnimation on opacity {
          running: mainInstance?.animations || root.status == "critical"
          loops: Animation.Infinite

          NumberAnimation {
            to: 0.25
            duration: root.pulseSpeed
            easing.type: Easing.OutQuad
          }
          NumberAnimation {
            to: 1.0
            duration: root.pulseSpeed
            easing.type: Easing.InQuad
          }
          PauseAnimation {
            duration: root.pauseDuration
          }
        }
      }

      NText {
        id: labelText
        text: root.displayText
        pointSize: root.barFontSize
        applyUiScale: false
        color: root.statusColor
        Layout.alignment: Qt.AlignVCenter
        Behavior on color {
          ColorAnimation {
            duration: 300
          }
        }
      }
    }

    ColumnLayout {
      anchors.centerIn: parent
      spacing: Style.marginXS
      visible: isVertical

      Rectangle {
        width: Style.toOdd(root.capsuleHeight * 0.28)
        height: width
        radius: width / 2
        color: root.statusColor
        Layout.alignment: Qt.AlignHCenter

        SequentialAnimation on opacity {
          running: root.status === "critical"
          loops: Animation.Infinite
          NumberAnimation {
            to: 0.25
            duration: 600
          }
          NumberAnimation {
            to: 1.0
            duration: 600
          }
        }
      }

      NText {
        text: root.verticalLine1
        pointSize: root.barFontSize * 0.7
        applyUiScale: false
        font.weight: Font.Medium
        color: root.statusColor
        Layout.alignment: Qt.AlignHCenter
        Behavior on color {
          ColorAnimation {
            duration: 300
          }
        }
      }

      NText {
        text: root.verticalLine2
        pointSize: root.barFontSize * 0.8
        applyUiScale: false
        opacity: 0.75
        color: root.statusColor
        visible: root.verticalLine2 !== ""
        Layout.alignment: Qt.AlignHCenter
      }
    }

    MouseArea {
      anchors.fill: parent
      hoverEnabled: true
      cursorShape: Qt.PointingHandCursor
      acceptedButtons: Qt.LeftButton | Qt.RightButton

      onClicked: mouse => {
        if (mouse.button === Qt.LeftButton) {
          if (pluginApi)
            pluginApi.openPanel(root.screen, root);
        } else if (mouse.button === Qt.RightButton) {
          PanelService.showContextMenu(contextMenu, root, screen);
        }
      }

      onEntered: TooltipService.show(root, tooltipText, BarService.getTooltipDirection(root.screen?.name))
      onExited: TooltipService.hide()
    }
  }

  NPopupContextMenu {
    id: contextMenu
    model: [
      {
        "label": pluginApi?.tr("menu.openPanel"),
        "action": "open",
        "icon": "cloud"
      },
      {
        "label": pluginApi?.tr("menu.settings"),
        "action": "settings",
        "icon": "settings"
      }
    ]
    onTriggered: function (action) {
      contextMenu.close();
      PanelService.closeContextMenu(screen);
      if (action === "open") {
        pluginApi.openPanel(root.screen, root);
      } else if (action === "settings") {
        BarService.openPluginSettings(root.screen, pluginApi.manifest);
      }
    }
  }
}
