#!/bin/bash

# Check if script is run with root privileges
ROOT_FLAG=""
if [ "$(id -u)" -eq 0 ]; then
    ROOT_FLAG="--allow-root"
    echo "Running with root privileges. Adding --allow-root to WP-CLI commands."
fi

# Step 1: Backup wp-content dan wp-config.php
BACKUP_DIR="wp-backup-$(date +%Y%m%d%H%M%S)"
mkdir -p "$BACKUP_DIR"
cp -r wp-content "$BACKUP_DIR/"
cp wp-config.php "$BACKUP_DIR/"

# Step 2: Catat WordPress core version dan simpan ke log
WP_VERSION=$(wp core version $ROOT_FLAG)
echo "WordPress Version: $WP_VERSION" > "$BACKUP_DIR/wordpress_version.log"

# Step 3: Hapus semua file dan folder selain wp-content dan wp-config.php
find . -mindepth 1 -maxdepth 1 ! -name 'wp-content' ! -name 'wp-config.php' ! -name "$BACKUP_DIR" -exec rm -rf {} +

# Step 4: Download WordPress core dari link resmi
WP_CORE_URL="https://wordpress.org/latest.zip"
wget "$WP_CORE_URL" -O latest.zip

# Step 5: Unzip / extract file core
unzip latest.zip
rm latest.zip
cd wordpress
rm -rf wp-content
cd ../

# Step 6: Pindahkan file-file core WordPress ke direktori saat ini
mv wordpress/* .
mv wordpress/.* . 2>/dev/null || true  # Pindahkan file hidden (seperti .htaccess)

# Step 7: Hapus folder wordpress yang sudah kosong
rm -rf wordpress

# Step 8: Kembalikan wp-content dan wp-config.php dari backup
cp -r "$BACKUP_DIR/wp-content" .
cp "$BACKUP_DIR/wp-config.php" .

echo "Pembersihan WordPress selesai. Backup disimpan di $BACKUP_DIR."
