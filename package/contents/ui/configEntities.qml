// SPDX-License-Identifier: GPL-3.0-or-later
// Entity selection: pick entities from Home Assistant, reorder them, and set
// per-entity name, icon and placement.
import QtQuick
import QtQuick.Controls as QQC2
import QtQuick.Layouts
import org.kde.kirigami as Kirigami
import org.kde.kcmutils as KCM

import "../code/ha.js" as Ha

KCM.SimpleKCM {
    id: page

    property string cfg_haUrl
    property string cfg_tokenStorage
    property string cfg_tokenFallback
    property int cfg_tokenRevision
    property int cfg_pollInterval
    property string cfg_entities
    property int cfg_scrollStep

    // entity_id -> state, from GET /api/states
    property var allStates: ({})
    property var allIds: []
    // "loading" | "ok" | "error" | "unconfigured"
    property string loadState: "loading"
    property string loadError: ""
    property var selectedIds: ({})

    readonly property int maxResults: 300

    readonly property var filteredIds: {
        const q = searchField.text.trim().toLowerCase();
        const domain = domainBox.currentIndex > 0 ? Ha.DOMAINS[domainBox.currentIndex - 1] : "";
        const out = [];
        for (const id of allIds) {
            if (domain !== "" && Ha.domainOf(id) !== domain)
                continue;
            if (q !== "") {
                const s = allStates[id];
                const name = (s.attributes && s.attributes.friendly_name || "").toLowerCase();
                if (id.indexOf(q) < 0 && name.indexOf(q) < 0)
                    continue;
            }
            out.push(id);
        }
        return out;
    }

    Wallet { id: wallet }

    HaRest {
        id: rest
        baseUrl: page.cfg_haUrl
        timeout: 10000
    }

    ListModel { id: selectedModel }

    Component.onCompleted: {
        for (const e of Ha.parseEntities(cfg_entities))
            selectedModel.append({ entityId: e.id, name: e.name, iconSpec: e.icon, placement: e.placement,
                                   actionsJson: JSON.stringify(e.actions) });
        updateSelectedIds();
        loadEntities();
    }

    function loadEntities() {
        if (Ha.normaliseUrl(cfg_haUrl) === "") {
            loadState = "unconfigured";
            return;
        }
        loadState = "loading";
        const fetch = (token) => {
            if (token === "") {
                loadState = "unconfigured";
                return;
            }
            rest.token = token;
            rest.getStates((r) => {
                if (!r.ok) {
                    loadState = "error";
                    loadError = r.message;
                    return;
                }
                const map = {};
                for (const s of r.data)
                    map[s.entity_id] = s;
                allStates = map;
                allIds = Object.keys(map).sort();
                loadState = "ok";
            });
        };
        if (cfg_tokenStorage === "config")
            fetch(cfg_tokenFallback);
        else
            wallet.read((code, token) => fetch(code === wallet.ok ? token : cfg_tokenFallback));
    }

    function sync() {
        const list = [];
        for (let i = 0; i < selectedModel.count; ++i) {
            const e = selectedModel.get(i);
            let actions = {};
            try { actions = JSON.parse(e.actionsJson || "{}"); } catch (err) {}
            const item = { id: e.entityId, placement: e.placement };
            if (e.name) item.name = e.name;
            if (e.iconSpec) item.icon = e.iconSpec;
            if (Object.keys(actions).length > 0) item.actions = actions;
            list.push(item);
        }
        cfg_entities = JSON.stringify(list);
        updateSelectedIds();
    }

    function updateSelectedIds() {
        const set = {};
        for (let i = 0; i < selectedModel.count; ++i)
            set[selectedModel.get(i).entityId] = true;
        selectedIds = set;
    }

    function setSelected(entityId, selected) {
        for (let i = 0; i < selectedModel.count; ++i) {
            if (selectedModel.get(i).entityId === entityId) {
                if (!selected)
                    selectedModel.remove(i);
                sync();
                return;
            }
        }
        if (selected)
            selectedModel.append({ entityId: entityId, name: "", iconSpec: "", placement: Ha.PLACEMENT_BOTH, actionsJson: "{}" });
        sync();
    }

    function friendlyName(entityId) {
        const s = allStates[entityId];
        return s && s.attributes && s.attributes.friendly_name ? s.attributes.friendly_name : entityId;
    }

    IconPicker {
        id: iconPicker
        property int targetIndex: -1
        onPicked: (spec) => {
            if (targetIndex >= 0 && targetIndex < selectedModel.count) {
                selectedModel.setProperty(targetIndex, "iconSpec", spec);
                page.sync();
            }
        }
    }

    ColumnLayout {
        spacing: Kirigami.Units.largeSpacing

        // ───────────── Selected entities ─────────────
        Kirigami.Heading {
            level: 3
            text: i18n("Shown entities")
        }

        QQC2.Label {
            Layout.fillWidth: true
            visible: selectedModel.count === 0
            wrapMode: Text.Wrap
            opacity: 0.7
            text: i18n("No entities selected yet. Tick entities in the list below to add them.")
        }

        ListView {
            id: selectedList
            Layout.fillWidth: true
            Layout.preferredHeight: contentHeight
            interactive: false
            model: selectedModel
            spacing: Kirigami.Units.smallSpacing
            moveDisplaced: Transition {
                YAnimator { duration: Kirigami.Units.longDuration; easing.type: Easing.InOutQuad }
            }

            delegate: QQC2.ItemDelegate {
                id: selectedDelegate
                required property int index
                required property string entityId
                required property string name
                required property string iconSpec
                required property string placement

                width: selectedList.width
                down: false
                highlighted: false
                hoverEnabled: false

                contentItem: RowLayout {
                    spacing: Kirigami.Units.smallSpacing

                    Kirigami.ListItemDragHandle {
                        listItem: selectedDelegate
                        listView: selectedList
                        onMoveRequested: (oldIndex, newIndex) => selectedModel.move(oldIndex, newIndex, 1)
                        onDropped: page.sync()
                    }

                    QQC2.Button {
                        Layout.preferredWidth: Kirigami.Units.iconSizes.medium + Kirigami.Units.largeSpacing * 2
                        Layout.preferredHeight: Layout.preferredWidth
                        Accessible.name: i18n("Change icon of %1", page.friendlyName(selectedDelegate.entityId))
                        QQC2.ToolTip.text: i18n("Change icon")
                        QQC2.ToolTip.visible: hovered
                        onClicked: {
                            iconPicker.targetIndex = selectedDelegate.index;
                            iconPicker.current = selectedDelegate.iconSpec;
                            iconPicker.open();
                        }
                        EntityIcon {
                            anchors.centerIn: parent
                            width: Kirigami.Units.iconSizes.medium
                            height: width
                            spec: selectedDelegate.iconSpec || Ha.defaultIcon(selectedDelegate.entityId, page.allStates[selectedDelegate.entityId])
                            lit: true
                            activeColor: Kirigami.Theme.textColor
                        }
                    }

                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: 0
                        QQC2.TextField {
                            Layout.fillWidth: true
                            text: selectedDelegate.name
                            placeholderText: page.friendlyName(selectedDelegate.entityId)
                            Accessible.name: i18n("Display name")
                            onTextEdited: {
                                selectedModel.setProperty(selectedDelegate.index, "name", text);
                                page.sync();
                            }
                        }
                        QQC2.Label {
                            Layout.fillWidth: true
                            text: selectedDelegate.entityId
                                  + (page.loadState === "ok" && !page.allStates[selectedDelegate.entityId] ? " " + i18n("(not found)") : "")
                            font: Kirigami.Theme.smallFont
                            opacity: 0.7
                            elide: Text.ElideMiddle
                        }
                    }

                    QQC2.ComboBox {
                        id: placementBox
                        textRole: "text"
                        valueRole: "value"
                        Accessible.name: i18n("Placement")
                        model: [
                            { value: Ha.PLACEMENT_BOTH, text: i18n("Panel and list") },
                            { value: Ha.PLACEMENT_PANEL, text: i18n("Panel only") },
                            { value: Ha.PLACEMENT_LIST, text: i18n("List only") }
                        ]
                        Component.onCompleted: currentIndex = indexOfValue(selectedDelegate.placement)
                        onActivated: {
                            selectedModel.setProperty(selectedDelegate.index, "placement", currentValue);
                            page.sync();
                        }
                    }

                    QQC2.ToolButton {
                        icon.name: "list-remove"
                        display: QQC2.AbstractButton.IconOnly
                        text: i18n("Remove")
                        QQC2.ToolTip.text: text
                        QQC2.ToolTip.visible: hovered
                        onClicked: page.setSelected(selectedDelegate.entityId, false)
                    }
                }
            }
        }

        Kirigami.Separator {
            Layout.fillWidth: true
            Layout.topMargin: Kirigami.Units.largeSpacing
        }

        // ───────────── All entities ─────────────
        RowLayout {
            Layout.fillWidth: true
            Kirigami.Heading {
                Layout.fillWidth: true
                level: 3
                text: i18n("Available entities")
            }
            QQC2.ToolButton {
                icon.name: "view-refresh"
                text: i18n("Reload")
                display: QQC2.AbstractButton.IconOnly
                QQC2.ToolTip.text: text
                QQC2.ToolTip.visible: hovered
                enabled: page.loadState !== "loading"
                onClicked: page.loadEntities()
            }
        }

        RowLayout {
            Layout.fillWidth: true
            spacing: Kirigami.Units.smallSpacing
            enabled: page.loadState === "ok"

            Kirigami.SearchField {
                id: searchField
                Layout.fillWidth: true
                placeholderText: i18n("Search by name or entity ID…")
            }
            QQC2.ComboBox {
                id: domainBox
                Accessible.name: i18n("Domain filter")
                model: [i18n("All domains")].concat(Ha.DOMAINS)
            }
        }

        Kirigami.InlineMessage {
            Layout.fillWidth: true
            visible: page.loadState === "error" || page.loadState === "unconfigured"
            type: page.loadState === "error" ? Kirigami.MessageType.Error : Kirigami.MessageType.Information
            text: page.loadState === "error" ? page.loadError
                 : i18n("Set up the connection on the Connection page and click Apply, then come back here.")
        }

        QQC2.BusyIndicator {
            Layout.alignment: Qt.AlignHCenter
            visible: page.loadState === "loading"
            running: visible
        }

        QQC2.Label {
            Layout.fillWidth: true
            visible: page.loadState === "ok"
            opacity: 0.7
            font: Kirigami.Theme.smallFont
            text: page.filteredIds.length > page.maxResults
                  ? i18n("Showing %1 of %2 matching entities. Refine the search to see more.", page.maxResults, page.filteredIds.length)
                  : i18np("%1 matching entity", "%1 matching entities", page.filteredIds.length)
        }

        ListView {
            id: availableList
            Layout.fillWidth: true
            Layout.preferredHeight: contentHeight
            interactive: false
            visible: page.loadState === "ok"
            model: page.filteredIds.slice(0, page.maxResults)

            delegate: QQC2.CheckDelegate {
                id: availableDelegate
                required property string modelData
                readonly property var haState: page.allStates[modelData]

                width: availableList.width
                checked: page.selectedIds[modelData] === true
                onToggled: page.setSelected(modelData, checked)

                contentItem: RowLayout {
                    spacing: Kirigami.Units.largeSpacing
                    EntityIcon {
                        Layout.preferredWidth: Kirigami.Units.iconSizes.smallMedium
                        Layout.preferredHeight: Kirigami.Units.iconSizes.smallMedium
                        spec: Ha.defaultIcon(availableDelegate.modelData, availableDelegate.haState)
                        lit: Ha.isOn(availableDelegate.haState)
                        unavailable: Ha.isUnavailable(availableDelegate.haState)
                    }
                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: 0
                        QQC2.Label {
                            Layout.fillWidth: true
                            text: page.friendlyName(availableDelegate.modelData)
                            elide: Text.ElideRight
                        }
                        QQC2.Label {
                            Layout.fillWidth: true
                            text: availableDelegate.modelData
                            font: Kirigami.Theme.smallFont
                            opacity: 0.7
                            elide: Text.ElideMiddle
                        }
                    }
                    QQC2.Label {
                        text: availableDelegate.haState ? availableDelegate.haState.state : ""
                        font: Kirigami.Theme.smallFont
                        opacity: 0.7
                    }
                    // Leave room for the check indicator drawn by the style.
                    Item { Layout.preferredWidth: availableDelegate.indicator ? availableDelegate.indicator.width : 0 }
                }
            }
        }
    }
}
