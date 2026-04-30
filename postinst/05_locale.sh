#!/bin/bash

cat > /etc/locale.gen << EOF
ru_RU.UTF-8 UTF-8
en_US.UTF-8 UTF-8
EOF

locale-gen

update-locale LANG=en_US.UTF-8

locale -a | grep -E "en_US|ru_RU"

# dpkg-reconfigure console-setup
# dpkg-reconfigure keyboard-configuration

source /etc/default/locale

# find /usr/share/locale/ -mindepth 1 -maxdepth 1 -type d -not \( -name "en*" -o -name "ru*" \) -exec rm -rf {} \;