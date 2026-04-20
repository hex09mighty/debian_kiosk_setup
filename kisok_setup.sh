#!/bin/bash

set -e

KIOSK_USER="agent"
KIOSK_URL="https://google.com"

echo "🚀 Starting Kiosk Setup..."

# -------------------------------
# 1. Create kiosk user
# -------------------------------
if id "$KIOSK_USER" &>/dev/null; then
    echo "✔ User $KIOSK_USER already exists"
else
    echo "➕ Creating user $KIOSK_USER..."
    adduser --gecos "" $KIOSK_USER
fi

# Ensure correct shell
usermod -s /bin/bash $KIOSK_USER

# Unlock user if locked
if passwd -S $KIOSK_USER | grep -q " L "; then
    echo "🔓 Unlocking user..."
    passwd -d $KIOSK_USER
else
    echo "✔ User already unlocked"
fi

# -------------------------------
# 2. Install packages
# -------------------------------
echo "📦 Installing packages..."
apt update -qq
apt install -y firefox-esr unclutter >/dev/null

# -------------------------------
# 3. Detect display manager
# -------------------------------
DM=$(cat /etc/X11/default-display-manager 2>/dev/null || echo "")
echo "🖥 Detected display manager: $DM"

# -------------------------------
# 4. Configure auto login
# -------------------------------
echo "⚙️ Configuring auto login..."

if [[ "$DM" == *"gdm3"* ]]; then
    echo "→ Using GDM"

    cat <<EOF > /etc/gdm3/daemon.conf
[daemon]
WaylandEnable=false
AutomaticLoginEnable=true
AutomaticLogin=$KIOSK_USER
EOF

elif [[ "$DM" == *"lightdm"* ]]; then
    echo "→ Using LightDM"

    cat <<EOF > /etc/lightdm/lightdm.conf
[Seat:*]
autologin-user=$KIOSK_USER
autologin-session=gnome
EOF

else
    echo "⚠️ Unknown display manager"
fi

# -------------------------------
# 5. Create kiosk script
# -------------------------------
echo "🧩 Creating kiosk launcher..."

mkdir -p /home/$KIOSK_USER/.local/bin

cat <<EOF > /home/$KIOSK_USER/.local/bin/kiosk.sh
#!/bin/bash

sleep 2

pkill firefox-esr || true

xset s off
xset -dpms
xset s noblank

gsettings set org.gnome.desktop.screensaver lock-enabled false
gsettings set org.gnome.desktop.session idle-delay 0
gsettings set org.gnome.desktop.notifications show-banners false
gsettings set org.gnome.desktop.interface enable-hot-corners false

gsettings set org.gnome.settings-daemon.plugins.media-keys logout '' || true
gsettings set org.gnome.settings-daemon.plugins.media-keys screensaver '' || true

unclutter -idle 2 &

firefox-esr --kiosk --no-remote --private-window "$KIOSK_URL"
EOF

chmod +x /home/$KIOSK_USER/.local/bin/kiosk.sh

# -------------------------------
# 6. Autostart
# -------------------------------
echo "🚀 Configuring autostart..."

mkdir -p /home/$KIOSK_USER/.config/autostart

cat <<EOF > /home/$KIOSK_USER/.config/autostart/kiosk.desktop
[Desktop Entry]
Type=Application
Exec=/home/$KIOSK_USER/.local/bin/kiosk.sh
X-GNOME-Autostart-enabled=true
Name=Kiosk
EOF

# -------------------------------
# 7. Permissions
# -------------------------------
chown -R $KIOSK_USER:$KIOSK_USER /home/$KIOSK_USER

# -------------------------------
# 8. Hardening
# -------------------------------
echo "🔒 Applying hardening..."

grep -q "^NAutoVTs=" /etc/systemd/logind.conf && \
sed -i 's/^NAutoVTs=.*/NAutoVTs=0/' /etc/systemd/logind.conf || \
echo "NAutoVTs=0" >> /etc/systemd/logind.conf

grep -q "^ReserveVT=" /etc/systemd/logind.conf && \
sed -i 's/^ReserveVT=.*/ReserveVT=0/' /etc/systemd/logind.conf || \
echo "ReserveVT=0" >> /etc/systemd/logind.conf

mkdir -p /etc/X11/xorg.conf.d
cat <<EOF > /etc/X11/xorg.conf.d/00-disable-ctrl-alt-backspace.conf
Section "ServerFlags"
    Option "DontZap" "true"
EndSection
EOF

# -------------------------------
# 9. VERIFICATION
# -------------------------------
echo ""
echo "🔍 Running self-checks..."
echo "--------------------------------"

PASS=true

# Check user
if id "$KIOSK_USER" &>/dev/null; then
    echo "✔ User exists"
else
    echo "❌ User missing"
    PASS=false
fi

# Check unlocked
if passwd -S $KIOSK_USER | grep -q "NP"; then
    echo "✔ User unlocked"
else
    echo "❌ User still locked"
    PASS=false
fi

# Check autologin config
if grep -q "AutomaticLogin=$KIOSK_USER" /etc/gdm3/daemon.conf 2>/dev/null; then
    echo "✔ Autologin configured"
else
    echo "❌ Autologin not configured"
    PASS=false
fi

# Check kiosk script
if [ -x "/home/$KIOSK_USER/.local/bin/kiosk.sh" ]; then
    echo "✔ Kiosk script OK"
else
    echo "❌ Kiosk script missing"
    PASS=false
fi

# Check autostart
if [ -f "/home/$KIOSK_USER/.config/autostart/kiosk.desktop" ]; then
    echo "✔ Autostart configured"
else
    echo "❌ Autostart missing"
    PASS=false
fi

echo "--------------------------------"

if $PASS; then
    echo "✅ ALL CHECKS PASSED"
else
    echo "⚠️ SOME CHECKS FAILED"
fi

echo ""
echo "👉 Reboot your system to apply changes"
