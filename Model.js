.pragma library

var baseUrl = "https://api.torn.com/user/"
var selections = "basic,bars,cooldowns,profile,travel"
var barsUrl = "https://api.torn.com/v2/user?selections=bars"

var statusIcons = {
    "Okay": "🟢",
    "Hospital": "🏥",
    "Traveling": "✈️",
    "Jail": "⚖️",
    "Federal Jail": "🏛️",
    "Abroad": "🌍"
}

var statusColors = {
    "Okay": "#4CAF50",
    "Hospital": "#F44336",
    "Traveling": "#2196F3",
    "Jail": "#FF9800",
    "Federal Jail": "#9C27B0",
    "Abroad": "#00BCD4"
}

var tornLinks = {
    "Hospital": "https://www.torn.com/hospitalview.php",
    "Traveling": "https://www.torn.com/page.php?sid=travel",
    "Jail": "https://www.torn.com/jailview.php",
    "Federal Jail": "https://www.torn.com/jailview.php",
    "Gym": "https://www.torn.com/gym.php",
    "Okay": "https://www.torn.com"
}

function formatTime(seconds) {
    if (seconds <= 0) return "00:00:00"
    var h = Math.floor(seconds / 3600)
    var m = Math.floor((seconds % 3600) / 60)
    var s = seconds % 60
    return padZero(h) + ":" + padZero(m) + ":" + padZero(s)
}

function formatTimeShort(seconds) {
    if (seconds <= 0) return "0:00"
    var h = Math.floor(seconds / 3600)
    var m = Math.floor((seconds % 3600) / 60)
    var s = seconds % 60
    if (h > 0) return h + ":" + padZero(m) + ":" + padZero(s)
    return m + ":" + padZero(s)
}

function padZero(num) {
    return num < 10 ? "0" + num : "" + num
}

function getStatusIcon(state) {
    return statusIcons[state] || "❓"
}

function getStatusColor(state) {
    return statusColors[state] || "#9E9E9E"
}

function getLink(type) {
    return tornLinks[type] || "https://www.torn.com"
}

function parseApiResponse(jsonString) {
    try {
        var data = JSON.parse(jsonString)
        if (data.error) {
            return { error: data.error.error || "API Error" }
        }
        return {
            name: data.name || "",
            level: data.level || 0,
            playerId: data.player_id || 0,
            factionId: data.faction ? data.faction.faction_id : null,
            status: {
                state: data.status ? data.status.state : "Okay",
                description: data.status ? data.status.description : "",
                until: data.status ? data.status.until : 0
            },
            travel: {
                destination: data.travel ? data.travel.destination : "",
                method: data.travel ? data.travel.method : "",
                timeLeft: data.travel ? data.travel.time_left : 0,
                departed: data.travel ? data.travel.departed : 0
            },
            states: {
                hospitalTimestamp: data.states ? data.states.hospital_timestamp : 0,
                jailTimestamp: data.states ? data.states.jail_timestamp : 0
            },
            cooldowns: {
                drug: data.cooldowns ? data.cooldowns.drug : 0,
                medical: data.cooldowns ? data.cooldowns.medical : 0,
                booster: data.cooldowns ? data.cooldowns.booster : 0
            },
            bars: {
                energy: { current: data.energy ? data.energy.current : 0, maximum: data.energy ? data.energy.maximum : 0 },
                nerve: { current: data.nerve ? data.nerve.current : 0, maximum: data.nerve ? data.nerve.maximum : 0 },
                happy: { current: data.happy ? data.happy.current : 0, maximum: data.happy ? data.happy.maximum : 0 },
                life: { current: data.life ? data.life.current : 0, maximum: data.life ? data.life.maximum : 0 }
            },
            serverTime: data.server_time || Math.floor(Date.now() / 1000)
        }
    } catch (e) {
        return { error: "Parse error: " + e.message }
    }
}

function calculateTimers(serverTime, data) {
    var now = Math.floor(Date.now() / 1000)
    var timers = []

    if (data.states.hospitalTimestamp > 0) {
        var hospitalLeft = data.states.hospitalTimestamp - now
        if (hospitalLeft > 0) {
            timers.push({ type: "Hospital", timeLeft: hospitalLeft, description: "In Hospital", link: getLink("Hospital") })
        }
    }
    if (data.states.jailTimestamp > 0) {
        var jailLeft = data.states.jailTimestamp - now
        if (jailLeft > 0) {
            timers.push({ type: "Jail", timeLeft: jailLeft, description: "In Jail", link: getLink("Jail") })
        }
    }
    if (data.travel.timeLeft > 0 && data.status.state === "Traveling") {
        timers.push({ type: "Traveling", timeLeft: data.travel.timeLeft, description: "Traveling to " + data.travel.destination, link: getLink("Traveling") })
    }
    if (data.cooldowns.drug > 0) {
        timers.push({ type: "Drug Cooldown", timeLeft: data.cooldowns.drug, description: "Drug Cooldown", link: "https://www.torn.com/item.php", icon: "💊" })
    }
    if (data.cooldowns.medical > 0) {
        timers.push({ type: "Medical Cooldown", timeLeft: data.cooldowns.medical, description: "Medical Cooldown", link: "https://www.torn.com/item.php", icon: "💉" })
    }
    if (data.cooldowns.booster > 0) {
        timers.push({ type: "Booster Cooldown", timeLeft: data.cooldowns.booster, description: "Booster Cooldown", link: "https://www.torn.com/item.php", icon: "🆙" })
    }
    return timers
}

function getMainTimer(data) {
    var timers = calculateTimers(data.serverTime, data)
    if (timers.length > 0) {
        return timers[0]
    }
    return null
}
