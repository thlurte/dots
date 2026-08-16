import QtQuick
import Quickshell.Io
import qs.Commons

QtObject {
  id: root

  required property string name
  required property string address

  property int intervalMs: 5000
  property int thresholdGood: 20
  property int thresholdWarning: 70

  property var samples: []      // [{ts: epoch-ms, rtt: int-ms}]
  property int lastRtt: -1      // -1 == no data / timed out
  property bool timedOut: false

  property real avg10m: -1
  property real avg30m: -1
  property real avg60m: -1

  readonly property string status: {
    if (timedOut)
      return "critical";
    if (samples.length === 0)
      return "unknown";
    const a = avg10m >= 0 ? avg10m : (avg30m >= 0 ? avg30m : avg60m);
    return rttToStatus(a);
  }

  function rttToStatus(rtt) {
    if (rtt < 0)
      return "unknown";
    if (rtt < root.thresholdGood)
      return "good";
    if (rtt < root.thresholdWarning)
      return "warning";
    return "critical";
  }

  signal polled

  function samplesInWindow(minutes) {
    const cutoff = Date.now() - minutes * 60000;
    return samples.filter(s => s.ts >= cutoff);
  }

  function _avg(minutes) {
    const win = samplesInWindow(minutes);
    if (win.length === 0)
      return -1;
    return win.reduce((acc, s) => acc + s.rtt, 0) / win.length;
  }

  function _commit(rtt) {
    const now = Date.now();
    const cutoff = now - 3900000;   // 65-minute rolling window
    root.samples = root.samples.filter(s => s.ts >= cutoff).concat([
      {
        ts: now,
        rtt: rtt
      }
    ]);
    root.lastRtt = rtt;
    root.timedOut = false;
  }

  function _refreshAvgs() {
    root.avg10m = root._avg(10);
    root.avg30m = root._avg(30);
    root.avg60m = root._avg(60);
  }

  property int _pendingRtt: -1

  property var _proc: Process {
    id: proc
    command: ["ping", "-n", "-c", "1", "-W", String(Math.max(1, Math.floor(intervalMs / 1000) - 1)), root.address]
    running: false

    stdout: SplitParser {
      splitMarker: "\n"
      onRead: function (line) {
        const m = line.match(/time[=<](\d+(?:\.\d+)?)/);
        if (m)
          root._pendingRtt = Math.round(parseFloat(m[1]));
      }
    }

    onExited: function () {
      if (root._pendingRtt >= 0) {
        root._commit(root._pendingRtt);
      } else {
        root.timedOut = true;
        root.lastRtt = -1;
      }
      root._pendingRtt = -1;
      root._refreshAvgs();
      root.polled();
    }
  }

  property var _timer: Timer {
    interval: root.intervalMs
    running: true
    repeat: true
    triggeredOnStart: true
    onTriggered: if (!proc.running)
      proc.running = true
  }
}
