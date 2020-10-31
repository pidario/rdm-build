#!/bin/sh

# artifacts:
# raw binary file: $repo/bin/linux/release/rdm
# AppImage: $base/rdm.AppImage
# AppImage zsync: $base/rdm.AppImage.zsync

# ext. variables:
# SSH_KEY
# TAG
# GITHUB_TOKEN
# GH_USER
# GH_REPO
# EMAIL
# MAINTAINER

# info on build:
# https://github.com/RedisDesktop/redisdesktopmanager-snap/blob/master/snap/snapcraft.yaml

# docker build -t rdm-build .
# docker run -t --rm -e SSH_KEY="$(cat ~/.ssh/id_rsa)" -e TAG=$tag -e GITHUB_TOKEN=$gh_token -e GH_USER=$gh_user -e GH_REPO=$gh_repo -e MAINTAINER="John Doe <john.doe at example dot com>" rdm-build

set -eu
base=$HOME/rdm-build
repo=$base/rdm

echo "$SSH_KEY" > $HOME/.ssh/id_rsa
chmod 600 $HOME/.ssh/id_rsa
ssh-keyscan -H aur.archlinux.org >> $HOME/.ssh/known_hosts

export QML_SOURCES_PATHS=$repo/src
export APPIMAGE_EXTRACT_AND_RUN=1
export OUTPUT=rdm.AppImage
export UPDATE_INFORMATION="zsync|https://github.com/$GH_USER/$GH_REPO/releases/latest/download/rdm.AppImage.zsync"

# build
git clone --branch $TAG git://github.com/uglide/RedisDesktopManager.git rdm
pushd $repo
rdm_version="$(git describe --abbrev=0 --tags)+$(git rev-parse --short HEAD)"
echo $rdm_version
git submodule update --init --recursive
popd
pushd $repo/src/py && pip install -r requirements.txt && popd
pushd $repo/3rdparty/lz4/build/cmake && cmake -DBUILD_STATIC_LIBS=true . && make && popd
pushd $repo/src
lrelease rdm.pro
sed -i "s/2020\.[[:digit:]]\.0\-dev/$rdm_version/g" rdm.pro
rm -rf $repo/bin
qmake && make
popd

# appimage build
pushd $base
curl -fsSOL https://github.com/linuxdeploy/linuxdeploy/releases/download/continuous/linuxdeploy-x86_64.AppImage
curl -fsSOL https://github.com/linuxdeploy/linuxdeploy-plugin-qt/releases/download/continuous/linuxdeploy-plugin-qt-x86_64.AppImage
chmod +x $base/linuxdeploy*.AppImage
convert $repo/src/resources/images/rdm.png -resize 512x512 $base/rdm.png
./linuxdeploy-x86_64.AppImage --appdir AppDir -e $repo/bin/linux/release/rdm -d $base/rdm.desktop -i $base/rdm.png -p qt -l /usr/lib/libbotan-2.so -l /usr/lib/libssh2.so --output appimage

# copy artifacts
cp $repo/bin/linux/release/rdm $base/rdm.AppImage $base/rdm.AppImage.zsync $base/artifacts/

# github release
curl -fsSOL https://github.com/tcnksm/ghr/releases/download/v0.13.0/ghr_v0.13.0_linux_amd64.tar.gz
tar -zxvf ghr_v0.13.0_linux_amd64.tar.gz
ghr_v0.13.0_linux_amd64/ghr -t $GITHUB_TOKEN -u $GH_USER -r $GH_REPO -delete $TAG $base/artifacts

# aur release
git clone ssh://aur@aur.archlinux.org/rdm-bin.git
pushd rdm-bin
git config user.email $EMAIL
git config user.name $GH_USER
rm -f PKGBUILD .SRCINFO rdm.desktop
checksum=`sha256sum $base/rdm.desktop | awk '{print $1}'`
cat <<EOT >> PKGBUILD
# Maintainer: $MAINTAINER

pkgname=rdm-bin
pkgver=$TAG
pkgrel=1
pkgdesc='Cross-platform open source database management tool for Redis ®'
arch=('x86_64')
url="https://rdm.dev/"
license=('GPL3')
depends=(
  'botan'
  'libssh2'
  'python'
  'qt5-base'
  'qt5-imageformats'
  'qt5-tools'
  'qt5-declarative'
  'qt5-quickcontrols'
  'qt5-quickcontrols2'
  'qt5-charts'
  'qt5-graphicaleffects'
  'qt5-svg')
makedepends=('curl')
conflicts=('redis-desktop-manager-bin' 'redis-desktop-manager')

source=('rdm.desktop')
sha256sums=('SKIP'
            '$checksum')

prepare() {
  curl -fsSOL https://github.com/$GH_USER/$GH_REPO/releases/download/\${pkgver}/rdm
  curl -fsSOL https://github.com/uglide/RedisDesktopManager/blob/2020/src/resources/images/rdm.png
}

build() {
  echo "skipping build"
}

package() {
  _bindir="\$pkgdir/usr/bin"
  _pixdir="\$pkgdir/usr/share/pixmaps"
  _appdir="\$pkgdir/usr/share/applications"

  mkdir -p "\${_bindir}"
  mkdir -p "\${_pixdir}"
  mkdir -p "\${_appdir}"

  install -Dm755 "\$srcdir/rdm" "\${_bindir}/rdm"
  install -Dm644 "\$srcdir/rdm.png" "\${_pixdir}/rdm.png"
  install -Dm644 "\$srcdir/rdm.desktop" "\${_appdir}/rdm.desktop"
}
EOT
makepkg --printsrcinfo > .SRCINFO
cp $base/rdm.desktop ./
git add PKGBUILD .SRCINFO rdm.desktop
git commit -m "release $TAG"
git push
