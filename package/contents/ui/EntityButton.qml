// SPDX-License-Identifier: GPL-3.0-or-later
// Icon-only entity button for the panel.
import QtQuick
import org.kde.kirigami as Kirigami
import org.kde.plasma.core as PlasmaCore
import org.kde.plasma.components as PlasmaComponents
import org.kde.plasma.plasmoid

PlasmaCore.ToolTipArea {
    id: button

    required property var client
    required property var cfg
    property int scrollStep: 5

    mainText: logic.name
    subText: logic.adjusting ? i18n("Brightness: %1%", logic.brightness) : logic.tooltipText
    location: Plasmoid.location

    Accessible.role: Accessible.Button
    Accessible.name: logic.name
    Accessible.description: logic.stateText
    Accessible.onPressAction: logic.activate()

    EntityLogic {
        id: logic
        client: button.client
        cfg: button.cfg
        scrollStep: button.scrollStep
    }

    // Subtle background for "on" so full-colour theme icons are distinguishable too.
    Rectangle {
        anchors.fill: parent
        anchors.margins: Math.round(Kirigami.Units.smallSpacing / 2)
        radius: Kirigami.Units.cornerRadius
        color: Kirigami.Theme.highlightColor
        opacity: logic.on && !logic.unavailable ? 0.18 : (mouse.containsMouse ? 0.10 : 0)
        Behavior on opacity { NumberAnimation { duration: Kirigami.Units.shortDuration } }
    }

    EntityIcon {
        id: icon
        anchors.centerIn: parent
        width: Math.min(parent.width, parent.height) - Kirigami.Units.smallSpacing * 2
        height: width
        spec: logic.icon
        lit: logic.on
        unavailable: logic.unavailable
    }

    // Brightness overlay while scrolling: a bar along the bottom plus the value.
    Item {
        anchors.fill: parent
        opacity: logic.adjusting ? 1 : 0
        visible: opacity > 0
        Behavior on opacity { NumberAnimation { duration: Kirigami.Units.longDuration } }

        Rectangle {
            anchors { left: parent.left; right: parent.right; bottom: parent.bottom; margins: 1 }
            height: Math.max(2, Math.round(parent.height / 12))
            radius: height / 2
            color: Kirigami.Theme.backgroundColor
            opacity: 0.8
            Rectangle {
                anchors { left: parent.left; top: parent.top; bottom: parent.bottom }
                width: parent.width * logic.brightness / 100
                radius: parent.radius
                color: Kirigami.Theme.highlightColor
            }
        }
        PlasmaComponents.Label {
            anchors.centerIn: parent
            visible: parent.height >= Kirigami.Units.gridUnit * 1.2
            text: logic.brightness
            font.bold: true
            font.pixelSize: Math.round(parent.height * 0.38)
            style: Text.Outline
            styleColor: Kirigami.Theme.backgroundColor
        }
    }

    MouseArea {
        id: mouse
        anchors.fill: parent
        hoverEnabled: true
        acceptedButtons: Qt.LeftButton
        onClicked: logic.activate()
        onWheel: (wheel) => {
            // Unsupported entities let the event through to the panel / parent.
            wheel.accepted = logic.wheel(wheel.inverted ? -wheel.angleDelta.y : wheel.angleDelta.y);
        }
    }
}
