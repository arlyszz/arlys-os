#!/bin/bash
# ==============================================================================
# ARLYS OS AUTOMATED BUILD SCRIPT (ULTIMATE FIXED VERSION)
# ==============================================================================
set -euo pipefail

if [[ $EUID -ne 0 ]]; then
   echo "Jalankan sebagai root: sudo bash arlys-bootstrap.sh"
   exit 1
fi

PROJ_DIR="/root/arlys-build"
DIST_DIR="/root/arlys-build/dist"
mkdir -p "$PROJ_DIR"
cd "$PROJ_DIR"

echo "[1/5] Menginstal dependency build..."
apt-get update
DEBIAN_FRONTEND=noninteractive apt-get install -y \
    live-build debootstrap squashfs-tools xorriso \
    grub-pc-bin grub-efi-amd64-bin mtools dosfstools zip curl

echo "[2/5] Membuat struktur folder..."
lb clean --purge || true
mkdir -p config/package-lists config/hooks/live config/includes.chroot/etc/lightdm
mkdir -p config/includes.chroot/etc/xdg/openbox config/includes.chroot/etc/xdg/tint2
mkdir -p config/includes.chroot/usr/bin config/includes.chroot/usr/share/xsessions
mkdir -p config/includes.chroot/usr/share/backgrounds

echo "[3/5] Menulis konfigurasi OS, GUI, dan Branding..."

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

cat > config/hooks/live/0100-arlys-branding.hook.chroot <<'EOF'
#!/bin/sh
set -e
cat > /etc/os-release <<'EOT'
PRETTY_NAME="ARLYS OS 1.0"
NAME="ARLYS OS"
VERSION_ID="1.0"
ID=arlys
ID_LIKE=debian
EOT
echo "arlys" > /etc/hostname
if ! id arlys >/dev/null 2>&1; then
    useradd -m -s /bin/bash -G sudo,audio,video,netdev,plugdev arlys
    echo "arlys:arlys" | chpasswd
fi
echo "arlys ALL=(ALL) NOPASSWD: ALL" > /etc/sudoers.d/arlys
chmod 0755 /usr/bin/arlys-session || true
chmod 0755 /etc/xdg/openbox/autostart || true

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

cat > config/includes.chroot/etc/lightdm/lightdm.conf <<'EOF'
[Seat:*]
autologin-user=arlys
autologin-user-timeout=0
user-session=arlys
greeter-session=lightdm-gtk-greeter
allow-guest=false
EOF

cat > config/includes.chroot/usr/share/xsessions/arlys.desktop <<'EOF'
[Desktop Entry]
Name=ARLYS Desktop
Exec=/usr/bin/arlys-session
Type=Application
EOF

cat > config/includes.chroot/usr/bin/arlys-session <<'EOF'
#!/bin/bash
export XDG_CURRENT_DESKTOP=ARLYS
xset s off -dpms s noblank 2>/dev/null || true
exec openbox-session
EOF
chmod +x config/includes.chroot/usr/bin/arlys-session

cat > config/includes.chroot/etc/xdg/openbox/autostart <<'EOF'
#!/bin/sh
feh --no-fehbg --bg-fill /usr/share/backgrounds/arlys-wallpaper.jpg 2>/dev/null || xsetroot -solid '#0a0d14'
tint2 -c /etc/xdg/tint2/tint2rc &
EOF
chmod +x config/includes.chroot/etc/xdg/openbox/autostart

cat > config/includes.chroot/etc/xdg/tint2/tint2rc <<'EOF'
panel_position = bottom center horizontal
panel_size = 100% 40
panel_background_id = 1
panel_items = LTSC
task_icon = 1
task_text = 1
task_font = Inter 9
task_font_color = #c9d1e0 100
time1_format = %H:%M
time1_font = Inter Bold 10
clock_font_color = #e6ecf5 100
launcher_item_app = /usr/share/applications/chromium.desktop
launcher_item_app = /usr/share/applications/lxterminal.desktop
launcher_item_app = /usr/share/applications/pcmanfm.desktop
rounded = 0
background_color = #000000 0
rounded = 0
background_color = #0a0d14 92
EOF

echo "[4/5] Build ISO (INI PROSES PALING LAMA)..."
lb config \
    --mode debian \
    --distribution bookworm \
    --architecture amd64 \
    --archive-areas "main contrib non-free non-free-firmware" \
    --security false \
    --apt-indices false \
    --mirror-bootstrap "http://deb.debian.org/debian/" \
    --mirror-chroot "http://deb.debian.org/debian/" \
    --mirror-binary "http://deb.debian.org/debian/" \
    --binary-images iso-hybrid \
    --bootloader "grub-efi grub-pc" \
    --debian-installer false \
    --iso-application "ARLYS OS" \
    --iso-volume "ARLYS_OS" \
    --memtest none \
    --bootappend-live "boot=live components quiet splash"

lb build

echo "[5/5] Memindahkan output..."
mkdir -p "$DIST_DIR"
mv live-image-amd64.hybrid.iso "$DIST_DIR/ARLYS-OS.iso"
