import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import qs.Commons
import qs.Services.UI
import qs.Widgets

Item {
  id: root

  property var pluginApi: null

  readonly property var geometryPlaceholder: panelContainer
  property real contentPreferredWidth: 400 * Style.uiScaleRatio
  readonly property real maxHeight: 540 * Style.uiScaleRatio
  property real contentPreferredHeight: Math.min(contentColumn.implicitHeight + Style.marginL * 2, maxHeight)
  property bool panelReady: false
  readonly property bool allowAttach: true

  Behavior on contentPreferredHeight {
    enabled: panelReady
    NumberAnimation {
      duration: 180
      easing.type: Easing.InOutCubic
    }
  }

  readonly property var mainInstance: pluginApi?.mainInstance
  readonly property var hosts: mainInstance?.hosts ?? []
  readonly property int thresholdGood: mainInstance?.thresholdGood ?? 20
  readonly property int thresholdWarning: mainInstance?.thresholdWarning ?? 70

  property int _activeHost: 0
  property int _windowMinutes: 30     // 10 | 30 | 60

  readonly property var _host: hosts[_activeHost] ?? null

  readonly property var _currentSamples: {
    void (_host?.samples);
    return _host ? _host.samplesInWindow(_windowMinutes) : [];
  }

  readonly property var _currentRtts: _currentSamples.map(s => s.rtt)

  function statusColor(status) {
    switch (status) {
    case "good":
      return mainInstance?.colorGood;
    case "warning":
      return mainInstance?.colorWarning;
    case "critical":
      return mainInstance?.colorCritical;
    default:
      return "onSurface";
    }
  }

  function _threshY(thresh, maxVal, h) {
    if (maxVal <= 0 || h <= 0)
      return -1;
    const pad = maxVal * 0.12;                  // curvePadding
    const norm = (thresh + pad) / (maxVal + pad * 2);
    return h * (1.0 - norm);                         // flip: y=0 is top
  }

  anchors.fill: parent

  Rectangle {
    id: panelContainer
    anchors.fill: parent
    color: "transparent"

    ColumnLayout {
      id: contentColumn
      anchors {
        fill: parent
        margins: Style.marginL
      }
      spacing: Style.marginM

      RowLayout {
        Layout.fillWidth: true
        spacing: Style.marginM

        NIcon {
          icon: "cloud"
          pointSize: Style.fontSizeXL
          color: Color.mPrimary
          Layout.alignment: Qt.AlignVCenter
        }
        NText {
          text: pluginApi?.tr("panel.title")
          pointSize: Style.fontSizeL
          font.weight: Font.Bold
          color: Color.mOnSurface
          Layout.alignment: Qt.AlignVCenter
        }
        Item {
          Layout.fillWidth: true
        }

        NIconButton {
          icon: "settings"
          tooltipText: pluginApi?.tr("menu.settings")
          onClicked: {
            const screen = pluginApi?.panelOpenScreen;
            if (screen) {
              pluginApi.closePanel(screen);
              Qt.callLater(() => BarService.openPluginSettings(screen, pluginApi.manifest));
            }
          }
          Layout.alignment: Qt.AlignVCenter
        }
        NIconButton {
          icon: "x"
          tooltipText: pluginApi?.tr("panel.close")
          onClicked: {
            const s = pluginApi?.panelOpenScreen;
            if (s)
              pluginApi.closePanel(s);
          }
          Layout.alignment: Qt.AlignVCenter
        }
      }

      Repeater {
        model: hosts

        delegate: RowLayout {
          id: rootHostLayout
          required property int index
          required property var modelData

          Layout.fillWidth: true

          NButton {
            text: modelData.name
            fontSize: Style.fontSizeXS
            backgroundColor: root._activeHost == index ? Color.mPrimary : Color.mSecondary
            tooltipText: modelData.address
            onClicked: {
              root._activeHost = index;
            }
            opacity: index === root._activeHost ? 1.0 : 0.5
          }
          Item {
            Layout.fillWidth: true
          }

          RowLayout {
            Layout.fillWidth: true
            spacing: Style.marginS

            Repeater {
              model: [
                {
                  labelKey: "panel.timings.1h",
                  avg: rootHostLayout.modelData.avg60m ?? -1
                },
                {
                  labelKey: "panel.timings.30m",
                  avg: rootHostLayout.modelData.avg30m ?? -1
                },
                {
                  labelKey: "panel.timings.10m",
                  avg: rootHostLayout.modelData.avg10m ?? -1
                },
                {
                  labelKey: "panel.timings.last",
                  avg: rootHostLayout.modelData.lastRtt ?? -1
                },
              ]

              delegate: Rectangle {
                id: tagRoot
                required property var modelData
                readonly property int rtt: Math.round(modelData.avg)
                readonly property var accentColor: root.statusColor(rootHostLayout.modelData.rttToStatus(rtt))

                implicitWidth: timeoutLabel.implicitWidth + Style.marginM * 2
                implicitHeight: timeoutLabel.implicitHeight + Style.marginXS * 2

                radius: Style.radiusS
                color: Qt.alpha(Color.mError, 0.12)
                border.color: accentColor
                border.width: Style.marginXXS
                opacity: rootHostLayout.index === root._activeHost ? 1.0 : 0.5

                NText {
                  id: timeoutLabel
                  anchors.centerIn: parent
                  text: `${rtt}ms`
                  pointSize: Style.fontSizeXS
                  color: accentColor
                }

                property var tooltipText: pluginApi?.tr(modelData.labelKey)
                property bool hovered: false
                signal entered
                signal exited

                MouseArea {
                  id: mouseArea
                  anchors.fill: parent
                  enabled: tagRoot.enabled
                  hoverEnabled: true
                  cursorShape: tagRoot.enabled ? Qt.PointingHandCursor : Qt.ArrowCursor

                  onEntered: {
                    tagRoot.hovered = tagRoot.enabled ? true : false;
                    tagRoot.entered();
                    if (tagRoot.hovered && tagRoot.tooltipText && (!Array.isArray(tagRoot.tooltipText) || tagRoot.tooltipText.length > 0)) {
                      TooltipService.show(tagRoot, tagRoot.tooltipText);
                    }
                  }
                  onExited: {
                    tagRoot.hovered = false;
                    tagRoot.exited();
                    if (tagRoot.tooltipText && (!Array.isArray(tagRoot.tooltipText) || tagRoot.tooltipText.length > 0)) {
                      TooltipService.hide();
                    }
                  }
                  onCanceled: {
                    tagRoot.hovered = false;
                    if (tagRoot.tooltipText && (!Array.isArray(tagRoot.tooltipText) || tagRoot.tooltipText.length > 0)) {
                      TooltipService.hide();
                    }
                  }
                }
              }
            }
          }
        }
      }

      NDivider {
        Layout.fillWidth: true
        opacity: 0.4
      }

      RowLayout {
        Layout.fillWidth: true
        spacing: Style.marginXS

        NTabBar {
          id: windowBar
          Layout.fillWidth: true
          currentIndex: root._windowMinutes === 10 ? 0 : root._windowMinutes === 30 ? 1 : 2
          color: "transparent"

          Repeater {
            model: [
              {
                label: pluginApi?.tr("panel.timings.10m"),
                value: 10
              },
              {
                label: pluginApi?.tr("panel.timings.30m"),
                value: 30
              },
              {
                label: pluginApi?.tr("panel.timings.1h"),
                value: 60
              },
            ]

            delegate: NTabButton {
              required property var modelData
              required property int index

              text: modelData.label ?? ""
              tabIndex: index
              checked: root._windowMinutes === modelData.value
              onClicked: root._windowMinutes = modelData.value
            }
          }
        }
      }

      Item {
        Layout.fillWidth: true
        implicitHeight: 140 * Style.uiScaleRatio + timeRow.implicitHeight + Style.marginXS

        Item {
          id: graphArea
          anchors {
            left: parent.left
            right: parent.right
            top: parent.top
          }
          height: 140 * Style.uiScaleRatio

          NGraph {
            id: graph
            anchors.fill: parent

            values: root._currentRtts
            minValue: 0
            maxValue: root._currentRtts.length > 0 ? Math.max(...root._currentRtts, root.thresholdWarning) * 1.15 : root.thresholdWarning * 1.15
            animateScale: true
            fill: true
            updateInterval: (mainInstance?.intervalSeconds ?? 5) * 1000

            color: root.statusColor(root._host?.status ?? "unknown")
          }

          Repeater {
            model: [
              {
                thresh: root.thresholdGood,
                color: mainInstance?.colorGood
              },
              {
                thresh: root.thresholdWarning,
                color: mainInstance?.colorWarning
              },
            ]
            delegate: Item {
              required property var modelData
              anchors {
                left: parent.left
                right: parent.right
              }

              readonly property real _y: root._threshY(modelData.thresh, graph.maxValue, graph.height)
              readonly property color _col: modelData.color

              visible: _y >= 0 && _y <= graph.height
              y: _y

              Row {
                anchors {
                  left: parent.left
                  right: labelBox.left
                  rightMargin: Style.marginXS
                }
                spacing: Style.marginXS
                Repeater {
                  model: Math.ceil(parent.width / 7)
                  delegate: Rectangle {
                    width: Style.marginS
                    height: 1
                    color: Qt.alpha(parent.parent.parent._col, 0.40)
                  }
                }
              }

              Rectangle {
                id: labelBox
                anchors.right: parent.right
                y: -height / 2
                implicitWidth: threshLabel.implicitWidth + Style.marginXS * 2
                implicitHeight: threshLabel.implicitHeight + 2
                radius: Style.radiusXS
                color: Qt.alpha(parent._col, 0.12)
                NText {
                  id: threshLabel
                  anchors.centerIn: parent
                  text: modelData.thresh + "ms"
                  pointSize: Style.fontSizeXS * 0.85
                  color: parent.parent._col
                }
              }
            }
          }

          MouseArea {
            id: graphHover
            anchors.fill: parent
            hoverEnabled: true

            readonly property int _idx: {
              const n = root._currentSamples.length;
              if (n < 2 || !containsMouse)
                return -1;
              return Math.max(0, Math.min(n - 1, Math.round(mouseX / width * (n - 1))));
            }
            readonly property var _sample: _idx >= 0 ? root._currentSamples[_idx] : null

            Rectangle {
              visible: graphHover._idx >= 0
              x: graphHover._idx >= 0 ? (graphHover._idx / Math.max(root._currentSamples.length - 1, 1)) * parent.width - width / 2 : 0
              width: 1
              height: parent.height
              color: Qt.alpha(Color.mOnSurface, 0.25)

              Rectangle {
                readonly property string _label: {
                  const s = graphHover._sample;
                  if (!s)
                    return "";
                  const d = new Date(s.ts);
                  const hms = d.getHours().toString().padStart(2, "0") + ":" + d.getMinutes().toString().padStart(2, "0") + ":" + d.getSeconds().toString().padStart(2, "0");
                  return `${s.rtt}ms · ${hms}`;
                }

                readonly property real _rawX: -(implicitWidth / 2)
                x: Math.max(-parent.x, Math.min(graphArea.width - parent.x - implicitWidth, _rawX))
                y: Style.marginXS

                implicitWidth: bubbleText.implicitWidth + Style.marginS * 2
                implicitHeight: bubbleText.implicitHeight + Style.marginXS * 2
                radius: Style.radiusS
                color: Color.mSurfaceVariant
                border.color: Qt.alpha(Color.mOnSurface, 0.15)
                border.width: Style.marginM

                NText {
                  id: bubbleText
                  anchors.centerIn: parent
                  text: parent._label
                  pointSize: Style.fontSizeXS
                  color: Color.mOnSurface
                }
              }
            }
          }
        }

        Row {
          id: timeRow
          anchors {
            left: parent.left
            right: parent.right
            top: graphArea.bottom
            topMargin: Style.marginXS
          }
          visible: root._currentSamples.length >= 2

          Repeater {
            model: 3   // start · mid · end
            delegate: Item {
              required property int index
              width: timeRow.width / 3
              height: timeLabel.implicitHeight

              readonly property int _sIdx: {
                const n = root._currentSamples.length;
                if (n < 2)
                  return -1;
                return index === 0 ? 0 : index === 1 ? Math.floor(n / 2) : n - 1;
              }

              NText {
                id: timeLabel
                anchors.horizontalCenter: parent.horizontalCenter
                visible: parent._sIdx >= 0

                text: {
                  const s = root._currentSamples[parent._sIdx];
                  if (!s)
                    return "";
                  const d = new Date(s.ts);
                  return d.getHours().toString().padStart(2, "0") + ":" + d.getMinutes().toString().padStart(2, "0");
                }
                pointSize: Style.fontSizeXS * 0.85
                color: Qt.alpha(Color.mSecondary, 0.6)
              }
            }
          }
        }
      }
    }
  }
}
