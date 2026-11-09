// SPDX-License-Identifier: GPL-3.0-or-later
// Connection settings: URL, access token (KWallet), test button, polling interval.
import QtQuick
import QtQuick.Controls as QQC2
import QtQuick.Layouts
import org.kde.kirigami as Kirigami
import org.kde.kcmutils as KCM

import "../code/ha.js" as Ha

KCM.SimpleKCM {
    id: page

    // All config keys are passed to every page; declare them to avoid warnings.
    property string cfg_haUrl
    property string cfg_tokenStorage
    property string cfg_tokenFallback
    property int cfg_tokenRevision
    property int cfg_pollInterval
    property string cfg_entities
    property int cfg_scrollStep

    // null = still checking, true / false once known
    property var walletAvailable: null
    property string walletMessage: ""
    property bool walletBusy: false
    property bool tokenDirty: false
    property int _initialRevision: 0

    // "idle" | "running" | "ok" | "error"
    property string testState: "idle"
    property string testMessage: ""

    Wallet {
        id: wallet
    }

    HaRest {
        id: rest
        baseUrl: urlField.text
        token: tokenField.text.trim()
        timeout: 8000
    }

    Component.onCompleted: {
        _initialRevision = cfg_tokenRevision;
        wallet.check((code) => {
            walletAvailable = code === wallet.ok;
            walletMessage = wallet.messageFor(code);
            if (!walletAvailable) {
                // Fall back to plain-text storage, with the warning below.
                tokenField.text = cfg_tokenFallback;
                cfg_tokenStorage = "config";
                return;
            }
            if (cfg_tokenStorage === "config" && cfg_tokenFallback !== "") {
                // KWallet became available: migrate the plain-text token into it.
                tokenField.text = cfg_tokenFallback;
                markTokenEdited();
                return;
            }
            wallet.read((readCode, value) => {
                tokenField.text = readCode === wallet.ok ? value : "";
            });
        });
    }

    function markTokenEdited() {
        tokenDirty = true;
        if (walletAvailable) {
            cfg_tokenStorage = "wallet";
            cfg_tokenFallback = "";
            cfg_tokenRevision = _initialRevision + 1;   // enables "Apply" and tells the applet to reload
            walletWriteTimer.restart();
        } else {
            cfg_tokenStorage = "config";
            cfg_tokenFallback = tokenField.text.trim();
        }
    }

    function writeTokenToWallet() {
        walletWriteTimer.stop();
        if (!walletAvailable || !tokenDirty)
            return;
        const token = tokenField.text.trim();
        if (token !== "" && !Ha.isPlausibleToken(token)) {
            walletMessage = i18n("This does not look like a long-lived access token.");
            return;
        }
        walletBusy = true;
        wallet.write(token, (code) => {
            walletBusy = false;
            if (code === wallet.ok) {
                tokenDirty = false;
                walletMessage = "";
            } else {
                // Could not store it securely: keep it in the config instead, visibly.
                walletAvailable = false;
                walletMessage = wallet.messageFor(code);
                cfg_tokenStorage = "config";
                cfg_tokenFallback = token;
            }
        });
    }

    // Called by the configuration dialog before cfg_ values are written.
    function saveConfig() {
        if (walletWriteTimer.running || tokenDirty)
            writeTokenToWallet();
        cfg_haUrl = Ha.normaliseUrl(urlField.text);
    }

    Timer {
        id: walletWriteTimer
        interval: 700
        onTriggered: page.writeTokenToWallet()
    }

    Kirigami.FormLayout {
        QQC2.TextField {
            id: urlField
            Kirigami.FormData.label: i18n("Home Assistant URL:")
            Layout.fillWidth: true
            Layout.minimumWidth: Kirigami.Units.gridUnit * 18
            placeholderText: "http://homeassistant.local:8123"
            text: page.cfg_haUrl
            inputMethodHints: Qt.ImhUrlCharactersOnly | Qt.ImhNoAutoUppercase
            onTextEdited: {
                page.cfg_haUrl = text.trim();
                page.testState = "idle";
            }
        }

        Kirigami.PasswordField {
            id: tokenField
            Kirigami.FormData.label: i18n("Access token:")
            Layout.fillWidth: true
            placeholderText: page.walletAvailable === null ? i18n("Reading from KWallet…") : i18n("Long-lived access token")
            enabled: page.walletAvailable !== null
            onTextEdited: {
                page.markTokenEdited();
                page.testState = "idle";
            }
        }

        QQC2.Label {
            Layout.fillWidth: true
            Layout.maximumWidth: Kirigami.Units.gridUnit * 24
            wrapMode: Text.Wrap
            font: Kirigami.Theme.smallFont
            textFormat: Text.StyledText
            text: i18n("Create one in Home Assistant under <i>Profile → Security → Long-lived access tokens</i>.")
            onLinkActivated: (link) => Qt.openUrlExternally(link)
        }

        QQC2.Button {
            text: i18n("Open Token Page")
            icon.name: "internet-web-browser"
            enabled: Ha.normaliseUrl(urlField.text) !== ""
            onClicked: Qt.openUrlExternally(Ha.normaliseUrl(urlField.text) + "/profile/security")
        }

        Kirigami.InlineMessage {
            Layout.fillWidth: true
            Layout.maximumWidth: Kirigami.Units.gridUnit * 24
            visible: page.walletAvailable === false
            type: Kirigami.MessageType.Warning
            text: i18n("KWallet is unavailable, so the token is stored in plain text in the Plasma configuration (~/.config/plasma-org.kde.plasma.desktop-appletsrc). %1", page.walletMessage)
        }

        QQC2.Label {
            visible: page.walletAvailable === true
            font: Kirigami.Theme.smallFont
            opacity: 0.7
            text: page.walletBusy ? i18n("Saving token to KWallet…")
                 : page.tokenDirty ? i18n("The token will be saved to KWallet.")
                 : i18n("The token is stored in KWallet.")
        }

        Item { Kirigami.FormData.isSection: true }

        RowLayout {
            Kirigami.FormData.label: i18n("Connection:")
            spacing: Kirigami.Units.smallSpacing

            QQC2.Button {
                text: i18n("Test Connection")
                icon.name: "network-connect"
                enabled: page.testState !== "running" && urlField.text.trim() !== "" && tokenField.text.trim() !== ""
                onClicked: {
                    page.testState = "running";
                    rest.testConnection((r) => {
                        page.testState = r.ok ? "ok" : "error";
                        page.testMessage = r.ok ? i18n("Connected: %1", r.data.message) : r.message;
                    });
                }
            }
            QQC2.BusyIndicator {
                visible: page.testState === "running"
                running: visible
                Layout.preferredHeight: Kirigami.Units.iconSizes.medium
                Layout.preferredWidth: Kirigami.Units.iconSizes.medium
            }
        }

        Kirigami.InlineMessage {
            Layout.fillWidth: true
            Layout.maximumWidth: Kirigami.Units.gridUnit * 24
            visible: page.testState === "ok" || page.testState === "error"
            type: page.testState === "ok" ? Kirigami.MessageType.Positive : Kirigami.MessageType.Error
            text: page.testMessage
        }

        Item { Kirigami.FormData.isSection: true }

        QQC2.SpinBox {
            Kirigami.FormData.label: i18n("Fallback polling interval:")
            from: 5
            to: 3600
            value: page.cfg_pollInterval
            onValueModified: page.cfg_pollInterval = value
            textFromValue: (v) => i18np("%1 second", "%1 seconds", v)
            valueFromText: (t) => parseInt(t)
        }

        QQC2.Label {
            Layout.fillWidth: true
            Layout.maximumWidth: Kirigami.Units.gridUnit * 24
            wrapMode: Text.Wrap
            font: Kirigami.Theme.smallFont
            opacity: 0.7
            text: i18n("Live updates use the WebSocket API. Polling is only used while that connection is down.")
        }

        QQC2.SpinBox {
            Kirigami.FormData.label: i18n("Brightness per scroll step:")
            from: 1
            to: 50
            value: page.cfg_scrollStep
            onValueModified: page.cfg_scrollStep = value
            textFromValue: (v) => i18nc("percentage", "%1%", v)
            valueFromText: (t) => parseInt(t)
        }
    }
}
