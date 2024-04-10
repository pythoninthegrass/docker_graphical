#!/usr/bin/env bash

# shellcheck disable=SC1091

# import functions
. /etc/cont-init.d/common.sh

print_header "Configure Steam"

steam_autostart_desktop="$(cat <<EOF
[Desktop Entry]
Encoding=UTF-8
Type=Application
Name=Steam
Comment=Launch steam on login
Exec=/usr/games/steam %U ${STEAM_ARGS:-}
Icon=steam
OnlyShowIn=XFCE;
RunHook=0
StartupNotify=false
Terminal=false
Hidden=false
EOF
)"

if [ "${ENABLE_STEAM:-}" = "true" ]; then
    if [ "${MODE}" == "s" ] || [ "${MODE}" == "secondary" ]; then
        print_step_header "Enable Steam supervisor.d service"
        sed -i 's|^autostart.*=.*$|autostart=true|' /etc/supervisor/supervisord.conf
    else
        print_step_header "Enable Steam auto-start script"
        mkdir -p "${USER_HOME:?}/.config/autostart"
        echo "${steam_autostart_desktop:?}" > "${USER_HOME:?}/.config/autostart/Steam.desktop"
        sed -i 's|^autostart.*=.*$|autostart=false|' /etc/supervisor/supervisord.conf
    fi
else
    print_step_header "Disable Steam service"
    sed -i 's|^autostart.*=.*$|autostart=false|' /etc/supervisor/supervisord.conf
fi

echo -e "\e[34mDONE\e[0m"
