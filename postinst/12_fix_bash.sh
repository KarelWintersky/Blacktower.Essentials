#!/bin/bash

cat >> /root/.bashrc << 'EOF'
export HISTSIZE=10000
export HISTFILESIZE=50000
export HISTTIMEFORMAT="%F %T  "
export HISTCONTROL=ignoredups:ignorespace
shopt -s histappend
export PROMPT_COMMAND="history -a; history -c; history -r; $PROMPT_COMMAND"
EOF

source /root/.bashrc

