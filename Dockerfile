# syntax=docker/dockerfile:1.6

FROM ubuntu:20.04 AS builder

ENV DEBIAN_FRONTEND="noninteractive"

# enable source repositories
RUN sed -i '/^#\sdeb-src /s/^#//' "/etc/apt/sources.list"

WORKDIR /root

# install build dependencies for pulseaudio and clone xrdp-module
RUN apt-get update \
    && apt-get install -y --no-install-recommends \
        build-essential \
        dpkg-dev \
        git \
        libpulse-dev \
    && apt-get build-dep -y pulseaudio \
    && apt-get source pulseaudio \
    && git clone https://github.com/neutrinolabs/pulseaudio-module-xrdp.git xrdp-module \
    && rm -rf /var/lib/apt/lists/*

# configure pulseaudio and xrdp-module
RUN cd pulseaudio-* \
    && ./configure \
    && cd ../xrdp-module \
    && ./bootstrap \
    && ./configure PULSE_DIR=$(cd ../pulseaudio-* && pwd)

# build xrdp-module
RUN cd xrdp-module \
    && make \
    && make install \
    && cp $(pkg-config --variable=modlibexecdir libpulse)/module-xrdp-* /root/

FROM ubuntu:20.04 AS runner

ENV DEBIAN_FRONTEND="noninteractive"

# Copy built xrdp-module from previous stage
COPY --from=builder /root/module-xrdp-sink.so /var/lib/xrdp-pulseaudio-installer/
COPY --from=builder /root/module-xrdp-source.so /var/lib/xrdp-pulseaudio-installer/

# install necessary packages
RUN apt-get update \
    && apt-get install -y --no-install-recommends \
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
    && rm -rf /var/lib/apt/lists/*

# install additional dependencies for video streaming
RUN apt-get update \
    && apt-get install -y --no-install-recommends \
        intel-media-va-driver-non-free \
        i965-va-driver-shaders \
        libva2 \
    && apt-get clean autoclean -y \
    && apt-get autoremove -y \
    && rm -rf /var/lib/apt/lists/*

# install hardware monitoring tools
RUN apt-get update \
    && apt-get install -y --no-install-recommends \
        cpu-x \
        htop \
        vainfo \
        vdpauinfo \
        && apt-get clean autoclean -y \
        && apt-get autoremove -y \
        && rm -rf \
        /var/lib/apt/lists/* \
        /var/tmp/* \
        /tmp/*

# Install Sunshine
COPY --from=lizardbyte/sunshine:v0.22.2-ubuntu-20.04 /sunshine.deb /usr/src/sunshine.deb
RUN echo "**** Install Sunshine requirements ****" \
    && apt-get update \
    && apt-get install -y --no-install-recommends \
        va-driver-all \
    && echo "**** Install Sunshine ****" \
    && apt-get install -y --no-install-recommends \
        /usr/src/sunshine.deb \
    && apt-get clean autoclean -y \
    && apt-get autoremove -y \
    && rm -rf \
        /var/lib/apt/lists/* \
        /var/tmp/* \
        /tmp/*

# Install Steam
RUN dpkg --add-architecture i386 \
    && apt-get update \
    && echo "**** Install Steam ****" \
    && apt-get install -y --no-install-recommends \
        steam-installer \
    && ln -sf /usr/games/steam /usr/bin/steam \
    && apt-get clean autoclean -y \
    && apt-get autoremove -y \
    && rm -rf \
        /var/lib/apt/lists/* \
        /var/tmp/* \
        /tmp/*

# install dumb-init and dumb-udev
ARG DUMB_INIT_VERSION=1.2.5
ARG DUMB_UDEV_VERSION=64d1427

RUN wget --no-check-certificate --no-cookies --quiet -O /usr/bin/dumb-init \
        https://github.com/Yelp/dumb-init/releases/download/v${DUMB_INIT_VERSION}/dumb-init_${DUMB_INIT_VERSION}_x86_64 \
    && chmod +x /usr/bin/dumb-init \
    && python3 -m pip install --pre --upgrade --no-cache-dir \
        git+https://github.com/Steam-Headless/dumb-udev.git@${DUMB_UDEV_VERSION}

# copy scripts and configurations
COPY ./entrypoint.sh /usr/bin/entrypoint.sh
COPY ./init/ /etc/cont-init.d/
COPY ./supervisord.conf /etc/supervisor/supervisord.conf

# TODO: copy upstream ./overlay/usr/bin scripts here
# ! cf. `spawnerr: can't find command '/usr/bin/start-sunshine.sh'`
# Add FS overlay
# COPY overlay /

# create a non-root user
ARG USER_UID="${USER_UID:-1000}"
ENV USER_UID="$USER_UID"
ENV USER_GID="$USER_UID"
ARG USER_NAME="${USER_NAME:-appuser}"
ENV USER_NAME="${USER_NAME}"
ENV USER_HOME="/home/${USER_NAME}"

RUN groupadd --gid $USER_GID $USER_NAME \
    && useradd --uid $USER_UID --gid $USER_GID -m -d $HOME $USER_NAME \
    && echo $USER_NAME ALL=\(root\) NOPASSWD:ALL > /etc/sudoers.d/$USER_NAME \
    && chmod 0440 /etc/sudoers.d/$USER_NAME

# env vars
ENV SUNSHINE_USER=${SUNSHINE_USER:-"admin"}
ENV SUNSHINE_PASS=${SUNSHINE_PASS:-"admin"}
ENV NVIDIA_DRIVER_CAPABILITIES=${NVIDIA_DRIVER_CAPABILITIES:-all}
ENV NVIDIA_VISIBLE_DEVICES=${NVIDIA_VISIBLE_DEVICES:-all}
ENV NVIDIA_DRIVER_VERSION=${NVIDIA_DRIVER_VERSION}
ENV UMASK=${UMASK:-000}
ENV ENABLE_EVDEV_INPUTS=${ENABLE_EVDEV_INPUTS:-true}

# RUN bash /usr/bin/entrypoint.sh

WORKDIR ${USER_HOME}

EXPOSE 22/tcp
EXPOSE 3389/tcp

# USER ${USER_NAME}

# ENTRYPOINT [ "/usr/bin/supervisord" ]
# CMD ["-c", "/etc/supervisor/supervisord.conf"]
CMD [ "/usr/bin/entrypoint.sh" ]

LABEL org.opencontainers.image.source=https://github.com/pythoninthegrass/docker_graphical
LABEL org.opencontainers.image.description="Docker container with Firefox, SSH server, and RDP support"
LABEL org.opencontainers.image.licenses=Unlicense
