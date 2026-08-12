import QtQuick
import QtQuick.Layouts
import qs.Commons
import qs.Widgets

Item {
  id: root

  property var pluginApi: null
  property string resourceKind: ""
  property string resourceName: ""

  signal confirmed(string kind, string name)
  signal cancelled()

  implicitHeight: Math.round(confirmContent.implicitHeight + Style.marginL * 2)

  ColumnLayout {
    id: confirmContent
    anchors {
      left: parent.left
      right: parent.right
      verticalCenter: parent.verticalCenter
      margins: Style.marginL
    }
    spacing: Style.marginM

    NIcon {
      icon: "alert-triangle"
      pointSize: Style.fontSizeXXL
      color: Color.mError
      Layout.alignment: Qt.AlignHCenter
    }

    NText {
      text: pluginApi?.tr("delete.title")
      pointSize: Style.fontSizeL
      font.weight: Font.DemiBold
      color: Color.mOnSurface
      Layout.alignment: Qt.AlignHCenter
    }

    NText {
      text: pluginApi?.tr("delete.confirm", { "resource": root.resourceKind + "/" + root.resourceName })
      pointSize: Style.fontSizeM
      color: Color.mOnSurfaceVariant
      wrapMode: Text.WordWrap
      Layout.fillWidth: true
      Layout.alignment: Qt.AlignHCenter
      horizontalAlignment: Text.AlignHCenter
    }

    RowLayout {
      Layout.fillWidth: true
      spacing: Style.marginM

      NButton {
        Layout.fillWidth: true
        text: pluginApi?.tr("delete.cancel")
        onClicked: root.cancelled()
      }

      NButton {
        Layout.fillWidth: true
        text: pluginApi?.tr("delete.yes")
        backgroundColor: Color.mError
        textColor: Color.mOnError
        onClicked: root.confirmed(root.resourceKind, root.resourceName)
      }
    }
  }
}
