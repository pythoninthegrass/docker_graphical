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

print_step_header "Adding default user to any additional required device groups"
additional_groups=( video audio input pulse )
for group_name in "${additional_groups[@]}"; do
    if [ $(getent group ${group_name:?}) ]; then
        print_step_header "Adding user '${USER}' to group: '${group_name}'"
        usermod -aG ${group_name:?} ${USER}
    fi
done
device_nodes=( /dev/uinput /dev/input/event* /dev/dri/* )
added_groups=""
for dev in "${device_nodes[@]}"; do
    # Only process $dev if it's a character device
    if [[ ! -c "${dev}" ]]; then
        continue
    fi

    # Get group name and ID
    dev_group=$(stat -c "%G" "${dev}")
    dev_gid=$(stat -c "%g" "${dev}")

    # Dont add root
    if [[ "${dev_gid}" = 0 ]]; then
        continue
    fi

    # Create a name for the group ID if it does not yet already exist
    if [[ "${dev_group}" = "UNKNOWN" ]]; then
        dev_group="user-gid-${dev_gid}"
        groupadd -g $dev_gid "${dev_group}"
    fi

    # Add group to user
    if [[ "${added_groups}" != *"${dev_group}"* ]]; then
        print_step_header "Adding user '${USER}' to group: '${dev_group}' for device: ${dev}"
        usermod -aG ${dev_group} ${USER}
        added_groups=" ${added_groups} ${dev_group} "
    fi
done


print_step_header "Setting umask to ${UMASK}";
umask ${UMASK}

# Setup services log path
print_step_header "Setting ownership of all log files in '${USER_HOME}/.cache/log'"
mkdir -p "${USER_HOME}/.cache/log"
chown -R ${PUID}:${PGID} "${USER_HOME}/.cache/log"

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
