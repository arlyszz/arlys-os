#!/bin/bash
# ==============================================================================
# ARLYS OS V4.0 (KOIOS) - FINAL OPTIMIZED BUILD
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
    grub-pc-bin grub-efi-amd64-bin mtools dosfstools zip curl wget gpg

echo "[2/5] Meracik Folder OS..."
lb clean --purge || true
mkdir -p config/package-lists config/hooks/live config/includes.chroot/etc/lightdm
mkdir -p config/includes.chroot/etc/xdg/autostart
mkdir -p config/includes.chroot/etc/xdg/xfce4/xfconf/xfce-perchannel-xml
mkdir -p config/includes.chroot/etc/skel/.config/plank/dock1/launchers
mkdir -p config/includes.chroot/usr/share/backgrounds
mkdir -p config/includes.chroot/usr/share/plymouth/themes/koios

echo "[3/5] Memasukkan Paket Aplikasi, VS Code, Game, & WiFi..."

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
xfce4-network-manager-plugin
xfce4-pulseaudio-plugin
xfce4-power-manager
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

echo "[4/5] Konfigurasi Total (Anti-Debian, KOIOS Store, dll)..."
cat > config/hooks/live/0100-arlys-v4.hook.chroot <<'EOF'
#!/bin/sh
set -e

# 1. HAPUS TOTAL BRANDING DEBIAN & UBAH JADI KOIOS
cat > /etc/os-release <<'EOT'
PRETTY_NAME="ARLYS OS 4.0 (KOIOS)"
NAME="ARLYS OS"
VERSION_ID="4.0"
VERSION="4.0 (KOIOS)"
ID=arlys
ID_LIKE=linux
HOME_URL="https://koistudio.example/arlys"
EOT
echo "koios" > /etc/hostname
echo "127.0.1.1 koios" >> /etc/hosts
rm -f /etc/debian_version
echo "ARLYS OS 4.0 (KOIOS) \\n \\l" > /etc/issue

# Ubah prompt terminal jadi arlys@koios
echo "export PS1='\[\e[1;36m\]arlys@koios\[\e[0m\]:\[\e[1;34m\]\w\[\e[0m\]\$ '" >> /etc/bash.bashrc

# 2. BUAT USER
if ! id arlys >/dev/null 2>&1; then
    useradd -m -s /bin/bash -G sudo,audio,video,netdev,plugdev,cdrom arlys
    echo "arlys:arlys" | chpasswd
fi
echo "arlys ALL=(ALL) NOPASSWD: ALL" > /etc/sudoers.d/arlys

# 3. WALLPAPER KUSTOM
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

# 4. UBAH NAMA APP STORE JADI "KOIOS STORE"
if [ -f /usr/share/applications/org.gnome.Software.desktop ]; then
    cp /usr/share/applications/org.gnome.Software.desktop /usr/share/applications/koios-store.desktop
    sed -i 's/^Name=.*/Name=KOIOS Store/' /usr/share/applications/koios-store.desktop
    echo "NoDisplay=true" >> /usr/share/applications/org.gnome.Software.desktop
fi

# 5. INSTALL & UBAH NAMA VS CODE JADI "KOIOS CODE"
mkdir -p /etc/apt/keyrings
wget -qO- https://packages.microsoft.com/keys/microsoft.asc | gpg --dearmor > packages.microsoft.gpg
install -D -o root -g root -m 644 packages.microsoft.gpg /etc/apt/keyrings/packages.microsoft.gpg
echo "deb [arch=amd64,arm64,armhf signed-by=/etc/apt/keyrings/packages.microsoft.gpg] https://packages.microsoft.com/repos/code stable main" > /etc/apt/sources.list.d/vscode.list
rm -f packages.microsoft.gpg
apt-get update
apt-get install -y code
if [ -f /usr/share/applications/code.desktop ]; then
    cp /usr/share/applications/code.desktop /usr/share/applications/koios-code.desktop
    sed -i 's/^Name=.*/Name=KOIOS Code/' /usr/share/applications/koios-code.desktop
    echo "NoDisplay=true" >> /usr/share/applications/code.desktop
