#!/bin/sh

# artifacts:
# raw binary file: $repo/bin/linux/release/rdm
# AppImage: $base/rdm.AppImage
# AppImage zsync: $base/rdm.AppImage.zsync

# ext. variables:
# TAG
# GH_USER
# GH_REPO

# info on build:
# https://github.com/RedisDesktop/redisdesktopmanager-snap/blob/master/snap/snapcraft.yaml

# mkdir -p artifacts
# docker build -t rdm-build .
# docker run -t --rm -v $(pwd)/artifacts:/rdm-build/artifacts -e TAG=$tag -e GH_USER=$gh_user -e GH_REPO=$gh_repo rdm-build

set -eu

source /root/.bash_profile
ldconfig -v

base=/rdm-build
repo=$base/rdm

export QML_SOURCES_PATHS=$repo/src
export APPIMAGE_EXTRACT_AND_RUN=1
export OUTPUT=rdm.AppImage
export UPDATE_INFORMATION="zsync|https://github.com/$GH_USER/$GH_REPO/releases/latest/download/rdm.AppImage.zsync"

# build
git clone --branch $TAG --recursive git://github.com/uglide/RedisDesktopManager.git rdm
pushd $repo
rdm_version="$(git describe --abbrev=0 --tags)+$(git rev-parse --short HEAD)"
popd
pushd $repo/src/py && pip3 install -r requirements.txt && popd
pushd $repo/3rdparty/lz4/build/cmake && cmake -DBUILD_STATIC_LIBS=true . && make && popd
pushd $repo/src
lrelease rdm.pro
sed -i "s/2021\.[[:digit:]]\.0\-dev/$rdm_version/g" rdm.pro
rm -rf $repo/bin
qmake && make -j`cat /proc/cpuinfo | grep -c processor`
popd

# appimage build
pushd $base
curl -fsSOL https://github.com/linuxdeploy/linuxdeploy/releases/download/continuous/linuxdeploy-x86_64.AppImage
curl -fsSOL https://github.com/linuxdeploy/linuxdeploy-plugin-qt/releases/download/continuous/linuxdeploy-plugin-qt-x86_64.AppImage
chmod +x $base/linuxdeploy*.AppImage
convert $repo/src/resources/images/rdm.png -resize 512x512 $base/rdm.png
./linuxdeploy-x86_64.AppImage --appdir AppDir -e $repo/bin/linux/release/rdm -d $base/rdm.desktop -i $base/rdm.png -p qt --output appimage

# copy artifacts
cp $repo/bin/linux/release/rdm $base/artifacts/rdm-$rdm_version
cp $base/rdm.AppImage $base/rdm.AppImage.zsync $base/artifacts/

echo $rdm_version
