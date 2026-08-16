import QtQuick
import Quickshell
import Quickshell.Io
import qs.Commons
import qs.Services.UI

Item {
  id: root
  property var pluginApi: null

  property var cfg: pluginApi?.pluginSettings || ({})
  property var defaults: pluginApi?.manifest?.metadata?.defaultSettings || ({})

  // Shared state
  property var portList: []
  property int portCount: 0
  property list<var> sortedPorts: []

  // Terminal detection
  property string detectedTerminal: ""
  property var terminalCandidates: ["ghostty", "alacritty", "kitty", "foot", "wezterm", "konsole", "gnome-terminal", "xfce4-terminal", "xterm"]
  property int terminalCheckIndex: 0

  Component.onCompleted: {
    Logger.i("Port Monitor", "Plugin loaded")
    detectTerminal()
    refresh()
  }

  Process {
    id: terminalDetectProcess
    stdout: StdioCollector {}
    stderr: StdioCollector {}
    onExited: (exitCode, exitStatus) => {
      if (exitCode === 0) {
        root.detectedTerminal = root.terminalCandidates[root.terminalCheckIndex]
        Logger.i("Port Monitor", "Auto-detected terminal: " + root.detectedTerminal)
      } else {
        root.terminalCheckIndex++
        if (root.terminalCheckIndex < root.terminalCandidates.length) {
          terminalDetectProcess.command = ["which", root.terminalCandidates[root.terminalCheckIndex]]
          terminalDetectProcess.running = true
        } else {
          Logger.w("Port Monitor", "No terminal emulator found")
        }
      }
    }
  }

  function detectTerminal() {
    root.terminalCheckIndex = 0
    root.detectedTerminal = ""
    if (root.terminalCandidates.length > 0) {
      terminalDetectProcess.command = ["which", root.terminalCandidates[0]]
      terminalDetectProcess.running = true
    }
  }

  // Poll timer
  Timer {
    interval: (root.cfg.refreshInterval ?? root.defaults.refreshInterval ?? 5) * 1000
    running: true
    repeat: true
    onTriggered: root.refresh()
  }

  // IPC handler
  IpcHandler {
    target: "plugin:port-monitor"

    function refresh() {
      Logger.d("Port Monitor", "Refreshing through IPC...")
      root.refresh()
    }

    function toggle() {
      if (root.pluginApi) {
        root.pluginApi.withCurrentScreen(screen => {
          root.pluginApi.togglePanel(screen)
        })
      }
    }
  }

  // TCP scan
  Process {
    id: tcpProcess
    stderr: StdioCollector {}
    stdout: StdioCollector {
      onStreamFinished: {
        root.parseSsOutput(this.text, "TCP")
      }
    }
  }

  // UDP scan
  Process {
    id: udpProcess
    stderr: StdioCollector {}
    stdout: StdioCollector {
      onStreamFinished: {
        var udpPorts = root.parseSsLines(this.text, "UDP")
        // Merge TCP (from _tcpPorts) + UDP
        root.applyFiltersAndUpdate(root._tcpPorts.concat(udpPorts))
      }
    }
  }

  // Temporary TCP results
  property var _tcpPorts: []

  function refresh() {
    root._tcpPorts = []
    tcpProcess.command = ["ss", "-tlnp"]
    tcpProcess.running = true
  }

  function parseSsOutput(text, proto) {
    root._tcpPorts = parseSsLines(text, proto)
    // Chain: after TCP, run UDP
    udpProcess.command = ["ss", "-ulnp"]
    udpProcess.running = true
  }

  function parseSsLines(text, proto) {
    var ports = []
    if (!text) return ports

    var lines = text.trim().split("\n")
    // Skip header line
    for (var i = 1; i < lines.length; i++) {
      var line = lines[i].trim()
      if (!line) continue

      // Parse: State Recv-Q Send-Q LocalAddress:Port PeerAddress:Port Process
      var parts = line.split(/\s+/)
      if (parts.length < 5) continue

      // Extract local address:port
      var localAddr = parts[3]
      var lastColon = localAddr.lastIndexOf(":")
      if (lastColon === -1) continue

      var address = localAddr.substring(0, lastColon)
      var port = parseInt(localAddr.substring(lastColon + 1))
      if (isNaN(port)) continue

      // Clean up IPv6 brackets
      if (address.startsWith("[")) address = address.slice(1)
      if (address.endsWith("]")) address = address.slice(0, -1)

      // Extract process info if available
      var processName = ""
      var pid = ""
      var processMatch = line.match(/users:\(\("(.+?)",pid=(\d+)/)
      if (processMatch) {
        processName = processMatch[1]
        pid = processMatch[2]
      }

      ports.push({
        port: port,
        proto: proto,
        address: address,
        processName: processName,
        pid: pid
      })
    }

    return ports
  }

  function applyFiltersAndUpdate(allPorts) {
    var hideSystem = root.cfg.hideSystemPorts ?? root.defaults.hideSystemPorts ?? false
    var merged = allPorts

    if (hideSystem) {
      merged = merged.filter(function(p) { return p.port >= 1024 })
    }

    // Sort: user processes first (has PID), then system, then by port number
    merged.sort(function(a, b) {
      var aUser = a.pid ? 0 : 1
      var bUser = b.pid ? 0 : 1
      if (aUser !== bUser) return aUser - bUser
      return a.port - b.port
    })

    // Deduplicate by port+proto+address
    var seen = {}
    var unique = []
    for (var i = 0; i < merged.length; i++) {
      var key = merged[i].port + ":" + merged[i].proto + ":" + merged[i].address
      if (!seen[key]) {
        seen[key] = true
        unique.push(merged[i])
      }
    }

    root.portList = unique
    root.portCount = unique.length
    root.sortedPorts = unique
    Logger.d("Port Monitor", "Parsed " + root.portCount + " listening ports")
  }

  // Delayed refresh after kill to let the process terminate
  Timer {
    id: killRefreshTimer
    interval: 500
    repeat: false
    onTriggered: root.refresh()
  }

  function killProcess(pid) {
    if (!pid) return
    Logger.i("Port Monitor", "Killing PID " + pid)
    Quickshell.execDetached(["kill", pid])
    killRefreshTimer.start()
  }

  function killPortElevated(port, proto) {
    if (!detectedTerminal) {
      Logger.w("Port Monitor", "No terminal emulator configured")
      return
    }
    var portNum = parseInt(port)
    if (isNaN(portNum) || portNum < 1 || portNum > 65535) return
    var protoFlag = proto === "TCP" ? "tcp" : "udp"
    Logger.i("Port Monitor", "Opening terminal to kill port " + portNum + "/" + protoFlag)
    Quickshell.execDetached([detectedTerminal, "-e", "sh", "-c",
      "echo 'Killing process on port " + portNum + "/" + protoFlag + "...' && sudo fuser -k " + portNum + "/" + protoFlag + " && echo 'Done.' || echo 'Failed.'; read -n 1 -p \"Press any key to exit...\""])
  }

}
