#!/bin/bash

set -e

ANSI_RED='\033[0;31m'
ANSI_GREEN='\033[0;32m'
ANSI_YELLOW='\033[1;33m'
ANSI_RESET='\033[0m'

useradd -m arris && echo "arris:password" | chpasswd && passwd -e arris
usermod -aG sudo arris

touch /home/arris/.Xauthority
chown arris:arris /home/arris/.Xauthority

echo "${ANSI_GREEN}User ARRIS with password ${ANSI_YELLOW}'password'${ANSI_GREEN} created${ANSI_RESET}"

cat >> /home/arris/.bashrc << 'EOF'
export HISTSIZE=10000
export HISTFILESIZE=50000
export HISTTIMEFORMAT="%F %T  "
export HISTCONTROL=ignoredups:ignorespace
shopt -s histappend
export PROMPT_COMMAND="history -a; history -c; history -r; $PROMPT_COMMAND"
EOF

chown arris:arris /home/arris/.bashrc
