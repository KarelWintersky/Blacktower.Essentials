#!/bin/bash

(sudo crontab -l 2>/dev/null; echo "@reboot /root/update-issue.sh") | sudo crontab -