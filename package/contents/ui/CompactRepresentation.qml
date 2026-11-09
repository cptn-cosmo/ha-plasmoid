// SPDX-License-Identifier: GPL-3.0-or-later
// Panel view: pinned entities as icon buttons plus the popup toggle
// (Home Assistant logo when nothing is pinned, otherwise a small chevron).
import QtQuick
import QtQuick.Layouts
import org.kde.kirigami as Kirigami
import org.kde.plasma.core as PlasmaCore
import org.kde.plasma.plasmoid

Item {
    id: compact

    required property var plasmoidItem
    required property var client
    required property var entities        // panel-placed entity configs
    property int scrollStep: 5

    readonly property bool vertical: Plasmoid.formFactor === PlasmaCore.Types.Vertical
    readonly property bool hasPinned: entities.length > 0
    // Thickness of the panel: the size of one square button.
    readonly property real cell: vertical ? width : height
    readonly property real chevronExtent: Math.max(Kirigami.Units.iconSizes.small, Math.round(cell * 0.5))
    readonly property bool problem: client.configured
                                    && (client.status === "offline" || client.status === "unauthorized")

    Layout.minimumWidth: vertical ? Kirigami.Units.iconSizes.small : grid.implicitWidth
    Layout.preferredWidth: vertical ? -1 : grid.implicitWidth
    Layout.maximumWidth: vertical ? Infinity : grid.implicitWidth
    Layout.minimumHeight: vertical ? grid.implicitHeight : Kirigami.Units.iconSizes.small
    Layout.preferredHeight: vertical ? grid.implicitHeight : -1
    Layout.maximumHeight: vertical ? grid.implicitHeight : Infinity

    function chevronIcon() {
        const open = plasmoidItem.expanded;
        switch (Plasmoid.location) {
        case PlasmaCore.Types.TopEdge:
            return open ? "arrow-up" : "arrow-down";
        case PlasmaCore.Types.LeftEdge:
            return open ? "arrow-left" : "arrow-right";
        case PlasmaCore.Types.RightEdge:
            return open ? "arrow-right" : "arrow-left";
        case PlasmaCore.Types.BottomEdge:
            return open ? "arrow-down" : "arrow-up";
        default:
            // Floating / desktop: popups usually open below.
            if (vertical)
                return open ? "arrow-left" : "arrow-right";
            return open ? "arrow-up" : "arrow-down";
        }
    }

    GridLayout {
        id: grid
        anchors.fill: parent
        flow: GridLayout.LeftToRight
        columns: compact.vertical ? 1 : compact.entities.length + 1
        rowSpacing: 0
        columnSpacing: 0

        Repeater {
            model: compact.entities
            delegate: EntityButton {
                required property var modelData
                client: compact.client
                cfg: modelData
                scrollStep: compact.scrollStep
                Layout.preferredWidth: compact.cell
                Layout.preferredHeight: compact.cell
                Layout.fillWidth: compact.vertical
                Layout.fillHeight: !compact.vertical
            }
        }

        MouseArea {
            id: toggle
            Layout.preferredWidth: compact.vertical ? compact.width : (compact.hasPinned ? compact.chevronExtent : compact.cell)
            Layout.preferredHeight: compact.vertical ? (compact.hasPinned ? compact.chevronExtent : compact.cell) : compact.height
            Layout.fillWidth: compact.vertical
            Layout.fillHeight: !compact.vertical

            hoverEnabled: true
            acceptedButtons: Qt.LeftButton
            property bool wasExpanded: false
            onPressed: wasExpanded = compact.plasmoidItem.expanded
            onClicked: compact.plasmoidItem.expanded = !wasExpanded

            Accessible.role: Accessible.Button
            Accessible.name: compact.plasmoidItem.expanded ? i18n("Hide Home Assistant entities") : i18n("Show Home Assistant entities")
            Accessible.onPressAction: compact.plasmoidItem.expanded = !compact.plasmoidItem.expanded

            // The widget-level tooltip is disabled while entities are pinned (see main.qml),
            // so the chevron carries it. Hover-only, clicks still reach the MouseArea.
            PlasmaCore.ToolTipArea {
                anchors.fill: parent
                active: compact.hasPinned && !compact.plasmoidItem.expanded
                mainText: i18n("Home Assistant")
                subText: compact.plasmoidItem.statusText
                location: Plasmoid.location
            }

            Rectangle {
                anchors.fill: parent
                anchors.margins: Math.round(Kirigami.Units.smallSpacing / 2)
                radius: Kirigami.Units.cornerRadius
                color: Kirigami.Theme.highlightColor
                opacity: toggle.containsMouse || compact.plasmoidItem.expanded ? 0.12 : 0
                visible: compact.hasPinned
            }

            EntityIcon {
                id: haLogo
                visible: !compact.hasPinned
                anchors.centerIn: parent
                width: Math.min(parent.width, parent.height) - Kirigami.Units.smallSpacing * 2
                height: width
                spec: "ha:home-assistant"
                lit: compact.plasmoidItem.expanded || toggle.containsMouse
                unavailable: false
                activeColor: Kirigami.Theme.textColor
                opacity: compact.client.configured ? 1 : 0.6
            }

            Kirigami.Icon {
                visible: compact.hasPinned
                anchors.centerIn: parent
                width: Math.min(Kirigami.Units.iconSizes.small, parent.width, parent.height)
                height: width
                source: compact.chevronIcon()
                active: toggle.containsMouse
            }

            // Connection problem badge.
            Rectangle {
                visible: compact.problem
                width: Math.max(4, Math.round(Math.min(toggle.width, toggle.height) / 4))
                height: width
                radius: width / 2
                anchors { right: parent.right; bottom: parent.bottom; margins: Math.round(Kirigami.Units.smallSpacing / 2) }
                color: compact.client.status === "unauthorized" ? Kirigami.Theme.negativeTextColor : Kirigami.Theme.neutralTextColor
                border.color: Kirigami.Theme.backgroundColor
                border.width: 1
            }
        }
    }
}
