// SPDX-License-Identifier: GPL-3.0-or-later
// One entity in the popup list: icon, name, state, toggle and brightness slider.
import QtQuick
import QtQuick.Layouts
import org.kde.kirigami as Kirigami
import org.kde.plasma.components as PlasmaComponents

PlasmaComponents.ItemDelegate {
    id: row

    required property var client
    required property var cfg
    property int scrollStep: 5

    hoverEnabled: true
    enabled: true
    width: ListView.view ? ListView.view.width : implicitWidth

    Accessible.name: logic.name
    Accessible.description: logic.stateText

    EntityLogic {
        id: logic
        client: row.client
        cfg: row.cfg
        scrollStep: row.scrollStep
    }

    onClicked: logic.activate()

    PlasmaComponents.ToolTip.text: logic.unavailable && logic.known ? logic.tooltipText : ""
    PlasmaComponents.ToolTip.visible: hovered && PlasmaComponents.ToolTip.text !== ""
    PlasmaComponents.ToolTip.delay: Kirigami.Units.toolTipDelay

    contentItem: ColumnLayout {
        spacing: Kirigami.Units.smallSpacing

        RowLayout {
            spacing: Kirigami.Units.largeSpacing
            Layout.fillWidth: true

            EntityIcon {
                Layout.preferredWidth: Kirigami.Units.iconSizes.medium
                Layout.preferredHeight: Kirigami.Units.iconSizes.medium
                spec: logic.icon
                lit: logic.on
                unavailable: logic.unavailable
            }

            ColumnLayout {
                spacing: 0
                Layout.fillWidth: true
                PlasmaComponents.Label {
                    Layout.fillWidth: true
                    text: logic.name
                    elide: Text.ElideRight
                    opacity: logic.unavailable ? 0.6 : 1
                }
                PlasmaComponents.Label {
                    Layout.fillWidth: true
                    text: logic.stateText
                    elide: Text.ElideRight
                    font: Kirigami.Theme.smallFont
                    opacity: 0.7
                }
            }

            PlasmaComponents.Switch {
                visible: logic.toggleable && ["light", "switch", "input_boolean", "fan", "automation", "humidifier", "siren"].indexOf(logic.entityId.split(".")[0]) >= 0
                enabled: !logic.unavailable
                checked: logic.on
                onToggled: logic.activate()
                Accessible.name: i18n("Toggle %1", logic.name)
            }
        }

        PlasmaComponents.Slider {
            id: slider
            Layout.fillWidth: true
            visible: logic.dimmable
            from: 0
            to: 100
            stepSize: 1
            value: logic.brightness
            onMoved: logic.setBrightness(value)
            Accessible.name: i18n("Brightness of %1", logic.name)
        }
    }

    // Wheel over a dimmable row adjusts brightness; otherwise it scrolls the list.
    MouseArea {
        anchors.fill: parent
        acceptedButtons: Qt.NoButton
        onWheel: (wheel) => {
            wheel.accepted = logic.wheel(wheel.inverted ? -wheel.angleDelta.y : wheel.angleDelta.y);
        }
    }
}
