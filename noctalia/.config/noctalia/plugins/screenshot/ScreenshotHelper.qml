import QtQuick
import Quickshell
import Quickshell.Io
import qs.Commons
import qs.Services.UI
import qs.Services.Compositor

Item {
    id: root

    property var pluginApi: null

    Process {
        id: screenshotProcess
        onExited: code => {
            if (code === 0) {
                ToastService.showNotice(pluginApi?.tr("notification.title"), pluginApi?.tr("notification.success"), "camera", 3000);
            }
        }
    }

    function takeScreenshot(mode) {
        if (screenshotProcess.running) return false;

        var args = [];
        if (CompositorService.isHyprland) {
            if (mode === "active-window") {
                args = ["hyprshot", "-m", "window", "-m", "active", "--clipboard-only", "--silent"];
            } else if (mode === "active-screen") {
                args = ["hyprshot", "-m", "output", "-m", "active", "--clipboard-only", "--silent"];
            } else {
                args = ["hyprshot", "--freeze", "--clipboard-only", "--mode", mode, "--silent"];
            }
        } else if (CompositorService.isNiri) {
            args = ["niri", "msg", "action", "screenshot"];
        } else if (CompositorService.isSway) {
            if (mode === "screen" || mode === "fullscreen" || mode === "active-screen") {
                args = ["grimshot", "copy", "output"];
            } else if (mode === "window" || mode === "active-window") {
                args = ["grimshot", "copy", "active"];
            } else {
                args = ["grimshot", "copy", "area"];
            }
        } else {
            ToastService.showError(pluginApi?.tr("notification.title"), pluginApi?.tr("notification.unsupported-compositor"), 3000);
            return false;
        }

        screenshotProcess.command = args;
        screenshotProcess.running = true;
        return true;
    }
}
