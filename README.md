# Home Assistant for Plasma

A KDE Plasma 6 widget (plasmoid) that puts your Home Assistant lights, switches,
fans, covers and more into the panel or onto the desktop.

> 📸 *Screenshots coming soon.*
<!-- Add docs/screenshots/panel.png and docs/screenshots/config.png, then:
![Panel and popup](docs/screenshots/panel.png)
![Settings](docs/screenshots/config.png) -->

## Features

- **Panel buttons**: pin entities to the panel as icon-only buttons. Click to toggle,
  scroll to dim, hover for name and state.
- **Popup list**: the full list with icon, name, state, an on/off switch and a
  brightness slider for dimmable lights.
- **Smart toggle**: with nothing pinned, the panel shows the Home Assistant logo. With
  entities pinned, it shows a small chevron at the end of the row. The chevron follows the
  panel edge and flips when the popup opens.
- **Live updates** over the Home Assistant WebSocket API (`subscribe_events` /
  `state_changed`), with automatic reconnect (exponential backoff, ping/pong
  health check) and REST polling while the socket is down.
- **Mouse wheel brightness**: ±5 % per notch (configurable) on lights that support
  brightness, with an on-icon overlay. Rapid scrolling is debounced into a single service
  call. On entities without brightness, the scroll passes through to the panel.
- **Visual state**: on = highlight colour, off = dimmed, unavailable = greyed out with
  a tooltip.
- **Icons**: 22 bundled monochrome home icons (ceiling light, floor lamp, desk lamp,
  bulb, light strip, switch, plug, fan, blinds, curtains, TV, speaker, thermostat,
  lock, door, garage, …) plus a Home Assistant logo. They are drawn in the
  current Plasma colour scheme. You can also use any icon from your icon theme or a
  custom SVG/PNG file.
- **Per-entity settings**: display name, icon and placement (*panel only*,
  *list only* or *panel and list*). Reorder entities by dragging.
- **Secure token storage** in KWallet. If KWallet is unavailable, the token falls back to
  the plasmoid config, with a visible warning.
- Horizontal panels, vertical panels and the desktop are supported. All strings are
  translatable, and errors and offline states are handled.

## Requirements

- Plasma 6.0 or newer (libplasma, Kirigami, KCMUtils, KIconThemes, Plasma5Support)
- Qt 6 with the `QtWebSockets` QML module (Arch: `qt6-websockets`,
  Debian/Ubuntu: `qml6-module-qtwebsockets`, Fedora: `qt6-qtwebsockets`)
- `kwallet-query` (part of KWallet) for secure token storage
- Optional: `qdbus6` (to create the KWallet folder when it is missing)

## Installation

### Arch Linux

A `PKGBUILD` is included:

```sh
git clone https://github.com/cptn-cosmo/ha-plasmoid.git
cd ha-plasmoid
updpkgsums          # fills in the checksum of the release tarball
makepkg -si
```

This installs the widget system-wide to
`/usr/share/plasma/plasmoids/io.github.cptn-cosmo.homeassistant`.

### Other distributions (per-user install)

```sh
git clone https://github.com/cptn-cosmo/ha-plasmoid.git
cd ha-plasmoid
sh translate/build.sh                     # optional: compile translations
kpackagetool6 --type Plasma/Applet --install package
```

To upgrade later: `kpackagetool6 --type Plasma/Applet --upgrade package`.
To remove: `kpackagetool6 --type Plasma/Applet --remove io.github.cptn-cosmo.homeassistant`.

If the widget doesn't show up in *Add Widgets…* right away, restart Plasma:
`systemctl --user restart plasma-plasmashell`.

Then right-click the panel → *Add Widgets…* → search for **Home Assistant**.

## Configuration

### 1. Create a long-lived access token

1. Open Home Assistant in a browser and log in.
2. Click your user name at the bottom left to open your **Profile**.
3. Switch to the **Security** tab.
4. Scroll to **Long-lived access tokens** and click **Create token**.
5. Give it a name such as `Plasma widget` and copy the token. Home Assistant shows
   it only once.

