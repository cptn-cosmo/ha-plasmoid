// SPDX-License-Identifier: GPL-3.0-or-later
// Live entity state: WebSocket subscription with automatic reconnect, REST polling as fallback.
import QtQuick
import QtWebSockets

import "../code/ha.js" as Ha

Item {
    id: client
    visible: false

    property string baseUrl
    property string token
    property int pollInterval: 30          // seconds, used while the WebSocket is down
    property var watched: []              // entity ids whose changes should bump `revision`

    // entity_id -> state object as returned by Home Assistant
    property var entityStates: ({})
    // Bumped whenever a watched entity changes; bind to it to refresh.
    property int revision: 0

    // "unconfigured" | "connecting" | "connected" | "polling" | "unauthorized" | "offline"
    property string status: "unconfigured"
    property string errorString: ""
    readonly property bool configured: Ha.normaliseUrl(baseUrl) !== "" && token !== ""
    readonly property bool live: status === "connected"
    property bool hasData: false

    property int _msgId: 0
    property int _subscribeId: -1
    property int _getStatesId: -1
    property int _pingId: -1
    property int _reconnectDelay: 2000
    property var _watchedSet: ({})

    onWatchedChanged: {
        const set = {};
        for (const id of watched)
            set[id] = true;
        _watchedSet = set;
        revision++;
    }
    onBaseUrlChanged: restart()
    onTokenChanged: restart()
    Component.onCompleted: restart()

    function restart() {
        restartTimer.restart(); // coalesce url+token changes arriving together
    }

    function _doRestart() {
        socket.active = false;
        reconnectTimer.stop();
        _reconnectDelay = 2000;
        rest.baseUrl = baseUrl;
        rest.token = token;
        if (!configured) {
            status = "unconfigured";
            errorString = "";
            pollTimer.stop();
            return;
        }
        status = "connecting";
        errorString = "";
        refresh();
        _connectSocket();
    }

    function refresh() {
        if (!configured)
            return;
        rest.getStates((r) => {
            if (r.ok && Array.isArray(r.data)) {
                _replaceStates(r.data);
                if (status !== "connected")
                    status = "polling";
                errorString = "";
            } else if (r.kind === "unauthorized") {
                status = "unauthorized";
                errorString = r.message;
            } else if (status !== "connected") {
                status = "offline";
                errorString = r.message;
            }
            _updatePolling();
        });
    }

    function callService(domain, service, data, callback) {
        rest.callService(domain, service, data, (r) => {
            // REST returns the states that changed; useful when the WebSocket is down.
            if (r.ok && Array.isArray(r.data)) {
                for (const s of r.data)
                    _applyState(s.entity_id, s);
            } else if (!r.ok) {
                errorString = r.message;
                if (r.kind === "unauthorized")
                    status = "unauthorized";
            }
            if (callback)
                callback(r);
        });
    }

    function toggle(entityId) {
        const svc = Ha.toggleService(entityStates[entityId], entityId);
        callService(svc[0], svc[1], svc[2]);
    }

    function setBrightness(entityId, pct) {
        pct = Math.max(0, Math.min(100, Math.round(pct)));
        if (pct === 0)
            callService("light", "turn_off", { entity_id: entityId });
        else
            callService("light", "turn_on", { entity_id: entityId, brightness_pct: pct });
    }

    function _replaceStates(list) {
        const map = {};
        for (const s of list)
            map[s.entity_id] = s;
        entityStates = map;
        hasData = true;
        revision++;
    }

    function _applyState(entityId, newState) {
        if (newState)
            entityStates[entityId] = newState;
        else
            delete entityStates[entityId];
        if (_watchedSet[entityId])
            revision++;
    }

    function _connectSocket() {
        _msgId = 0;
        _subscribeId = _getStatesId = _pingId = -1;
        socket.url = Ha.websocketUrl(baseUrl);
        socket.active = true;
    }

    function _send(obj) {
        obj.id = ++_msgId;
        socket.sendTextMessage(JSON.stringify(obj));
        return obj.id;
    }

    function _scheduleReconnect() {
        if (!configured || status === "unauthorized")
            return;
        reconnectTimer.interval = _reconnectDelay;
        reconnectTimer.restart();
        _reconnectDelay = Math.min(_reconnectDelay * 2, 60000);
    }

    function _updatePolling() {
        const shouldPoll = configured && status !== "connected" && status !== "unauthorized";
        if (shouldPoll && !pollTimer.running)
            pollTimer.start();
        else if (!shouldPoll)
            pollTimer.stop();
    }

    function _handleMessage(msg) {
        switch (msg.type) {
        case "auth_required":
            socket.sendTextMessage(JSON.stringify({ type: "auth", access_token: token }));
            break;
        case "auth_ok":
            _reconnectDelay = 2000;
            _subscribeId = _send({ type: "subscribe_events", event_type: "state_changed" });
            _getStatesId = _send({ type: "get_states" });
            status = "connected";
            errorString = "";
            pingTimer.restart();
            _updatePolling();
            break;
        case "auth_invalid":
            status = "unauthorized";
            errorString = i18n("Authentication failed: %1", msg.message || i18n("invalid access token"));
            socket.active = false;
            _updatePolling();
            break;
        case "event":
            if (msg.id === _subscribeId && msg.event && msg.event.data)
                _applyState(msg.event.data.entity_id, msg.event.data.new_state);
            break;
        case "result":
            if (msg.id === _getStatesId && msg.success && Array.isArray(msg.result))
                _replaceStates(msg.result);
            break;
        case "pong":
            if (msg.id === _pingId)
                pongTimeout.stop();
            break;
        }
    }

    HaRest {
        id: rest
    }

    WebSocket {
        id: socket
        active: false
        onTextMessageReceived: (message) => {
            let msg;
            try {
                msg = JSON.parse(message);
            } catch (e) {
                return;
            }
            client._handleMessage(msg);
        }
        onStatusChanged: () => {
            const st = socket.status;
            if (st !== WebSocket.Error && st !== WebSocket.Closed)
                return;
            pingTimer.stop();
            pongTimeout.stop();
            if (st === WebSocket.Error && client.status !== "unauthorized")
                console.warn("Home Assistant WebSocket error:", socket.errorString);
            if (client.status === "connected" || client.status === "connecting")
                client.status = client.hasData ? "polling" : "offline";
            socket.active = false;
            client._updatePolling();
            client._scheduleReconnect();
        }
    }

    Timer {
        id: restartTimer
        interval: 50
        onTriggered: client._doRestart()
    }

    Timer {
        id: reconnectTimer
        repeat: false
        onTriggered: client._connectSocket()
    }

    Timer {
        id: pollTimer
        interval: Math.max(5, client.pollInterval) * 1000
        repeat: true
        onTriggered: client.refresh()
    }

    // Detect half-open connections (e.g. after suspend) that never report Closed.
    Timer {
        id: pingTimer
        interval: 30000
        repeat: true
        onTriggered: {
            if (socket.status !== WebSocket.Open)
                return;
            client._pingId = client._send({ type: "ping" });
            pongTimeout.restart();
        }
    }

    Timer {
        id: pongTimeout
        interval: 10000
        onTriggered: {
            console.warn("Home Assistant WebSocket: no pong, reconnecting");
            socket.active = false;
        }
    }
}
