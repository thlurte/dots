import QtQuick
import Quickshell
import Quickshell.Io
import qs.Commons
import qs.Services.UI

Item {
  id: root
  property var pluginApi: null

  // Settings access
  property var cfg: pluginApi?.pluginSettings || ({})
  property var defaults: pluginApi?.manifest?.metadata?.defaultSettings || ({})

  // Shared state
  property var hostList: []
  property var activeSessions: []
  property int activeCount: 0
  property bool configLoaded: false
  property list<var> sortedHosts: []

  // Terminal detection (netbird pattern)
  property string detectedTerminal: ""
  property bool terminalDetected: detectedTerminal !== ""
  property var terminalCandidates: ["ghostty", "alacritty", "kitty", "foot", "wezterm", "konsole", "gnome-terminal", "xfce4-terminal", "xterm"]
  property int terminalCheckIndex: 0

  // Effective terminal command
  readonly property string terminalCommand: {
    var override = cfg.terminalCommand ?? defaults.terminalCommand ?? ""
    return override !== "" ? override : detectedTerminal
  }

  Component.onCompleted: {
    Logger.i("SSH Sessions", "Plugin loaded")
    detectTerminal()
    refreshSessions()
  }

  // ======== SSH Config watcher + reader ========
  FileView {
    id: sshConfigWatcher
    path: Quickshell.env("HOME") + "/.ssh/config"
    watchChanges: true
    onLoaded: root.loadSshConfig()
    onFileChanged: {
      Logger.d("SSH Sessions", "SSH config changed, reloading...")
      root.loadSshConfig()
    }
  }

  Process {
    id: configReaderProcess
    stderr: StdioCollector {}
    stdout: StdioCollector {
      onStreamFinished: {
        root.parseSshConfig(this.text)
      }
    }
  }

  // ======== Session poll timer ========
  Timer {
    interval: (root.cfg.pollInterval ?? root.defaults.pollInterval ?? 10) * 1000
    running: true
    repeat: true
    onTriggered: root.refreshSessions()
  }

  // ======== IPC handler ========
  IpcHandler {
    target: "plugin:ssh-sessions"

    function refresh() {
      Logger.d("SSH Sessions", "Refreshing through IPC...")
      root.fullRefresh()
    }

    function toggle() {
      if (root.pluginApi) {
        root.pluginApi.withCurrentScreen(screen => {
          root.pluginApi.togglePanel(screen)
        })
      }
    }
  }

  // ======== Terminal detection (netbird pattern) ========
  Process {
    id: terminalDetectProcess
    stdout: StdioCollector {}
    stderr: StdioCollector {}
    onExited: (exitCode, exitStatus) => {
      if (exitCode === 0) {
        root.detectedTerminal = root.terminalCandidates[root.terminalCheckIndex]
        Logger.i("SSH Sessions", "Auto-detected terminal: " + root.detectedTerminal)
      } else {
        root.terminalCheckIndex++
        if (root.terminalCheckIndex < root.terminalCandidates.length) {
          terminalDetectProcess.command = ["which", root.terminalCandidates[root.terminalCheckIndex]]
          terminalDetectProcess.running = true
        } else {
          Logger.w("SSH Sessions", "No terminal emulator found")
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

  // ======== Session detection via pgrep ========
  Process {
    id: sessionProcess
    stderr: StdioCollector {}
    onExited: (exitCode, exitStatus) => {
      // exitCode 1 means no matches (normal when no SSH sessions)
    }
    stdout: StdioCollector {
      onStreamFinished: {
        var output = this.text.trim()
        var sessions = []
        var seenHosts = {}
        if (output) {
          var lines = output.split("\n")
          for (var i = 0; i < lines.length; i++) {
            var line = lines[i].trim()
            // Filter out non-client SSH processes
            if (line.indexOf("sshd") !== -1) continue
            if (line.indexOf("ssh-agent") !== -1) continue
            if (line.indexOf("ssh-add") !== -1) continue
            if (line.indexOf("ssh-keygen") !== -1) continue
            if (line.indexOf("ssh-copy-id") !== -1) continue
            if (line.indexOf("autossh") !== -1) continue
            if (line.indexOf("pgrep") !== -1) continue
            // Filter out terminal launcher lines (e.g. "ghostty -e ssh host")
            if (line.indexOf("-e ssh") !== -1) continue
            // Filter out ProxyJump/proxy sub-processes (ssh -W, ssh -l user -W)
            if (line.indexOf(" -W ") !== -1) continue

            // Extract the target host from the ssh command
            // Typical: "12345 ssh user@host" or "12345 ssh -p 22 host"
            var parts = line.split(/\s+/)
            var sshIdx = -1
            for (var j = 0; j < parts.length; j++) {
              if (parts[j] === "ssh" || parts[j].endsWith("/ssh")) {
                sshIdx = j
                break
              }
            }
            if (sshIdx === -1) continue

            // Last non-flag argument after "ssh" is the target
            var target = ""
            for (var k = parts.length - 1; k > sshIdx; k--) {
              if (!parts[k].startsWith("-")) {
                target = parts[k]
                break
              }
            }
            if (!target) continue

            // Deduplicate by matched host
            var matched = root.findMatchingHost(target)
            var dedupeKey = matched || target
            if (seenHosts[dedupeKey]) continue
            seenHosts[dedupeKey] = true

            sessions.push({
              "target": target,
              "line": line,
              "matchedHost": matched
            })
          }
        }
        root.activeSessions = sessions
        root.activeCount = sessions.length
        root.updateSortedHosts()
        Logger.d("SSH Sessions", "Active sessions: " + root.activeCount)
      }
    }
  }

  function loadSshConfig() {
    configReaderProcess.command = ["cat", Quickshell.env("HOME") + "/.ssh/config"]
    configReaderProcess.running = true
  }

  function refreshSessions() {
    sessionProcess.command = ["pgrep", "-af", "ssh "]
    sessionProcess.running = true
  }

  function fullRefresh() {
    loadSshConfig()
    refreshSessions()
  }

  // ======== SSH config parsing ========
  function parseSshConfig(text) {
    if (!text) text = ""
    if (!text) {
      Logger.w("SSH Sessions", "No SSH config found or empty")
      root.hostList = []
      root.configLoaded = true
      return
    }

    var hosts = []
    var current = null
    var lines = text.split("\n")

    for (var i = 0; i < lines.length; i++) {
      var line = lines[i].trim()
      if (!line || line.startsWith("#")) continue

      if (line.match(/^Host\s+/i)) {
        var hostName = line.replace(/^Host\s+/i, "").trim()
        // Skip wildcard hosts
        if (hostName === "*" || hostName.indexOf("*") !== -1) {
          current = null
          continue
        }
        current = {
          "name": hostName,
          "hostname": "",
          "user": "",
          "port": "",
          "proxyJump": "",
          "identityFile": ""
        }
        hosts.push(current)
      } else if (current) {
        var match
        if ((match = line.match(/^Hostname\s+(.+)/i))) {
          current.hostname = match[1].trim()
        } else if ((match = line.match(/^User\s+(.+)/i))) {
          current.user = match[1].trim()
        } else if ((match = line.match(/^Port\s+(.+)/i))) {
          current.port = match[1].trim()
        } else if ((match = line.match(/^ProxyJump\s+(.+)/i))) {
          current.proxyJump = match[1].trim()
        } else if ((match = line.match(/^IdentityFile\s+(.+)/i))) {
          current.identityFile = match[1].trim()
        }
      }
    }

    root.hostList = hosts
    root.configLoaded = true
    root.updateSortedHosts()
    Logger.i("SSH Sessions", "Parsed " + hosts.length + " hosts from SSH config")
  }

  // ======== Helper functions ========
  function findMatchingHost(target) {
    // Match target (e.g. "adria@165.227.160.74" or "api-prod") against hostList
    for (var i = 0; i < hostList.length; i++) {
      var host = hostList[i]
      if (target === host.name) return host.name
      if (target === host.hostname) return host.name
      if (host.user && target === host.user + "@" + host.hostname) return host.name
      if (host.user && target === host.user + "@" + host.name) return host.name
    }
    return ""
  }

  function isHostActive(hostName) {
    for (var i = 0; i < activeSessions.length; i++) {
      if (activeSessions[i].matchedHost === hostName) return true
    }
    return false
  }

  function connectToHost(hostName) {
    if (!terminalCommand) {
      Logger.w("SSH Sessions", "No terminal emulator configured")
      return
    }
    Logger.i("SSH Sessions", "Connecting to " + hostName + " via " + terminalCommand)
    Quickshell.execDetached([terminalCommand, "-e", "ssh", hostName])
  }

  function updateSortedHosts() {
    var showInactive = cfg.showInactiveHosts ?? defaults.showInactiveHosts ?? true
    var active = []
    var inactive = []
    var matchedNames = {}

    for (var i = 0; i < hostList.length; i++) {
      if (isHostActive(hostList[i].name)) {
        active.push({ host: hostList[i], isActive: true })
        matchedNames[hostList[i].name] = true
      } else if (showInactive) {
        inactive.push({ host: hostList[i], isActive: false })
      }
    }

    for (var j = 0; j < activeSessions.length; j++) {
      var s = activeSessions[j]
      if (!s.matchedHost && !matchedNames[s.target]) {
        active.push({
          host: { name: s.target, hostname: "", user: "", port: "", proxyJump: "", identityFile: "" },
          isActive: true
        })
        matchedNames[s.target] = true
      }
    }

    root.sortedHosts = active.concat(inactive)
  }

  function getHostDescription(host) {
    var desc = ""
    if (host.user) desc += host.user + "@"
    desc += host.hostname || host.name
    if (host.port && host.port !== "22") desc += ":" + host.port
    return desc
  }
}
