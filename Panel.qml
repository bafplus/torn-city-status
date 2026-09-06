import QtQuick
import Quickshell
import Quickshell.Io
import qs.Commons
import qs.Ui
import "Model.js" as Model

Panel {
    id: root
    moduleName: "torn-city-status"
    ipcTarget: "torn-city-status"

    property var playerData: null
    property var allTimers: []
    property var chainData: null
    property var barsData: null
    property string lastError: ""
    property bool loading: false
    property bool showSettings: false

    property string apiKey: root.settings && root.settings.apiKey ? root.settings.apiKey : ""
    property int updateIntervalSec: root.settings && root.settings.updateIntervalSec ? root.settings.updateIntervalSec : 30
    property int warningSeconds: root.settings && root.settings.warningSeconds ? root.settings.warningSeconds : 60

    implicitWidth: button.implicitWidth
    implicitHeight: button.implicitHeight

    property bool alertShown: false
    property string barText: root.getBarText()
    property real panelHeight: 200 + (root.allTimers.length * 36) + ((root.chainData && root.chainData.current >= 5) ? 60 : 0) + (root.barsData ? 140 : 0) + 50
    
    Timer {
        interval: 1000
        repeat: true
        running: true
        property var alertedTimers: ({})
        onTriggered: {
            for (var i = 0; i < root.allTimers.length; i++) {
                if (root.allTimers[i].timeLeft > 0) root.allTimers[i].timeLeft--
            }
            if (root.chainData && root.chainData.timeout > 0) {
                var newData = {
                    current: root.chainData.current,
                    max: root.chainData.max,
                    timeout: root.chainData.timeout - 1,
                    modifier: root.chainData.modifier,
                    cooldown: root.chainData.cooldown
                }
                root.chainData = newData
                
                // Alert at warning time for chain
                if (root.chainData.timeout === root.warningSeconds && !root.alertShown) {
                    root.alertShown = true
                    root.sendNotification("Chain expiring soon!", Model.formatTime(root.chainData.timeout) + " left - Chain " + root.chainData.current + "/" + root.chainData.max)
                }
                if (root.chainData.timeout > root.warningSeconds) {
                    root.alertShown = false
                }
            }
            
            // Alert for other timers - use type only as key
            for (var j = 0; j < root.allTimers.length; j++) {
                var timer = root.allTimers[j]
                if (timer.timeLeft === root.warningSeconds && !alertedTimers[timer.type]) {
                    alertedTimers[timer.type] = true
                    root.sendNotification(timer.type + " expiring soon!", Model.formatTime(timer.timeLeft) + " left")
                }
                if (timer.timeLeft > root.warningSeconds) {
                    delete alertedTimers[timer.type]
                }
            }
            
            // Update menubar text
            root.barText = root.getBarText()
        }
    }

    function sendNotification(title, message) {
        Quickshell.execDetached(["notify-send", "-u", "critical", "-i", "dialog-warning", title, message])
    }

    Timer {
        id: apiTimer
        interval: root.updateIntervalSec * 1000
        repeat: true
        running: root.apiKey !== ""
        triggeredOnStart: true
        onTriggered: root.fetchData()
    }

    onOpenedChanged: if (opened && !root.playerData) root.fetchData()

    function fetchData() {
        if (root.apiKey === "") { root.lastError = "No API key configured"; return }
        root.loading = true
        root.lastError = ""
        var timestamp = Math.floor(Date.now() / 1000)
        
        // Fetch user data
        var userUrl = Model.baseUrl + "?selections=" + Model.selections + "&key=" + root.apiKey + "&timestamp=" + timestamp
        var userXhr = new XMLHttpRequest()
        userXhr.open("GET", userUrl, true)
        userXhr.onreadystatechange = function() {
            if (userXhr.readyState === 4) {
                if (userXhr.status === 200) {
                    var result = Model.parseApiResponse(userXhr.responseText)
                    if (result.error) { root.lastError = result.error }
                    else {
                        root.playerData = result
                        root.allTimers = Model.calculateTimers(result.serverTime, result)
                        root.lastError = ""
                        
                        // Fetch bars data (includes chain)
                        var barsXhr = new XMLHttpRequest()
                        barsXhr.open("GET", Model.barsUrl, true)
                        barsXhr.setRequestHeader("Authorization", "ApiKey " + root.apiKey)
                        barsXhr.onreadystatechange = function() {
                            if (barsXhr.readyState === 4) {
                                root.loading = false
                                if (barsXhr.status === 200) {
                                    try {
                                        var barsData = JSON.parse(barsXhr.responseText)
                                        if (barsData.bars) {
                                            root.barsData = barsData.bars
                                            if (barsData.bars.chain) {
                                                root.chainData = barsData.bars.chain
                                            }
                                        }
                                    } catch (e) {}
                                }
                            }
                        }
                        barsXhr.send()
                    }
                } else { 
                    root.lastError = "HTTP " + userXhr.status
                    root.loading = false
                }
            }
        }
        userXhr.send()
    }

    function saveSetting(key, value) {
        if (root.bar && root.bar.shell && root.bar.shell.updateEntryInline) {
            var entry = { id: "torn-city-status" }
            for (var k in root.settings) entry[k] = root.settings[k]
            entry[key] = value
            root.bar.shell.updateEntryInline("torn-city-status", entry)
        }
    }

    WidgetButton {
        id: button
        anchors.fill: parent
        bar: root.bar
        text: root.barText
        tooltipText: root.playerData ? root.playerData.name + " - " + root.playerData.status.state : "Torn City Status"
        onPressed: function(buttonCode) {
            if (buttonCode === Qt.LeftButton) root.toggle()
            else if (buttonCode === Qt.RightButton) root.fetchData()
        }
    }

    function getBarText() {
        var parts = []
        
        // Status timer (hospital, jail, traveling)
        var statusTimer = null
        for (var i = 0; i < root.allTimers.length; i++) {
            if (root.allTimers[i].type === "Hospital" || root.allTimers[i].type === "Jail" || root.allTimers[i].type === "Traveling") {
                statusTimer = root.allTimers[i]
                break
            }
        }
        
        if (statusTimer) {
            parts.push(Model.getStatusIcon(statusTimer.type) + " " + Model.formatTimeShort(statusTimer.timeLeft))
        } else if (root.playerData) {
            parts.push(Model.getStatusIcon(root.playerData.status.state))
        } else {
            parts.push("🎮")
        }
        
        // Chain timer
        if (root.chainData && root.chainData.timeout > 0) {
            parts.push("🔗 " + Model.formatTimeShort(root.chainData.timeout))
        }
        
        return parts.join(" ")
    }

    KeyboardPanel {
        id: panel
        anchorItem: button
        owner: root
        bar: root.bar
        open: root.opened
        contentWidth: panel.fittedContentWidth(Style.space(340))
        contentHeight: panel.fittedContentHeight(body.implicitHeight, Style.space(root.panelHeight))

        Column {
            id: body
            width: parent.width
            spacing: 12

            // Header
            Row {
                width: parent.width
                spacing: 8

                Text {
                    text: "🎮 Torn City"
                    font.pixelSize: 16
                    font.bold: true
                    color: Color.foreground
                    width: parent.width - 40
                }

                Rectangle {
                    width: 28; height: 28; radius: 14
                    color: gearArea.containsMouse ? Color.accent : Color.background
                    border.color: Color.accent; border.width: 2
                    Text { anchors.centerIn: parent; text: "⚙"; font.pixelSize: 16; color: gearArea.containsMouse ? Color.background : Color.accent }
                    MouseArea { id: gearArea; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: root.showSettings = !root.showSettings }
                }
            }

            // Settings panel (shown when gear icon clicked)
            Rectangle {
                visible: root.showSettings
                width: parent.width
                height: root.showSettings ? settingsColumn.implicitHeight + 24 : 0
                color: Color.popups.background
                radius: 8
                border.color: Color.popups.border
                border.width: 1
                clip: true

                Column {
                    id: settingsColumn
                    anchors.fill: parent
                    anchors.margins: 12
                    spacing: 8

                    Text { text: "Settings"; font.pixelSize: 14; font.bold: true; color: Color.foreground }

                    // API Key
                    Row {
                        width: parent.width; spacing: 8; height: 28
                        Text { text: "API Key"; width: 80; font.pixelSize: 12; color: Color.foreground; anchors.verticalCenter: parent.verticalCenter }
                        Rectangle {
                            width: parent.width - 88; height: 24; radius: 4
                            color: Color.background
                            border.color: apiKeyInput.activeFocus ? Color.accent : Color.muted; border.width: 1
                            TextInput {
                                id: apiKeyInput
                                anchors.fill: parent; anchors.margins: 4
                                color: Color.foreground; font.pixelSize: 12; clip: true
                                text: root.apiKey
                                onTextChanged: { root.apiKey = text; root.saveSetting("apiKey", text) }
                                echoMode: TextInput.Password
                            }
                        }
                    }

                    // Update interval
                    Row {
                        width: parent.width; spacing: 8; height: 28
                        Text { text: "Update (s)"; width: 80; font.pixelSize: 12; color: Color.foreground; anchors.verticalCenter: parent.verticalCenter }
                        Rectangle {
                            width: 60; height: 24; radius: 4
                            color: Color.background
                            border.color: updateInput.activeFocus ? Color.accent : Color.muted; border.width: 1
                            TextInput {
                                id: updateInput
                                anchors.fill: parent; anchors.margins: 4
                                color: Color.foreground; font.pixelSize: 12; clip: true
                                text: root.updateIntervalSec.toString()
                                onTextChanged: { root.updateIntervalSec = parseInt(text) || 30; root.saveSetting("updateIntervalSec", root.updateIntervalSec) }
                                validator: IntValidator { bottom: 10; top: 300 }
                            }
                        }
                        Item { width: parent.width - 156; height: 1 }
                    }

                    // Warning time
                    Row {
                        width: parent.width; spacing: 8; height: 28
                        Text { text: "Warning (s)"; width: 80; font.pixelSize: 12; color: Color.foreground; anchors.verticalCenter: parent.verticalCenter }
                        Rectangle {
                            width: 60; height: 24; radius: 4
                            color: Color.background
                            border.color: warningInput.activeFocus ? Color.accent : Color.muted; border.width: 1
                            TextInput {
                                id: warningInput
                                anchors.fill: parent; anchors.margins: 4
                                color: Color.foreground; font.pixelSize: 12; clip: true
                                text: root.warningSeconds.toString()
                                onTextChanged: { root.warningSeconds = parseInt(text) || 60; root.saveSetting("warningSeconds", root.warningSeconds) }
                                validator: IntValidator { bottom: 10; top: 300 }
                            }
                        }
                        Item { width: parent.width - 156; height: 1 }
                    }

                    Text { text: "Get API key at torn.com/preferences.php#tab=api"; font.pixelSize: 10; color: Color.muted }
                }
            }

            // Player info
            Rectangle {
                width: parent.width; height: 60; color: Color.popups.background; radius: 8; border.color: Color.popups.border; border.width: 1
                Column {
                    anchors.fill: parent; anchors.margins: 12; spacing: 4
                    Row {
                        spacing: 8
                        Text { text: root.playerData ? Model.getStatusIcon(root.playerData.status.state) : "❓"; font.pixelSize: 24 }
                        Column {
                            Text { text: root.playerData ? root.playerData.name : "No data"; font.pixelSize: 16; font.bold: true; color: Color.foreground }
                            Text { text: root.playerData ? root.playerData.status.description : (root.lastError || "Click refresh"); font.pixelSize: 12; color: root.lastError ? Color.urgent : Color.muted }
                        }
                    }
                }
            }

            // Chain info
            Rectangle {
                visible: root.chainData !== null && root.chainData.current >= 5
                width: parent.width; height: 60; color: Color.popups.background; radius: 8; border.color: Color.popups.border; border.width: 1
                Column {
                    anchors.fill: parent; anchors.margins: 12; spacing: 4
                    Row {
                        width: parent.width
                        spacing: 8
                        Text { text: "Chain: " + (root.chainData ? root.chainData.current + "/" + root.chainData.max : "N/A"); font.pixelSize: 12; font.bold: true; color: Color.foreground; width: parent.width - 80 }
                        Text { text: root.chainData ? Model.formatTime(root.chainData.timeout) : ""; font.pixelSize: 12; color: root.chainData && root.chainData.timeout <= 60 ? Color.urgent : Color.foreground }
                        Text { text: root.chainData ? "x" + root.chainData.modifier.toFixed(2) : ""; font.pixelSize: 10; color: Color.muted }
                    }
                    Rectangle {
                        width: parent.width; height: 6; radius: 3; color: Color.background
                        Rectangle {
                            width: parent.width * (root.chainData ? Math.min(root.chainData.current / root.chainData.max, 1) : 0)
                            height: parent.height; radius: 3
                            color: root.chainData && root.chainData.timeout <= 60 ? Color.urgent : Color.accent
                        }
                    }
                }
            }

            // Bars info
            Rectangle {
                visible: root.barsData !== null
                width: parent.width; height: root.barsData ? 140 : 0; color: Color.popups.background; radius: 8; border.color: Color.popups.border; border.width: 1
                clip: true
                Column {
                    anchors.fill: parent; anchors.margins: 12; spacing: 6

                    Repeater {
                        model: root.barsData ? [
                            { label: "Energy", current: root.barsData.energy.current, max: root.barsData.energy.maximum, timeLeft: root.barsData.energy.full_time, color: "#4CAF50", icon: "⚡" },
                            { label: "Nerve", current: root.barsData.nerve.current, max: root.barsData.nerve.maximum, timeLeft: root.barsData.nerve.full_time, color: "#F44336", icon: "🔥" },
                            { label: "Happy", current: root.barsData.happy.current, max: root.barsData.happy.maximum, timeLeft: root.barsData.happy.full_time, color: "#FFEB3B", icon: "😊" },
                            { label: "Life", current: root.barsData.life.current, max: root.barsData.life.maximum, timeLeft: root.barsData.life.full_time, color: "#2196F3", icon: "❤️" }
                        ] : []
                        Column {
                            width: parent.width
                            spacing: 2
                            Row {
                                width: parent.width
                                Text { text: modelData.icon + " " + modelData.label + ": " + modelData.current + "/" + modelData.max; font.pixelSize: 11; font.bold: true; color: Color.foreground; width: parent.width - 60 }
                                Text { text: modelData.timeLeft > 0 ? Model.formatTime(modelData.timeLeft) : "FULL"; font.pixelSize: 11; color: modelData.timeLeft > 0 ? Color.foreground : Color.muted }
                            }
                            Rectangle {
                                width: parent.width; height: 6; radius: 3; color: Color.background
                                Rectangle {
                                    width: parent.width * (modelData.max > 0 ? Math.min(modelData.current / modelData.max, 1) : 0)
                                    height: parent.height; radius: 3
                                    color: modelData.color
                                }
                            }
                        }
                    }
                }
            }

            // Timers
            Repeater {
                model: root.allTimers
                Rectangle {
                    width: parent.width; height: 32; radius: 4
                    color: tmrMouse.containsMouse ? Color.accent + "20" : Color.popups.background
                    border.color: Color.popups.border; border.width: 1
                    Row {
                        anchors.fill: parent; anchors.margins: 6; spacing: 6
                        Text { text: modelData.icon || Model.getStatusIcon(modelData.type); font.pixelSize: 14; anchors.verticalCenter: parent.verticalCenter }
                        Text { text: modelData.description; font.pixelSize: 11; color: Color.foreground; width: parent.width - 110; elide: Text.ElideRight; anchors.verticalCenter: parent.verticalCenter }
                        Text { text: Model.formatTime(modelData.timeLeft); font.pixelSize: 11; font.bold: true; color: modelData.timeLeft <= 60 ? Color.urgent : Color.accent; anchors.verticalCenter: parent.verticalCenter }
                        Text { text: "↗"; font.pixelSize: 12; color: Color.muted; anchors.verticalCenter: parent.verticalCenter }
                    }
                    MouseArea { id: tmrMouse; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: Qt.openUrlExternally(modelData.link) }
                }
            }

            Text { text: root.allTimers.length === 0 ? "No active timers" : ""; font.pixelSize: 11; color: Color.muted }

            // Quick links
            Rectangle {
                width: parent.width; height: 50; color: Color.popups.background; radius: 8; border.color: Color.popups.border; border.width: 1
                Row {
                    anchors.fill: parent; anchors.margins: 6; spacing: 6
                    Repeater {
                        model: [
                            { icon: "🏥", url: "https://www.torn.com/hospitalview.php", label: "Hospital" },
                            { icon: "✈️", url: "https://www.torn.com/page.php?sid=travel", label: "Travel" },
                            { icon: "💪", url: "https://www.torn.com/gym.php", label: "Gym" }
                        ]
                        Rectangle {
                            width: (parent.width - 12) / 3; height: parent.height; radius: 4
                            color: lnkMouse.containsMouse ? Color.accent + "30" : Color.background
                            Column {
                                anchors.centerIn: parent; spacing: 2
                                Text { text: modelData.icon; font.pixelSize: 16; anchors.horizontalCenter: parent.horizontalCenter }
                                Text { text: modelData.label; font.pixelSize: 8; color: Color.muted; anchors.horizontalCenter: parent.horizontalCenter }
                            }
                            MouseArea { id: lnkMouse; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: Qt.openUrlExternally(modelData.url) }
                        }
                    }
                }
            }
        }
    }
}
