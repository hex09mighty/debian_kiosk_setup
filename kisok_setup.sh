#!/bin/bash

set -e

KIOSK_USER="agent"
KIOSK_URL="https://google.com"

echo "🚀 Starting Kiosk Setup..."

# -------------------------------
# 1. Create kiosk user
# -------------------------------
if id "$KIOSK_USER" &>/dev/null; then
    echo "User $KIOSK_USER already exists"
else
    echo "Creating user $KIOSK_USER..."
    adduser --disabled-password --gecos "" $KIOSK_USER
fi

# -------------------------------
# 2. Install packages
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

# Disable screen blanking
xset s off
xset -dpms
xset s noblank

# Apply GNOME settings (works ONLY inside session)
gsettings set org.gnome.desktop.screensaver lock-enabled false
gsettings set org.gnome.desktop.session idle-delay 0
gsettings set org.gnome.desktop.notifications show-banners false

# Disable some escape shortcuts (ignore errors if missing)
gsettings set org.gnome.settings-daemon.plugins.media-keys logout '' || true
gsettings set org.gnome.settings-daemon.plugins.media-keys screensaver '' || true

# Hide mouse cursor
unclutter -idle 2 &

# Launch browser in kiosk mode
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
# 6. Permissions
# -------------------------------
chown -R $KIOSK_USER:$KIOSK_USER /home/$KIOSK_USER

# -------------------------------
# 7. Optional Hardening
# -------------------------------
echo "Applying optional hardening..."

# Disable TTY switching
sed -i 's/^#NAutoVTs=.*/NAutoVTs=0/' /etc/systemd/logind.conf || true
sed -i 's/^#ReserveVT=.*/ReserveVT=0/' /etc/systemd/logind.conf || true

# Disable Ctrl+Alt+Backspace
mkdir -p /etc/X11/xorg.conf.d
cat <<EOF > /etc/X11/xorg.conf.d/00-disable-ctrl-alt-backspace.conf
Section "ServerFlags"
    Option "DontZap" "true"
EndSection
EOF

# -------------------------------
# DONE
# -------------------------------
echo "✅ Kiosk setup completed!"
echo "👉 Reboot your system"
