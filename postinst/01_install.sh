#!/bin/bash

set -e

ANSI_RED='\033[0;31m'
ANSI_GREEN='\033[0;32m'
ANSI_YELLOW='\033[1;33m'
ANSI_RESET='\033[0m'

# Объединённый список пакетов без дубликатов
PACKAGES=(
    pv nano curl wget sudo lsb-release iptables
    unzip pigz zstd
    ncdu gdu
    screen tmux lynx
    htop btop iftop mtr ioping
    git jq yq pwgen
    bind9-dnsutils net-tools ssh-audit
    cloud-guest-utils qemu-guest-agent
    console-setup
)

echo -e "${ANSI_GREEN}Installing packages...${ANSI_RESET}"
apt-get update
apt-get install -y "${PACKAGES[@]}"

echo -e "${ANSI_GREEN}Allowing SSH root login${ANSI_RESET}"
sed -i 's/^.*PermitRootLogin.*$/PermitRootLogin yes/' /etc/ssh/sshd_config
systemctl restart sshd
echo -e "${ANSI_GREEN}Ok.${ANSI_RESET}"

touch ~/.Xauthority