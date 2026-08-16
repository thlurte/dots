import QtQuick
import QtQuick.Layouts
import Quickshell.Io
import qs.Commons
import qs.Modules.DesktopWidgets
import qs.Widgets

DraggableDesktopWidget {
  id: root
  property var pluginApi: null
  property int busy: 0
  property int vramUsed: 0
  property int vramTotal: 0
  property int temp: 0
  property int mhz: 0
  property real watt: 0

  readonly property real _width: Math.round(288 * widgetScale)
  readonly property real _pad: Math.round(Style.marginL * widgetScale)

  implicitWidth: _width
  implicitHeight: Math.round(contentCol.implicitHeight + _pad * 2)
  width: implicitWidth
  height: implicitHeight

  Process {
    id: proc
    command: ["sh", "-c", "dev=; for c in /sys/class/drm/card*/device; do grep -qx DRIVER=amdgpu \"$c/uevent\" 2>/dev/null && dev=$c && break; done; [ -n \"$dev\" ] || exit 0; echo busy=$(cat \"$dev/gpu_busy_percent\" 2>/dev/null); echo vu=$(cat \"$dev/mem_info_vram_used\" 2>/dev/null); echo vt=$(cat \"$dev/mem_info_vram_total\" 2>/dev/null); hw=; for d in /sys/class/hwmon/hwmon*; do [ \"$(cat \"$d/name\" 2>/dev/null)\" = amdgpu ] && hw=$d && break; done; [ -n \"$hw\" ] || exit 0; echo temp=$(cat \"$hw/temp1_input\" 2>/dev/null); echo freq=$(cat \"$hw/freq1_input\" 2>/dev/null); echo pwr=$(cat \"$hw/power1_average\" 2>/dev/null)"]
    stdout: StdioCollector {}
    onExited: {
      var t = String(proc.stdout.text || "");
      function val(k) {
        var m = t.match(new RegExp(k + "=(\\d+)"));
        return m ? parseInt(m[1]) : 0;
      }
      root.busy = val("busy");
      root.vramUsed = Math.round(val("vu") / 1048576);
      root.vramTotal = Math.round(val("vt") / 1048576);
      root.temp = Math.round(val("temp") / 1000);
      root.mhz = Math.round(val("freq") / 1000000);
      root.watt = val("pwr") / 1000000;
    }
  }

  Timer {
    interval: 2000
    running: true
    repeat: true
    triggeredOnStart: true
    onTriggered: proc.running = true
  }

  ColumnLayout {
    id: contentCol
    anchors.fill: parent
    anchors.margins: root._pad
    spacing: Math.round(Style.marginXS * widgetScale)

    RowLayout {
      Layout.fillWidth: true
      NIcon {
        icon: "cpu"
        color: root.busy >= 80 || root.temp >= 80 ? Color.mError : Color.mPrimary
        pointSize: Style.fontSizeXL * widgetScale
      }
      NText {
        text: "760M"
        color: Color.mOnSurface
        font.weight: Style.fontWeightBold
        pointSize: Style.fontSizeL * widgetScale
        Layout.fillWidth: true
      }
      NText {
        text: root.temp + "°"
        color: root.temp >= 80 ? Color.mError : Color.mPrimary
        font.family: Settings.data.ui.fontFixed
        font.weight: Style.fontWeightBold
        pointSize: Style.fontSizeM * widgetScale
      }
    }

    NText {
      text: root.busy + "%  ·  " + root.vramUsed + "/" + root.vramTotal + " MiB"
      color: Color.mOnSurface
      font.family: Settings.data.ui.fontFixed
      pointSize: Style.fontSizeS * widgetScale
    }

    NText {
      text: root.mhz + " MHz  ·  " + root.watt.toFixed(1) + " W"
      color: Color.mOnSurfaceVariant
      font.family: Settings.data.ui.fontFixed
      pointSize: Style.fontSizeXS * widgetScale
    }
  }
}
