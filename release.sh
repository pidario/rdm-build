#!/bin/sh

# ext. variables:
# TAG
# VER
# GITHUB_TOKEN
# GH_USER
# GH_REPO
# EMAIL
# MAINTAINER

set -eu

# github release
curl -fsSOL https://github.com/tcnksm/ghr/releases/download/v0.13.0/ghr_v0.13.0_linux_amd64.tar.gz
tar -zxvf ghr_v0.13.0_linux_amd64.tar.gz
ghr_v0.13.0_linux_amd64/ghr -t $GITHUB_TOKEN -u $GH_USER -r $GH_REPO -delete $TAG ./artifacts

# aur release
ssh-keyscan -H aur.archlinux.org >> $HOME/.ssh/known_hosts
git clone ssh://aur@aur.archlinux.org/rdm-bin.git
pushd rdm-bin
git config user.email $EMAIL
git config user.name $GH_USER
rm -f PKGBUILD .SRCINFO rdm.desktop
cp ../rdm.desktop ./
checksum=`sha256sum ./rdm.desktop | awk '{print $1}'`
checksum_bin=`sha256sum ../artifacts/rdm-$VER | awk '{print $1}'`
cat <<EOT >> PKGBUILD
# Maintainer: $MAINTAINER

pkgname=rdm-bin
pkgver=$TAG
pkgrel=1
pkgdesc='Cross-platform open source database management tool for Redis ®'
arch=('x86_64')
url="https://resp.app/"
license=('GPL3')
depends=(
  'qt5-charts'
  'qt5-quickcontrols'
  'qt5-quickcontrols2'
  'qt5-svg'
  'brotli'
  'python'
  'snappy'
)
conflicts=('redis-desktop-manager-bin' 'redis-desktop-manager')
provides=('rdm' 'resp')
source=('rdm.desktop'
        "https://github.com/pidario/rdm-build/releases/download/\${pkgver}/rdm-$VER"
        'https://raw.githubusercontent.com/uglide/RedisDesktopManager/2022/src/resources/images/resp.png')
sha256sums=('$checksum'
            '$checksum_bin'
            'SKIP')

package() {
  _bindir="\$pkgdir/usr/bin"
  _pixdir="\$pkgdir/usr/share/pixmaps"
  _appdir="\$pkgdir/usr/share/applications"

  mkdir -p "\${_bindir}"
  mkdir -p "\${_pixdir}"
  mkdir -p "\${_appdir}"

  install -Dm755 "\$srcdir/rdm-$VER" "\${_bindir}/rdm"
  install -Dm644 "\$srcdir/resp.png" "\${_pixdir}/rdm.png"
  install -Dm644 "\$srcdir/rdm.desktop" "\${_appdir}/rdm.desktop"
}
EOT
makepkg --printsrcinfo > .SRCINFO
git add PKGBUILD .SRCINFO rdm.desktop
git commit -m "release $TAG"
git push
popd
