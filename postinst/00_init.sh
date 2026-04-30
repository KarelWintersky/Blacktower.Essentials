#!/bin/bash

add_mephi_repository() {
    # Determine release
    . /etc/os-release 2>/dev/null || { echo "Failed to determine release"; exit 1; }
    [ -z "$VERSION_CODENAME" ] && echo "VERSION_CODENAME not found" && exit 1

    local conf_file="/etc/apt/sources.list.d/debian_mephi.list"

    # Check and add
    if grep -qs "mirror.mephi.ru.*$VERSION_CODENAME" "$conf_file" 2>/dev/null; then
        echo -e "Repository for $VERSION_CODENAME already exists in $conf_file"
    else
        echo -e "Adding repository for Debian $VERSION_CODENAME"
        cat >> "$conf_file" << EOF

# Added $(date '+%Y-%m-%d')
deb http://mirror.mephi.ru/debian/ $VERSION_CODENAME main non-free-firmware
deb-src http://mirror.mephi.ru/debian/ $VERSION_CODENAME main non-free-firmware
EOF
        echo "Repository added, updating package list..."
        apt update
    fi
}

add_mephi_repository "$@"
apt -y upgrade
