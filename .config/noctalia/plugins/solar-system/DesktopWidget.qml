import QtQuick
import QtQuick.Layouts
import Quickshell.Io
import qs.Commons
import qs.Modules.DesktopWidgets
import qs.Widgets

DraggableDesktopWidget {
  id: root
  property var pluginApi: null
  property var planets: []
  property var aspects: []
  property var season: ({})
  property var moon: ({})
  property string utcLabel: ""
  property int hovered: -1

  readonly property var cfg: pluginApi?.pluginSettings || ({})
  readonly property real box: Math.round((cfg.size ?? 280) * widgetScale)
  readonly property bool showOrbits: cfg.showOrbits !== false
  readonly property bool showLabels: !!cfg.showLabels
  readonly property int refreshSeconds: cfg.refreshSeconds ?? 60
  readonly property int earthIndex: {
    for (var i = 0; i < planets.length; i++) {
      if (planets[i] && planets[i].name === "Earth")
        return i;
    }
    return -1;
  }
  readonly property var earthP: earthIndex >= 0 ? planets[earthIndex] : ({})

  Component.onCompleted: {
    if (pluginApi && pluginApi.pluginSettings) {
      pluginApi.pluginSettings.showBackground = false;
      pluginApi.pluginSettings.roundedCorners = false;
    }
  }

  implicitWidth: box
  implicitHeight: Math.round(box + Style.fontSizeXS * widgetScale * 2.2)
  width: implicitWidth
  height: implicitHeight

  function repaintOverlays() {
    orbitCanvas.requestPaint();
  }

  Process {
    id: proc
    command: ["python3", "/home/ahmed/.config/noctalia/plugins/solar-system/fetch.py"]
    stdout: StdioCollector {}
    onExited: {
      try {
        var data = JSON.parse(String(proc.stdout.text || "{}"));
        root.planets = data.planets || [];
        root.aspects = data.aspects || [];
        root.season = data.season || ({});
        root.moon = data.moon || ({});
        root.utcLabel = data.utc || "";
      } catch (e) {
        root.planets = [];
        root.aspects = [];
      }
    }
  }

  Timer {
    interval: Math.max(30, root.refreshSeconds) * 1000
    running: true
    repeat: true
    triggeredOnStart: true
    onTriggered: proc.running = true
  }

  ColumnLayout {
    anchors.fill: parent
    spacing: Math.round(2 * widgetScale)

    Item {
      id: sky
      Layout.preferredWidth: root.box
      Layout.preferredHeight: root.box
      Layout.alignment: Qt.AlignHCenter
      width: root.box
      height: root.box
      clip: false

      Canvas {
        id: orbitCanvas
        anchors.fill: parent
        onWidthChanged: requestPaint()
        onHeightChanged: requestPaint()
        onPaint: {
          var ctx = getContext("2d");
          ctx.clearRect(0, 0, width, height);
          var planets = root.planets || [];
          var cx = width / 2;
          var cy = height / 2;
          var scale = width * 0.48;

          function toXY(pt) {
            return {
              x: cx + Number(pt[0]) * scale,
              y: cy - Number(pt[1]) * scale
            };
          }

          if (root.showOrbits) {
            for (var i = 0; i < planets.length; i++) {
              var p = planets[i] || {};
              var orbit = p.orbit || [];
              if (orbit.length < 3)
                continue;
              ctx.strokeStyle = p.color || "#9ab0c8";
              ctx.lineWidth = (p.name === "Earth" ? 1.7 : 1.15);
              ctx.globalAlpha = 0.65;
              if (ctx.setLineDash) {
                if (i >= 5)
                  ctx.setLineDash([4, 3]);
                else if (i >= 3)
                  ctx.setLineDash([6, 2]);
                else
                  ctx.setLineDash([]);
              }
              ctx.beginPath();
              for (var j = 0; j < orbit.length; j++) {
                var xy = toXY(orbit[j]);
                if (j === 0)
                  ctx.moveTo(xy.x, xy.y);
                else
                  ctx.lineTo(xy.x, xy.y);
              }
              ctx.closePath();
              ctx.stroke();
            }
            if (ctx.setLineDash)
              ctx.setLineDash([]);
          }

          // Earth perihelion → aphelion season arc
          var season = root.season || {};
          var sarc = season.arc || [];
          if (sarc.length >= 2) {
            ctx.globalAlpha = 0.5;
            ctx.strokeStyle = "#5eb0ff";
            ctx.lineWidth = 2.4;
            if (ctx.setLineDash)
              ctx.setLineDash([]);
            ctx.beginPath();
            for (var s = 0; s < sarc.length; s++) {
              var sxy = toXY(sarc[s]);
              if (s === 0)
                ctx.moveTo(sxy.x, sxy.y);
              else
                ctx.lineTo(sxy.x, sxy.y);
            }
            ctx.stroke();

            function endMark(pt, filled) {
              if (!pt || pt.length < 2)
                return;
              var e = toXY(pt);
              ctx.globalAlpha = 0.9;
              ctx.fillStyle = "#9fd0ff";
              ctx.strokeStyle = "#9fd0ff";
              ctx.lineWidth = 1.2;
              ctx.beginPath();
              ctx.arc(e.x, e.y, filled ? 3.4 : 3.0, 0, Math.PI * 2);
              if (filled)
                ctx.fill();
              else
                ctx.stroke();
            }
            endMark(season.peri, true);
            endMark(season.apo, false);
          }

          // Conjunction / opposition radial ticks
          var aspects = root.aspects || [];
          for (var a = 0; a < aspects.length; a++) {
            var asp = aspects[a] || {};
            var lon = Number(asp.lon) || 0;
            var rad = lon * Math.PI / 180;
            var r0 = width * 0.48 * 0.12;
            var r1 = width * 0.48 * 0.96;
            var c0x = cx + Math.cos(rad) * r0;
            var c0y = cy - Math.sin(rad) * r0;
            var c1x = cx + Math.cos(rad) * r1;
            var c1y = cy - Math.sin(rad) * r1;
            var isOpp = asp.type === "opposition";
            ctx.globalAlpha = isOpp ? 0.48 : 0.3;
            ctx.strokeStyle = isOpp ? (asp.color_b || "#e07050") : "#b8c4d0";
            ctx.lineWidth = isOpp ? 1.45 : 1.0;
            if (ctx.setLineDash)
              ctx.setLineDash(isOpp ? [5, 4] : [2, 3]);
            ctx.beginPath();
            ctx.moveTo(c0x, c0y);
            ctx.lineTo(c1x, c1y);
            ctx.stroke();
            if (ctx.setLineDash)
              ctx.setLineDash([]);
            ctx.globalAlpha = 0.75;
            ctx.fillStyle = isOpp ? (asp.color_b || "#e07050") : (asp.color_a || "#b8c4d0");
            ctx.beginPath();
            ctx.arc(c1x, c1y, isOpp ? 3.2 : 2.4, 0, Math.PI * 2);
            ctx.fill();
          }
          ctx.globalAlpha = 1.0;
        }
      }

      Connections {
        target: root
        function onPlanetsChanged() {
          root.repaintOverlays();
        }
        function onAspectsChanged() {
          root.repaintOverlays();
        }
        function onSeasonChanged() {
          root.repaintOverlays();
        }
      }

      Rectangle {
        anchors.centerIn: parent
        width: Math.round(16 * widgetScale)
        height: width
        radius: width / 2
        color: "#ffcc55"
        border.color: "#ffe9a0"
        border.width: 1
        z: 2
      }

      Repeater {
        model: root.planets.length
        delegate: Item {
          id: body
          required property int index
          readonly property var p: root.planets[index] || ({})
          readonly property real scale: sky.width * 0.48
          readonly property real s: Math.round((p.name === "Jupiter" || p.name === "Saturn" ? 9 : p.name === "Mercury" || p.name === "Mars" ? 5 : 7) * widgetScale)
          width: s
          height: s
          x: sky.width / 2 + Number(p.vx || 0) * scale - s / 2
          y: sky.height / 2 - Number(p.vy || 0) * scale - s / 2
          z: 5

          Rectangle {
            anchors.fill: parent
            radius: width / 2
            color: body.p.color || Color.mPrimary
            border.color: Color.mOnSurface
            border.width: bodyHover.containsMouse ? 1 : 0
            scale: bodyHover.containsMouse ? 1.25 : 1.0
            Behavior on scale {
              NumberAnimation {
                duration: 120
              }
            }
          }

          // now tick above Earth
          Rectangle {
            visible: body.p.name === "Earth"
            width: Math.round(2 * widgetScale)
            height: Math.round(7 * widgetScale)
            radius: 1
            color: "#9fd0ff"
            opacity: 0.95
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.bottom: parent.top
            anchors.bottomMargin: 1
            z: 6
          }

          NText {
            visible: root.showLabels || bodyHover.containsMouse
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.top: parent.bottom
            anchors.topMargin: 1
            text: body.p.name || ""
            color: Color.mPrimary
            pointSize: Style.fontSizeXS * widgetScale * 0.9
          }

          MouseArea {
            id: bodyHover
            anchors.fill: parent
            anchors.margins: -6
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onEntered: root.hovered = body.index
            onExited: {
              if (root.hovered === body.index)
                root.hovered = -1;
            }
          }
        }
      }

      // Moon phase badge beside Earth
      Item {
        id: moonBadge
        visible: root.earthIndex >= 0 && root.moon && root.moon.phase !== undefined
        readonly property real scale: sky.width * 0.48
        readonly property real earthS: Math.round(7 * widgetScale)
        readonly property real ms: Math.round(12 * widgetScale)
        width: ms
        height: ms
        z: 8
        x: sky.width / 2 + Number(root.earthP.vx || 0) * scale + earthS * 0.65
        y: sky.height / 2 - Number(root.earthP.vy || 0) * scale - ms / 2

        Canvas {
          id: moonPhase
          anchors.fill: parent
          onWidthChanged: requestPaint()
          onHeightChanged: requestPaint()
          Connections {
            target: root
            function onMoonChanged() {
              moonPhase.requestPaint();
            }
          }
          onPaint: {
            var ctx = getContext("2d");
            ctx.clearRect(0, 0, width, height);
            var illum = Math.max(0, Math.min(1, Number(root.moon.illumination || 0)));
            var waxing = !!root.moon.waxing;
            var r = Math.max(1, width / 2 - 0.75);
            var cx = width / 2;
            var cy = height / 2;

            // dark disc
            ctx.beginPath();
            ctx.arc(cx, cy, r, 0, Math.PI * 2);
            ctx.fillStyle = "#252a34";
            ctx.fill();

            if (illum < 0.01) {
              // new — rim only
            } else {
              ctx.save();
              ctx.beginPath();
              ctx.arc(cx, cy, r, 0, Math.PI * 2);
              ctx.clip();

              // lit disc
              ctx.beginPath();
              ctx.arc(cx, cy, r, 0, Math.PI * 2);
              ctx.fillStyle = "#e8e2ce";
              ctx.fill();

              // shadow disc offset along x (two-circle phase)
              // illum 0 → fully covered; 0.5 → half; 1 → uncovered
              if (illum < 0.995) {
                var shx = waxing ? (cx + (1 - 2 * illum) * r) : (cx - (1 - 2 * illum) * r);
                ctx.beginPath();
                ctx.arc(shx, cy, r, 0, Math.PI * 2);
                ctx.fillStyle = "#252a34";
                ctx.fill();
              }
              ctx.restore();
            }

            ctx.beginPath();
            ctx.arc(cx, cy, r, 0, Math.PI * 2);
            ctx.strokeStyle = "#8b93a2";
            ctx.lineWidth = 1;
            ctx.globalAlpha = 0.65;
            ctx.stroke();
            ctx.globalAlpha = 1.0;
          }
        }

        MouseArea {
          anchors.fill: parent
          anchors.margins: -4
          hoverEnabled: true
          id: moonHover
        }

        NText {
          visible: moonHover.containsMouse
          anchors.horizontalCenter: parent.horizontalCenter
          anchors.top: parent.bottom
          anchors.topMargin: 1
          text: (root.moon.name || "Moon") + " · " + Math.round((root.moon.illumination || 0) * 100) + "%"
          color: Color.mPrimary
          pointSize: Style.fontSizeXS * widgetScale * 0.85
        }
      }
    }

    NText {
      text: {
        var bits = [];
        if (root.utcLabel)
          bits.push(root.utcLabel);
        if (root.moon && root.moon.name)
          bits.push(root.moon.name);
        return bits.join(" · ");
      }
      visible: text.length > 0
      color: Color.mOnSurfaceVariant
      font.family: Settings.data.ui.fontFixed
      pointSize: Style.fontSizeXS * widgetScale * 0.85
      Layout.alignment: Qt.AlignHCenter
      opacity: 0.75
    }
  }
}
