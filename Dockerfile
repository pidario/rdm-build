# flatpack and snap builds:
# https://github.com/flathub/dev.rdm.RDM
# https://github.com/RedisDesktop/redisdesktopmanager-snap/blob/master/snap/snapcraft.yaml

FROM centos/devtoolset-7-toolchain-centos7:latest AS dependencies
USER root
ENV QT_VER="5.15.2"
ENV PYTHON_VER="3.10.1"
ENV AQT_VER="1.2.5"
ENV PATH="/opt/${QT_VER}/gcc_64/bin:$PATH"
RUN yum -y update && \
	yum -y install epel-release yum-utils && \
	yum-builddep -y python3 && \
	yum -y install file patch wget lz4 lz4-devel libzstd-devel lzma which cmake botan libssh2 openssl11 openssl11-devel snappy-devel brotli-devel ImageMagick xcb-util xcb-util-wm xcb-util-image xcb-util-keysyms xcb-util-renderutil libxkbcommon-x11
RUN pip3 install aqtinstall==${AQT_VER} && \
	aqt install --outputdir /opt ${QT_VER} linux desktop -m qtbase qttools qtcharts qtdeclarative qtgraphicaleffects qtimageformats qtquickcontrols qtquickcontrols2 qtsvg && \
	curl -LO https://github.com/python/cpython/archive/v${PYTHON_VER}.tar.gz && \
	tar -xvf v${PYTHON_VER}.tar.gz && \
	cd cpython-${PYTHON_VER} && \
	sed -i 's/PKG_CONFIG openssl /PKG_CONFIG openssl11 /g' configure && \
	./configure --enable-optimizations --enable-shared && \
	make -j$(cat /proc/cpuinfo | grep -c processor) && \
	make install
RUN echo "/usr/local/lib" > /etc/ld.so.conf.d/py.conf && \
	echo "/opt/${QT_VER}/gcc_64/lib" > /etc/ld.so.conf.d/qt.conf
WORKDIR /rdm-build
COPY 3rdparty.patch rdm.desktop version ./

FROM dependencies
ENV GH_USER="pidario"
ENV GH_REPO="rdm-build"
ENV BASE_VER="2022"
ENV BASE="/rdm-build"
ENV REPO="${BASE}/rdm"
ENV QML_SOURCES_PATHS="${REPO}/src"
ENV APPIMAGE_EXTRACT_AND_RUN=1
ENV OUTPUT="rdm.AppImage"
ENV UPDATE_INFORMATION="zsync|https://github.com/${GH_USER}/${GH_REPO}/releases/latest/download/rdm.AppImage.zsync"
RUN ldconfig && \
	version="$(cat version)" && \
	git clone --branch "$version" --recursive git://github.com/uglide/RedisDesktopManager.git rdm && \
	cd ${REPO} && \
	rdm_version="$(git describe --abbrev=0 --tags)+$(git rev-parse --short HEAD)" && \
	cd "${REPO}/3rdparty" && \
	patch -i ${BASE}/3rdparty.patch && \
	cd "${REPO}/src" && \
	lrelease resp.pro && \
	sed -i "s/${BASE_VER}\\.[[:digit:]]\.0\-dev/$rdm_version/g" resp.pro && \
	qmake && make -j$(cat /proc/cpuinfo | grep -c processor) && \
	mkdir -p "${BASE}/artifacts" && \
	mv "${REPO}/bin/linux/release/resp" "${REPO}/bin/linux/release/rdm" && \
	cp "${REPO}/bin/linux/release/rdm" "${BASE}/artifacts/rdm-$rdm_version" && \
	cd "${BASE}" && \
	curl -fsSOL https://github.com/linuxdeploy/linuxdeploy/releases/download/continuous/linuxdeploy-x86_64.AppImage && \
	curl -fsSOL https://github.com/linuxdeploy/linuxdeploy-plugin-qt/releases/download/continuous/linuxdeploy-plugin-qt-x86_64.AppImage && \
	chmod +x "${BASE}"/linuxdeploy*.AppImage && \
	convert "${REPO}/src/resources/images/rdm.png" -resize 512x512 "${BASE}/rdm.png" && \
	./linuxdeploy-x86_64.AppImage --appdir AppDir -e "${REPO}/bin/linux/release/rdm" -d "${BASE}/rdm.desktop" -i "${BASE}/rdm.png" -p qt --output appimage && \
	cp "${BASE}/rdm.AppImage" "${BASE}/rdm.AppImage.zsync" "${BASE}/artifacts/" && \
	echo $rdm_version
