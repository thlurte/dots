import QtQuick
import QtQuick.Layouts
import Quickshell.Io
import qs.Commons
import qs.Modules.DesktopWidgets
import qs.Widgets

DraggableDesktopWidget {
  id: root
  property var pluginApi: null
  property var items: []
  property var pins: []
  property var errors: []
  property string status: ""
  property bool rateLimited: false

  // Layer data
  property var issTrail: []
  property real issLat: 0
  property real issLon: 0
  property real issAlt: 420
  property real issDistKm: 0
  property var issEtaMin: null
  property bool issVisibleNow: false
  property string issStatus: ""
  property var quakes: []
  property var planes: []
  property int hoveredQuake: -1
  property int hoveredPlane: -1
  property bool hoveredIss: false

  property real yaw: 0.15
  property real pitch: 0.18
  property real zoom: 1.0
  property bool dragging: false
  property bool hovering: false
  property int hoveredPin: -1
  // Remember docked position so we can restore after fullscreen zoom
  property real dockedX: -1
  property real dockedY: -1

  readonly property var cfg: pluginApi?.pluginSettings || ({})
  readonly property int refreshSeconds: cfg.refreshSeconds ?? 600
  readonly property real spinDps: cfg.spinDegreesPerSec ?? 1.8
  property bool showNews: cfg.showNews !== false
  property bool showIss: cfg.showIss !== false
  property bool showQuakes: !!cfg.showQuakes
  property bool showAdsb: !!cfg.showAdsb
  property bool showWind: !!cfg.showWind
  property bool showRain: !!cfg.showRain
  property bool showOcean: !!cfg.showOcean
  property var windGrid: null
  property string rainPath: ""
  property real rainPhase: 0
  property string oceanPath: ""
  property int weatherTick: 0
  readonly property real homeLat: cfg.homeLat ?? 7.73
  readonly property real homeLon: cfg.homeLon ?? 81.70
  readonly property real baseGlobeSize: Math.round((cfg.globeSize ?? 1020) * widgetScale)
  readonly property real _pad: Math.round(Style.marginS * widgetScale)
  readonly property real screenW: root.parent ? root.parent.width : 1920
  readonly property real screenH: root.parent ? root.parent.height : 1080
  // Grow toward fullscreen before digging into the sphere (avoids square crop on the sides)
  readonly property real maxGlobeSize: Math.max(200, Math.floor(Math.min(screenW, screenH) - _pad * 2 - 8))
  readonly property real desiredSize: baseGlobeSize * root.zoom
  readonly property real globeSize: Math.round(Math.min(maxGlobeSize, desiredSize))
  readonly property real opticalZoom: desiredSize / Math.max(1, globeSize)
  readonly property bool isFullscreenZoom: globeSize >= maxGlobeSize - 1 && root.zoom > 1.02
  // Base radius leaves margin for atmosphere; only exceed it once already fullscreen
  readonly property real sphereRadiusBase: 0.70
  readonly property real sphereRadius: Math.min(2.6, sphereRadiusBase * opticalZoom)
  readonly property string earthSrc: pluginApi ? ("file://" + pluginApi.pluginDir + "/assets/earth.jpg") : ""
  readonly property string blankSrc: pluginApi ? ("file://" + pluginApi.pluginDir + "/assets/blank.png") : ""
  readonly property string shaderSrc: pluginApi ? Qt.resolvedUrl(pluginApi.pluginDir + "/shaders/globe.frag.qsb") : ""
  readonly property string rainSrc: root.showRain && root.rainPath ? ("file://" + root.rainPath + "?t=" + root.weatherTick) : root.blankSrc
  readonly property string oceanSrc: root.showOcean && root.oceanPath ? ("file://" + root.oceanPath + "?t=" + root.weatherTick) : root.blankSrc
  readonly property bool wantWeather: root.showWind || root.showRain || root.showOcean
  readonly property bool autoSpin: !root.dragging

  implicitWidth: Math.round(globeSize + _pad * 2)
  implicitHeight: Math.round(globeSize + _pad * 2)
  width: implicitWidth
  height: implicitHeight

  Behavior on width {
    NumberAnimation {
      duration: 140
      easing.type: Easing.OutCubic
    }
  }
  Behavior on height {
    NumberAnimation {
      duration: 140
      easing.type: Easing.OutCubic
    }
  }

  function applyZoomLayout() {
    if (!root.parent)
      return;
    if (root.isFullscreenZoom) {
      if (root.dockedX < 0) {
        root.dockedX = root.x;
        root.dockedY = root.y;
      }
      root.x = Math.max(0, (root.screenW - root.width) / 2);
      root.y = Math.max(0, (root.screenH - root.height) / 2);
    } else if (root.dockedX >= 0) {
      root.x = root.dockedX;
      root.y = root.dockedY;
      root.dockedX = -1;
      root.dockedY = -1;
    }
  }

  onZoomChanged: applyZoomLayout()
  onWidthChanged: {
    if (root.isFullscreenZoom)
      applyZoomLayout();
  }
  onHeightChanged: {
    if (root.isFullscreenZoom)
      applyZoomLayout();
  }

  function openLink(link) {
    if (link)
      Qt.openUrlExternally(link);
  }

  function persistLayers() {
    if (!pluginApi || !pluginApi.pluginSettings)
      return;
    pluginApi.pluginSettings.showNews = root.showNews;
    pluginApi.pluginSettings.showIss = root.showIss;
    pluginApi.pluginSettings.showQuakes = root.showQuakes;
    pluginApi.pluginSettings.showAdsb = root.showAdsb;
    pluginApi.pluginSettings.showWind = root.showWind;
    pluginApi.pluginSettings.showRain = root.showRain;
    pluginApi.pluginSettings.showOcean = root.showOcean;
    pluginApi.saveSettings();
  }

  function toggleLayer(name) {
    if (name === "news")
      root.showNews = !root.showNews;
    else if (name === "iss")
      root.showIss = !root.showIss;
    else if (name === "quakes")
      root.showQuakes = !root.showQuakes;
    else if (name === "adsb")
      root.showAdsb = !root.showAdsb;
    else if (name === "wind")
      root.showWind = !root.showWind;
    else if (name === "rain")
      root.showRain = !root.showRain;
    else if (name === "ocean")
      root.showOcean = !root.showOcean;
    persistLayers();
  }

  property int clockTick: 0

  function localTimeLine(pin) {
    if (!pin || pin.tz_offset_min === undefined || pin.tz_offset_min === null)
      return "";
    // Depend on clockTick so the label updates while hovering
    var _t = root.clockTick;
    var offset = Number(pin.tz_offset_min);
    var now = new Date();
    var utcMs = now.getTime() + now.getTimezoneOffset() * 60000;
    var local = new Date(utcMs + offset * 60000);
    var hh = local.getHours();
    var mm = local.getMinutes();
    var pad = n => (n < 10 ? "0" : "") + n;
    var days = ["Sun", "Mon", "Tue", "Wed", "Thu", "Fri", "Sat"];
    var label = pin.tz ? String(pin.tz) : "";
    return days[local.getDay()] + " " + pad(hh) + ":" + pad(mm) + (label ? (" · " + label) : "");
  }

  Timer {
    interval: 1000
    running: root.hoveredPin >= 0
    repeat: true
    onTriggered: root.clockTick++
  }

  // Forward transform: local lat/lon -> camera space (matches globe.frag inverse)
  function project(lat, lon) {
    var la = (lat || 0) * Math.PI / 180;
    var lo = (lon || 0) * Math.PI / 180;
    var lx = Math.cos(la) * Math.cos(lo);
    var ly = Math.sin(la);
    var lz = -Math.cos(la) * Math.sin(lo);

    var cy = Math.cos(root.yaw);
    var sy = Math.sin(root.yaw);
    var x1 = lx * cy + lz * sy;
    var z1 = -lx * sy + lz * cy;

    var cp = Math.cos(root.pitch);
    var sp = Math.sin(root.pitch);
    return {
      x: x1,
      y: ly * cp - z1 * sp,
      z: ly * sp + z1 * cp
    };
  }

  function pinPos(lat, lon, altScale) {
    var p = root.project(lat, lon);
    var half = root.globeSize / 2;
    var scale = (altScale === undefined || altScale === null) ? 1.0 : altScale;
    var rr = root.sphereRadius * half * scale;
    return {
      x: half + p.x * rr,
      y: half - p.y * rr,
      z: p.z
    };
  }

  function inViewPos(pos) {
    var half = root.globeSize / 2;
    var viewR = Math.min(half, root.sphereRadius * half) * 1.02;
    var dx = pos.x - half;
    var dy = pos.y - half;
    return pos.z > 0.06 && Math.sqrt(dx * dx + dy * dy) < viewR;
  }

  Process {
    id: proc
    command: ["python3", "/home/ahmed/.config/noctalia/plugins/news-globe/fetch.py"]
    stdout: StdioCollector {}
    onExited: {
      try {
        var data = JSON.parse(String(proc.stdout.text || "{}"));
        root.items = data.items || [];
        root.pins = data.pins || [];
        root.errors = data.errors || [];
        root.rateLimited = data.rate_limited || false;
        root.status = root.rateLimited ? "limited" : (root.errors.length ? "partial" : "ok");
      } catch (e) {
        root.status = "error";
        root.errors = ["parse failed"];
      }
    }
  }

  Process {
    id: issProc
    command: ["python3", "/home/ahmed/.config/noctalia/plugins/iss-track/fetch.py"]
    stdout: StdioCollector {}
    onExited: {
      try {
        var data = JSON.parse(String(issProc.stdout.text || "{}"));
        root.issLat = data.lat || 0;
        root.issLon = data.lon || 0;
        root.issAlt = data.altitude || 420;
        root.issDistKm = data.dist_km || 0;
        root.issEtaMin = data.eta_min;
        root.issVisibleNow = !!data.visible_now;
        root.issTrail = data.trail || [];
        if (root.issVisibleNow)
          root.issStatus = "visible · " + root.issDistKm + " km";
        else if (root.issEtaMin !== null && root.issEtaMin !== undefined)
          root.issStatus = "~" + root.issEtaMin + "m · " + root.issDistKm + " km";
        else
          root.issStatus = root.issDistKm + " km";
      } catch (e) {
        root.issStatus = "err";
      }
    }
  }

  Process {
    id: quakeProc
    command: ["python3", "/home/ahmed/.config/noctalia/plugins/quake-map/fetch.py"]
    stdout: StdioCollector {}
    onExited: {
      try {
        var data = JSON.parse(String(quakeProc.stdout.text || "{}"));
        root.quakes = data.quakes || [];
      } catch (e) {
        root.quakes = [];
      }
    }
  }

  Process {
    id: adsbProc
    command: ["python3", "/home/ahmed/.config/noctalia/plugins/adsb-board/fetch.py"]
    stdout: StdioCollector {}
    onExited: {
      try {
        var data = JSON.parse(String(adsbProc.stdout.text || "{}"));
        root.planes = data.planes || [];
      } catch (e) {
        root.planes = [];
      }
    }
  }

  Timer {
    interval: Math.max(300, root.refreshSeconds) * 1000
    running: true
    repeat: true
    triggeredOnStart: true
    onTriggered: proc.running = true
  }

  Timer {
    interval: 20000
    running: root.showIss
    repeat: true
    triggeredOnStart: true
    onTriggered: issProc.running = true
  }

  Timer {
    interval: 300000
    running: root.showQuakes
    repeat: true
    triggeredOnStart: true
    onTriggered: quakeProc.running = true
  }

  Timer {
    interval: 15000
    running: root.showAdsb
    repeat: true
    triggeredOnStart: true
    onTriggered: adsbProc.running = true
  }

  Timer {
    interval: 32
    running: root.autoSpin
    repeat: true
    onTriggered: {
      root.yaw += root.spinDps * (interval / 1000) * Math.PI / 180;
      if (root.yaw > Math.PI * 2)
        root.yaw -= Math.PI * 2;
    }
  }

  Process {
    id: weatherProc
    command: {
      var cmd = ["python3", "/home/ahmed/.config/noctalia/plugins/news-globe/weather_fetch.py"];
      if (!root.showRain)
        cmd.push("--skip-rain");
      if (!root.showOcean)
        cmd.push("--skip-ocean");
      if (!root.showWind)
        cmd.push("--skip-wind");
      return cmd;
    }
    stdout: StdioCollector {}
    onExited: {
      try {
        var data = JSON.parse(String(weatherProc.stdout.text || "{}"));
        if (data.wind && data.wind.u)
          root.windGrid = data.wind;
        if (data.rain)
          root.rainPath = data.rain;
        if (data.ocean)
          root.oceanPath = data.ocean;
        root.weatherTick = Number(data.updated) || Date.now();
        rainTexture.scheduleUpdate();
        oceanTexture.scheduleUpdate();
        if (data.wind && data.wind.u)
          windFlow.resetParticles();
      } catch (e) {
        root.windGrid = null;
      }
    }
  }

  // Drives the shader's wind advection. Linear and seamless across the wrap.
  NumberAnimation {
    target: root
    property: "rainPhase"
    running: root.showRain
    from: 0
    to: 1
    duration: 14000
    loops: Animation.Infinite
  }

  Timer {
    interval: 600000
    running: root.wantWeather
    repeat: true
    triggeredOnStart: true
    onTriggered: weatherProc.running = true
  }

  Image {
    id: earthImage
    source: root.earthSrc
    width: 2048
    height: 1024
    smooth: true
    mipmap: true
    asynchronous: true
    onStatusChanged: {
      if (status === Image.Ready)
        earthTexture.scheduleUpdate();
    }
  }

  ShaderEffectSource {
    id: earthTexture
    sourceItem: earthImage
    hideSource: true
    live: false
    wrapMode: ShaderEffectSource.Repeat
    textureSize: Qt.size(2048, 1024)
  }

  Image {
    id: rainImage
    source: root.rainSrc
    width: 1024
    height: 512
    smooth: true
    cache: false
    asynchronous: true
    onStatusChanged: {
      if (status === Image.Ready)
        rainTexture.scheduleUpdate();
    }
  }

  Image {
    id: oceanImage
    source: root.oceanSrc
    width: 1024
    height: 512
    smooth: true
    cache: false
    asynchronous: true
    onStatusChanged: {
      if (status === Image.Ready)
        oceanTexture.scheduleUpdate();
    }
  }

  ShaderEffectSource {
    id: rainTexture
    sourceItem: rainImage
    hideSource: true
    live: false
    wrapMode: ShaderEffectSource.Repeat
    textureSize: Qt.size(1024, 512)
  }

  ShaderEffectSource {
    id: oceanTexture
    sourceItem: oceanImage
    hideSource: true
    live: false
    wrapMode: ShaderEffectSource.Repeat
    textureSize: Qt.size(1024, 512)
  }

  Item {
    id: globeBox
    anchors.centerIn: parent
    width: root.globeSize
    height: root.globeSize
    // Only clip once we're past fullscreen and digging into the sphere
    clip: root.opticalZoom > 1.02

    ShaderEffect {
      id: sphere
      anchors.fill: parent
      blending: true

      property var earthTex: earthTexture
      property var rainTex: rainTexture
      property var oceanTex: oceanTexture
      property real yaw: root.yaw
      property real pitch: root.pitch
      property real sphereRadius: root.sphereRadius
      property real haloStrength: root.opticalZoom > 1.15 ? 0.04 : 0.16
      property real nightLevel: 0.22
      property real rainMix: root.showRain ? 1.0 : 0.0
      property real oceanMix: root.showOcean ? 0.85 : 0.0
      property color haloColor: Color.mPrimary
      property real rainPhase: root.rainPhase

      fragmentShader: root.shaderSrc
    }

    Rectangle {
      anchors.centerIn: parent
      width: parent.width * root.sphereRadius
      height: width
      radius: width / 2
      color: Color.mSurfaceVariant
      visible: sphere.fragmentShader === "" || sphere.status === ShaderEffect.Error

      NText {
        anchors.centerIn: parent
        text: "shader missing"
        color: Color.mOnSurfaceVariant
        pointSize: Style.fontSizeS * widgetScale
      }
    }

    MouseArea {
      id: dragArea
      anchors.fill: parent
      z: 1
      hoverEnabled: true
      acceptedButtons: Qt.LeftButton | Qt.MiddleButton
      cursorShape: root.dragging ? Qt.ClosedHandCursor : Qt.OpenHandCursor
      property real lastX: 0
      property real lastY: 0

      onEntered: root.hovering = true
      onExited: {
        if (!pressed)
          root.hovering = false;
      }
      onPressed: mouse => {
        if (mouse.button === Qt.MiddleButton) {
          root.zoom = 1.0;
          return;
        }
        root.dragging = true;
        root.hovering = true;
        lastX = mouse.x;
        lastY = mouse.y;
      }
      onPositionChanged: mouse => {
        if (!pressed || !root.dragging)
          return;
        var sens = 0.006 / root.zoom;
        root.yaw += (mouse.x - lastX) * sens;
        root.pitch = Math.max(-1.1, Math.min(1.1, root.pitch - (mouse.y - lastY) * sens * 0.85));
        lastX = mouse.x;
        lastY = mouse.y;
      }
      onReleased: {
        root.dragging = false;
        root.hovering = containsMouse;
      }
      onCanceled: {
        root.dragging = false;
        root.hovering = false;
      }
      onDoubleClicked: proc.running = true
      onWheel: wheel => {
        wheel.accepted = true;
        var factor = Math.exp(wheel.angleDelta.y * 0.0018);
        root.zoom = Math.max(1.0, Math.min(3.2, root.zoom * factor));
      }
    }

    Repeater {
      model: root.pins.length

      delegate: Item {
        id: pinItem
        required property int index
        readonly property var p: root.pins[index] || ({})
        readonly property var pos: root.pinPos(p.lat, p.lon)
        readonly property bool onFront: pos.z > 0.08
        readonly property real half: root.globeSize / 2
        readonly property real viewR: Math.min(half, root.sphereRadius * half) * 0.98
        readonly property bool inView: {
          var dx = pos.x - half;
          var dy = pos.y - half;
          return Math.sqrt(dx * dx + dy * dy) < viewR;
        }
        readonly property real s: Math.round((11 + 5 * Math.max(pos.z, 0)) * widgetScale)

        visible: root.showNews && onFront && inView
        width: s
        height: s
        x: pos.x - s / 2
        y: pos.y - s / 2
        z: 5
        opacity: 0.55 + 0.45 * pos.z

        // Soft ping — staggered so pins don't blink in unison
        SequentialAnimation {
          id: pinPulse
          property real phase: 0
          running: pinItem.visible && !pinHover.containsMouse
          loops: Animation.Infinite

          PauseAnimation {
            duration: (pinItem.index % 5) * 220
          }
          NumberAnimation {
            target: pinPulse
            property: "phase"
            from: 0
            to: 1
            duration: 1600
            easing.type: Easing.OutQuad
          }
          PauseAnimation {
            duration: 400 + (pinItem.index % 3) * 120
          }
        }

        // Expanding halo ring
        Rectangle {
          anchors.centerIn: parent
          width: parent.s * (1.2 + pinPulse.phase * 2.2)
          height: width
          radius: width / 2
          color: "transparent"
          border.color: Color.mPrimary
          border.width: Math.max(1, Math.round(1.5 * widgetScale))
          opacity: pinHover.containsMouse ? 0 : (1.0 - pinPulse.phase) * 0.55
          visible: pinPulse.running
        }

        Rectangle {
          anchors.centerIn: parent
          width: parent.s * (2.2 + (pinHover.containsMouse ? 0.4 : 0.15 * Math.sin(pinPulse.phase * Math.PI)))
          height: width
          radius: width / 2
          color: Color.mPrimary
          opacity: pinHover.containsMouse ? 0.42 : 0.14 + 0.12 * (1.0 - pinPulse.phase)
        }

        Rectangle {
          anchors.centerIn: parent
          width: parent.s * (pinHover.containsMouse ? 1.15 : 1.0)
          height: width
          radius: width / 2
          color: pinHover.containsMouse ? Color.mTertiary : Color.mPrimary
          border.color: Color.mOnSurface
          border.width: 1

          Behavior on width {
            NumberAnimation {
              duration: 140
              easing.type: Easing.OutQuad
            }
          }
        }

        MouseArea {
          id: pinHover
          anchors.fill: parent
          anchors.margins: -Math.round(8 * widgetScale)
          hoverEnabled: true
          cursorShape: Qt.PointingHandCursor
          onEntered: {
            root.hoveredPin = pinItem.index;
            pinPulse.phase = 0;
          }
          onExited: {
            if (root.hoveredPin === pinItem.index)
              root.hoveredPin = -1;
          }
          onClicked: root.openLink(pinItem.p.link || "")
        }
      }
    }

    // —— ISS orbital trail (slightly above surface) ——
    Repeater {
      model: root.showIss ? root.issTrail.length : 0
      delegate: Rectangle {
        required property int index
        readonly property var pt: root.issTrail[index] || ({})
        readonly property real altScale: 1.0 + Math.min(0.06, (Number(pt.alt) || 420) / 12000.0)
        readonly property var pos: root.pinPos(pt.lat, pt.lon, altScale)
        readonly property real s: Math.round((2.5 + 2.5 * (index / Math.max(1, root.issTrail.length - 1))) * widgetScale)
        visible: root.inViewPos(pos)
        width: s
        height: s
        radius: s / 2
        x: pos.x - s / 2
        y: pos.y - s / 2
        z: 6
        color: Color.mTertiary
        opacity: 0.12 + 0.75 * (index / Math.max(1, root.issTrail.length - 1))
      }
    }

    // ISS craft
    Item {
      id: issMark
      visible: root.showIss && root.inViewPos(pos)
      readonly property var pos: root.pinPos(root.issLat, root.issLon, 1.0 + Math.min(0.06, root.issAlt / 12000.0))
      readonly property real s: Math.round(14 * widgetScale)
      width: s * 3
      height: s * 3
      x: pos.x - width / 2
      y: pos.y - height / 2
      z: 12

      Rectangle {
        anchors.centerIn: parent
        width: parent.s * (1.4 + issPulse.phase * 2.4)
        height: width
        radius: width / 2
        color: "transparent"
        border.color: Color.mTertiary
        border.width: 1
        opacity: (1 - issPulse.phase) * 0.7
      }

      SequentialAnimation {
        id: issPulse
        property real phase: 0
        running: issMark.visible
        loops: Animation.Infinite
        NumberAnimation {
          target: issPulse
          property: "phase"
          from: 0
          to: 1
          duration: 1600
          easing.type: Easing.OutQuad
        }
        PauseAnimation {
          duration: 200
        }
      }

      Rectangle {
        anchors.centerIn: parent
        width: parent.s
        height: width
        radius: width / 2
        color: root.issVisibleNow ? Color.mTertiary : Color.mPrimary
        border.color: Color.mOnSurface
        border.width: 1
      }

      MouseArea {
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onEntered: root.hoveredIss = true
        onExited: root.hoveredIss = false
        onClicked: root.openLink("https://spotthestation.nasa.gov/")
      }
    }

    // —— Quakes ——
    Repeater {
      model: root.showQuakes ? root.quakes.length : 0
      delegate: Item {
        id: qItem
        required property int index
        readonly property var q: root.quakes[index] || ({})
        readonly property real mag: Number(q.mag) || 0
        readonly property var pos: root.pinPos(q.lat, q.lon)
        readonly property real core: Math.round((5 + mag * 1.8) * widgetScale)
        visible: root.inViewPos(pos)
        width: core * 6
        height: core * 6
        x: pos.x - width / 2
        y: pos.y - height / 2
        z: 7

        Rectangle {
          anchors.centerIn: parent
          width: qItem.core * (1.2 + qPulse.phase * (2.5 + qItem.mag * 0.35))
          height: width
          radius: width / 2
          color: "transparent"
          border.color: qItem.mag >= 5 ? Color.mError : Color.mPrimary
          border.width: 1
          opacity: (1 - qPulse.phase) * 0.5
        }

        SequentialAnimation {
          id: qPulse
          property real phase: 0
          running: qItem.visible
          loops: Animation.Infinite
          PauseAnimation {
            duration: (qItem.index % 6) * 160
          }
          NumberAnimation {
            target: qPulse
            property: "phase"
            from: 0
            to: 1
            duration: 2000 + qItem.mag * 180
            easing.type: Easing.OutQuad
          }
          PauseAnimation {
            duration: 400
          }
        }

        Rectangle {
          anchors.centerIn: parent
          width: qItem.core
          height: width
          radius: width / 2
          color: qItem.mag >= 5 ? Color.mError : Color.mPrimary
          border.color: Color.mOnSurface
          border.width: 1
        }

        MouseArea {
          anchors.fill: parent
          hoverEnabled: true
          cursorShape: Qt.PointingHandCursor
          onEntered: root.hoveredQuake = qItem.index
          onExited: {
            if (root.hoveredQuake === qItem.index)
              root.hoveredQuake = -1;
          }
          onClicked: root.openLink(qItem.q.url || "")
        }
      }
    }

    // —— ADS-B ——
    Repeater {
      model: root.showAdsb ? root.planes.length : 0
      delegate: Item {
        id: acItem
        required property int index
        readonly property var p: root.planes[index] || ({})
        readonly property var pos: root.pinPos(p.lat, p.lon, 1.012)
        readonly property real s: Math.round(10 * widgetScale)
        visible: root.inViewPos(pos)
        width: s
        height: s
        x: pos.x - s / 2
        y: pos.y - s / 2
        z: 8
        rotation: Number(p.track) || 0
        transformOrigin: Item.Center

        Canvas {
          anchors.fill: parent
          onPaint: {
            var ctx = getContext("2d");
            ctx.clearRect(0, 0, width, height);
            ctx.fillStyle = "#e8b84a";
            ctx.beginPath();
            ctx.moveTo(width * 0.5, 0);
            ctx.lineTo(width * 0.12, height);
            ctx.lineTo(width * 0.5, height * 0.68);
            ctx.lineTo(width * 0.88, height);
            ctx.closePath();
            ctx.fill();
          }
          Component.onCompleted: requestPaint()
        }

        MouseArea {
          anchors.fill: parent
          anchors.margins: -4
          hoverEnabled: true
          cursorShape: Qt.PointingHandCursor
          onEntered: root.hoveredPlane = acItem.index
          onExited: {
            if (root.hoveredPlane === acItem.index)
              root.hoveredPlane = -1;
          }
          onClicked: {
            var cs = (acItem.p.callsign || "").trim();
            if (cs)
              root.openLink("https://flightaware.com/live/flight/" + encodeURIComponent(cs));
          }
        }
      }
    }

    // —— Wind particle flow (nullschool-style) ——
    Canvas {
      id: windFlow
      anchors.fill: parent
      z: 6
      visible: root.showWind
      contextType: "2d"
      renderStrategy: Canvas.Cooperative
      property var particles: []
      readonly property int count: 520
      readonly property int trail: 9

      function wrapLon(lon) {
        lon = lon % 360;
        if (lon < -180)
          lon += 360;
        if (lon > 180)
          lon -= 360;
        return lon;
      }

      function spawnOne() {
        var lat = Math.random() * 140 - 70;
        var lon = Math.random() * 360 - 180;
        return {
          lat: lat,
          lon: lon,
          age: 0,
          life: 50 + Math.floor(Math.random() * 90),
          hist: [[lat, lon]]
        };
      }

      function resetParticles() {
        var next = [];
        for (var i = 0; i < count; i++)
          next.push(spawnOne());
        particles = next;
      }

      function sample(lat, lon) {
        var g = root.windGrid;
        if (!g || !g.u || !g.nlat)
          return null;
        var nlat = g.nlat, nlon = g.nlon;
        var fi = (lat - g.lat0) / g.dlat;
        var fj = (lon - g.lon0) / g.dlon;
        if (fi < 0 || fi >= nlat - 1)
          return null;
        while (fj < 0)
          fj += nlon;
        fj = fj % nlon;
        var i0 = Math.floor(fi);
        var j0 = Math.floor(fj);
        var ti = fi - i0;
        var tj = fj - j0;
        var i1 = Math.min(i0 + 1, nlat - 1);
        var j1 = (j0 + 1) % nlon;
        function at(ii, jj, key) {
          return Number(g[key][ii * nlon + jj]) || 0;
        }
        var u = at(i0, j0, "u") * (1 - ti) * (1 - tj) + at(i1, j0, "u") * ti * (1 - tj) + at(i0, j1, "u") * (1 - ti) * tj + at(i1, j1, "u") * ti * tj;
        var v = at(i0, j0, "v") * (1 - ti) * (1 - tj) + at(i1, j0, "v") * ti * (1 - tj) + at(i0, j1, "v") * (1 - ti) * tj + at(i1, j1, "v") * ti * tj;
        return {
          u: u,
          v: v,
          s: Math.sqrt(u * u + v * v)
        };
      }

      function step(dt) {
        var pts = particles;
        if (!pts || !pts.length) {
          resetParticles();
          pts = particles;
        }
        var k = 0.55; // visual exaggeration (deg per m/s per second)
        for (var i = 0; i < pts.length; i++) {
          var p = pts[i];
          p.age++;
          if (p.age > p.life || p.lat > 78 || p.lat < -78) {
            pts[i] = spawnOne();
            continue;
          }
          var uv = sample(p.lat, p.lon);
          if (!uv || uv.s < 0.4) {
            pts[i] = spawnOne();
            continue;
          }
          var clat = Math.max(0.2, Math.cos(p.lat * Math.PI / 180));
          p.lat += uv.v * dt * k;
          p.lon = wrapLon(p.lon + uv.u * dt * k / clat);
          p.spd = uv.s;
          p.hist.push([p.lat, p.lon]);
          if (p.hist.length > trail)
            p.hist.shift();
        }
      }

      onPaint: {
        var ctx = getContext("2d");
        ctx.clearRect(0, 0, width, height);
        if (!root.showWind)
          return;
        ctx.lineCap = "round";
        ctx.lineJoin = "round";
        ctx.globalCompositeOperation = "lighter";
        var pts = particles;
        for (var i = 0; i < pts.length; i++) {
          var p = pts[i];
          var hist = p.hist;
          if (!hist || hist.length < 2)
            continue;
          var spd = p.spd || 0;
          var t = Math.min(1, spd / 18);
          var r = Math.round(90 + 165 * t);
          var gcol = Math.round(210 - 40 * t);
          var b = Math.round(255 - 180 * t);
          ctx.strokeStyle = "rgba(" + r + "," + gcol + "," + b + "," + (0.18 + 0.45 * t) + ")";
          ctx.lineWidth = Math.max(1.1, (1.1 + t * 1.6) * widgetScale);
          ctx.beginPath();
          var started = false;
          var lastOn = false;
          for (var h = 0; h < hist.length; h++) {
            var pos = root.pinPos(hist[h][0], hist[h][1]);
            var on = pos.z > 0.08 && root.inViewPos(pos);
            if (on) {
              if (!started || !lastOn)
                ctx.moveTo(pos.x, pos.y);
              else
                ctx.lineTo(pos.x, pos.y);
              started = true;
            }
            lastOn = on;
          }
          if (started)
            ctx.stroke();
        }
        ctx.globalCompositeOperation = "source-over";
      }

      Component.onCompleted: resetParticles()
      onVisibleChanged: {
        if (visible)
          resetParticles();
      }
    }

    Timer {
      interval: 33
      running: root.showWind && !!root.windGrid
      repeat: true
      onTriggered: {
        windFlow.step(interval / 1000);
        windFlow.requestPaint();
      }
    }

    // Layer toggles
    Flow {
      id: layerBar
      anchors.horizontalCenter: parent.horizontalCenter
      anchors.bottom: parent.bottom
      anchors.bottomMargin: Math.round(8 * widgetScale)
      width: Math.round(parent.width * 0.92)
      spacing: Math.round(6 * widgetScale)
      z: 30

      Repeater {
        model: [
          {
            "key": "news",
            "label": "News",
            "on": root.showNews
          },
          {
            "key": "iss",
            "label": "ISS",
            "on": root.showIss
          },
          {
            "key": "quakes",
            "label": "Quakes",
            "on": root.showQuakes
          },
          {
            "key": "adsb",
            "label": "ADS-B",
            "on": root.showAdsb
          },
          {
            "key": "wind",
            "label": "Wind",
            "on": root.showWind
          },
          {
            "key": "rain",
            "label": "Rain",
            "on": root.showRain
          },
          {
            "key": "ocean",
            "label": "Ocean",
            "on": root.showOcean
          }
        ]

        delegate: Rectangle {
          required property var modelData
          width: layerTxt.implicitWidth + Math.round(14 * widgetScale)
          height: Math.round(24 * widgetScale)
          radius: height / 2
          color: modelData.on ? Color.mPrimary : Color.mSurface
          opacity: 0.92
          border.color: Color.mPrimary
          border.width: 1

          NText {
            id: layerTxt
            anchors.centerIn: parent
            text: modelData.label
            color: modelData.on ? Color.mOnPrimary : Color.mPrimary
            pointSize: Style.fontSizeXS * widgetScale
          }

          MouseArea {
            anchors.fill: parent
            cursorShape: Qt.PointingHandCursor
            onClicked: root.toggleLayer(modelData.key)
          }
        }
      }
    }

    // ISS / quake / plane callouts (share space with news callout priority)
    Rectangle {
      id: layerTip
      visible: (root.hoveredIss || root.hoveredQuake >= 0 || root.hoveredPlane >= 0) && root.hoveredPin < 0
      z: 20
      readonly property string tipText: {
        if (root.hoveredIss)
          return "ISS · " + root.issStatus;
        if (root.hoveredQuake >= 0 && root.hoveredQuake < root.quakes.length) {
          var q = root.quakes[root.hoveredQuake];
          return "M" + q.mag + " · " + (q.place || "");
        }
        if (root.hoveredPlane >= 0 && root.hoveredPlane < root.planes.length) {
          var p = root.planes[root.hoveredPlane];
          return ((p.callsign || "?").trim()) + " · " + p.dist_km + " km";
        }
        return "";
      }
      width: Math.round(Math.min(280 * widgetScale, tipLabel.implicitWidth + 20 * widgetScale))
      height: Math.round(28 * widgetScale)
      anchors.horizontalCenter: parent.horizontalCenter
      anchors.bottom: layerBar.top
      anchors.bottomMargin: Math.round(6 * widgetScale)
      radius: Style.radiusS
      color: Color.mSurface
      border.color: Color.mPrimary
      border.width: 1
      opacity: 0.95

      NText {
        id: tipLabel
        anchors.centerIn: parent
        text: layerTip.tipText
        color: Color.mOnSurface
        pointSize: Style.fontSizeXS * widgetScale
        elide: Text.ElideRight
        width: parent.width - Math.round(12 * widgetScale)
        horizontalAlignment: Text.AlignHCenter
      }
    }

    Rectangle {
      id: callout
      visible: root.showNews && root.hoveredPin >= 0 && root.hoveredPin < root.pins.length
      z: 8
      readonly property var p: visible ? root.pins[root.hoveredPin] : ({})
      readonly property var pos: visible ? root.pinPos(p.lat, p.lon) : ({
          x: 0,
          y: 0
        })

      width: Math.round(260 * widgetScale)
      height: calloutCol.implicitHeight + Math.round(16 * widgetScale)
      x: Math.max(0, Math.min(globeBox.width - width, pos.x - width / 2))
      y: Math.max(0, pos.y - height - Math.round(18 * widgetScale))
      radius: Style.radiusS
      color: Color.mSurface
      border.color: Color.mPrimary
      border.width: 1
      opacity: 0.96

      ColumnLayout {
        id: calloutCol
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.verticalCenter: parent.verticalCenter
        anchors.margins: Math.round(8 * widgetScale)
        spacing: 2

        NText {
          text: (callout.p.place || "") + (callout.p.label ? (" · " + callout.p.label) : "")
          color: Color.mPrimary
          pointSize: Style.fontSizeXS * widgetScale
          Layout.fillWidth: true
          elide: Text.ElideRight
        }

        NText {
          visible: root.localTimeLine(callout.p) !== ""
          text: root.localTimeLine(callout.p)
          color: Color.mTertiary
          font.family: Settings.data.ui.fontFixed
          pointSize: Style.fontSizeXS * widgetScale
          Layout.fillWidth: true
          elide: Text.ElideRight
        }

        NText {
          text: callout.p.title || ""
          color: Color.mOnSurface
          pointSize: Style.fontSizeS * widgetScale
          Layout.fillWidth: true
          wrapMode: Text.WordWrap
          maximumLineCount: 4
          elide: Text.ElideRight
        }

        NText {
          visible: !!(callout.p.age)
          text: callout.p.age || ""
          color: Color.mOnSurfaceVariant
          font.family: Settings.data.ui.fontFixed
          pointSize: Style.fontSizeXS * widgetScale
        }
      }
    }
  }
}
