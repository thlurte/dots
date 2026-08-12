import QtQuick
import Quickshell
import Quickshell.Io
import qs.Commons

Item {
  id: root
  property var pluginApi: null

  // ─── Settings ───────────────────────────────────────────────────────────────
  property var cfg: pluginApi?.pluginSettings || ({})
  property var defaults: pluginApi?.manifest?.metadata?.defaultSettings || ({})

  readonly property string kubeconfigPath: cfg.kubeconfigPath ?? defaults.kubeconfigPath ?? ""
  readonly property int pollInterval: cfg.pollInterval ?? defaults.pollInterval ?? 60
  readonly property bool showErrorBadge: cfg.showErrorBadge ?? defaults.showErrorBadge ?? true
  readonly property string terminal: cfg.terminal ?? defaults.terminal ?? ""

  // ─── Shared State ───────────────────────────────────────────────────────────
  property var contexts: []
  property string activeContext: ""
  property var namespaces: []
  property string activeNamespace: ""

  property var pods: []
  property var deployments: []
  property var statefulsets: []
  property var daemonsets: []
  property var services: []
  property var ingresses: []
  property var configmaps: []
  property var secrets: []

  property bool loading: false
  property bool hasError: false
  property bool hasCriticalPod: false

  // ─── IPC ────────────────────────────────────────────────────────────────────
  IpcHandler {
    target: "plugin:kubectl-ctx"

    function toggle() {
      if (pluginApi) {
        pluginApi.withCurrentScreen(screen => {
          pluginApi.togglePanel(screen);
        });
      }
    }

    function refresh() {
      root.fetchContexts();
    }
  }

  // ─── Init ───────────────────────────────────────────────────────────────────
  Component.onCompleted: {
    Logger.i("KubectlCtx", "Plugin loaded");
    fetchContexts();
  }

  onPluginApiChanged: {
    if (pluginApi) fetchContexts();
  }

  // ─── Poll timer ─────────────────────────────────────────────────────────────
  Timer {
    id: pollTimer
    interval: root.pollInterval * 1000
    repeat: true
    running: root.pluginApi !== null
    onTriggered: root.fetchResources()
  }

  // ─── kubectl helper ─────────────────────────────────────────────────────────
  function kubectlArgs(args) {
    // Always prepend ~/.krew/bin to PATH for OIDC and other krew plugins
    var currentPath = Quickshell.env("PATH") ?? "/usr/bin:/bin";
    var home = Quickshell.env("HOME") ?? "/root";
    var krewBin = home + "/.krew/bin";
    var base = ["env", "PATH=" + krewBin + ":" + currentPath, "kubectl"];
    if (root.kubeconfigPath && root.kubeconfigPath !== "") {
      base = base.concat(["--kubeconfig", root.kubeconfigPath]);
    }
    return base.concat(args);
  }

  // ─── Processes ───────────────────────────────────────────────────────────────

  Process {
    id: getContextsProc
    property string output: ""

    stdout: SplitParser {
      onRead: line => getContextsProc.output += line + "\n"
    }

    onExited: exitCode => {
      // code 15 = SIGTERM (killed by running=false restart) — not a real error
      if (exitCode === 15) {
        getContextsProc.output = "";
        return;
      }
      if (exitCode !== 0) {
        Logger.i("KubectlCtx", "get-contexts failed, code: " + exitCode);
        root.hasError = true;
        root.loading = false;
        return;
      }
      var lines = getContextsProc.output.trim().split("\n");
      var ctxList = [];
      var current = "";
      for (var i = 0; i < lines.length; i++) {
        var line = lines[i];
        if (line.trim() === "") continue;
        var cols = line.trim().split(/\s+/);
        var isCurrent = cols[0] === "*";
        var name = isCurrent ? cols[1] : cols[0];
        ctxList.push(name);
        if (isCurrent) current = name;
      }
      root.contexts = ctxList;
      if (current !== "") root.activeContext = current;
      else if (ctxList.length > 0 && root.activeContext === "") root.activeContext = ctxList[0];
      Logger.i("KubectlCtx", "Contexts: " + ctxList.length + ", active: " + root.activeContext);
      getContextsProc.output = "";
      fetchNamespaces();
    }
  }

  Process {
    id: getNamespacesProc
    property string output: ""

    stdout: SplitParser {
      onRead: line => getNamespacesProc.output += line + "\n"
    }

    onExited: exitCode => {
      if (exitCode !== 0 && getNamespacesProc.output.trim() === "") {
        Logger.i("KubectlCtx", "get-namespaces failed, code: " + exitCode + " (cluster unreachable?)");
        root.namespaces = [];
        root.activeNamespace = "";
        root.loading = false;
        root.hasError = true;
        return;
      }
      var lines = getNamespacesProc.output.trim().split("\n");
      var nsList = [];
      for (var i = 0; i < lines.length; i++) {
        var line = lines[i].trim();
        if (line === "" || line.startsWith("NAME")) continue;
        var cols = line.split(/\s+/);
        nsList.push(cols[0]);
      }
      root.namespaces = nsList;
      if (root.activeNamespace === "" || nsList.indexOf(root.activeNamespace) === -1) {
        root.activeNamespace = nsList.length > 0 ? nsList[0] : "";
      }
      Logger.i("KubectlCtx", "Namespaces: " + nsList.length);
      getNamespacesProc.output = "";
      fetchResources();
    }
  }

  Process {
    id: podsProc
    property string output: ""
    stdout: SplitParser { onRead: line => podsProc.output += line + "\n" }
    onExited: exitCode => {
      if (exitCode === 0) {
        root.pods = parsePods(podsProc.output);
        root.hasCriticalPod = root.pods.some(function(p) {
          return p.status === "Error" || p.status === "CrashLoopBackOff" || p.status === "OOMKilled";
        });
      } else {
        root.pods = [];
      }
      podsProc.output = "";
      root.loading = false;
    }
  }

  Process {
    id: deploymentsProc
    property string output: ""
    stdout: SplitParser { onRead: line => deploymentsProc.output += line + "\n" }
    onExited: exitCode => {
      root.deployments = exitCode === 0 ? parseReadyResources(deploymentsProc.output) : [];
      deploymentsProc.output = "";
    }
  }

  Process {
    id: statefulsetsProc
    property string output: ""
    stdout: SplitParser { onRead: line => statefulsetsProc.output += line + "\n" }
    onExited: exitCode => {
      root.statefulsets = exitCode === 0 ? parseReadyResources(statefulsetsProc.output) : [];
      statefulsetsProc.output = "";
    }
  }

  Process {
    id: daemonsetsProc
    property string output: ""
    stdout: SplitParser { onRead: line => daemonsetsProc.output += line + "\n" }
    onExited: exitCode => {
      root.daemonsets = exitCode === 0 ? parseDaemonsets(daemonsetsProc.output) : [];
      daemonsetsProc.output = "";
    }
  }

  Process {
    id: servicesProc
    property string output: ""
    stdout: SplitParser { onRead: line => servicesProc.output += line + "\n" }
    onExited: exitCode => {
      root.services = exitCode === 0 ? parseServices(servicesProc.output) : [];
      servicesProc.output = "";
    }
  }

  Process {
    id: ingressesProc
    property string output: ""
    stdout: SplitParser { onRead: line => ingressesProc.output += line + "\n" }
    onExited: exitCode => {
      root.ingresses = exitCode === 0 ? parseIngresses(ingressesProc.output) : [];
      ingressesProc.output = "";
    }
  }

  Process {
    id: configmapsProc
    property string output: ""
    stdout: SplitParser { onRead: line => configmapsProc.output += line + "\n" }
    onExited: exitCode => {
      root.configmaps = exitCode === 0 ? parseSimple(configmapsProc.output) : [];
      configmapsProc.output = "";
    }
  }

  Process {
    id: secretsProc
    property string output: ""
    stdout: SplitParser { onRead: line => secretsProc.output += line + "\n" }
    onExited: exitCode => {
      root.secrets = exitCode === 0 ? parseSecrets(secretsProc.output) : [];
      secretsProc.output = "";
    }
  }

  Process {
    id: switchContextProc
    onExited: exitCode => {
      if (exitCode === 0) {
        Logger.i("KubectlCtx", "Context switched to: " + root.activeContext);
        root.activeNamespace = "";
        fetchNamespaces();
      } else {
        Logger.i("KubectlCtx", "Context switch failed");
        root.hasError = true;
      }
    }
  }

  Process {
    id: switchNamespaceProc
    onExited: exitCode => {
      if (exitCode === 0) {
        Logger.i("KubectlCtx", "Namespace switched to: " + root.activeNamespace);
        fetchResources();
      }
    }
  }

  Process {
    id: deleteProc
    onExited: exitCode => {
      if (exitCode === 0) {
        Logger.i("KubectlCtx", "Resource deleted");
        fetchResources();
      } else {
        Logger.i("KubectlCtx", "Delete failed");
      }
    }
  }

  Process {
    id: restartProc
    onExited: exitCode => {
      if (exitCode === 0) {
        Logger.i("KubectlCtx", "Rollout restart triggered");
        Qt.callLater(fetchResources);
      }
    }
  }

  Process { id: copyProc }
  Process { id: terminalProc }

  // ─── Public functions ────────────────────────────────────────────────────────
  function fetchContexts() {
    root.loading = true;
    root.hasError = false;
    getContextsProc.command = kubectlArgs(["config", "get-contexts", "--no-headers"]);
    getContextsProc.running = false;
    getContextsProc.running = true;
  }

  function fetchNamespaces() {
    if (root.activeContext === "") return;
    getNamespacesProc.command = kubectlArgs(["get", "namespaces", "--no-headers",
      "--context", root.activeContext]);
    getNamespacesProc.running = false;
    getNamespacesProc.running = true;
  }

  function fetchResources() {
    if (root.activeContext === "" || root.activeNamespace === "") return;
    root.hasError = false;
    root.loading = true;
    var ctx = ["--context", root.activeContext, "-n", root.activeNamespace, "--no-headers"];

    podsProc.command = kubectlArgs(["get", "pods"].concat(ctx));
    deploymentsProc.command = kubectlArgs(["get", "deployments"].concat(ctx));
    statefulsetsProc.command = kubectlArgs(["get", "statefulsets"].concat(ctx));
    daemonsetsProc.command = kubectlArgs(["get", "daemonsets"].concat(ctx));
    servicesProc.command = kubectlArgs(["get", "services"].concat(ctx));
    ingressesProc.command = kubectlArgs(["get", "ingresses"].concat(ctx));
    configmapsProc.command = kubectlArgs(["get", "configmaps"].concat(ctx));
    secretsProc.command = kubectlArgs(["get", "secrets"].concat(ctx));

    [podsProc, deploymentsProc, statefulsetsProc, daemonsetsProc,
     servicesProc, ingressesProc, configmapsProc, secretsProc].forEach(function(p) {
      p.running = false;
      p.running = true;
    });
  }

  function switchContext(name) {
    root.activeContext = name;
    root.activeNamespace = "";
    switchContextProc.command = kubectlArgs(["config", "use-context", name]);
    switchContextProc.running = false;
    switchContextProc.running = true;
  }

  function switchNamespace(name) {
    root.activeNamespace = name;
    switchNamespaceProc.command = kubectlArgs([
      "config", "set-context", "--current", "--namespace", name,
      "--context", root.activeContext
    ]);
    switchNamespaceProc.running = false;
    switchNamespaceProc.running = true;
  }

  function deleteResource(kind, name) {
    deleteProc.command = kubectlArgs([
      "delete", kind, name,
      "--context", root.activeContext,
      "-n", root.activeNamespace,
      "--wait=false"
    ]);
    deleteProc.running = false;
    deleteProc.running = true;
  }

  function restartResource(kind, name) {
    restartProc.command = kubectlArgs([
      "rollout", "restart", kind + "/" + name,
      "--context", root.activeContext,
      "-n", root.activeNamespace
    ]);
    restartProc.running = false;
    restartProc.running = true;
  }

  function copyToClipboard(text) {
    copyProc.command = ["wl-copy", text];
    copyProc.running = false;
    copyProc.running = true;
  }

  function openTerminal(args) {
    var term = root.terminal !== "" ? root.terminal : (Quickshell.env("TERMINAL") ?? "xterm");
    var kubectlCmd = kubectlArgs(["--context", root.activeContext, "-n", root.activeNamespace].concat(args));
    // wrap in bash so the window stays open after kubectl exits
    var script = kubectlCmd.map(a => "'" + a.replace(/'/g, "'\\''") + "'").join(" ");
    script += "; echo; echo '--- Press Enter to close ---'; read";
    var cmd = [term, "-e", "bash", "-c", script];
    terminalProc.command = cmd;
    terminalProc.running = false;
    terminalProc.running = true;
  }

  // ─── Parsers ─────────────────────────────────────────────────────────────────
  function parsePods(output) {
    var result = [];
    var lines = output.trim().split("\n");
    for (var i = 0; i < lines.length; i++) {
      var line = lines[i].trim();
      if (line === "") continue;
      var cols = line.split(/\s+/);
      if (cols.length < 3) continue;
      result.push({ name: cols[0], ready: cols[1], status: cols[2], restarts: cols[3] ?? "0" });
    }
    return result;
  }

  function parseReadyResources(output) {
    var result = [];
    var lines = output.trim().split("\n");
    for (var i = 0; i < lines.length; i++) {
      var line = lines[i].trim();
      if (line === "") continue;
      var cols = line.split(/\s+/);
      if (cols.length < 2) continue;
      result.push({ name: cols[0], ready: cols[1] ?? "-", status: "" });
    }
    return result;
  }

  function parseDaemonsets(output) {
    var result = [];
    var lines = output.trim().split("\n");
    for (var i = 0; i < lines.length; i++) {
      var line = lines[i].trim();
      if (line === "") continue;
      var cols = line.split(/\s+/);
      if (cols.length < 4) continue;
      result.push({ name: cols[0], ready: cols[3] + "/" + cols[1], status: "" });
    }
    return result;
  }

  function parseServices(output) {
    var result = [];
    var lines = output.trim().split("\n");
    for (var i = 0; i < lines.length; i++) {
      var line = lines[i].trim();
      if (line === "") continue;
      var cols = line.split(/\s+/);
      if (cols.length < 2) continue;
      // cols: NAME TYPE CLUSTER-IP EXTERNAL-IP PORT(S) AGE
      result.push({ name: cols[0], ready: cols[1] ?? "", status: "" });
    }
    return result;
  }

  function parseIngresses(output) {
    var result = [];
    var lines = output.trim().split("\n");
    for (var i = 0; i < lines.length; i++) {
      var line = lines[i].trim();
      if (line === "") continue;
      var cols = line.split(/\s+/);
      if (cols.length < 2) continue;
      // cols: NAME CLASS HOSTS ADDRESS PORTS AGE
      result.push({ name: cols[0], ready: cols[2] ?? cols[1] ?? "", status: "" });
    }
    return result;
  }

  function parseSimple(output) {
    var result = [];
    var lines = output.trim().split("\n");
    for (var i = 0; i < lines.length; i++) {
      var line = lines[i].trim();
      if (line === "") continue;
      var cols = line.split(/\s+/);
      result.push({ name: cols[0], ready: "", status: "" });
    }
    return result;
  }

  function parseSecrets(output) {
    var result = [];
    var lines = output.trim().split("\n");
    for (var i = 0; i < lines.length; i++) {
      var line = lines[i].trim();
      if (line === "") continue;
      var cols = line.split(/\s+/);
      if (cols.length < 2) continue;
      result.push({ name: cols[0], ready: cols[1], status: "" });
    }
    return result;
  }
}
