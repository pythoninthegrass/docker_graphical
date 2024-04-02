# syntax=docker/dockerfile:1.6

FROM ubuntu:20.04 AS builder

WORKDIR /root

ENV DEBIAN_FRONTEND="noninteractive"

RUN sed -i '/^#\sdeb-src /s/^#//' "/etc/apt/sources.list"

RUN apt-get update \
    && apt-get install -y --no-install-recommends \
        build-essential \
        dpkg-dev \
        git \
        libpulse-dev \
        pulseaudio \
    && apt-get build-dep -y pulseaudio \
    && apt-get source pulseaudio

RUN cd pulseaudio-* \
    && ./configure

RUN git clone https://github.com/neutrinolabs/pulseaudio-module-xrdp.git xrdp-module \
    && cd xrdp-module \
    && ./bootstrap \
    && ./configure PULSE_DIR=$(cd /root/pulseaudio-* && pwd) \
    && make \
    && make install \
    && cp $(pkg-config --variable=modlibexecdir libpulse)/module-xrdp-* /root/

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
    ca-certificates \
    command-not-found \
    cron \
    dbus-x11 \
    dialog \
    dropbear-bin \
    firefox \
    language-pack-en \
    less \
    logrotate \
    lxde-core lxde-icon-theme \
    lxterminal \
    pavumeter \
    pulseaudio \
    software-properties-common \
    sudo \
    supervisor \
    vim-tiny \
    xorgxrdp \
    xrdp \
    && apt-get autoclean && apt-get autoremove \
    && rm -rf /var/lib/apt/lists

RUN update-locale LANG=en_US.UTF-8 LC_CTYPE=en_US.UTF-8 \
    && useradd -m -g users -G sudo \
        -p $(openssl passwd -1 admin) \
        -s /bin/bash admin

COPY --from=builder /root/module-xrdp-sink.so /var/lib/xrdp-pulseaudio-installer/
COPY --from=builder /root/module-xrdp-source.so /var/lib/xrdp-pulseaudio-installer/
COPY ./clean_launch.sh /usr/bin/clean_launch.sh
COPY ./supervisord.conf /etc/supervisor/supervisord.conf

RUN chmod +x /usr/bin/clean_launch.sh \
    && mkdir -p /var/run/dbus \
    && printf "autospawn = no" >> /etc/pulse/client.conf \
    && printf "[Desktop Entry]\nType=Application\nExec=pulseaudio --daemonize" > /etc/xdg/autostart/pulseaudio-xrdp.desktop \
    && mv /usr/bin/lxpolkit /usr/bin/lxpolkit.disabled \
    && rm -rf /var/lib/apt/lists

EXPOSE 22/tcp
EXPOSE 3389/tcp

CMD ["/usr/bin/clean_launch.sh"]

LABEL org.opencontainers.image.source=https://github.com/pythoninthegrass/docker_graphical
LABEL org.opencontainers.image.description="Docker container with Firefox, SSH server, and RDP support"
LABEL org.opencontainers.image.licenses=Unlicense
