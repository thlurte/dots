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

  property real contentPreferredWidth: 320 * Style.uiScaleRatio
  property real contentPreferredHeight: 400 * Style.uiScaleRatio

  readonly property var mainInstance: pluginApi?.mainInstance
  readonly property int activeCount: mainInstance?.activeCount ?? 0

  // Search state
  property string searchQuery: ""
  property int selectedIndex: -1

  function getFilteredHosts() {
    var hosts = root.mainInstance?.sortedHosts ?? []
    if (!root.searchQuery || root.searchQuery.trim() === "") return hosts

    var results = FuzzySort.go(root.searchQuery, hosts, {
      keys: ["host.name", "host.hostname", "host.user"],
      limit: 50
    })
    return results.map(function(r) { return r.obj })
  }

  function connectSelected() {
    var filtered = getFilteredHosts()
    if (root.selectedIndex >= 0 && root.selectedIndex < filtered.length) {
      root.mainInstance?.connectToHost(filtered[root.selectedIndex].host.name)
    }
  }

  onVisibleChanged: {
    if (visible) {
      root.searchQuery = ""
      root.selectedIndex = -1
      Qt.callLater(function() {
        if (searchInput && searchInput.inputItem) {
          searchInput.inputItem.forceActiveFocus()
        }
      })
    }
  }

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

      // ======== Header ========
      NText {
        Layout.alignment: Qt.AlignHCenter
        Layout.topMargin: Style.marginM
        text: {
          if (root.activeCount === 0) return pluginApi?.tr("panel.noActive")
          if (root.activeCount === 1) return pluginApi?.tr("bar.oneSession")
          return root.activeCount + " " + pluginApi?.tr("bar.multipleSessions")
        }
        pointSize: Style.fontSizeL
        font.weight: Font.DemiBold
        color: root.activeCount > 0 ? Color.mPrimary : Color.mOnSurfaceVariant
      }

      // ======== Search input ========
      NTextInput {
        id: searchInput
        Layout.fillWidth: true
        placeholderText: pluginApi?.tr("panel.search")
        text: root.searchQuery
        onTextChanged: {
          root.searchQuery = text
          root.selectedIndex = text.length > 0 ? 0 : -1
        }

        Keys.onDownPressed: {
          var filtered = root.getFilteredHosts()
          if (filtered.length > 0) {
            root.selectedIndex = Math.min(root.selectedIndex + 1, filtered.length - 1)
          }
        }
        Keys.onUpPressed: {
          if (root.selectedIndex > 0) {
            root.selectedIndex = root.selectedIndex - 1
          }
        }
        Keys.onReturnPressed: root.connectSelected()
        Keys.onEscapePressed: {
          if (root.searchQuery !== "") {
            root.searchQuery = ""
            searchInput.text = ""
            root.selectedIndex = -1
          } else {
            if (pluginApi) pluginApi.closePanel(pluginApi.panelOpenScreen)
          }
        }
      }

      // ======== Scrollable host list ========
      NScrollView {
        id: hostScrollView
        Layout.fillWidth: true
        Layout.fillHeight: true
        contentWidth: availableWidth

        ColumnLayout {
          id: hostColumn
          width: hostScrollView.availableWidth
          spacing: Style.marginS

          Repeater {
            model: root.getFilteredHosts()

            delegate: NBox {
              required property var modelData
              required property int index
              Layout.fillWidth: true
              Layout.preferredHeight: hostRow.implicitHeight + Style.marginM * 2
              color: index === root.selectedIndex ? Qt.alpha(Color.mPrimary, 0.15) : Color.mSurfaceVariant

              RowLayout {
                id: hostRow
                anchors.fill: parent
                anchors.margins: Style.marginM
                spacing: Style.marginM

                // Status dot
                Rectangle {
                  width: 8 * Style.uiScaleRatio
                  height: width
                  radius: width / 2
                  color: modelData.isActive ? Color.mPrimary : "transparent"
                  border.width: modelData.isActive ? 0 : 1.5 * Style.uiScaleRatio
                  border.color: Color.mOnSurfaceVariant
                  opacity: modelData.isActive ? 1.0 : 0.5
                  Layout.alignment: Qt.AlignVCenter
                }

                // Host info
                ColumnLayout {
                  Layout.fillWidth: true
                  spacing: Style.marginXS

                  NText {
                    text: modelData.host.name
                    pointSize: Style.fontSizeM
                    font.weight: modelData.isActive ? Font.DemiBold : Font.Normal
                    color: Color.mOnSurface
                    Layout.fillWidth: true
                    elide: Text.ElideRight
                  }

                  NText {
                    text: root.mainInstance?.getHostDescription(modelData.host) ?? ""
                    pointSize: Style.fontSizeS
                    color: Color.mOnSurfaceVariant
                    Layout.fillWidth: true
                    elide: Text.ElideRight
                  }
                }

                // Connect button
                NIcon {
                  icon: "terminal"
                  pointSize: Style.fontSizeM
                  color: connectArea.containsMouse ? Color.mPrimary : Color.mOnSurfaceVariant
                  Layout.alignment: Qt.AlignVCenter

                  MouseArea {
                    id: connectArea
                    anchors.fill: parent
                    anchors.margins: -Style.marginS
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: root.mainInstance?.connectToHost(modelData.host.name)
                  }
                }
              }
            }
          }

          // No hosts message
          NText {
            visible: (root.mainInstance?.hostList ?? []).length === 0 && root.mainInstance?.configLoaded
            Layout.alignment: Qt.AlignHCenter
            Layout.topMargin: Style.marginXL
            Layout.bottomMargin: Style.marginXL
            text: pluginApi?.tr("panel.noHosts")
            pointSize: Style.fontSizeM
            color: Color.mOnSurfaceVariant
          }
        }
      }

      // ======== Footer ========
      RowLayout {
        Layout.fillWidth: true
        spacing: Style.marginM

        NButton {
          Layout.fillWidth: true
          text: pluginApi?.tr("panel.refresh")
          onClicked: root.mainInstance?.fullRefresh()
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
