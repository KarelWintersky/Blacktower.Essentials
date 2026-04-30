#!/bin/bash

set -e

# Цвета для вывода
ANSI_RED=$(tput -Txterm setaf 1)
ANSI_GREEN=$(tput -Txterm setaf 2)
ANSI_YELLOW=$(tput -Txterm setaf 3)
ANSI_RESET=$(tput -Txterm sgr0)

# ==================== ФУНКЦИИ ====================

# Проверка прав root
check_root() {
    if [ "$EUID" -ne 0 ]; then
        echo -e "${ANSI_RED}Ошибка: скрипт должен запускаться от root${ANSI_RESET}"
        exit 1
    fi
}

# Запрос имени хоста
ask_hostname() {
    local current_hostname=$(hostname)
    read -e -p "${ANSI_YELLOW}Введите имя хоста: (текущее: $current_hostname) ${ANSI_RESET}" -i "${current_hostname}" NEW_HOSTNAME
    echo "$NEW_HOSTNAME"
}

# Запрос - создавать ли пользователя
ask_create_user() {
    local choice
    echo -e "${ANSI_YELLOW}Создать нового пользователя? (y/n):${ANSI_RESET}"
    read -p "Create user [Y/N]? " choice
    if [[ "$choice" =~ ^[Yy]$ ]]; then
        CREATE_USER="yes"
    else
        CREATE_USER="no"
    fi
}

# Запрос имени пользователя
ask_username() {
    local username
    echo -e "${ANSI_YELLOW}Введите имя нового пользователя:${ANSI_RESET}" >&2
    read -p "Username: " username
    if [ -z "$username" ]; then
        echo -e "${ANSI_RED}Имя пользователя не может быть пустым.${ANSI_RESET}" >&2
        exit 1
    fi
    echo "$username"
}

# Запрос пароля
ask_password() {
    local username=$1
    local user_pass
    echo -e "${ANSI_YELLOW}Введите пароль для пользователя $username:${ANSI_RESET}" >&2
    read -s -p "Password: " user_pass
    echo >&2
    if [ -z "$user_pass" ]; then
        echo -e "${ANSI_RED}Пароль не может быть пустым.${ANSI_RESET}" >&2
        exit 1
    fi
    echo "$user_pass"
}

# Запрос настройки прокси
ask_proxy() {
    echo -e "\n${ANSI_YELLOW}Использовать прокси-сервер apt-cacher-ng? (y/n):${ANSI_RESET}"
    read -p "Use proxy? " USE_PROXY
    if [[ "$USE_PROXY" =~ ^[Yy]$ ]]; then
        echo -e "${ANSI_YELLOW}Введите URL прокси-сервера (например: http://192.168.111.87:3142):${ANSI_RESET}"
        read -e -p "Proxy URL: " -i "http://192.168.111.87:3142" PROXY_URL
        if [ -n "$PROXY_URL" ]; then
            configure_proxy "$PROXY_URL"
        fi
    fi
}

# Настройка прокси для apt
configure_proxy() {
    local proxy_url=$1
    echo -e "${ANSI_GREEN}Настройка прокси для apt...${ANSI_RESET}"
    cat > /etc/apt/apt.conf.d/02aptproxy << EOF
Acquire::http::proxy "$proxy_url";
Acquire::ftp::proxy "$proxy_url";
EOF
    echo -e "${ANSI_GREEN}Прокси настроен в /etc/apt/apt.conf.d/02aptproxy${ANSI_RESET}"
}

# Установка имени хоста
set_hostname() {
    local hostname=$1
    echo -e "\n${ANSI_GREEN}=== Установка имени хоста: $hostname ===${ANSI_RESET}"
    hostnamectl set-hostname "$hostname"
    if grep -q "^127.0.1.1" /etc/hosts; then
        sed -i "s/^127.0.1.1.*/127.0.1.1\t$hostname/" /etc/hosts
    else
        echo "127.0.1.1\t$hostname" >> /etc/hosts
    fi
    echo -e "${ANSI_GREEN}Имя хоста установлено.${ANSI_RESET}"
}

