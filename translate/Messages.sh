#!/bin/sh
# Extract translatable strings into translate/template.pot
# and merge them into the existing .po files.
set -e
cd "$(dirname "$0")/.."
DOMAIN="plasma_applet_io.github.cptn-cosmo.homeassistant"
find package -name '*.qml' -o -name '*.js' | sort > translate/files.txt
xgettext --from-code=UTF-8 -C --kde \
    -ci18n -ki18n:1 -ki18nc:1c,2 -ki18np:1,2 -ki18ncp:1c,2,3 \
    --package-name="$DOMAIN" --msgid-bugs-address="https://github.com/cptn-cosmo/ha-plasmoid/issues" \
    -L JavaScript -f translate/files.txt -o translate/template.pot
rm translate/files.txt
for po in translate/*.po; do
    [ -e "$po" ] || continue
    msgmerge --update --backup=none "$po" translate/template.pot
done
echo "Updated translate/template.pot"
