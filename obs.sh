#!/bin/bash

# Meminta link download dari user
echo "Masukkan link download file backup (format zip):"
read download_link

# 1. Hapus semua file kecuali wp-config.php
echo "Menghapus semua file kecuali wp-config.php..."
find . -type f -not -name "wp-config.php" -delete

# 2. Rename wp-config.php ke wp-config.php.OBS
echo "Merename wp-config.php ke wp-config.php.OBS..."
mv wp-config.php wp-config.php.OBS

# 3. Download file zip backup menggunakan wget
echo "Mendownload file backup..."
wget "$download_link"

# Ambil nama file dari link download
filename=$(basename "$download_link")

# 4. Unzip file backup dan rename wp-config.php hasil unzip ke wp-config.php.ORI
echo "Mengekstrak file backup..."
unzip "$filename"
if [ -f wp-config.php ]; then
    echo "Merename wp-config.php hasil ekstrak ke wp-config.php.ORI..."
    mv wp-config.php wp-config.php.ORI
fi

# 5. Rename wp-config.php.OBS kembali menjadi wp-config.php
echo "Merename wp-config.php.OBS kembali menjadi wp-config.php..."
mv wp-config.php.OBS wp-config.php

# 6. Instalasi plugin wordfence dan one-time-login menggunakan wp cli
echo "Menginstall plugin Wordfence..."
wp plugin install wordfence --activate --allow-root
echo "Menginstall plugin One Time Login..."
wp plugin install one-time-login --activate --allow-root

# 7 & 8. Login dengan wp user one-time-login dengan --allow-root
echo "Membuat link login one-time untuk user ID 19..."
wp user one-time-login 19 --allow-root

# 9. Echo selesai dengan warna font hijau
echo -e "\e[32mSelesai!\e[0m"
