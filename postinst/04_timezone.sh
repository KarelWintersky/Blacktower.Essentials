#!/bin/bash

# Устанавливаем таймзону через debconf
echo "tzdata tzdata/Areas select Europe" | debconf-set-selections
echo "tzdata tzdata/Zones/Europe select Moscow" | debconf-set-selections

# Запускаем переконфигурацию в неинтерактивном режиме
DEBIAN_FRONTEND=noninteractive dpkg-reconfigure tzdata
