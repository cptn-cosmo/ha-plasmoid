// SPDX-License-Identifier: GPL-3.0-or-later
// Icon chooser: bundled home icons, any theme icon, or a custom SVG/PNG file.
import QtQuick
import QtQuick.Controls as QQC2
import QtQuick.Dialogs as Dialogs
import QtQuick.Layouts
import org.kde.kirigami as Kirigami
import org.kde.iconthemes as KIconThemes

import "../code/ha.js" as Ha

Kirigami.Dialog {
    id: picker

    property string current: ""
    signal picked(string spec)

    title: i18n("Choose Icon")
    standardButtons: Kirigami.Dialog.Cancel
    preferredWidth: Kirigami.Units.gridUnit * 24

    function choose(spec) {
        picked(spec);
        close();
    }

    ColumnLayout {
        spacing: Kirigami.Units.largeSpacing

        GridView {
            id: grid
            Layout.fillWidth: true
            Layout.preferredHeight: cellHeight * Math.ceil(count / Math.max(1, Math.floor(width / cellWidth)))
            Layout.margins: Kirigami.Units.smallSpacing
            interactive: false
            cellWidth: Kirigami.Units.iconSizes.large + Kirigami.Units.largeSpacing * 2
            cellHeight: cellWidth + Kirigami.Units.gridUnit
            model: Ha.BUNDLED_ICONS

            delegate: QQC2.ItemDelegate {
                id: cell
                required property string modelData
                readonly property string spec: "ha:" + modelData
                width: grid.cellWidth
                height: grid.cellHeight
                highlighted: picker.current === spec
                onClicked: picker.choose(spec)
                QQC2.ToolTip.text: modelData
                QQC2.ToolTip.visible: hovered
                QQC2.ToolTip.delay: Kirigami.Units.toolTipDelay
                Accessible.name: modelData

                contentItem: ColumnLayout {
                    spacing: 0
                    EntityIcon {
                        Layout.alignment: Qt.AlignHCenter
                        Layout.preferredWidth: Kirigami.Units.iconSizes.medium
                        Layout.preferredHeight: Kirigami.Units.iconSizes.medium
                        spec: cell.spec
                        lit: true
                        activeColor: Kirigami.Theme.textColor
                    }
                    QQC2.Label {
                        Layout.fillWidth: true
                        horizontalAlignment: Text.AlignHCenter
                        text: cell.modelData.replace(/-/g, " ")
                        elide: Text.ElideRight
                        font: Kirigami.Theme.smallFont
                    }
                }
            }
        }

        RowLayout {
            Layout.fillWidth: true
            Layout.margins: Kirigami.Units.smallSpacing
            spacing: Kirigami.Units.smallSpacing

            QQC2.Button {
                text: i18n("System Icon…")
                icon.name: "preferences-desktop-icons"
                onClicked: themeDialog.open()
            }
            QQC2.Button {
                text: i18n("Image File…")
                icon.name: "document-open"
                onClicked: fileDialog.open()
            }
            Item { Layout.fillWidth: true }
            QQC2.Button {
                text: i18n("Default")
                icon.name: "edit-undo"
                onClicked: picker.choose("")
            }
        }
    }

    KIconThemes.IconDialog {
        id: themeDialog
        onIconNameChanged: {
            if (iconName !== "")
                picker.choose(iconName);
        }
    }

    Dialogs.FileDialog {
        id: fileDialog
        title: i18n("Choose an Icon Image")
        nameFilters: [i18n("Images (*.svg *.svgz *.png)"), i18n("All files (*)")]
        onAccepted: picker.choose(selectedFile.toString())
    }
}
