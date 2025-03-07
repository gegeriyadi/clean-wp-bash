#!/bin/bash

# Script untuk reset instalasi plugin WordPress setelah serangan malware
# Penggunaan: ./wp-plugin-reset.sh [path-ke-wordpress]

# Warna untuk output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
NC='\033[0m' # No Color

# Fungsi untuk menampilkan pesan
print_message() {
    echo -e "${2}${1}${NC}"
}

# Cek apakah path disediakan
if [ $# -eq 0 ]; then
    read -p "Masukkan path ke instalasi WordPress: " WP_PATH
    # Jika user tidak memasukkan apa-apa, gunakan direktori saat ini
    if [ -z "$WP_PATH" ]; then
        WP_PATH="."
        print_message "Path tidak disediakan, menggunakan direktori saat ini." "$YELLOW"
    fi
else
    WP_PATH="$1"
fi

# Cek apakah direktori WordPress valid
if [ ! -f "$WP_PATH/wp-config.php" ]; then
    print_message "Error: Direktori WordPress tidak valid! wp-config.php tidak ditemukan di $WP_PATH" "$RED"
    exit 1
fi

# Konfirmasi dari pengguna
print_message "PERINGATAN: Script ini akan menghapus semua plugin dan cache WordPress Anda." "$RED"
print_message "Backup database Anda sebelum melanjutkan!" "$RED"
read -p "Apakah Anda yakin ingin melanjutkan? (y/n): " -n 1 -r
echo
if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    print_message "Operasi dibatalkan." "$YELLOW"
    exit 0
fi

# Mulai proses reset
print_message "Memulai proses reset plugin WordPress..." "$GREEN"

# 1. Backup daftar plugin aktif
ACTIVE_PLUGINS_FILE="$WP_PATH/active-plugins-backup.txt"
print_message "Membuat backup daftar plugin aktif ke $ACTIVE_PLUGINS_FILE..." "$GREEN"

# Deteksi apakah script dijalankan dengan sudo/root
ROOT_USER=0
if [ "$(id -u)" = "0" ]; then
    ROOT_USER=1
    print_message "Script dijalankan sebagai root, akan menambahkan --allow-root ke perintah WP-CLI" "$YELLOW"
fi

# Menggunakan WP-CLI jika tersedia
if command -v wp &> /dev/null; then
    if [ $ROOT_USER -eq 1 ]; then
        cd "$WP_PATH" && wp plugin list --status=active --field=name --allow-root > "$ACTIVE_PLUGINS_FILE"
    else
        cd "$WP_PATH" && wp plugin list --status=active --field=name > "$ACTIVE_PLUGINS_FILE"
    fi
    
    if [ $? -ne 0 ]; then
        print_message "WP-CLI gagal, menggunakan metode alternatif..." "$YELLOW"
        find "$WP_PATH/wp-content/plugins" -maxdepth 1 -type d -not -path "*/\.*" -not -path "$WP_PATH/wp-content/plugins" | xargs -n 1 basename > "$ACTIVE_PLUGINS_FILE"
    fi
else
    print_message "WP-CLI tidak ditemukan, menggunakan metode alternatif untuk backup plugin..." "$YELLOW"
    find "$WP_PATH/wp-content/plugins" -maxdepth 1 -type d -not -path "*/\.*" -not -path "$WP_PATH/wp-content/plugins" | xargs -n 1 basename > "$ACTIVE_PLUGINS_FILE"
fi

# 2. Hapus direktori plugin
print_message "Menghapus semua plugin..." "$GREEN"
if [ -d "$WP_PATH/wp-content/plugins" ]; then
    # Hitung jumlah plugin sebelum backup
    PLUGIN_COUNT=$(find "$WP_PATH/wp-content/plugins" -maxdepth 1 -type d -not -path "*/\.*" -not -path "$WP_PATH/wp-content/plugins" | wc -l)
    
    if [ "$PLUGIN_COUNT" -eq 0 ]; then
        print_message "Tidak ada plugin terdeteksi di direktori plugin." "$YELLOW"
        read -p "Tetap lanjutkan? (y/n): " -n 1 -r
        echo
        if [[ ! $REPLY =~ ^[Yy]$ ]]; then
            print_message "Operasi dibatalkan." "$YELLOW"
            exit 0
        fi
    else
        print_message "Ditemukan $PLUGIN_COUNT plugin. Membackup ke plugins.bak..." "$GREEN"
    fi
    
    # Backup direktori plugin
    mv "$WP_PATH/wp-content/plugins" "$WP_PATH/wp-content/plugins.bak"
    
    # Verifikasi backup berhasil
    if [ ! -d "$WP_PATH/wp-content/plugins.bak" ]; then
        print_message "KESALAHAN: Backup plugin gagal!" "$RED"
        exit 1
    fi
    
    # Verifikasi isi backup
    BACKUP_COUNT=$(find "$WP_PATH/wp-content/plugins.bak" -maxdepth 1 -type d -not -path "*/\.*" -not -path "$WP_PATH/wp-content/plugins.bak" | wc -l)
    if [ "$BACKUP_COUNT" -ne "$PLUGIN_COUNT" ]; then
        print_message "PERINGATAN: Jumlah plugin dalam backup ($BACKUP_COUNT) berbeda dari jumlah asli ($PLUGIN_COUNT)" "$YELLOW"
    else
        print_message "Verifikasi backup: $BACKUP_COUNT plugin berhasil dicadangkan." "$GREEN"
    fi
    
    # Buat direktori plugin baru
    mkdir "$WP_PATH/wp-content/plugins"
    chmod 755 "$WP_PATH/wp-content/plugins"
    
    print_message "Reset plugin selesai. Direktori asli tersimpan di: $WP_PATH/wp-content/plugins.bak" "$GREEN"
else
    print_message "Direktori plugin tidak ditemukan!" "$RED"
    exit 1
fi

# 3. Hapus cache
print_message "Menghapus cache WordPress..." "$GREEN"
rm -rf "$WP_PATH/wp-content/cache/"*
if [ -d "$WP_PATH/wp-content/advanced-cache.php" ]; then
    rm -f "$WP_PATH/wp-content/advanced-cache.php"
fi

# 4. Instal ulang plugin dari daftar yang sudah dicadangkan
if command -v wp &> /dev/null; then
    print_message "WP-CLI terdeteksi. Ingin menginstal ulang plugin dari daftar backup?" "$GREEN"
    read -p "Instal ulang plugin? (y/n): " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        print_message "Menginstal plugin dari daftar backup..." "$GREEN"
        
        # Buat log file
        LOG_FILE="$WP_PATH/plugin_install_log.txt"
        echo "Log instalasi plugin pada $(date)" > "$LOG_FILE"
        echo "-------------------------------------" >> "$LOG_FILE"
        
        # Inisialisasi counter untuk plugin yang berhasil dan gagal
        SUCCESS_COUNT=0
        FAILED_COUNT=0
        FAILED_PLUGINS=""
        
        # Cek apakah file daftar plugin tersedia
        if [ -f "$ACTIVE_PLUGINS_FILE" ]; then
            # Baca file daftar plugin dan instal satu per satu
            while IFS= read -r plugin
            do
                print_message "Menginstal plugin: $plugin" "$GREEN"
                if [ $ROOT_USER -eq 1 ]; then
                    cd "$WP_PATH" && wp plugin install "$plugin" --activate --allow-root > /tmp/wp_install_output 2>&1
                else
                    cd "$WP_PATH" && wp plugin install "$plugin" --activate > /tmp/wp_install_output 2>&1
                fi
                
                INSTALL_STATUS=$?
                cat /tmp/wp_install_output >> "$LOG_FILE"
                
                if [ $INSTALL_STATUS -ne 0 ]; then
                    print_message "Gagal menginstal plugin: $plugin" "$RED"
                    echo "[GAGAL] $plugin" >> "$LOG_FILE"
                    echo "---" >> "$LOG_FILE"
                    FAILED_COUNT=$((FAILED_COUNT + 1))
                    FAILED_PLUGINS="$FAILED_PLUGINS\n- $plugin"
                else
                    print_message "Berhasil menginstal plugin: $plugin" "$GREEN"
                    echo "[SUKSES] $plugin" >> "$LOG_FILE"
                    echo "---" >> "$LOG_FILE"
                    SUCCESS_COUNT=$((SUCCESS_COUNT + 1))
                fi
            done < "$ACTIVE_PLUGINS_FILE"
            
            # Ringkasan instalasi
            print_message "\nInstalasi plugin selesai!" "$GREEN"
            print_message "Berhasil: $SUCCESS_COUNT plugin" "$GREEN"
            
            if [ $FAILED_COUNT -gt 0 ]; then
                print_message "Gagal: $FAILED_COUNT plugin" "$RED"
                print_message "Plugin yang gagal diinstal:$FAILED_PLUGINS" "$RED"
                print_message "Silakan lihat log lengkap di: $LOG_FILE" "$YELLOW"
                print_message "Anda perlu menginstal plugin tersebut secara manual" "$YELLOW"
            fi
        else
            print_message "File daftar plugin tidak ditemukan!" "$RED"
        fi
    else
        print_message "Penginstalan plugin dibatalkan." "$YELLOW"
    fi
else
    print_message "WP-CLI tidak terdeteksi. Plugin harus diinstal secara manual." "$YELLOW"
    print_message "Instal WP-CLI untuk penginstalan otomatis: https://wp-cli.org/" "$YELLOW"
    print_message "Lihat daftar plugin yang perlu diinstal di: $ACTIVE_PLUGINS_FILE" "$YELLOW"
fi

# 8. Petunjuk untuk langkah selanjutnya
print_message "\nReset plugin selesai!" "$GREEN"
print_message "Langkah selanjutnya:" "$GREEN"
print_message "1. Update WordPress ke versi terbaru" "$YELLOW"
print_message "2. Instal plugin keamanan seperti Wordfence atau Sucuri" "$YELLOW"
print_message "3. Ubah semua password (WordPress, FTP, database, hosting)" "$YELLOW"
print_message "4. Jika Anda menyimpan backup plugin lama di plugins.bak, hapus setelah verifikasi" "$YELLOW"

exit 0