# Добавление репозитория MEPHI
add_mephi_repository() {
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

# Обновление системы
update_system() {
    echo -e "${ANSI_GREEN}=== Обновление системы ===${ANSI_RESET}"
    apt update
    apt -y upgrade
}

# Установка пакетов
install_packages() {
    local packages=(
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
    apt-get install -y "${packages[@]}"
}

# Настройка SSH
configure_ssh() {
    echo -e "${ANSI_GREEN}Allowing SSH root login${ANSI_RESET}"
    sed -i 's/^.*PermitRootLogin.*$/PermitRootLogin yes/' /etc/ssh/sshd_config
    systemctl restart sshd
    echo -e "${ANSI_GREEN}Ok.${ANSI_RESET}"
}

# Настройка таймзоны и локали
configure_locale() {
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
}

# Настройка journald
configure_journald() {
    mkdir -p /etc/systemd/journald.conf.d
    cat > /etc/systemd/journald.conf.d/size.conf << EOF
[Journal]
SystemMaxUse=1G
SystemMaxFileSize=50M
MaxLevelStore=warning
EOF

    systemctl restart systemd-journald
}

# Создание пользователя
create_user() {
    local username=$1
    local password=$2

    useradd -m "$username" && echo "$username:$password" | chpasswd && passwd -e "$username"
    usermod -aG sudo "$username"

    touch "/home/$username/.Xauthority"
    chown "$username:$username" "/home/$username/.Xauthority"

    echo -e "${ANSI_GREEN}Пользователь $username с паролем '${ANSI_YELLOW}$password${ANSI_GREEN}' создан${ANSI_RESET}"
}

# Настройка истории для пользователя
configure_user_history() {
    local username=$1
    cat >> "/home/$username/.bashrc" << 'EOF'
export HISTSIZE=10000
export HISTFILESIZE=50000
export HISTTIMEFORMAT="%F %T  "
export HISTCONTROL=ignoredups:ignorespace
shopt -s histappend
export PROMPT_COMMAND="history -a; history -c; history -r; $PROMPT_COMMAND"
export TERM=xterm-256color
EOF
    chown "$username:$username" "/home/$username/.bashrc"
}

# Настройка истории для root
configure_root_history() {
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
}

# Очистка документации git
clean_git_docs() {
    rm -rf /usr/share/doc/git/RelNotes
}

# Финальное сообщение
finish_setup() {
    echo -e "${ANSI_GREEN}=== Настройка завершена ===${ANSI_RESET}"
}

# Запись конфигурационного файла
write_config_file() {
    local file_path=$1
    local create_backup=${2:-true}  # создать резервную копию? (по умолчанию true)

    echo -e "${ANSI_GREEN}=== Запись конфигурации в $file_path ===${ANSI_RESET}"

    # Создание резервной копии
    if [ "$create_backup" = true ] && [ -f "$file_path" ]; then
        local backup_path="${file_path}.backup.$(date +%Y%m%d_%H%M%S)"
        cp "$file_path" "$backup_path"
        echo -e "${ANSI_YELLOW}Создана резервная копия: $backup_path${ANSI_RESET}"
    fi

    # Создание директории, если её нет
    local dir_path=$(dirname "$file_path")
    if [ ! -d "$dir_path" ]; then
        mkdir -p "$dir_path"
        echo -e "${ANSI_YELLOW}Создана директория: $dir_path${ANSI_RESET}"
    fi

    # Чтение содержимого из heredoc
    cat > "$file_path"

    # Установка правильных прав (опционально)
    chmod 644 "$file_path"

    echo -e "${ANSI_GREEN}Файл успешно записан: $file_path${ANSI_RESET}"
}

make_motd_generator() {
    write_config_file "/etc/update-motd.d/99-mymotd-generator" false << 'EOF'
    #!/bin/bash

    # Text Color Variables http://misc.flogisoft.com/bash/tip_colors_and_formatting
    tcLtG="\033[00;37m"    # LIGHT GRAY
    tcDkG="\033[01;30m"    # DARK GRAY
    tcLtR="\033[01;31m"    # LIGHT RED
    tcLtGRN="\033[01;32m"  # LIGHT GREEN
    tcLtBL="\033[01;34m"   # LIGHT BLUE
    tcLtP="\033[01;35m"    # LIGHT PURPLE
    tcLtC="\033[01;36m"    # LIGHT CYAN
    tcW="\033[01;37m"      # WHITE
    tcRESET="\033[0m"
    tcORANGE="\033[38;5;209m"

    # Time of day
    HOUR=$(date +"%H")
    if [ $HOUR -lt 12  -a $HOUR -ge 0 ]; then TIME="morning"
    elif [ $HOUR -lt 17 -a $HOUR -ge 12 ]; then TIME="afternoon"
    else TIME="evening"
    fi

    # System uptime
    uptime=`cat /proc/uptime | cut -f1 -d.`
    upDays=$((uptime/60/60/24))
    upHours=$((uptime/60/60%24))
    upMins=$((uptime/60%60))

    # System + Memory
    MEMORY_USED=`free -b | grep Mem | awk '{print $3/$2 * 100.0}'`
    SWAP_USED=`free -b | grep Swap | awk '{print $3/$2 * 100.0}'`
    NUM_PROCS=`ps aux | wc -l`

    # IP первого сетевого интерфейса
    LOCAL_IP=$(ip -4 addr show | grep -oP '(?<=inet\s)\d+\.\d+\.\d+\.\d+' | grep -v '^127\.' | head -n 1)

    # Имя сервера
    HOSTNAME=$(hostname)

    # ОS
    OS=$(grep PRETTY_NAME /etc/os-release | cut -d= -f2 | tr -d '"')

    # Пользователь
    USER_NAME=$(whoami)
    [ "$USER_NAME" = "root" ] && USER_NAME="${tcLtR}${USER_NAME}${tcRESET}"

    # Load average
    LOADAVG=$(awk '{print $1" "$2" "$3}' /proc/loadavg)
    SYS_LOADS=`cat /proc/loadavg | awk '{print $1}'`

    # RAM: всего и свободно (в мегабайтах)
    RAM_TOTAL=$(free -m | awk '/Mem:/ {print $2}')
    RAM_FREE=$(free -m | awk '/Mem:/ {print $7}')
    RAM_FREE_PCT=$(( RAM_FREE * 100 / RAM_TOTAL ))

    # Количество CPU
    CPU_COUNT=$(nproc)

    # Uptime
    UPTIME=$(uptime -p)

    # HDD: для корневого раздела /
    DISK_TOTAL_HUMAN=$(df -h / | awk 'NR==2 {print $2}')
    DISK_FREE_HUMAN=$(df -h / | awk 'NR==2 {print $4}')

    # Используем df без форматирования для процентов
    DISK_TOTAL=$(df -k / | awk 'NR==2 {print $2}')
    DISK_FREE=$(df -k / | awk 'NR==2 {print $4}')
    DISK_FREE_PCT=$(( DISK_FREE * 100 / DISK_TOTAL ))

    echo -e "$tcDkG ==============================================================="
    echo -e $tcLtG " Good $TIME!                                $tcORANGE $LOCAL_IP"
    echo -e $tcDkG "==============================================================="
    echo -e $tcLtG " - Hostname      :$tcW ${HOSTNAME}"
    echo -e $tcLtG " - IP Address    :$tcW ${LOCAL_IP:-N/A}"
    echo -e $tcLtG " - User          :$tcW ${USER_NAME}"
    echo -e $tcLtG "==============================================================="
    echo -e $tcLtG " - OS Release    :$tcW ${OS}"
    echo -e $tcLtG " - Kernel        : `uname -a | awk '{print $1" "$3" "$12}'`"
    echo -e $tcLtG " - Users         : Currently `users | wc -w` user(s) logged on"
    echo -e $tcLtG "==============================================================="
    echo -e $tcLtG " - Server Time   : `date`"
    echo -e $tcLtG " - System load   : ${SYS_LOADS} / ${NUM_PROCS} processes running"
    echo -e $tcLtG " - Load average  : ${LOADAVG}"
    echo -e $tcLtG " - System uptime : ${upDays} days ${upHours} hours ${upMins} minutes"
    echo -e $tcLtG "==============================================================="
    echo -e $tcLtG " - CPU           : ${CPU_COUNT} CPU"
    echo -e $tcLtG " - RAM           : ${RAM_TOTAL} MB, ${RAM_FREE} MB (${RAM_FREE_PCT}%) free"
    echo -e $tcLtG " - HDD           : ${DISK_TOTAL_HUMAN}, ${DISK_FREE_HUMAN} (${DISK_FREE_PCT}%) free"
    echo -e $tcLtG " - Swap used %   : ${SWAP_USED}"
    echo -e $tcDkG "==============================================================="
    echo -e $tcRESET ""
EOF

    write_config_file "/etc/issue" false << 'EOF'
    Debian GNU/Linux 12 \n \l

    Local IP: не доступен
EOF
}

install_midnight_commanger() {
    apt-get -y install mc

    write_config_file "/root/.config/mc/ini" false << 'EOF'
[Midnight-Commander]
verbose=true
shell_patterns=true
auto_save_setup=true
preallocate_space=false
auto_menu=false
use_internal_view=true
use_internal_edit=false
clear_before_exec=true
confirm_delete=true
confirm_overwrite=true
confirm_execute=false
confirm_history_cleanup=true
confirm_exit=false
confirm_directory_hotlist_delete=false
confirm_view_dir=false
safe_delete=false
safe_overwrite=false
use_8th_bit_as_meta=false
mouse_move_pages_viewer=true
mouse_close_dialog=false
fast_refresh=false
drop_menus=false
wrap_mode=true
old_esc_mode=true
cd_symlinks=true
show_all_if_ambiguous=false
use_file_to_guess_type=true
alternate_plus_minus=false
only_leading_plus_minus=true
show_output_starts_shell=false
xtree_mode=false
file_op_compute_totals=true
classic_progressbar=true
use_netrc=true
ftpfs_always_use_proxy=false
ftpfs_use_passive_connections=true
ftpfs_use_passive_connections_over_proxy=false
ftpfs_use_unix_list_options=true
ftpfs_first_cd_then_ls=true
ignore_ftp_chattr_errors=true
editor_fill_tabs_with_spaces=false
editor_return_does_auto_indent=false
editor_backspace_through_tabs=false
editor_fake_half_tabs=true
editor_option_save_position=true
editor_option_auto_para_formatting=false
editor_option_typewriter_wrap=false
editor_edit_confirm_save=true
editor_syntax_highlighting=true
editor_persistent_selections=true
editor_drop_selection_on_copy=true
editor_cursor_beyond_eol=false
editor_cursor_after_inserted_block=false
editor_visible_tabs=true
editor_visible_spaces=true
editor_line_state=false
editor_simple_statusbar=false
editor_check_new_line=false
editor_show_right_margin=false
editor_group_undo=true
editor_state_full_filename=true
editor_ask_filename_before_edit=false
nice_rotating_dash=true
shadows=true
mcview_remember_file_position=false
auto_fill_mkdir_name=true
copymove_persistent_attr=true
pause_after_run=1
mouse_repeat_rate=100
double_click_speed=250
old_esc_mode_timeout=1000000
max_dirt_limit=10
num_history_items_recorded=60
vfs_timeout=60
ftpfs_directory_timeout=900
ftpfs_retry_seconds=30
fish_directory_timeout=900
editor_tab_spacing=8
editor_word_wrap_line_length=72
editor_option_save_mode=0
editor_backup_extension=~
editor_filesize_threshold=64M
editor_stop_format_chars=-+*\\,.;:&>
mcview_eof=
skin=modarcon16

filepos_max_saved_entries=1024

[Layout]
output_lines=0
left_panel_size=86
top_panel_size=0
message_visible=false
keybar_visible=true
xterm_title=true
command_prompt=true
menubar_visible=true
free_space=true
horizontal_split=false
vertical_equal=true
horizontal_equal=true

[Misc]
timeformat_recent=%b %e %H:%M
timeformat_old=%b %e  %Y
ftp_proxy_host=gate
ftpfs_password=anonymous@
display_codepage=UTF-8
source_codepage=Other_8_bit
autodetect_codeset=
spell_language=en
clipboard_store=
clipboard_paste=

[Colors]
base_color=
linux=
color_terminals=

xterm-256color=

[Panels]
show_mini_info=true
kilobyte_si=false
mix_all_files=false
show_backups=true
show_dot_files=true
fast_reload=false
fast_reload_msg_shown=false
mark_moves_down=true
reverse_files_only=true
auto_save_setup_panels=false
navigate_with_arrows=false
panel_scroll_pages=true
panel_scroll_center=false
mouse_move_pages=true
filetype_mode=true
permission_mode=false
torben_fj_mode=false
quick_search_mode=2
select_flags=6

[Panelize]
Find *.orig after patching=find . -name \\*.orig -print
Find SUID and SGID programs=find . \\( \\( -perm -04000 -a -perm /011 \\) -o \\( -perm -02000 -a -perm /01 \\) \\) -print
Find rejects after patching=find . -name \\*.rej -print
Modified git files=git ls-files --modified

EOF

    write_config_file "/root/.config/mc/panels.ini" false << 'EOF'
[New Left Panel]
display=listing
reverse=false
case_sensitive=true
exec_first=false
sort_order=name
list_mode=full
brief_cols=2
user_format=half type name | size | owner
user_status0=half type name | size | perm
user_status1=half type name | size | perm
user_status2=half type name | size | perm
user_status3=half type name | size | perm
user_mini_status=false
filter_flags=7
list_format=user

[New Right Panel]
display=listing
reverse=false
case_sensitive=true
exec_first=false
sort_order=name
list_mode=full
brief_cols=2
user_format=half type name | size | owner
user_status0=half type name | size | perm
user_status1=half type name | size | perm
user_status2=half type name | size | perm
user_status3=half type name | size | perm
user_mini_status=false
filter_flags=7
list_format=user

[Dirs]
current_is_left=false
other_dir=/root
EOF
}

# Обновление GPG ключей Debian
fix_debian_keys() {
    echo -e "${ANSI_GREEN}=== Исправление GPG-ключей Debian ===${ANSI_RESET}"

    # 1. Полностью удаляем кэш списков пакетов
    rm -rf /var/lib/apt/lists/*

    # 2. Удаляем старые проблемные ключи из trusted.gpg.d и связки apt-key
    rm -f /etc/apt/trusted.gpg.d/*54404762BBB6E853* \
          /etc/apt/trusted.gpg.d/*6ED0E7B82643E131* 2>/dev/null || true
    apt-key del 54404762BBB6E853 2>/dev/null || true
    apt-key del 6ED0E7B82643E131 2>/dev/null || true

    # 3. Очищаем кэш apt
    apt-get clean

    # 4. Принудительно переустанавливаем пакет с ключами (без проверки подписи)
    apt-get install --reinstall -y --allow-unauthenticated debian-archive-keyring

    # 5. Если прокси-сервер используется, настраиваем переменные окружения для gpg
    if [ -n "$PROXY_URL" ]; then
        export http_proxy="$PROXY_URL"
        export https_proxy="$PROXY_URL"
    fi

    # 6. Пытаемся получить ключи напрямую с keyserver (альтернативный источник)
    echo "Получение свежих ключей с keyserver..."
    gpg --keyserver keyserver.ubuntu.com --recv-keys 54404762BBB6E853 6ED0E7B82643E131 2>/dev/null || \
    gpg --keyserver pgp.mit.edu --recv-keys 54404762BBB6E853 6ED0E7B82643E131 2>/dev/null || \
    gpg --keyserver keys.openpgp.org --recv-keys 54404762BBB6E853 6ED0E7B82643E131 2>/dev/null || true

    # 7. Экспортируем ключи в директорию apt (если были получены)
    gpg --export 54404762BBB6E853 > /etc/apt/trusted.gpg.d/debian-security-automatic.gpg 2>/dev/null || true
    gpg --export 6ED0E7B82643E131 > /etc/apt/trusted.gpg.d/debian-archive-automatic.gpg 2>/dev/null || true

    # 8. Снова очищаем списки и обновляем
    rm -rf /var/lib/apt/lists/*
    apt-get update --allow-insecure-repositories || true

    echo -e "${ANSI_GREEN}Ключи обновлены.${ANSI_RESET}"
}

# ==================== ОСНОВНАЯ ЛОГИКА ====================

main() {
    # check_root

    echo -e "${ANSI_GREEN}=== Настройка системы ===${ANSI_RESET}"

    NEW_HOSTNAME=$(ask_hostname)

    ask_create_user

    echo $CREATE_USER

    if [ "$CREATE_USER" = "yes" ]; then
        NEW_USER=$(ask_username)
        USER_PASS=$(ask_password "$NEW_USER")
        create_user "$NEW_USER" "$USER_PASS"
        configure_user_history "$NEW_USER"
    fi

    ask_proxy
    fix_debian_keys

    # Выполнение настроек
    configure_root_history

    set_hostname "$NEW_HOSTNAME"
    add_mephi_repository
    update_system
    install_packages
    configure_ssh
    configure_locale
    configure_journald
    clean_git_docs

    make_motd_generator

    install_midnight_commanger

    finish_setup
}

# Запуск главной функции
main "$@"