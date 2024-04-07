#!/usr/bin/env bash

# shellcheck disable=SC1090,SC2164

print_header() {
    # Magenta
	echo -e "\e[35m**** ${*} ****\e[0m"
}

print_step_header() {
    # Cyan
    echo -e "\e[36m  - ${*}\e[0m"
}

print_warning() {
    # Yellow
    echo -e "\e[33mWARNING: ${*}\e[0m"
}

print_error() {
    # Red
    echo -e "\e[31mERROR: ${*}\e[0m"
}

# execute all container init scripts
for init_script in /etc/cont-init.d/*.sh ; do
    echo
    echo -e "\e[34m[ ${init_script:?}: executing... ]\e[0m"
    sed -i 's/\r$//' "${init_script:?}"
    source "${init_script:?}"
done

rm -rf /var/run/sudo/* /tmp/* /var/tmp/*
rm -f /run/* 2>/dev/null

# TODO: use host ssh / xrdp keys instead of regenerating them

if [[ ! -d "/etc/dropbear" ]]; then
	mkdir /etc/dropbear
	/usr/bin/dropbearkey -t ecdsa -f /etc/dropbear/dropbear_ecdsa_host_key
fi

mkdir -p /var/run/dbus \
&& printf "autospawn = no" >> /etc/pulse/client.conf \
&& printf "[Desktop Entry]\nType=Application\nExec=pulseaudio --daemonize" > /etc/xdg/autostart/pulseaudio-xrdp.desktop \
&& mv /usr/bin/lxpolkit /usr/bin/lxpolkit.disabled \
&& rm -rf /var/lib/apt/lists

if [[ ! -f "/etc/xrdp/rsakeys.ini" ]]; then
	/usr/bin/xrdp-keygen xrdp auto 2048
	pushd /etc/xrdp &>/dev/null
	rm -f cert.pem key.pem
	openssl req -new -newkey rsa:2048 -days 365 -nodes -x509 -subj "/C=XX/ST=XX/L=XX/O=XX/CN=$(hostname)" -keyout key.pem -out cert.pem
fi

exit 0
