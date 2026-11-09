// SPDX-License-Identifier: GPL-3.0-or-later
// Asynchronous access to the token stored in KWallet, via contents/code/wallet.sh.
import QtQuick
import org.kde.plasma.plasma5support as P5Support

import "../code/ha.js" as Ha

QtObject {
    id: wallet

    // Result codes reported to callbacks.
    readonly property int ok: 0
    readonly property int missingTool: 10
    readonly property int disabled: 11
    readonly property int failed: 12

    property var _callbacks: ({})
    property int _seq: 0

    readonly property string _script: {
        const url = Qt.resolvedUrl("../code/wallet.sh").toString();
        return decodeURIComponent(url.replace(/^file:\/\//, ""));
    }

    function _quote(s) {
        return "'" + String(s).replace(/'/g, "'\\''") + "'";
    }

    function _run(command, callback) {
        // A unique trailing comment keeps identical commands from being merged by the engine.
        const source = command + " # " + (++_seq);
        _callbacks[source] = callback;
        executable.connectSource(source);
    }

    function messageFor(code) {
        switch (code) {
        case ok: return "";
        case missingTool: return i18n("kwallet-query was not found. Install KWallet to store the token securely.");
        case disabled: return i18n("KWallet is disabled in System Settings.");
        default: return i18n("KWallet could not be opened (was the unlock prompt cancelled?).");
        }
    }

    // callback(code, token)
    function read(callback) {
        _run("sh " + _quote(_script) + " read", (code, out) => callback(code, out.trim()));
    }

    // callback(code). Refuses tokens with unexpected characters so nothing odd reaches the shell.
    function write(token, callback) {
        if (token !== "" && !Ha.isPlausibleToken(token)) {
            callback(failed);
            return;
        }
        _run("printf '%s' " + _quote(token) + " | sh " + _quote(_script) + " write", (code) => callback(code));
    }

    // callback(code)
    function check(callback) {
        _run("sh " + _quote(_script) + " check", (code) => callback(code));
    }

    property P5Support.DataSource executable: P5Support.DataSource {
        engine: "executable"
        connectedSources: []
        onNewData: (source, data) => {
            const cb = wallet._callbacks[source];
            delete wallet._callbacks[source];
            disconnectSource(source);
            if (cb)
                cb(data["exit code"] || 0, data["stdout"] || "");
        }
    }
}
