# Maintainer: cptn-cosmo <cosmo@geeks.gay>

pkgname=plasma6-applets-homeassistant
_pluginid=io.github.cptn-cosmo.homeassistant
pkgver=0.1.1
pkgrel=1
pkgdesc="Plasma 6 widget to control Home Assistant lights, switches and more from the panel"
arch=('any')
url="https://github.com/cptn-cosmo/ha-plasmoid"
license=('GPL-3.0-or-later')
depends=(
  'bash'
  'plasma-workspace'
  'libplasma'
  'plasma5support'
  'kirigami'
  'kcmutils'
  'kiconthemes'
  'kconfig'
  'kwallet'
  'qt6-declarative'
  'qt6-websockets'
)
makedepends=('gettext')
optdepends=('qt6-tools: qdbus6, used to create the KWallet folder if it is missing')
source=("$pkgname-$pkgver.tar.gz::$url/archive/refs/tags/v$pkgver.tar.gz")
sha256sums=('ac6420800af7f605186e6a59fe2b64be7557837057388cda7f8714ac57bba7e4')

build() {
  cd "ha-plasmoid-$pkgver"
  sh translate/build.sh
}

package() {
  cd "ha-plasmoid-$pkgver"
  local dest="$pkgdir/usr/share/plasma/plasmoids/$_pluginid"
  install -dm755 "$dest"
  cp -r --no-preserve=ownership package/. "$dest/"
  find "$dest" -type d -exec chmod 755 {} +
  find "$dest" -type f -exec chmod 644 {} +
  chmod 755 "$dest/contents/code/wallet.sh"
  install -Dm644 README.md "$pkgdir/usr/share/doc/$pkgname/README.md"
}
