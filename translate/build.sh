#!/bin/sh
# Compile translate/<lang>.po into package/contents/locale/<lang>/LC_MESSAGES/*.mo
set -e
cd "$(dirname "$0")/.."
DOMAIN="plasma_applet_io.github.cptn-cosmo.homeassistant"
for po in translate/*.po; do
    [ -e "$po" ] || continue
    lang=$(basename "$po" .po)
    mkdir -p "package/contents/locale/$lang/LC_MESSAGES"
    msgfmt -o "package/contents/locale/$lang/LC_MESSAGES/$DOMAIN.mo" "$po"
    echo "built $lang"
done
