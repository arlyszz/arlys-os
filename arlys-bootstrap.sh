#!/bin/bash
# ==============================================================================
# ARLYS OS V3.0 - ULTIMATE EDITION (1 FILE SCRIPT)
# Tampilan Modern, Dock Bawah, Internet, Jam Real-time, Games, App Store.
# 100% Bebas Branding Debian!
# ==============================================================================
set -euo pipefail

if [[ $EUID -ne 0 ]]; then
   echo "Harus root!"
   exit 1
fi

PROJ_DIR="/root/arlys-build"
DIST_DIR="/root/arlys-build/dist"
mkdir -p "$PROJ_DIR"
cd "$PROJ_DIR"

echo "[1/5] Install dependency dasar..."
apt-get update
DEBIAN_FRONTEND=noninteractive apt-get install -y \
    live-build debootstrap squashfs-tools xorriso \
    grub-pc-bin grub-efi-amd64-bin mtools dosfstools zip curl

echo "[2/5] Meracik Folder OS..."
lb clean --purge || true
mkdir -p config/package-lists config/hooks/live config/includes.chroot/etc/lightdm
mkdir -p config/includes.chroot/etc/xdg/autostart
mkdir -p config/includes.chroot/etc/skel/.config/plank/dock1/launchers
mkdir -p config/includes.chroot/usr/share/backgrounds
mkdir -p config/includes.chroot/usr/share/plymouth/themes/arlys

echo "[3/5] Memasukkan Paket Aplikasi & Game (100% ARLYS)..."

cat > config/package-lists/arlys.list.chroot <<'EOF'
live-boot
live-config
live-config-systemd
xorg
xserver-xorg
xinit
xfce4
xfce4-terminal
thunar
lightdm
lightdm-gtk-greeter
network-manager
network-manager-gnome
chromium
plymouth
plymouth-themes
gnome-software
gnome-games
sgt-puzzles
htop
nano
curl
sudo
fonts-inter
fonts-dejavu-core
adwaita-icon-theme
arc-theme
papirus-icon-theme
plank
python3
python3-pil
EOF

echo "[4/5] Menyuntikkan Tema, Jam, Wallpaper, dan Branding ARLYS..."
cat > config/hooks/live/0100-arlys-v3.hook.chroot <<'EOF'
#!/bin/sh
set -e

# 1. HAPUS TOTAL BRANDING DEBIAN
cat > /etc/os-release <<'EOT'
PRETTY_NAME="ARLYS OS 3.0"
NAME="ARLYS OS"
VERSION_ID="3.0"
VERSION="3.0 (Ultimate)"
ID=arlys
ID_LIKE=linux
HOME_URL="https://koistudio.example/arlys"
EOT
echo "arlys" > /etc/hostname
grep -q '^127.0.1.1' /etc/hosts || echo "127.0.1.1 arlys" >> /etc/hosts
echo "ARLYS OS 3.0 \\n \\l" > /etc/issue

# 2. USER & PASSWORD
if ! id arlys >/dev/null 2>&1; then
    useradd -m -s /bin/bash -G sudo,audio,video,netdev,plugdev,cdrom arlys
    echo "arlys:arlys" | chpasswd
fi
echo "arlys ALL=(ALL) NOPASSWD: ALL" > /etc/sudoers.d/arlys

# 3. WALLPAPER KUSTOM (PILIHAN)
python3 -c "
from PIL import Image, ImageDraw
W, H = 1920, 1080
img = Image.new('RGB', (W, H), (5, 8, 15))
d = ImageDraw.Draw(img)
for y in range(H):
    t = y / H
    d.line([(0,y),(W,y)], fill=(int(10-8*t), int(15-10*t), int(25-15*t)))
for i in range(400, 0, -1):
    a = i/400.0 * 0.15
    d.ellipse([(W-600-i*3, H-600-i*3),(W-600+i*3, H-600+i*3)], fill=(int(30*a),int(100*a),int(255*a)))
img.save('/usr/share/backgrounds/arlys-bg.jpg', 'JPEG')
"

# 4. JAM REAL-TIME (SINKRONISASI INTERNET)
systemctl enable systemd-timesyncd || true

# 5. TEMA XFCE (MODE GELAP ELEGAN + DOCK)
mkdir -p /etc/xdg/xfce4/xfconf/xfce-perchannel-xml
cat > /etc/xdg/xfce4/xfconf/xfce-perchannel-xml/xsettings.xml <<'XML'
<?xml version="1.0" encoding="UTF-8"?>
<channel name="xsettings" version="1.0">
  <property name="Net" type="empty">
    <property name="ThemeName" type="string" value="Arc-Dark"/>
    <property name="IconThemeName" type="string" value="Papirus-Dark"/>
  </property>
</channel>
XML

# 6. AUTOSTART PLANK DOCK (MAC-STYLE) & NETWORK
cat > /etc/xdg/autostart/plank.desktop <<'XML'
[Desktop Entry]
Type=Application
Exec=plank
Hidden=false
NoDisplay=false
X-GNOME-Autostart-enabled=true
Name=Plank
XML

# Set Dock bawah otomatis
cat > /etc/skel/.config/plank/dock1/settings <<'EOT'
[PlankDockPreferences]
Theme=Transparent
Position=3
IconSize=48
EOT

# 7. LIGHTDM (AUTOLOGIN KE XFCE)
cat > /etc/lightdm/lightdm.conf <<'EOT'
[Seat:*]
autologin-user=arlys
autologin-user-timeout=0
user-session=xfce
greeter-session=lightdm-gtk-greeter
EOT

cat > /etc/lightdm/lightdm-gtk-greeter.conf <<'EOT'
[greeter]
theme-name = Arc-Dark
icon-theme-name = Papirus-Dark
background = /usr/share/backgrounds/arlys-bg.jpg
EOT

systemctl enable lightdm NetworkManager || true
EOF
chmod +x config/hooks/live/0100-arlys-v3.hook.chroot

echo "[5/5] Build ISO (20-40 menit)..."
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
    --iso-volume "ARLYS_OS_V3" \
    --memtest none \
    --bootappend-live "boot=live components quiet splash"

lb build

mkdir -p "$DIST_DIR"
mv live-image-amd64.hybrid.iso "$DIST_DIR/ARLYS-OS-V3.iso"
