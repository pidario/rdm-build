FROM centos/devtoolset-7-toolchain-centos7:latest
USER root
RUN yum -y update && \
	yum -y install epel-release && \
	#yum -y groupinstall "Development Tools" && \
	yum -y install yum-utils wget lz4 lzma which cmake botan libssh2 ImageMagick xcb-util xcb-util-wm xcb-util-image xcb-util-keysyms xcb-util-renderutil libxkbcommon-x11 && \
	yum-builddep -y python3
RUN curl -LO https://github.com/python/cpython/archive/v3.9.1.tar.gz && \
	tar xvf v3.9.1.tar.gz && \
	cd cpython-3.9.1 && \
	./configure --enable-optimizations --enable-shared && \
	make -j`cat /proc/cpuinfo | grep -c processor` && \
	make install
RUN echo 'export PATH=/opt/5.15.2/gcc_64/bin:$PATH' >> /root/.bash_profile && \
    echo '/usr/local/lib' > /etc/ld.so.conf.d/py.conf && \
    echo '/opt/5.15.2/gcc_64/lib' > /etc/ld.so.conf.d/qt.conf && \
    ldconfig
RUN pip3 install aqtinstall && \
    aqt install --outputdir /opt 5.15.2 linux desktop -m qtbase qttools qtcharts qtdeclarative qtgraphicaleffects qtimageformats qtquickcontrols qtquickcontrols2 qtsvg
WORKDIR /rdm-build
COPY . ./
ENTRYPOINT ./build.sh
