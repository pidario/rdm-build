FROM archlinux:latest
RUN pacman --noconfirm --needed -Syu fakeroot sudo openssh git botan libssh2 lz4 cmake make gcc python python-pip qt5-base qt5-tools qt5-charts qt5-declarative qt5-graphicaleffects qt5-imageformats qt5-quickcontrols qt5-quickcontrols2 qt5-svg imagemagick
WORKDIR /rdm-build
COPY . ./
ENTRYPOINT ./build.sh
