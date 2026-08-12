import QtQuick
import Quickshell
import qs.Commons

Item {
  id: root

  property var pluginApi: null
  property var launcher: null
  property string name: "SSH"
  property bool handleSearch: true
  property string supportedLayouts: "list"
  property bool supportsAutoPaste: false
  property bool ignoreDensity: false
  property bool trackUsage: true

  property int maxResults: 50

  readonly property var mainInstance: pluginApi?.mainInstance

  function init() {}

  function onOpened() {}

  function handleCommand(searchText) {
    return searchText.startsWith(">ssh")
  }

  function commands() {
    return [{
      "name": pluginApi?.tr("launcher.name"),
      "description": pluginApi?.tr("launcher.description"),
      "icon": "terminal",
      "isTablerIcon": true,
      "isImage": false,
      "onActivate": function() {
        launcher.setSearchText(">ssh ")
      }
    }]
  }

  function getResults(searchText) {
    var hosts = mainInstance?.hostList ?? []
    if (hosts.length === 0) return []

    var trimmed = searchText.trim()
    var isCommandMode = trimmed.startsWith(">ssh")

    if (isCommandMode) {
      var query = trimmed.slice(4).trim()
      if (query.length > 0) {
        return doSearch(query, hosts)
      }
      return hosts.map(h => formatEntry(h))
    }

    if (!trimmed || trimmed.length < 2) return []
    return doSearch(trimmed, hosts)
  }

  function doSearch(query, hosts) {
    return FuzzySort.go(query, hosts, {
      limit: maxResults,
      keys: ["name", "hostname", "user"]
    }).map(r => formatEntry(r.obj, r.score))
  }

  function formatEntry(host, score) {
    var isActive = mainInstance?.isHostActive(host.name) ?? false
    return {
      "usageKey": "ssh:" + host.name,
      "name": host.name,
      "description": mainInstance?.getHostDescription(host) ?? host.hostname,
      "_score": (score !== undefined ? score : 0),
      "icon": "terminal",
      "isTablerIcon": true,
      "badgeIcon": isActive ? "circle-check" : "",
      "isImage": false,
      "hideIcon": false,
      "singleLine": false,
      "provider": root,
      "onActivate": function() {
        mainInstance?.connectToHost(host.name)
        launcher.close()
      }
    }
  }
}
