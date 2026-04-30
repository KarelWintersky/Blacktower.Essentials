
sudo apt purge localepurge
sudo apt install localepurge
sudo dpkg-reconfigure localepurge
# Выбрать только нужные локали (en_US.UTF-8, ru_RU.UTF-8)
sudo apt install --reinstall bash  # триггерим очистку
