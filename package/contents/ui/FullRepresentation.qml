// SPDX-License-Identifier: GPL-3.0-or-later
// Popup (or desktop) view with the full entity list.
import QtQuick
import QtQuick.Layouts
import org.kde.kirigami as Kirigami
import org.kde.plasma.components as PlasmaComponents
import org.kde.plasma.extras as PlasmaExtras
import org.kde.plasma.plasmoid

PlasmaExtras.Representation {
    id: full

    required property var client
    required property var entities       // list-placed entity configs
    property int scrollStep: 5

    Layout.minimumWidth: Kirigami.Units.gridUnit * 14
    Layout.minimumHeight: Kirigami.Units.gridUnit * 10
    Layout.preferredWidth: Kirigami.Units.gridUnit * 20
    Layout.preferredHeight: Kirigami.Units.gridUnit * 24

    collapseMarginsHint: true

    header: PlasmaExtras.PlasmoidHeading {
        RowLayout {
            anchors.fill: parent
            spacing: Kirigami.Units.smallSpacing

            Kirigami.Heading {
                Layout.fillWidth: true
                Layout.leftMargin: Kirigami.Units.smallSpacing
                level: 3
                text: i18n("Home Assistant")
                elide: Text.ElideRight
            }

            Kirigami.Icon {
                Layout.preferredWidth: Kirigami.Units.iconSizes.small
                Layout.preferredHeight: Kirigami.Units.iconSizes.small
                source: full.client.live ? "network-connect" : "network-disconnect"
                opacity: full.client.live ? 0.7 : 1
                visible: full.client.configured
                PlasmaComponents.ToolTip.text: statusText()
                PlasmaComponents.ToolTip.visible: statusHover.hovered
                HoverHandler { id: statusHover }
            }

            PlasmaComponents.ToolButton {
                icon.name: "view-refresh"
                display: PlasmaComponents.AbstractButton.IconOnly
                text: i18n("Refresh")
                visible: full.client.configured
                onClicked: full.client.restart()
                PlasmaComponents.ToolTip.text: text
                PlasmaComponents.ToolTip.visible: hovered
            }

            PlasmaComponents.ToolButton {
                icon.name: "configure"
                display: PlasmaComponents.AbstractButton.IconOnly
                text: i18n("Configure…")
                onClicked: Plasmoid.internalAction("configure").trigger()
                PlasmaComponents.ToolTip.text: text
                PlasmaComponents.ToolTip.visible: hovered
            }
        }
    }

    // "unconfigured" | "connecting" | "unauthorized" | "offline" | "empty" | "list"
    readonly property string mode: {
        if (!client.configured)
            return "unconfigured";
        if (!client.hasData) {
            if (client.status === "unauthorized" || client.status === "offline")
                return client.status;
            return "connecting";
        }
        return entities.length === 0 ? "empty" : "list";
    }

    function statusText() {
        switch (client.status) {
        case "connected": return i18n("Connected (live updates)");
        case "connecting": return i18n("Connecting…");
        case "polling": return i18n("Live updates unavailable, polling every %1 s", client.pollInterval);
        case "unauthorized": return client.errorString;
        case "offline": return client.errorString || i18n("Offline");
        default: return "";
        }
    }

    ColumnLayout {
        anchors.fill: parent
        spacing: 0

        // Non-fatal problems: shown above the list while stale data stays visible.
        Kirigami.InlineMessage {
            Layout.fillWidth: true
            Layout.margins: Kirigami.Units.smallSpacing
            visible: full.client.configured && full.client.hasData
                     && (full.client.status === "offline" || full.client.status === "polling" || full.client.status === "unauthorized")
            type: full.client.status === "polling" ? Kirigami.MessageType.Information
                 : (full.client.status === "unauthorized" ? Kirigami.MessageType.Error : Kirigami.MessageType.Warning)
            text: full.statusText()
        }

        PlasmaComponents.ScrollView {
            Layout.fillWidth: true
            Layout.fillHeight: true
            visible: full.mode === "list"

            contentItem: ListView {
                id: list
                model: full.entities
                clip: true
                spacing: Kirigami.Units.smallSpacing
                topMargin: Kirigami.Units.smallSpacing
                bottomMargin: Kirigami.Units.smallSpacing
                boundsBehavior: Flickable.StopAtBounds
                delegate: EntityRow {
                    required property var modelData
                    client: full.client
                    cfg: modelData
                    scrollStep: full.scrollStep
                }
            }
        }

        Item {
            Layout.fillWidth: true
            Layout.fillHeight: true
            visible: full.mode !== "list"

            PlasmaComponents.BusyIndicator {
                anchors.centerIn: parent
                visible: full.mode === "connecting"
                running: visible
            }

            PlasmaExtras.PlaceholderMessage {
                id: placeholder
                anchors.centerIn: parent
                width: parent.width - Kirigami.Units.gridUnit * 2
                visible: full.mode !== "connecting"

                readonly property bool canRetry: full.mode === "offline"

                iconName: ({ unconfigured: "configure", unauthorized: "dialog-password",
                             offline: "network-disconnect", empty: "view-list-details" })[full.mode] || ""
                text: ({ unconfigured: i18n("Not connected to Home Assistant"),
                         unauthorized: i18n("Access denied"),
                         offline: i18n("Home Assistant is unreachable"),
                         empty: i18n("No entities selected") })[full.mode] || ""
                explanation: ({ unconfigured: i18n("Enter your Home Assistant URL and a long-lived access token."),
                                unauthorized: full.client.errorString,
                                offline: full.client.errorString,
                                empty: i18n("Choose which entities to show in the widget settings.") })[full.mode] || ""
                helpfulAction: Kirigami.Action {
                    icon.name: placeholder.canRetry ? "view-refresh" : "configure"
                    text: placeholder.canRetry ? i18n("Retry") : i18n("Configure…")
                    onTriggered: {
                        if (placeholder.canRetry)
                            full.client.restart();
                        else
                            Plasmoid.internalAction("configure").trigger();
                    }
                }
            }
        }
    }
}
