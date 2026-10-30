#!/bin/bash
# ARLYS OS — One-shot bootstrap (Phase 1 minimal)
# Jalankan di Debian 12 amd64 sebagai root:  sudo bash arlys-bootstrap.sh
set -euo pipefail

if [[ $EUID -ne 0 ]]; then
    echo "Harus root: sudo bash $0"
    exit 1
fi

PROJ="/root/arlys-os"
ISO_OUT="ARLYS_OS_1.0_amd64.iso"

echo "==> [1/6] Install dependency build..."
apt-get update
DEBIAN_FRONTEND=noninteractive apt-get install -y \
    live-build debootstrap squashfs-tools xorriso \
    grub-pc-bin grub-efi-amd64-bin mtools dosfstools

echo "==> [2/6] Siapkan folder project di $PROJ ..."
rm -rf "$PROJ"
mkdir -p "$PROJ"
cd "$PROJ"

mkdir -p config/package-lists
mkdir -p config/hooks/live
mkdir -p config/includes.chroot/etc/lightdm
mkdir -p config/includes.chroot/etc/xdg/openbox
mkdir -p config/includes.chroot/etc/xdg/tint2
mkdir -p config/includes.chroot/usr/bin
mkdir -p config/includes.chroot/usr/share/xsessions
mkdir -p config/includes.chroot/usr/share/arlys

echo "==> [3/6] Tulis file konfigurasi..."

# --- daftar paket ---
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
lxterminal
pcmanfm
htop
fonts-inter
fonts-dejavu-core
adwaita-icon-theme
network-manager
sudo
curl
ca-certificates
python3
python3-pyqt6
EOF

# --- LightDM autologin ---
cat > config/includes.chroot/etc/lightdm/lightdm.conf <<'EOF'
[Seat:*]
autologin-user=arlys
autologin-user-timeout=0
user-session=arlys
greeter-session=lightdm-gtk-greeter
greeter-hide-users=true
allow-guest=false
EOF

# --- session file ---
cat > config/includes.chroot/usr/share/xsessions/arlys.desktop <<'EOF'
[Desktop Entry]
Name=ARLYS Desktop
Comment=ARLYS OS Session
Exec=/usr/bin/arlys-session
TryExec=/usr/bin/arlys-session
Type=Application
DesktopNames=ARLYS
EOF

# --- session runner ---
cat > config/includes.chroot/usr/bin/arlys-session <<'EOF'
#!/bin/bash
export XDG_CURRENT_DESKTOP=ARLYS
export XDG_SESSION_DESKTOP=arlys
export XDG_SESSION_TYPE=x11
export QT_QPA_PLATFORM=xcb
xset s off -dpms s noblank 2>/dev/null || true
xsetroot -solid '#0a0d14' 2>/dev/null || true
exec openbox-session
EOF
chmod +x config/includes.chroot/usr/bin/arlys-session

# --- openbox autostart ---
cat > config/includes.chroot/etc/xdg/openbox/autostart <<'EOF'
#!/bin/sh
feh --no-fehbg --bg-fill /usr/share/arlys/wallpaper.jpg 2>/dev/null || \
    xsetroot -solid '#0a0d14'
tint2 -c /etc/xdg/tint2/tint2rc &
EOF
chmod +x config/includes.chroot/etc/xdg/openbox/autostart

# --- tint2 panel minimal ---
cat > config/includes.chroot/etc/xdg/tint2/tint2rc <<'EOF'
panel_monitor = all
panel_position = bottom center horizontal
panel_size = 100% 38
panel_padding = 8 0 8
panel_background_id = 1
panel_items = LTSC

taskbar_mode = single_desktop
task_icon = 1
task_text = 1
task_maximum_size = 200 30
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

launcher_item_app = /usr/share/applications/lxterminal.desktop
launcher_item_app = /usr/share/applications/pcmanfm.desktop
launcher_padding = 8 4 8

# backgrounds
rounded = 0
border_width = 0
background_color = #000000 0
border_color = #000000 0

rounded = 0
border_width = 0
background_color = #0a0d14 92
border_color = #1a2233 100
EOF

# --- wallpaper generator (dijalankan saat build, bukan runtime) ---
cat > config/includes.chroot/usr/share/arlys/make_wallpaper.py <<'EOF'
#!/usr/bin/env python3
from PIL import Image, ImageDraw
W, H = 1920, 1080
img = Image.new("RGB", (W, H), (10, 13, 20))
d = ImageDraw.Draw(img)
for y in range(H):
    t = y / H
    d.line([(0,y),(W,y)], fill=(int(10-8*t), int(13-9*t), int(20-12*t)))
for i in range(200, 0, -1):
    a = i/200.0 * 0.16
    cx, cy = W-380, H-320
    d.ellipse([(cx-i*3,cy-i*3),(cx+i*3,cy+i*3)],
              fill=(int(37*a),int(99*a),int(235*a)))
img.save("/usr/share/arlys/wallpaper.jpg", "JPEG", quality=88, optimize=True)
EOF

# --- hook: branding + user + wallpaper ---
cat > config/hooks/live/0100-arlys.hook.chroot <<'EOF'
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

if ! id arlys >/dev/null 2>&1; then
    useradd -m -s /bin/bash \
        -G sudo,audio,video,netdev,plugdev,cdrom,floppy \
        arlys
    echo "arlys:arlys" | chpasswd
fi
echo "arlys ALL=(ALL) NOPASSWD: ALL" > /etc/sudoers.d/arlys
chmod 0440 /etc/sudoers.d/arlys

chmod 0755 /usr/bin/arlys-session || true
chmod 0755 /etc/xdg/openbox/autostart || true

# wallpaper (butuh Pillow)
if ! python3 -c "import PIL" 2>/dev/null; then
    apt-get install -y python3-pil || true
fi
python3 /usr/share/arlys/make_wallpaper.py || \
    echo "[arlys] WARN: wallpaper generation failed (panel tetap jalan)"

for svc in lightdm NetworkManager; do
    systemctl enable "$svc" 2>/dev/null || true
done
EOF
chmod +x config/hooks/live/0100-arlys.hook.chroot

# --- build script (dipanggil otomatis di bawah) ---
cat > build.sh <<'EOF'
#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")"

lb clean --purge || true
lb config \
    --mode debian \
    --distribution bookworm \
    --architecture amd64 \
    --archive-areas "main contrib non-free non-free-firmware" \
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
EOF
chmod +x build.sh

echo "==> [4/6] Semua file tertulis di $PROJ"
echo "    Struktur:"
find . -type f | sort | sed 's|^\./|    |'

echo "==> [5/6] Mulai build ISO (15–45 menit, tergantung jaringan)..."
./build.sh

echo "==> [6/6] Selesai. Cek hasil:"
ls -lh "$PROJ"/live-image-*.hybrid.iso

if [[ -f live-image-amd64.hybrid.iso ]]; then
    mv live-image-amd64.hybrid.iso "$ISO_OUT"
    sha256sum "$ISO_OUT" > "$ISO_OUT.sha256"
    echo ""
    echo "    ISO  : $PROJ/$ISO_OUT"
    echo "    SHA  : $PROJ/$ISO_OUT.sha256"
    echo ""
    echo "    Ukuran:"
    ls -lh "$ISO_OUT"
else
    echo "    ERROR: ISO tidak terbentuk. Cek log di $PROJ"
    exit 2
fi