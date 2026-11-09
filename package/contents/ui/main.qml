// SPDX-License-Identifier: GPL-3.0-or-later
import QtQuick
import org.kde.kirigami as Kirigami
import org.kde.plasma.core as PlasmaCore
import org.kde.plasma.plasmoid

import "../code/ha.js" as Ha

PlasmoidItem {
    id: root

    readonly property var entityConfigs: Ha.parseEntities(Plasmoid.configuration.entities)
    readonly property var panelEntities: entityConfigs.filter(Ha.inPanel)
    readonly property var listEntities: entityConfigs.filter(Ha.inList)
    readonly property string haUrl: Ha.normaliseUrl(Plasmoid.configuration.haUrl)

    property string token: ""
    property string walletError: ""

    Plasmoid.icon: Qt.resolvedUrl("../icons/home-assistant.svg")

    preferredRepresentation: Plasmoid.formFactor === PlasmaCore.Types.Planar ? fullRepresentation : compactRepresentation
    switchWidth: Kirigami.Units.gridUnit * 10
    switchHeight: Kirigami.Units.gridUnit * 8

    toolTipMainText: i18n("Home Assistant")
    toolTipSubText: {
        if (!haClient.configured)
            return i18n("Not configured");
        switch (haClient.status) {
        case "connected": return i18np("%1 entity", "%1 entities", entityConfigs.length);
        case "connecting": return i18n("Connecting…");
        case "polling": return i18n("Live updates unavailable, polling");
        default: return haClient.errorString || i18n("Offline");
        }
    }

    compactRepresentation: CompactRepresentation {
        plasmoidItem: root
        client: haClient
        entities: root.panelEntities
        scrollStep: Plasmoid.configuration.scrollStep
    }

    fullRepresentation: FullRepresentation {
        client: haClient
        entities: root.listEntities
        scrollStep: Plasmoid.configuration.scrollStep
    }

    HaClient {
        id: haClient
        baseUrl: root.haUrl
        token: root.token
        pollInterval: Plasmoid.configuration.pollInterval
        watched: root.entityConfigs.map(e => e.id)
    }

    Wallet {
        id: wallet
    }

    function loadToken() {
        if (Plasmoid.configuration.tokenStorage === "config") {
            walletError = "";
            token = Plasmoid.configuration.tokenFallback;
            return;
        }
        wallet.read((code, value) => {
            if (code === wallet.ok) {
                walletError = "";
                token = value;
            } else {
                walletError = wallet.messageFor(code);
                console.warn("Home Assistant plasmoid:", walletError);
                token = Plasmoid.configuration.tokenFallback;
            }
        });
    }

    Component.onCompleted: loadToken()

    Timer {
        id: tokenReloadTimer
        interval: 1500
        onTriggered: root.loadToken()
    }

    Connections {
        target: Plasmoid.configuration
        // The settings page writes KWallet asynchronously; give it a moment before re-reading.
        function onTokenRevisionChanged() { tokenReloadTimer.restart(); }
        function onTokenStorageChanged() { root.loadToken(); }
        function onTokenFallbackChanged() { root.loadToken(); }
    }

    Plasmoid.contextualActions: [
        PlasmaCore.Action {
            text: i18n("Refresh")
            icon.name: "view-refresh"
            enabled: haClient.configured
            onTriggered: haClient.restart()
        },
        PlasmaCore.Action {
            text: i18n("Open Home Assistant")
            icon.name: "internet-web-browser"
            enabled: root.haUrl !== ""
            onTriggered: Qt.openUrlExternally(root.haUrl)
        }
    ]
}
