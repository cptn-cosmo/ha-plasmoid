// SPDX-License-Identifier: GPL-3.0-or-later
// Resolves an icon spec ("ha:<bundled>", theme icon name, or file URL/path) and
// renders it according to the entity state while following the Plasma colour scheme.
import QtQuick
import org.kde.kirigami as Kirigami

import "../code/icons.js" as Icons

Item {
    id: icon

    // "ha:ceiling-light", "lightbulb", "file:///home/me/lamp.svg" or "/home/me/lamp.png"
    property string spec: "ha:home-assistant"
    property bool lit: false
    property bool unavailable: false
    // Colour of monochrome icons in the "on" state.
    property color activeColor: Kirigami.Theme.highlightColor

    readonly property bool bundled: spec.startsWith("ha:")
    readonly property color tint: unavailable ? Kirigami.Theme.disabledTextColor
                                              : (lit ? activeColor : Kirigami.Theme.textColor)

    implicitWidth: Kirigami.Units.iconSizes.medium
    implicitHeight: Kirigami.Units.iconSizes.medium
    opacity: unavailable ? 0.5 : (lit ? 1.0 : 0.6)

    Behavior on opacity {
        NumberAnimation { duration: Kirigami.Units.shortDuration }
    }

    function hex(c) {
        const h = (v) => ("0" + Math.round(v * 255).toString(16)).slice(-2);
        return "#" + h(c.r) + h(c.g) + h(c.b);
    }

    // Bundled icons are drawn from path data in the current colour scheme colour.
    Image {
        anchors.fill: parent
        visible: icon.bundled
        source: icon.bundled ? Icons.url(icon.spec.substring(3), icon.hex(icon.tint)) : ""
        sourceSize: Qt.size(Math.max(16, Math.ceil(width)), Math.max(16, Math.ceil(height)))
        fillMode: Image.PreserveAspectFit
        smooth: true
        asynchronous: false
    }

    // Theme icons (symbolic ones are recoloured by Plasma) and custom image files.
    Kirigami.Icon {
        anchors.fill: parent
        visible: !icon.bundled
        source: {
            if (icon.bundled)
                return "";
            if (icon.spec.startsWith("/"))
                return "file://" + icon.spec;
            return icon.spec;
        }
        fallback: "emblem-unavailable"
        isMask: icon.spec.endsWith("-symbolic")
        color: icon.tint
        enabled: !icon.unavailable
    }
}