Tip: the settings page has an **Open Token Page** button that goes straight to
`<your URL>/profile/security`.

### 2. Connection page

Right-click the widget → *Configure Home Assistant…*

| Setting | Description |
|---|---|
| Home Assistant URL | e.g. `http://homeassistant.local:8123` or `https://ha.example.com` |
| Access token | the long-lived token. It is stored in KWallet (folder *Passwords*, entry `plasma-applet-homeassistant`) |
| Test Connection | calls `GET /api/` and reports success, a bad URL, an invalid token or a timeout |
| Fallback polling interval | how often to poll `/api/states` while the WebSocket is down |
| Brightness per scroll step | percent per mouse wheel notch (default 5 %) |

### 3. Entities page

- **Available entities** lists every entity in Home Assistant. Search by name or ID and
  filter by domain (light, switch, input_boolean, fan, cover, …). Tick an entity to add it.
- **Shown entities** lists your selection. For each entity you can:
  - drag the handle to reorder,
  - click the icon to pick a bundled icon, a theme icon or an image file,
  - type a display name (leave empty to use Home Assistant's friendly name),
  - choose the placement: *Panel and list*, *Panel only* or *List only*.

## Usage

| Action | Effect |
|---|---|
| Left-click an entity | toggle it. Uses the domain service, e.g. `light.toggle`, `cover.toggle`, `lock.lock`/`unlock`, `scene.turn_on`, `button.press`; otherwise `homeassistant.toggle` |
| Mouse wheel over a dimmable light | brightness ±step via `light.turn_on` with `brightness_pct`. Scrolling to 0 turns the light off |
| Mouse wheel over anything else | passed through (scrolls the list / panel) |
| Click the HA logo or chevron | open or close the popup |
| Right-click the widget | *Refresh*, *Open Home Assistant*, *Configure…* |

## How it works

- `contents/ui/HaClient.qml`: WebSocket client (auth → `subscribe_events` →
  `get_states`), reconnect with backoff, ping every 30 s, REST polling fallback.
- `contents/ui/HaRest.qml`: asynchronous `XMLHttpRequest` wrapper with timeouts and
  error classification. Nothing blocks the UI thread.
- `contents/ui/EntityLogic.qml`: per-entity state, toggle, debounced brightness
  (250 ms) with optimistic UI.
- `contents/ui/Wallet.qml` + `contents/code/wallet.sh`: asynchronous KWallet access
  through `kwallet-query`, run by the Plasma5Support *executable* engine.

### Security notes

- The token is never written to the Plasma config while KWallet works.
- A pure-QML widget can't talk to KWallet directly. Saving the token therefore runs
  `kwallet-query` through a short-lived shell, and the token is part of that shell's
  command line for a few milliseconds. On multi-user machines, other local users could
  in theory read it from `/proc` in that window. Mount `/proc` with `hidepid=2` if that
  matters to you. Reading the token does not expose it this way. The token is checked
  to contain only JWT characters before it reaches the shell.
- Use `https://` when Home Assistant is reachable from outside your LAN.
  Self-signed certificates must be trusted by the system for Qt to accept them.

## Development

```sh
python3 tools/mock_ha.py --port 8123          # fake Home Assistant (needs aiohttp)
# token: dev-token-0123456789abcdefghij
kpackagetool6 -t Plasma/Applet --install package   # or --upgrade
plasmawindowed io.github.cptn-cosmo.homeassistant
```

- `python3 tools/gen-icons.py` regenerates the bundled icons and `contents/code/icons.js`.
- `sh translate/Messages.sh` updates `translate/template.pot`. To add a language, copy it
  to `translate/<lang>.po`, translate it, and build with `sh translate/build.sh`.

## Roadmap

- Configurable actions per entity: middle-click, right-click menu, and wheel for
  fan speed or cover position. The entity config already reserves an `actions` field.
- Colour and colour-temperature controls in the popup.
- Groups and areas as sections in the popup.

## License

GPL-3.0-or-later. See [LICENSE](LICENSE).

Home Assistant is a trademark of the Open Home Foundation. This project is not
affiliated with or endorsed by Home Assistant.
