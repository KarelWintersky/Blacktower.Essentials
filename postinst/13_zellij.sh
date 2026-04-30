#!/usr/bin/env bash

# Целевая директория для установки
install_dir="/usr/local/bin"
binary_path="$install_dir/zellij"

# Проверяем, не запущен ли скрипт от root (нужно для /usr/local/bin)
if [[ $EUID -ne 0 ]]; then
   echo "Этот скрипт требует прав root для установки в $install_dir"
   echo "Запустите с sudo: sudo $0"
   exit 1
fi

# Определяем архитектуру
case $(uname -m) in
    "x86_64"|"aarch64")
        arch=$(uname -m)
        ;;
    "arm64")
        arch="aarch64"
        ;;
    *)
        echo "Unsupported cpu arch: $(uname -m)"
        exit 2
        ;;
esac

# Определяем ОС
case $(uname -s) in
    "Linux")
        sys="unknown-linux-musl"
        ;;
    "Darwin")
        sys="apple-darwin"
        ;;
    *)
        echo "Unsupported system: $(uname -s)"
        exit 2
        ;;
esac

# Создаём временную директорию для скачивания
temp_dir=$(mktemp -d)
trap "rm -rf $temp_dir" EXIT

# Скачиваем и распаковываем
url="https://github.com/zellij-org/zellij/releases/latest/download/zellij-$arch-$sys.tar.gz"
echo "Downloading zellij from: $url"
curl --location "$url" | tar -C "$temp_dir" -xz

if [[ $? -ne 0 ]]; then
    echo
    echo "Extracting binary failed, cannot download zellij :("
    echo "One probable cause is that a new release just happened and the binary is currently building."
    echo "Maybe try again later? :)"
    exit 1
fi

# Копируем бинарник в /usr/local/bin
cp "$temp_dir/zellij" "$binary_path"
chmod +x "$binary_path"

echo -e "✓ Zellij successfully installed to $binary_path"
echo -e "Run 'zellij' to start using it"

