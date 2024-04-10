#!/usr/bin/env bash

# shellcheck disable=SC1090,SC1091,SC2164

# set -euo pipefail

# import functions
. /etc/cont-init.d/common.sh

# env vars
USER_NAME="${USER_NAME:-appuser}"
USER_HOME="${USER_HOME:-$HOME}"
USER_UID="${USER_UID:-1000}"
USER_GID="${USER_GID:-1000}"
UMASK="${UMASK:-022}"
SUNSHINE_USER="${SUNSHINE_USER:-admin}"
SUNSHINE_PASS="${SUNSHINE_PASS:-admin}"
NVIDIA_DRIVER_CAPABILITIES="${NVIDIA_DRIVER_CAPABILITIES:-all}"
NVIDIA_VISIBLE_DEVICES="${NVIDIA_VISIBLE_DEVICES:-all}"
ENABLE_EVDEV_INPUTS="${ENABLE_EVDEV_INPUTS:-true}"

# cleanup
cleanup() {
	rm -rf /var/run/sudo/* /tmp/* /var/tmp/*
	rm -f /run/* 2>/dev/null
	rm -rf /var/lib/apt/lists
}

# execute all container init scripts
run_init_scripts() {
	print_header "Starting container init script..."
	for init_script in /etc/cont-init.d/*.sh ; do
		echo
		echo -e "\e[34m[ ${init_script:?}: executing... ]\e[0m"
		sudo sed -i 's/\r$//' "${init_script:?}"
		source "${init_script:?}"
	done
}

add_user_to_additional_groups() {
	local user="${1:?}"
	local additional_groups=( video audio input pulse )
	print_step_header "Setting up user '${USER}'..."
	for group_name in "${additional_groups[@]}"; do
		if [ $(getent group ${group_name:?}) ]; then
			print_step_header "Adding user '${user}' to group: '${group_name}'"
			usermod -aG ${group_name:?} ${user}
		fi
	done
}

add_user_to_device_groups() {
	local user="${1:?}"
	local device_nodes=( /dev/uinput /dev/input/event* /dev/dri/* )
	local added_groups=""
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
			print_step_header "Adding user '${user}' to group: '${dev_group}' for device: ${dev}"
			usermod -aG ${dev_group} ${user}
			added_groups=" ${added_groups} ${dev_group} "
		fi
	done
}

# set umask
set_umask() {
	local umask="${1:?}"
	print_step_header "Setting umask to ${umask}"
	umask ${umask}
}

# Setup services log path
set_log_ownership() {
	local user_home="${1:?}"
	local user_uid="${2:?}"
	local user_gid="${3:?}"
	print_step_header "Setting ownership of all log files in '${user_home}/.cache/log'"
	mkdir -p "${user_home}/.cache/log"
	chown -R ${user_uid}:${user_gid} "${user_home}/.cache/log"
}

# TODO: use host ssh / xrdp keys instead of regenerating them
# setup ssh keys
generate_ssh_keys() {
	if [[ ! -d "/etc/dropbear" ]]; then
		print_step_header "Setting up ssh keys..."
		mkdir /etc/dropbear
		/usr/bin/dropbearkey -t ecdsa -f /etc/dropbear/dropbear_ecdsa_host_key
	fi
}

# setup xrdp keys
generate_xrdp_keys() {
	if [[ ! -f "/etc/xrdp/rsakeys.ini" ]]; then
		print_step_header "Setting up xrdp keys..."
		/usr/bin/xrdp-keygen xrdp auto 2048
		pushd /etc/xrdp &>/dev/null
		rm -f cert.pem key.pem
		openssl req -new -newkey rsa:2048 -days 365 -nodes -x509 -subj "/C=XX/ST=XX/L=XX/O=XX/CN=$(hostname)" -keyout key.pem -out cert.pem
	fi
}

# start pulseaudio
create_audio_shortcut() {
	print_step_header "Setting up pulseaudio..."
	mkdir -p /var/run/dbus \
	&& printf "autospawn = no" >> /etc/pulse/client.conf \
	&& printf "[Desktop Entry]\nType=Application\nExec=pulseaudio --daemonize" > /etc/xdg/autostart/pulseaudio-xrdp.desktop \
	&& mv /usr/bin/lxpolkit /usr/bin/lxpolkit.disabled
}

# start supervisord
start_supervisord() {
	print_header "Starting supervisord..."
	exec /usr/bin/supervisord -c /etc/supervisor/supervisord.conf --nodaemon --user root
}

main() {
	run_init_scripts
	add_user_to_additional_groups "${USER_NAME}"
	add_user_to_device_groups "${USER_NAME}"
	set_umask "${UMASK}"
	set_log_ownership "${USER_HOME}" "${USER_UID}" "${USER_GID}"
	generate_ssh_keys
	generate_xrdp_keys
	create_audio_shortcut
	cleanup
	set -x
	start_supervisord
	set +x
}
main "$@"

exit 0
