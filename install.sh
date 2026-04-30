#!/bin/bash

set -e

# Цвета для вывода
ANSI_RED='\033[0;31m'
ANSI_GREEN='\033[0;32m'
ANSI_YELLOW='\033[1;33m'
ANSI_RESET='\033[0m'

# Проверка, что скрипт запущен от root
if [ "$EUID" -ne 0 ]; then
    echo -e "${ANSI_RED}Ошибка: скрипт должен запускаться от root${ANSI_RESET}"
    exit 1
fi

echo -e "${ANSI_GREEN}=== Настройка системы ===${ANSI_RESET}"

# Получаем текущее имя хоста
CURRENT_HOSTNAME=$(hostname)

# Запрос имени хоста с выводом текущего значения
echo -e "${ANSI_YELLOW}Введите новое имя хоста (текущее: $CURRENT_HOSTNAME):${ANSI_RESET}"
read -p "Hostname: " NEW_HOSTNAME
if [ -z "$NEW_HOSTNAME" ]; then
    NEW_HOSTNAME="$CURRENT_HOSTNAME"
fi

# Запрос имени пользователя
echo -e "${ANSI_YELLOW}Введите имя нового пользователя:${ANSI_RESET}"
read -p "Username: " NEW_USER
if [ -z "$NEW_USER" ]; then
    echo -e "${ANSI_RED}Имя пользователя не может быть пустым.${ANSI_RESET}"
    exit 1
fi

# Запрос пароля для нового пользователя
echo -e "${ANSI_YELLOW}Введите пароль для пользователя $NEW_USER:${ANSI_RESET}"
read -s -p "Password: " USER_PASS
echo
if [ -z "$USER_PASS" ]; then
    echo -e "${ANSI_RED}Пароль не может быть пустым.${ANSI_RESET}"
    exit 1
fi

# Запрос о использовании прокси для apt
echo -e "\n${ANSI_YELLOW}Использовать прокси-сервер apt-cacher-ng? (y/n):${ANSI_RESET}"
read -p "Use proxy? " USE_PROXY
if [[ "$USE_PROXY" =~ ^[Yy]$ ]]; then
    echo -e "${ANSI_YELLOW}Введите URL прокси-сервера (например: http://192.168.1.100:3142):${ANSI_RESET}"
    read -p "Proxy URL: " PROXY_URL
    if [ -n "$PROXY_URL" ]; then
        echo -e "${ANSI_GREEN}Настройка прокси для apt...${ANSI_RESET}"
        cat > /etc/apt/apt.conf.d/02aptproxy << EOF
Acquire::http::proxy "$PROXY_URL";
Acquire::ftp::proxy "$PROXY_URL";
EOF
        echo -e "${ANSI_GREEN}Прокси настроен в /etc/apt/apt.conf.d/02aptproxy${ANSI_RESET}"
    else
        echo -e "${ANSI_RED}URL прокси не введен, пропускаем${ANSI_RESET}"
    fi
fi

echo -e "\n${ANSI_GREEN}=== Установка имени хоста: $NEW_HOSTNAME ===${ANSI_RESET}"
hostnamectl set-hostname "$NEW_HOSTNAME"

# Обновление /etc/hosts
if grep -q "^127.0.1.1" /etc/hosts; then
    sed -i "s/^127.0.1.1.*/127.0.1.1\t$NEW_HOSTNAME/" /etc/hosts
else
    echo "127.0.1.1\t$NEW_HOSTNAME" >> /etc/hosts
fi
echo -e "${ANSI_GREEN}Имя хоста установлено.${ANSI_RESET}"

# Функция добавления репозитория MEPHI
add_mephi_repository() {
    # Определение версии Debian
    . /etc/os-release 2>/dev/null || { echo "Failed to determine release"; exit 1; }
    [ -z "$VERSION_CODENAME" ] && echo "VERSION_CODENAME not found" && exit 1

    local conf_file="/etc/apt/sources.list.d/debian_mephi.list"

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

# Добавляем репозиторий MEPHI
add_mephi_repository

# Обновление и апгрейд
apt -y upgrade

# Установка пакетов (включая sudo)
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

# Настройка SSH
echo -e "${ANSI_GREEN}Allowing SSH root login${ANSI_RESET}"
sed -i 's/^.*PermitRootLogin.*$/PermitRootLogin yes/' /etc/ssh/sshd_config
systemctl restart sshd
echo -e "${ANSI_GREEN}Ok.${ANSI_RESET}"

# Midnight Commander
apt-get -y install mc

# Настройка таймзоны и локали
echo "tzdata tzdata/Areas select Europe" | debconf-set-selections
echo "tzdata tzdata/Zones/Europe select Moscow" | debconf-set-selections
DEBIAN_FRONTEND=noninteractive dpkg-reconfigure tzdata

cat > /etc/locale.gen << EOF
ru_RU.UTF-8 UTF-8
en_US.UTF-8 UTF-8
EOF

locale-gen
update-locale LANG=en_US.UTF-8
locale -a | grep -E "en_US|ru_RU"
source /etc/default/locale

dpkg-reconfigure console-setup
dpkg-reconfigure keyboard-configuration

# Настройка journald
mkdir -p /etc/systemd/journald.conf.d
cat > /etc/systemd/journald.conf.d/size.conf << EOF
[Journal]
SystemMaxUse=1G
SystemMaxFileSize=50M
MaxLevelStore=warning
EOF

systemctl restart systemd-journald

# Создание пользователя
useradd -m "$NEW_USER" && echo "$NEW_USER:$USER_PASS" | chpasswd && passwd -e "$NEW_USER"
usermod -aG sudo "$NEW_USER"

# Настройка .Xauthority
touch "/home/$NEW_USER/.Xauthority"
chown "$NEW_USER:$NEW_USER" "/home/$NEW_USER/.Xauthority"

echo -e "${ANSI_GREEN}Пользователь $NEW_USER с паролем '${ANSI_YELLOW}$USER_PASS${ANSI_GREEN}' создан${ANSI_RESET}"

# Настройка истории для пользователя
cat >> "/home/$NEW_USER/.bashrc" << 'EOF'
export HISTSIZE=10000
export HISTFILESIZE=50000
export HISTTIMEFORMAT="%F %T  "
export HISTCONTROL=ignoredups:ignorespace
shopt -s histappend
export PROMPT_COMMAND="history -a; history -c; history -r; $PROMPT_COMMAND"
export TERM=xterm-256color
EOF

chown "$NEW_USER:$NEW_USER" "/home/$NEW_USER/.bashrc"

# Удаление документации git
rm -rf /usr/share/doc/git/RelNotes

# Настройка истории для root
cat >> /root/.bashrc << 'EOF'
export HISTSIZE=10000
export HISTFILESIZE=50000
export HISTTIMEFORMAT="%F %T  "
export HISTCONTROL=ignoredups:ignorespace
shopt -s histappend
export PROMPT_COMMAND="history -a; history -c; history -r; $PROMPT_COMMAND"
export TERM=xterm-256color
EOF

source /root/.bashrc

echo -e "${ANSI_GREEN}=== Настройка завершена успешно ===${ANSI_RESET}"
