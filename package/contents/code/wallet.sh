#!/bin/sh
# KWallet helper for the Home Assistant plasmoid.
#
#   wallet.sh read          print the stored token (empty output if none)
#   wallet.sh write         store the token read from stdin
#   wallet.sh check         exit 0 if KWallet is usable
#
# Exit codes: 0 ok, 10 kwallet-query missing, 11 KWallet disabled,
#             12 wallet could not be opened / read / written.

ENTRY="plasma-applet-homeassistant"
FOLDER="Passwords"
APPID="Home Assistant Plasmoid"

command -v kwallet-query >/dev/null 2>&1 || exit 10

READCFG=$(command -v kreadconfig6 || command -v kreadconfig5)
if [ -n "$READCFG" ]; then
    enabled=$("$READCFG" --file kwalletrc --group Wallet --key Enabled --default true 2>/dev/null)
    [ "$enabled" = "false" ] && exit 11
    WALLET=$("$READCFG" --file kwalletrc --group Wallet --key "Default Wallet" --default kdewallet 2>/dev/null)
fi
[ -n "$WALLET" ] || WALLET=kdewallet

ensure_folder() {
    QDBUS=$(command -v qdbus6 || command -v qdbus-qt6 || command -v qdbus)
    [ -n "$QDBUS" ] || return 0
    handle=$("$QDBUS" org.kde.kwalletd6 /modules/kwalletd6 org.kde.KWallet.open "$WALLET" 0 "$APPID" 2>/dev/null) || return 0
    [ "$handle" -ge 0 ] 2>/dev/null || return 0
    "$QDBUS" org.kde.kwalletd6 /modules/kwalletd6 org.kde.KWallet.createFolder "$handle" "$FOLDER" "$APPID" >/dev/null 2>&1
    return 0
}

case "$1" in
    read)
        # No entry yet is not an error: print nothing.
        if ! kwallet-query -f "$FOLDER" -l "$WALLET" 2>/dev/null | grep -qxF "$ENTRY"; then
            exit 0
        fi
        kwallet-query -f "$FOLDER" -r "$ENTRY" "$WALLET" 2>/dev/null || exit 12
        ;;
    write)
        ensure_folder
        kwallet-query -f "$FOLDER" -w "$ENTRY" "$WALLET" >/dev/null 2>&1 || exit 12
        ;;
    check)
        kwallet-query -f "$FOLDER" -l "$WALLET" >/dev/null 2>&1 || { ensure_folder; kwallet-query -f "$FOLDER" -l "$WALLET" >/dev/null 2>&1 || exit 12; }
        ;;
    *)
        echo "usage: $0 read|write|check" >&2
        exit 2
        ;;
esac
