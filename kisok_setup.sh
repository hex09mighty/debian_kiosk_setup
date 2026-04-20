#!/bin/bash

set -e

KIOSK_USER="agent"
KIOSK_URL="https://google.com"

echo "🚀 Starting Kiosk Setup..."

# -------------------------------
# 1. Create kiosk user (if not exists)
# -------------------------------
if id "$KIOSK_USER" &>/dev/null; then
    echo "User $KIOSK_USER already exists"
else
    echo "Creating user $KIOSK_USER..."
    adduser --disabled-password --gecos "" $KIOSK_USER
fi

# -------------------------------
# 2. Install required packages
# -------------------------------
echo "Installing packages..."
apt update
apt install -y firefox-esr unclutter

# -------------------------------
# 3. Enable auto login (GDM)
# -------------------------------
echo "Configuring auto login..."

GDM_CONF="/etc/gdm3/daemon.conf"

sed -i 's/^#\?AutomaticLoginEnable.*/AutomaticLoginEnable = true/' $GDM_CONF
sed -i "s/^#\?AutomaticLogin.*/AutomaticLogin = $KIOSK_USER/" $GDM_CONF

# -------------------------------
# 4. Create kiosk startup script
# -------------------------------
echo "Creating kiosk startup script..."

mkdir -p /home/$KIOSK_USER/.local/bin

cat <<EOF > /home/$KIOSK_USER/.local/bin/kiosk.sh
#!/bin/bash

xset s off
xset -dpms
xset s noblank

unclutter -idle 2 &

firefox-esr --kiosk "$KIOSK_URL"
EOF

chmod +x /home/$KIOSK_USER/.local/bin/kiosk.sh

# -------------------------------
# 5. Autostart config
# -------------------------------
echo "Setting autostart..."

mkdir -p /home/$KIOSK_USER/.config/autostart

cat <<EOF > /home/$KIOSK_USER/.config/autostart/kiosk.desktop
[Desktop Entry]
Type=Application
Exec=/home/$KIOSK_USER/.local/bin/kiosk.sh
Hidden=false
NoDisplay=false
X-GNOME-Autostart-enabled=true
Name=Kiosk
EOF

# -------------------------------
# 6. Set ownership
# -------------------------------
chown -R $KIOSK_USER:$KIOSK_USER /home/$KIOSK_USER

# -------------------------------
# 7. Disable lock screen & idle
# -------------------------------
echo "Configuring GNOME settings..."

sudo -u $KIOSK_USER dbus-launch gsettings set org.gnome.desktop.screensaver lock-enabled false
sudo -u $KIOSK_USER dbus-launch gsettings set org.gnome.desktop.session idle-delay 0
sudo -u $KIOSK_USER dbus-launch gsettings set org.gnome.desktop.notifications show-banners false

# -------------------------------
# 8. Disable common escape shortcuts
# -------------------------------
sudo -u $KIOSK_USER dbus-launch gsettings set org.gnome.settings-daemon.plugins.media-keys logout ''
sudo -u $KIOSK_USER dbus-launch gsettings set org.gnome.settings-daemon.plugins.media-keys terminal ''
sudo -u $KIOSK_USER dbus-launch gsettings set org.gnome.settings-daemon.plugins.media-keys screensaver ''

# -------------------------------
# 9. Optional Hardening
# -------------------------------
echo "Applying optional hardening..."

# Disable TTY switching
sed -i 's/^#NAutoVTs=.*/NAutoVTs=0/' /etc/systemd/logind.conf || true
sed -i 's/^#ReserveVT=.*/ReserveVT=0/' /etc/systemd/logind.conf || true

# -------------------------------
# DONE
# -------------------------------
echo "✅ Kiosk setup completed!"
echo "👉 Reboot your system to apply changes"
