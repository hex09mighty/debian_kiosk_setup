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
# 3. Detect display manager
# -------------------------------
DM=$(cat /etc/X11/default-display-manager 2>/dev/null || echo "")

echo "Detected display manager: $DM"

# -------------------------------
# 4. Configure auto login
# -------------------------------
echo "Configuring auto login..."

if [[ "$DM" == *"gdm3"* ]]; then
    echo "Using GDM..."

    cat <<EOF > /etc/gdm3/daemon.conf
[daemon]
WaylandEnable=false
AutomaticLoginEnable=true
AutomaticLogin=$KIOSK_USER

[security]

[xdmcp]

[chooser]

[debug]
EOF

elif [[ "$DM" == *"lightdm"* ]]; then
    echo "Using LightDM..."

    cat <<EOF > /etc/lightdm/lightdm.conf
[Seat:*]
autologin-user=$KIOSK_USER
autologin-session=gnome
EOF

else
    echo "⚠️ Unknown display manager. Autologin not configured."
fi

# -------------------------------
# 5. Create kiosk startup script
# -------------------------------
echo "Creating kiosk startup script..."

mkdir -p /home/$KIOSK_USER/.local/bin

cat <<EOF > /home/$KIOSK_USER/.local/bin/kiosk.sh
#!/bin/bash

# Disable screen blanking
xset s off
xset -dpms
xset s noblank

# Apply GNOME settings (only works inside session)
gsettings set org.gnome.desktop.screensaver lock-enabled false
gsettings set org.gnome.desktop.session idle-delay 0
gsettings set org.gnome.desktop.notifications show-banners false

# Disable some shortcuts
gsettings set org.gnome.settings-daemon.plugins.media-keys logout '' || true
gsettings set org.gnome.settings-daemon.plugins.media-keys screensaver '' || true

# Hide cursor
unclutter -idle 2 &

# Launch browser
firefox-esr --kiosk "$KIOSK_URL"
EOF

chmod +x /home/$KIOSK_USER/.local/bin/kiosk.sh

# -------------------------------
# 6. Autostart config
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
# 7. Permissions
# -------------------------------
chown -R $KIOSK_USER:$KIOSK_USER /home/$KIOSK_USER

# -------------------------------
# 8. Optional Hardening
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
