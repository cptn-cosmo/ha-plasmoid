// SPDX-License-Identifier: GPL-3.0-or-later
// Minimal asynchronous Home Assistant REST client with timeouts and error classification.
import QtQuick

import "../code/ha.js" as Ha

Item {
    id: rest
    visible: false

    property string baseUrl
    property string token
    property int timeout: 10000

    // callback({ ok, status, kind, data, message })
    // kind: "ok" | "timeout" | "network" | "unauthorized" | "notfound" | "badresponse" | "http" | "config"
    function request(method, path, body, callback) {
        const base = Ha.normaliseUrl(baseUrl);
        if (base === "") {
            callback({ ok: false, status: 0, kind: "config", message: i18n("No Home Assistant URL configured.") });
            return;
        }
        if (token === "") {
            callback({ ok: false, status: 0, kind: "config", message: i18n("No access token configured.") });
            return;
        }

        const xhr = new XMLHttpRequest();
        let finished = false;
        const timer = timerComponent.createObject(rest, { interval: timeout });

        const finish = (result) => {
            if (finished)
                return;
            finished = true;
            timer.stop();
            timer.destroy();
            callback(result);
        };

        timer.triggered.connect(() => {
            xhr.abort();
            finish({ ok: false, status: 0, kind: "timeout",
                     message: i18n("Timed out after %1 seconds connecting to %2.", Math.round(timeout / 1000), base) });
        });

        xhr.onreadystatechange = () => {
            if (xhr.readyState !== XMLHttpRequest.DONE || finished)
                return;
            const status = xhr.status;
            if (status === 0) {
                finish({ ok: false, status: 0, kind: "network",
                         message: i18n("Could not reach %1. Check the URL, the network and (for https) the certificate.", base) });
                return;
            }
            if (status === 401 || status === 403) {
                finish({ ok: false, status: status, kind: "unauthorized",
                         message: i18n("Unauthorized (HTTP %1). The access token is invalid or was revoked.", status) });
                return;
            }
            if (status === 404) {
                finish({ ok: false, status: status, kind: "notfound",
                         message: i18n("Not found (HTTP 404). Is %1 really a Home Assistant instance?", base) });
                return;
            }
            let data = null;
            try {
                data = xhr.responseText ? JSON.parse(xhr.responseText) : null;
            } catch (e) {
                finish({ ok: false, status: status, kind: "badresponse",
                         message: i18n("Unexpected response from %1 (not JSON). Is this the Home Assistant URL?", base) });
                return;
            }
            if (status < 200 || status >= 300) {
                const detail = data && data.message ? data.message : xhr.statusText;
                finish({ ok: false, status: status, kind: "http", data: data,
                         message: i18n("Home Assistant returned HTTP %1: %2", status, detail) });
                return;
            }
            finish({ ok: true, status: status, kind: "ok", data: data, message: "" });
        };

        try {
            xhr.open(method, base + path);
            xhr.setRequestHeader("Authorization", "Bearer " + token);
            xhr.setRequestHeader("Content-Type", "application/json");
            timer.start();
            xhr.send(body === undefined || body === null ? "" : JSON.stringify(body));
        } catch (e) {
            finish({ ok: false, status: 0, kind: "network", message: i18n("Invalid URL: %1", base) });
        }
    }

    // GET /api/ – returns {"message": "API running."} when URL and token are fine.
    function testConnection(callback) {
        request("GET", "/api/", null, (r) => {
            if (r.ok && !(r.data && typeof r.data.message === "string")) {
                r.ok = false;
                r.kind = "badresponse";
                r.message = i18n("The server answered, but it does not look like the Home Assistant API.");
            }
            callback(r);
        });
    }

    function getStates(callback) {
        request("GET", "/api/states", null, callback);
    }

    function callService(domain, service, data, callback) {
        request("POST", "/api/services/" + encodeURIComponent(domain) + "/" + encodeURIComponent(service),
                data || {}, callback || (() => {}));
    }

    Component {
        id: timerComponent
        Timer { repeat: false }
    }
}
