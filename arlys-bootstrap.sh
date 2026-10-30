#!/bin/bash
# ==============================================================================
# ARLYS OS AUTOMATED BUILD SCRIPT (FIXED)
# ==============================================================================
set -euo pipefail

if [[ $EUID -ne 0 ]]; then
   echo "Jalankan sebagai root: sudo bash build.sh"
   exit 1
fi

PROJ_DIR="/root/arlys-build"
DIST_DIR="/root/arlys-build/dist"
mkdir -p "$PROJ_DIR"
cd "$PROJ_DIR"

echo "[1/5] Menginstal dependency build (live-build, dll)..."
apt-get update
DEBIAN_FRONTEND=noninteractive apt-get install -y \
    live-build debootstrap squashfs-tools xorriso \
    grub-pc-bin grub-efi-amd64-bin mtools dosfstools zip curl

echo "[2/5] Membuat struktur folder ARLYS OS..."
lb clean --purge || true
mkdir -p config/package-lists
mkdir -p config/hooks/live
mkdir -p config/includes.chroot/etc/lightdm
mkdir -p config/includes.chroot/etc/xdg/openbox
mkdir -p config/includes.chroot/etc/xdg/tint2
mkdir -p config/includes.chroot/usr/bin
mkdir -p config/includes.chroot/usr/share/xsessions
mkdir -p config/includes.chroot/usr/share/arlys
mkdir -p config/includes.chroot/usr/share/backgrounds

echo "[3/5] Menulis konfigurasi OS, GUI, dan Branding..."

# --- Package List ---
cat > config/package-lists/arlys.list.chroot <<'EOF'
live-boot
live-config
live-config-systemd
xorg
xserver-xorg
xinit
x11-xserver-utils
lightdm
lightdm-gtk-greeter
openbox
obconf
tint2
feh
network-manager
network-manager-gnome
chromium
lxterminal
pcmanfm
htop
nano
curl
fonts-inter
fonts-dejavu-core
adwaita-icon-theme
python3
python3-pil
EOF

# --- Branding OS ---
cat > config/hooks/live/0100-arlys-branding.hook.chroot <<'EOF'
#!/bin/sh
set -e

cat > /etc/os-release <<'EOT'
PRETTY_NAME="ARLYS OS 1.0"
NAME="ARLYS OS"
VERSION_ID="1.0"
VERSION="1.0 (Genesis)"
ID=arlys
ID_LIKE=debian
HOME_URL="https://koistudio.example/arlys"
EOT
echo "ARLYS OS 1.0 \\n \\l" > /etc/issue
echo "arlys" > /etc/hostname
grep -q '^127.0.1.1' /etc/hosts || echo "127.0.1.1 arlys" >> /etc/hosts

# Buat user default 'arlys'
if ! id arlys >/dev/null 2>&1; then
    useradd -m -s /bin/bash -G sudo,audio,video,netdev,plugdev,cdrom arlys
    echo "arlys:arlys" | chpasswd
fi
echo "arlys ALL=(ALL) NOPASSWD: ALL" > /etc/sudoers.d/arlys
chmod 0440 /etc/sudoers.d/arlys

chmod 0755 /usr/bin/arlys-session || true
chmod 0755 /etc/xdg/openbox/autostart || true

# Buat wallpaper kustom via Python
python3 -c "
from PIL import Image, ImageDraw
W, H = 1920, 1080
img = Image.new('RGB', (W, H), (10, 13, 20))
d = ImageDraw.Draw(img)
for y in range(H):
    t = y / H
    d.line([(0,y),(W,y)], fill=(int(10-8*t), int(13-9*t), int(20-12*t)))
for i in range(200, 0, -1):
    a = i/200.0 * 0.16
    d.ellipse([(W-400-i*3, H-400-i*3),(W-400+i*3, H-400+i*3)], fill=(int(37*a),int(99*a),int(235*a)))
img.save('/usr/share/backgrounds/arlys-wallpaper.jpg', 'JPEG')
" || true