fi

# 6. INTRO BOOT (PLYMOUTH KOIOS)
cat > /usr/share/plymouth/themes/koios/koios.plymouth <<'XML'
[Plymouth Theme]
Name=KOIOS
Description=ARLYS OS KOIOS Boot
ModuleName=script
[script]
ImageDir=/usr/share/plymouth/themes/koios
ScriptFile=/usr/share/plymouth/themes/koios/koios.script
XML

cat > /usr/share/plymouth/themes/koios/koios.script <<'XML'
Window.SetBackgroundTopColor(0.02, 0.03, 0.05);
Window.SetBackgroundBottomColor(0.01, 0.01, 0.02);
title_image = Image.Text("KOIOS", 1, 1, 1);
title_sprite = Sprite(title_image);
title_sprite.SetX(Window.GetWidth() / 2 - title_image.GetWidth() / 2);
title_sprite.SetY(Window.GetHeight() / 2 - title_image.GetHeight() / 2);
Plymouth.SetRefreshFunction(function() {
    progress = Plymouth.GetBootProgress();
    if (progress > 1) progress = 1;
    title_sprite.SetOpacity(progress);
});
XML

plymouth-set-default-theme koios || true

# 7. SETUP DESKTOP XFCE (TEMA GELAP & PANEL RAPI)
cat > /etc/xdg/xfce4/xfconf/xfce-perchannel-xml/xsettings.xml <<'XML'
<?xml version="1.0" encoding="UTF-8"?>
<channel name="xsettings" version="1.0">
  <property name="Net" type="empty">
    <property name="ThemeName" type="string" value="Arc-Dark"/>
    <property name="IconThemeName" type="string" value="Papirus-Dark"/>
  </property>
</channel>
XML

# Setup Panel (Jam & Tray di Kanan)
cat > /etc/xdg/xfce4/xfconf/xfce-perchannel-xml/xfce4-panel.xml <<'XML'
<?xml version="1.0" encoding="UTF-8"?>
<channel name="xfce4-panel" version="1.0">
  <property name="panels" type="array">
    <value type="int" value="1"/>
  </property>
  <property name="panel-1" type="empty">
    <property name="position" type="string" value="p=8;x=0;y=0"/>
    <property name="length" type="uint" value="100"/>
    <property name="position-locked" type="bool" value="true"/>
    <property name="size" type="uint" value="32"/>
    <property name="plugin-ids" type="array">
      <value type="int" value="1"/>
      <value type="int" value="2"/>
      <value type="int" value="3"/>
    </property>
  </property>
  <property name="plugins" type="empty">
    <property name="plugin-1" type="string" value="whiskermenu"/>
    <property name="plugin-2" type="string" value="systray"/>
    <property name="plugin-3" type="string" value="clock"/>
  </property>
</channel>
XML

# Autostart Dock & Network
cat > /etc/xdg/autostart/plank.desktop <<'XML'
[Desktop Entry]
Type=Application
Exec=plank
Hidden=false
NoDisplay=false
X-GNOME-Autostart-enabled=true
Name=Plank
XML

mkdir -p /etc/skel/.config/plank/dock1/
cat > /etc/skel/.config/plank/dock1/settings <<'EOT'
[PlankDockPreferences]
Theme=Transparent
Position=3
IconSize=48
EOT

# Autologin
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
chmod +x config/hooks/live/0100-arlys-v4.hook.chroot

echo "[5/5] Build ISO V4 (20-40 menit)..."
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
    --iso-volume "ARLYS_KOIOS" \
    --memtest none \
    --bootappend-live "boot=live components quiet splash"

lb build

mkdir -p "$DIST_DIR"
mv live-image-amd64.hybrid.iso "$DIST_DIR/ARLYS-OS-V4.iso"
