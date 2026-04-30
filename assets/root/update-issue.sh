#!/bin/bash

# Получаем локальный IP адрес (исключая localhost)
LOCAL_IP=$(ip -4 addr show | grep -oP '(?<=inet\s)\d+\.\d+\.\d+\.\d+' | grep -v '^127\.' | head -n 1)

# Если не удалось получить IP, используем "не доступен"
[ -z "$LOCAL_IP" ] && LOCAL_IP="не доступен"

# Временный файл
TEMP_FILE=$(mktemp)

# Проверяем, существует ли уже строка с Local IP
if grep -q "^Local IP:" /etc/issue; then
    # Обновляем существующую строку
    sed -r "s/^Local IP:.*$/Local IP: $LOCAL_IP/" /etc/issue > "$TEMP_FILE"
else
    # Копируем файл и добавляем новую строку
    cp /etc/issue "$TEMP_FILE"
    echo "Local IP: $LOCAL_IP" >> "$TEMP_FILE"
fi

# Заменяем оригинальный файл
cp "$TEMP_FILE" /etc/issue
rm -f "$TEMP_FILE"


