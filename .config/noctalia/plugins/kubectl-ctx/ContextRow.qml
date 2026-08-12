import QtQuick
import QtQuick.Layouts
import qs.Commons
import qs.Widgets

Item {
  id: root

  property var pluginApi: null
  property string contextName: ""
  property bool isActive: false
  property bool highlighted: false

  signal activated(string name)

  implicitHeight: Math.round(rowContent.implicitHeight + Style.marginS * 2)

  Rectangle {
    anchors.fill: parent
    radius: Style.radiusM
    color: {
      if (root.isActive) return Qt.alpha(Color.mPrimary, 0.15);
      if (root.highlighted) return Qt.alpha(Color.mPrimary, 0.08);
      if (hoverArea.containsMouse) return Qt.alpha(Color.mOnSurface, 0.06);
      return "transparent";
    }
  }

  RowLayout {
    id: rowContent
    anchors {
      left: parent.left
      right: parent.right
      verticalCenter: parent.verticalCenter
      leftMargin: Style.marginM
      rightMargin: Style.marginM
    }
    spacing: Style.marginS

    // Active indicator dot
    Rectangle {
      width: Math.round(Style.fontSizeS * 0.55)
      height: width
      radius: width / 2
      color: root.isActive ? Color.mPrimary : "transparent"
      border.width: root.isActive ? 0 : Style.borderS
      border.color: Color.mOnSurfaceVariant
      opacity: root.isActive ? 1.0 : 0.4
      Layout.alignment: Qt.AlignVCenter
    }

    NText {
      text: root.contextName
      pointSize: Style.fontSizeM
      font.weight: root.isActive ? Font.DemiBold : Font.Normal
      color: root.isActive ? Color.mPrimary : Color.mOnSurface
      elide: Text.ElideRight
      Layout.fillWidth: true
      Layout.alignment: Qt.AlignVCenter
    }

    NIcon {
      visible: root.isActive
      icon: "check"
      pointSize: Style.fontSizeM
      color: Color.mPrimary
      Layout.alignment: Qt.AlignVCenter
    }
  }

  MouseArea {
    id: hoverArea
    anchors.fill: parent
    hoverEnabled: true
    cursorShape: Qt.PointingHandCursor
    onPressed: {
      root.activated(root.contextName);
    }
  }
}
