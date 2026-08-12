import QtQuick
import QtQuick.Layouts
import qs.Commons
import qs.Services.UI
import qs.Widgets

Item {
  id: root
  property var pluginApi: null

  readonly property var geometryPlaceholder: panelContainer
  readonly property bool allowAttach: true

  property real contentPreferredWidth: 380 * Style.uiScaleRatio
  property real contentPreferredHeight: 400 * Style.uiScaleRatio

  readonly property var mainInstance: pluginApi?.mainInstance
  readonly property int portCount: mainInstance?.portCount ?? 0

  // Kill confirmation state
  property string pendingKillPid: ""
  property string pendingKillPort: ""
  property string pendingKillProto: ""
  property bool pendingKillIsSystem: false

  anchors.fill: parent

  Rectangle {
    id: panelContainer
    anchors.fill: parent
    color: "transparent"

    ColumnLayout {
      anchors {
        fill: parent
        margins: Style.marginXL
      }
      spacing: Style.marginL

      // Header
      NText {
        Layout.alignment: Qt.AlignHCenter
        Layout.topMargin: Style.marginM
        text: root.portCount === 0 ? pluginApi?.tr("panel.noPorts") : pluginApi?.trp("bar.ports", root.portCount)
        pointSize: Style.fontSizeL
        font.weight: Font.DemiBold
        color: root.portCount > 0 ? Color.mPrimary : Color.mOnSurfaceVariant
      }

      // Confirmation bar
      NBox {
        id: confirmBar
        visible: root.pendingKillPort !== ""
        Layout.fillWidth: true
        Layout.preferredHeight: confirmRow.implicitHeight + Style.marginM * 2

        RowLayout {
          id: confirmRow
          anchors.fill: parent
          anchors.margins: Style.marginM
          spacing: Style.marginM

          NText {
            Layout.fillWidth: true
            text: root.pendingKillIsSystem
              ? pluginApi?.tr("panel.confirmKillSystem", { port: root.pendingKillPort })
              : pluginApi?.tr("panel.confirmKill", { port: root.pendingKillPort })
            pointSize: Style.fontSizeS
            color: Color.mError
            wrapMode: Text.WordWrap
          }

          NButton {
            text: pluginApi?.tr("panel.confirm")
            onClicked: {
              if (root.pendingKillIsSystem) {
                root.mainInstance?.killPortElevated(root.pendingKillPort, root.pendingKillProto)
              } else {
                root.mainInstance?.killProcess(root.pendingKillPid)
              }
              root.pendingKillPort = ""
              root.pendingKillPid = ""
              root.pendingKillProto = ""
              root.pendingKillIsSystem = false
            }
          }

          NButton {
            text: pluginApi?.tr("panel.cancel")
            onClicked: {
              root.pendingKillPort = ""
              root.pendingKillPid = ""
              root.pendingKillProto = ""
              root.pendingKillIsSystem = false
            }
          }
        }
      }

      // Scrollable port list
      NScrollView {
        id: portScrollView
        Layout.fillWidth: true
        Layout.fillHeight: true
        contentWidth: availableWidth

        ColumnLayout {
          id: portColumn
          width: portScrollView.availableWidth
          spacing: Style.marginS

          Repeater {
            model: root.mainInstance?.sortedPorts ?? []

            delegate: NBox {
              required property var modelData
              Layout.fillWidth: true
              Layout.preferredHeight: portRow.implicitHeight + Style.marginM * 2

              readonly property bool hasProcess: (modelData.pid ?? "") !== ""

              RowLayout {
                id: portRow
                anchors.fill: parent
                anchors.margins: Style.marginM
                spacing: Style.marginM

                // Port number
                NText {
                  text: pluginApi?.tr("panel.portNumber", { port: modelData.port })
                  pointSize: Style.fontSizeM
                  font.weight: Font.Bold
                  font.family: Settings.data.ui.fontFixed
                  color: modelData.proto === "TCP" ? Color.mPrimary : Color.mTertiary
                  Layout.preferredWidth: 60 * Style.uiScaleRatio
                }

                // Protocol badge
                NText {
                  text: modelData.proto
                  pointSize: Style.fontSizeXS
                  color: Color.mOnSurfaceVariant
                  Layout.preferredWidth: 30 * Style.uiScaleRatio
                }

                // Address + process info
                ColumnLayout {
                  Layout.fillWidth: true
                  spacing: Style.marginXS

                  NText {
                    text: modelData.address
                    pointSize: Style.fontSizeS
                    font.family: Settings.data.ui.fontFixed
                    color: Color.mOnSurface
                    Layout.fillWidth: true
                    elide: Text.ElideRight
                  }

                  NText {
                    text: modelData.processName ? pluginApi?.tr("panel.processInfo", { name: modelData.processName, pid: modelData.pid }) : pluginApi?.tr("panel.unknownProcess")
                    pointSize: Style.fontSizeS
                    color: modelData.processName ? Color.mOnSurface : Color.mOnSurfaceVariant
                    Layout.fillWidth: true
                    elide: Text.ElideRight
                  }
                }

                // Kill button with confirmation
                NIcon {
                  icon: hasProcess ? "x" : "shield-x"
                  pointSize: Style.fontSizeM
                  color: killArea.containsMouse ? Color.mError : Color.mOnSurfaceVariant
                  Layout.alignment: Qt.AlignVCenter

                  MouseArea {
                    id: killArea
                    anchors.fill: parent
                    anchors.margins: -Style.marginS
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: {
                      root.pendingKillPort = modelData.port.toString()
                      root.pendingKillProto = modelData.proto
                      root.pendingKillPid = modelData.pid ?? ""
                      root.pendingKillIsSystem = !hasProcess
                    }
                  }
                }
              }
            }
          }

          // Spacer when empty
          Item {
            visible: root.portCount === 0
          }
        }
      }

      // Footer
      RowLayout {
        Layout.fillWidth: true
        spacing: Style.marginM

        NButton {
          Layout.fillWidth: true
          text: pluginApi?.tr("panel.refresh")
          onClicked: root.mainInstance?.refresh()
        }

        NIconButton {
          icon: "settings"
          onClicked: {
            if (!pluginApi) return
            BarService.openPluginSettings(pluginApi.panelOpenScreen, pluginApi.manifest)
            pluginApi.closePanel(pluginApi.panelOpenScreen)
          }
        }
      }
    }
  }
}