systemctl enable lightdm NetworkManager || true
EOF
chmod +x config/hooks/live/0100-arlys-branding.hook.chroot

# --- LightDM Autologin ---
cat > config/includes.chroot/etc/lightdm/lightdm.conf <<'EOF'
[Seat:*]
autologin-user=arlys
autologin-user-timeout=0
user-session=arlys
greeter-session=lightdm-gtk-greeter
allow-guest=false
EOF

# --- Sesi X11 ARLYS ---
cat > config/includes.chroot/usr/share/xsessions/arlys.desktop <<'EOF'
[Desktop Entry]
Name=ARLYS Desktop
Comment=ARLYS OS Session
Exec=/usr/bin/arlys-session
Type=Application
DesktopNames=ARLYS
EOF

cat > config/includes.chroot/usr/bin/arlys-session <<'EOF'
#!/bin/bash
export XDG_CURRENT_DESKTOP=ARLYS
export XDG_SESSION_DESKTOP=arlys
export QT_QPA_PLATFORM=xcb
xset s off -dpms s noblank 2>/dev/null || true
exec openbox-session
EOF
chmod +x config/includes.chroot/usr/bin/arlys-session

# --- Openbox Autostart (Wallpaper & Panel) ---
cat > config/includes.chroot/etc/xdg/openbox/autostart <<'EOF'
#!/bin/sh
feh --no-fehbg --bg-fill /usr/share/backgrounds/arlys-wallpaper.jpg 2>/dev/null || xsetroot -solid '#0a0d14'
tint2 -c /etc/xdg/tint2/tint2rc &
EOF
chmod +x config/includes.chroot/etc/xdg/openbox/autostart

# --- Tint2 Panel Kustom ---
cat > config/includes.chroot/etc/xdg/tint2/tint2rc <<'EOF'
panel_monitor = all
panel_position = bottom center horizontal
panel_size = 100% 40
panel_padding = 8 0 8
panel_background_id = 1
panel_items = LTSC
taskbar_mode = single_desktop
task_icon = 1
task_text = 1
task_maximum_size = 200 32
task_font = Inter 9
task_font_color = #c9d1e0 100
task_active_font_color = #ffffff 100
task_background_id = 0
time1_format = %H:%M
time1_font = Inter Bold 10
time2_format = %a %d %b
time2_font = Inter 8
clock_font_color = #e6ecf5 100
systray_padding = 4 4 4
systray_icon_size = 22
launcher_item_app = /usr/share/applications/chromium.desktop
launcher_item_app = /usr/share/applications/lxterminal.desktop
launcher_item_app = /usr/share/applications/pcmanfm.desktop
launcher_padding = 8 4 8
rounded = 0
border_width = 0
background_color = #000000 0
border_color = #000000 0
rounded = 0
border_width = 0
background_color = #0a0d14 92
border_color = #1a2233 100
EOF

echo "[4/5] Menjalankan proses build live-build (20-40 menit)..."
lb config \
    --mode debian \
    --distribution bookworm \
    --architecture amd64 \
    --archive-areas "main contrib non-free non-free-firmware" \
    --security false \
    --binary-images iso-hybrid \
    --bootloader "grub-efi grub-pc" \
    --debian-installer false \
    --iso-application "ARLYS OS" \
    --iso-publisher "Koi Studio" \
    --iso-volume "ARLYS_OS" \
    --memtest none \
    --apt-indices false \
    --bootappend-live "boot=live components quiet splash"

lb build

echo "[5/5] Memindahkan output ke folder dist/ dan membuat ZIP..."
mkdir -p "$DIST_DIR"
mv live-image-amd64.hybrid.iso "$DIST_DIR/ARLYS-OS.iso"
cd "$PROJ_DIR"
zip -r "$DIST_DIR/ARLYS-OS.zip" config

echo "======================================================="
echo "BUILD SELESAI!"
echo "File ISO : $DIST_DIR/ARLYS-OS.iso"
echo "File ZIP : $DIST_DIR/ARLYS-OS.zip"
echo "======================================================="
