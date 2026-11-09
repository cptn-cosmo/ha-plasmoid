// SPDX-License-Identifier: GPL-3.0-or-later
// Per-entity state and actions shared by the panel button and the popup row.
import QtQuick

import "../code/ha.js" as Ha

Item {
    id: logic
    visible: false

    required property var client
    required property var cfg            // { id, name, icon, placement, actions }
    property int scrollStep: 5

    readonly property string entityId: cfg.id
    readonly property var haState: { client.revision; return client.entityStates[entityId]; }
    readonly property bool known: haState !== undefined && haState !== null
    readonly property bool unavailable: Ha.isUnavailable(haState)
    readonly property bool on: Ha.isOn(haState)
    readonly property bool toggleable: Ha.isToggleable(entityId)
    readonly property bool dimmable: !unavailable && Ha.supportsBrightness(haState)

    readonly property string name: {
        if (cfg.name)
            return cfg.name;
        if (haState && haState.attributes && haState.attributes.friendly_name)
            return haState.attributes.friendly_name;
        return entityId;
    }
    readonly property string icon: cfg.icon || Ha.defaultIcon(entityId, haState)

    // Brightness shown in the UI: pending value while a debounced change is in flight.
    property int pendingBrightness: -1
    readonly property int brightness: pendingBrightness >= 0 ? pendingBrightness : Ha.brightnessPct(haState)

    // True for a moment after a wheel step, for the overlay.
    property bool adjusting: false

    readonly property string stateText: {
        if (!client.hasData && !known)
            return i18nc("entity state", "Loading…");
        if (!known)
            return i18nc("entity state", "Not found");
        const s = haState.state;
        switch (s) {
        case "unavailable": return i18nc("entity state", "Unavailable");
        case "unknown": return i18nc("entity state", "Unknown");
        case "on":
            return dimmable ? i18nc("entity state with brightness", "On · %1%", brightness) : i18nc("entity state", "On");
        case "off": return i18nc("entity state", "Off");
        case "open": return i18nc("entity state", "Open");
        case "opening": return i18nc("entity state", "Opening");
        case "closed": return i18nc("entity state", "Closed");
        case "closing": return i18nc("entity state", "Closing");
        case "locked": return i18nc("entity state", "Locked");
        case "unlocked": return i18nc("entity state", "Unlocked");
        case "locking": return i18nc("entity state", "Locking");
        case "unlocking": return i18nc("entity state", "Unlocking");
        case "jammed": return i18nc("entity state", "Jammed");
        case "playing": return i18nc("entity state", "Playing");
        case "paused": return i18nc("entity state", "Paused");
        case "idle": return i18nc("entity state", "Idle");
        case "standby": return i18nc("entity state", "Standby");
        case "heat": return i18nc("climate mode", "Heating");
        case "cool": return i18nc("climate mode", "Cooling");
        case "auto": return i18nc("climate mode", "Auto");
        }
        const unit = haState.attributes && haState.attributes.unit_of_measurement;
        return unit ? s + " " + unit : s;
    }

    readonly property string tooltipText: {
        if (unavailable && known)
            return i18n("%1 is unavailable in Home Assistant", name);
        return stateText;
    }

    function activate() {
        if (!toggleable || unavailable)
            return;
        client.toggle(entityId);
    }

    // Returns true when the wheel event was consumed.
    property real _wheelAccumulator: 0
    function wheel(angleDeltaY) {
        if (!dimmable)
            return false;
        _wheelAccumulator += angleDeltaY;
        const steps = Math.trunc(_wheelAccumulator / 120);
        if (steps === 0)
            return true; // high-resolution touchpad: wait for a full notch
        _wheelAccumulator -= steps * 120;
        setBrightness(brightness + steps * scrollStep);
        adjusting = true;
        overlayTimer.restart();
        return true;
    }

    // Debounced: the UI follows immediately, the service call is sent once input settles.
    function setBrightness(pct) {
        pendingBrightness = Math.max(0, Math.min(100, Math.round(pct)));
        settleTimer.stop();
        debounce.restart();
    }

    onHaStateChanged: {
        // Drop the optimistic value once Home Assistant reports what we asked for.
        if (pendingBrightness < 0 || debounce.running)
            return;
        if (Math.abs(Ha.brightnessPct(haState) - pendingBrightness) <= 1) {
            settleTimer.stop();
            pendingBrightness = -1;
        }
    }

    Timer {
        id: debounce
        interval: 250
        onTriggered: {
            logic.client.setBrightness(logic.entityId, logic.pendingBrightness);
            settleTimer.restart();
        }
    }

    // Keep showing the requested value until HA confirms (or give up after a while).
    Timer {
        id: settleTimer
        interval: 3000
        onTriggered: logic.pendingBrightness = -1
    }

    Timer {
        id: overlayTimer
        interval: 1200
        onTriggered: logic.adjusting = false
    }
}
