// SPDX-License-Identifier: GPL-3.0-or-later
// Pure helpers shared by the applet and its configuration pages.
.pragma library

var PLACEMENT_PANEL = "panel";
var PLACEMENT_LIST = "list";
var PLACEMENT_BOTH = "both";

// Domains offered in the entity picker's filter, in display order.
var DOMAINS = ["light", "switch", "input_boolean", "fan", "cover", "lock",
               "climate", "media_player", "scene", "script", "automation",
               "button", "input_button", "humidifier", "siren", "valve",
               "vacuum", "group", "sensor", "binary_sensor"];

// Bundled icons (contents/icons/<name>.svg), referenced as "ha:<name>".
var BUNDLED_ICONS = ["home-assistant", "ceiling-light", "floor-lamp", "desk-lamp",
                     "bulb", "light-strip", "switch", "toggle", "plug", "fan",
                     "blinds", "curtains", "tv", "speaker", "thermostat",
                     "lock", "door", "garage", "scene", "script", "power", "sensor"];

function domainOf(entityId) {
    var i = entityId.indexOf(".");
    return i < 0 ? "" : entityId.substring(0, i);
}

function defaultIcon(entityId, state) {
    var d = domainOf(entityId);
    switch (d) {
    case "light": return "ha:bulb";
    case "switch": return "ha:switch";
    case "input_boolean": return "ha:toggle";
    case "fan": return "ha:fan";
    case "cover": return (state && state.attributes && state.attributes.device_class === "garage") ? "ha:garage" : "ha:blinds";
    case "lock": return "ha:lock";
    case "climate": return "ha:thermostat";
    case "media_player": return "ha:tv";
    case "scene": return "ha:scene";
    case "script":
    case "automation": return "ha:script";
    case "sensor":
    case "binary_sensor": return "ha:sensor";
    default: return "ha:power";
    }
}

// Parse the "entities" config entry defensively.
function parseEntities(json) {
    var list;
    try {
        list = JSON.parse(json || "[]");
    } catch (e) {
        return [];
    }
    if (!Array.isArray(list))
        return [];
    return list.filter(function (e) { return e && typeof e.id === "string" && e.id.length > 0; })
               .map(function (e) {
                   return {
                       id: e.id,
                       name: typeof e.name === "string" ? e.name : "",
                       icon: typeof e.icon === "string" ? e.icon : "",
                       placement: [PLACEMENT_PANEL, PLACEMENT_LIST, PLACEMENT_BOTH].indexOf(e.placement) >= 0 ? e.placement : PLACEMENT_LIST,
                       // Reserved for configurable actions (see README roadmap).
                       actions: (e.actions && typeof e.actions === "object") ? e.actions : {}
                   };
               });
}

function inPanel(cfg) { return cfg.placement === PLACEMENT_PANEL || cfg.placement === PLACEMENT_BOTH; }
function inList(cfg) { return cfg.placement === PLACEMENT_LIST || cfg.placement === PLACEMENT_BOTH; }

function isUnavailable(state) {
    return !state || state.state === "unavailable" || state.state === "unknown";
}

// "Active" means rendered highlighted.
function isOn(state) {
    if (!state)
        return false;
    switch (state.state) {
    case "on":
    case "open":
    case "opening":
    case "unlocked":
    case "playing":
    case "paused":
    case "heat":
    case "cool":
    case "heat_cool":
    case "auto":
    case "dry":
    case "fan_only":
    case "cleaning":
    case "home":
        return true;
    default:
        return false;
    }
}

function supportsBrightness(state) {
    if (!state || domainOf(state.entity_id) !== "light")
        return false;
    var a = state.attributes || {};
    var modes = a.supported_color_modes;
    if (Array.isArray(modes) && modes.length > 0) {
        for (var i = 0; i < modes.length; ++i) {
            if (modes[i] !== "onoff")
                return true;
        }
        return false;
    }
    // Legacy integrations: brightness attribute present (null while off).
    return a.hasOwnProperty("brightness");
}

// Current brightness in percent (0 when off).
function brightnessPct(state) {
    if (!state || state.state !== "on")
        return 0;
    var b = state.attributes ? state.attributes.brightness : null;
    if (typeof b !== "number")
        return 100;
    return Math.round(b / 255 * 100);
}

function isToggleable(entityId) {
    switch (domainOf(entityId)) {
    case "sensor":
    case "binary_sensor":
    case "weather":
    case "sun":
    case "person":
    case "device_tracker":
    case "zone":
        return false;
    default:
        return true;
    }
}

// The service to call for a left click: [domain, service, data].
function toggleService(state, entityId) {
    var d = domainOf(entityId);
    var s = state ? state.state : "";
    var data = { entity_id: entityId };
    switch (d) {
    case "light":
    case "switch":
    case "input_boolean":
    case "fan":
    case "automation":
    case "humidifier":
    case "siren":
    case "media_player":
    case "climate":
        return [d, "toggle", data];
    case "cover":
    case "valve":
        return [d, "toggle", data];
    case "lock":
        return [d, s === "locked" ? "unlock" : "lock", data];
    case "scene":
        return [d, "turn_on", data];
    case "script":
        return [d, s === "on" ? "turn_off" : "turn_on", data];
    case "button":
    case "input_button":
        return [d, "press", data];
    case "vacuum":
        return [d, s === "cleaning" ? "return_to_base" : "start", data];
    default:
        return ["homeassistant", "toggle", data];
    }
}

// Normalise user input like "homeassistant.local:8123/" into "http://homeassistant.local:8123".
function normaliseUrl(url) {
    var u = (url || "").trim();
    if (u.length === 0)
        return "";
    if (!/^https?:\/\//i.test(u))
        u = "http://" + u;
    return u.replace(/\/+$/, "");
}

function websocketUrl(baseUrl) {
    return normaliseUrl(baseUrl).replace(/^http/i, "ws") + "/api/websocket";
}

// Long-lived tokens are JWTs; reject anything else before it reaches a shell.
function isPlausibleToken(token) {
    return /^[A-Za-z0-9._-]{20,4096}$/.test(token || "");
}
