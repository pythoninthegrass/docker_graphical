# syntax=docker/dockerfile:1.6

FROM ubuntu:20.04 AS base

WORKDIR /root

ENV DEBIAN_FRONTEND="noninteractive"

RUN sed -i '/^#\sdeb-src /s/^#//' "/etc/apt/sources.list"

RUN apt-get update \
    && apt-get install -y --no-install-recommends \
        build-essential \
        dpkg-dev \
        git \
        libpulse-dev \
    && apt-get build-dep -y pulseaudio \
    && apt-get source pulseaudio \
    && rm -rf \
        /var/lib/apt/lists/* \
        /var/tmp/* \
        /tmp/*

RUN cd pulseaudio-* \
    && ./configure

RUN git clone https://github.com/neutrinolabs/pulseaudio-module-xrdp.git xrdp-module \
    && cd xrdp-module \
    && ./bootstrap \
    && ./configure PULSE_DIR=$(cd /root/pulseaudio-* && pwd) \
    && make \
    && make install \
    && cp $(pkg-config --variable=modlibexecdir libpulse)/module-xrdp-* /root/

# TODO: setup more stages
FROM ubuntu:20.04 as runner

ENV TERM xterm
ENV DEBIAN_FRONTEND="teletype"
ENV LANG="en_US.UTF-8"
ENV LANGUAGE="en_US:en"
ENV LC_ALL="en_US.UTF-8"

RUN rm /etc/dpkg/dpkg.cfg.d/excludes \
    && rm /etc/apt/apt.conf.d/docker-* \
    && echo y | unminimize \
    && apt-get update \
    && apt-get install -y --no-install-recommends locales \
    && locale-gen en_US.UTF-8 \
    && rm -rf /var/lib/apt/lists/*

ENV DEBIAN_FRONTEND="noninteractive"

RUN apt-get update && apt-get install -y --no-install-recommends \
    apt-transport-https \
    busybox-syslogd \
    bzip2 \
    ca-certificates \
    command-not-found \
    cron \
    curl \
    dbus-x11 \
    dialog \
    dropbear-bin \
    firefox \
    flatpak \
    fonts-vlgothic \
    git \
    gstreamer1.0-alsa \
    gstreamer1.0-gl \
    gstreamer1.0-gtk3 \
    gstreamer1.0-libav \
    gstreamer1.0-plugins-bad \
    gstreamer1.0-plugins-base \
    gstreamer1.0-plugins-good \
    gstreamer1.0-plugins-ugly \
    gstreamer1.0-pulseaudio \
    gstreamer1.0-qt5 \
    gstreamer1.0-tools \
    gstreamer1.0-vaapi \
    gstreamer1.0-x \
    imagemagick \
    jq \
    language-pack-en \
    less \
    libdbus-1-3 \
    libegl1 \
    libgstreamer1.0-0 \
    libgtk-3-0 \
    libgtk2.0-0 \
    libncursesw5 \
    libopenal1 \
    libsdl-image1.2 \
    libsdl-ttf2.0-0 \
    libsdl1.2debian \
    libsdl2-2.0-0 \
    libsndfile1 \
    logrotate \
    lxde-core \
    lxde-icon-theme \
    lxterminal \
    mlocate \
    msttcorefonts \
    net-tools \
    p7zip-full \
    patch \
    pavumeter \
    pciutils \
    pkg-config \
    procps \
    psmisc \
    psutils \
    pulseaudio \
    python3 \
    python3-numpy \
    python3-pip \
    python3-setuptools \
    python3-venv \
    rsync \
    screen \
    software-properties-common \
    sudo \
    supervisor \
    ucspi-tcp \
    unzip \
    vim-tiny \
    wget \
    xdg-utils \
    xmlstarlet \
    xorgxrdp \
    xrdp \
    xz-utils \
    && apt-get autoclean \
    && apt-get autoremove \
    && rm -rf \
        /var/lib/apt/lists/* \
        /var/tmp/* \
        /tmp/*

RUN update-locale LANG=en_US.UTF-8 LC_CTYPE=en_US.UTF-8

RUN echo "**** Configure flatpak ****" \
    && flatpak remote-add flathub https://flathub.org/repo/flathub.flatpakrepo \
    && dpkg-statoverride --update --add root root 0755 /usr/bin/bwrap

# Setup video streaming deps
RUN echo "**** Update apt database ****" \
    && apt-get update \
    && echo "**** Install Intel media drivers and VAAPI ****" \
    && apt-get install -y --no-install-recommends \
        intel-media-va-driver-non-free \
        i965-va-driver-shaders \
        libva2 \
    && echo "**** Section cleanup ****" \
    && apt-get clean autoclean -y \
    && apt-get autoremove -y \
    && rm -rf \
        /var/lib/apt/lists/* \
        /var/tmp/* \
        /tmp/*

# Install tools for monitoring hardware
RUN echo "**** Update apt database ****" \
    && apt-get update \
    && echo "**** Install useful HW monitoring tools ****" \
    && apt-get install -y --no-install-recommends \
        cpu-x \
        htop \
        vainfo \
        vdpauinfo \
    && echo "**** Section cleanup ****" \
    && apt-get clean autoclean -y \
    && apt-get autoremove -y \
    && rm -rf \
        /var/lib/apt/lists/* \
        /var/tmp/* \
        /tmp/*

# Install Sunshine
COPY --from=lizardbyte/sunshine:v0.22.2-ubuntu-20.04 /sunshine.deb /usr/src/sunshine.deb
RUN echo "**** Update apt database ****" \
    && apt-get update \
    && echo "**** Install Sunshine requirements ****" \
    && apt-get install -y --no-install-recommends \
        va-driver-all \
    && echo "**** Install Sunshine ****" \
    && apt-get install -y --no-install-recommends \
        /usr/src/sunshine.deb \
    && echo "**** Section cleanup ****" \
    && apt-get clean autoclean -y \
    && apt-get autoremove -y \
    && rm -rf \
        /var/lib/apt/lists/* \
        /var/tmp/* \
        /tmp/*

# Install Steam
RUN echo "**** Update apt database ****" \
    && dpkg --add-architecture i386 \
    && apt-get update \
    && echo "**** Install Steam ****" \
    && apt-get install -y --no-install-recommends \
        steam-installer \
    && ln -sf /usr/games/steam /usr/bin/steam \
    && echo "**** Section cleanup ****" \
    && apt-get clean autoclean -y \
    && apt-get autoremove -y \
    && rm -rf \
        /var/lib/apt/lists/* \
        /var/tmp/* \
        /tmp/*

# Various other tools
ARG DUMB_INIT_VERSION=1.2.5
ARG DUMB_UDEV_VERSION=64d1427
RUN echo "**** Install dumb-init ****" \
    && wget --no-check-certificate \
        --no-cookies \
        --quiet \
        -O /usr/bin/dumb-init \
        https://github.com/Yelp/dumb-init/releases/download/v${DUMB_INIT_VERSION}/dumb-init_${DUMB_INIT_VERSION}_x86_64 \
    && chmod +x /usr/bin/dumb-init \
    && echo "**** Install dumb-udev ****" \
    && python3 -m pip install \
        --pre \
        --upgrade \
        --no-cache-dir \
        git+https://github.com/Steam-Headless/dumb-udev.git@${DUMB_UDEV_VERSION}

COPY --from=base /root/module-xrdp-sink.so /var/lib/xrdp-pulseaudio-installer/
COPY --from=base /root/module-xrdp-source.so /var/lib/xrdp-pulseaudio-installer/
COPY ./bootstrap.sh /usr/bin/bootstrap.sh
COPY ./init/ /etc/cont-init.d/
COPY ./supervisord.conf /etc/supervisor/supervisord.conf

RUN bash /usr/bin/bootstrap.sh

ARG USER_NAME=${USER_NAME:-appuser}
ARG USER_UID=1000
ARG USER_GID=$USER_UID
ENV HOME /home/${USER_NAME}

RUN groupadd --gid $USER_GID $USER_NAME \
    && useradd --uid $USER_UID \
        --gid $USER_GID \
        -m -d $HOME $USER_NAME \
    && echo $USER_NAME ALL=\(root\) NOPASSWD:ALL > /etc/sudoers.d/$USER_NAME \
    && chmod 0440 /etc/sudoers.d/$USER_NAME

USER ${USER_NAME}

EXPOSE 22/tcp
EXPOSE 3389/tcp

# CMD ["/usr/bin/entrypoint.sh"]
ENTRYPOINT [ "/usr/bin/supervisord" ]
CMD ["-c", "/etc/supervisor/supervisord.conf"]

LABEL org.opencontainers.image.source=https://github.com/pythoninthegrass/docker_graphical
LABEL org.opencontainers.image.description="Docker container with Firefox, SSH server, and RDP support"
LABEL org.opencontainers.image.licenses=Unlicense
