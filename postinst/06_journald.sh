#!/bin/bash

cat > /etc/systemd/journald.conf.d/size.conf << EOF
[Journal]
SystemMaxUse=1G
SystemMaxFileSize=50M
MaxLevelStore=warning
EOF

systemctl restart journalctl



