#!/bin/bash

set -e

KIOSK_USER="agent"
KIOSK_URL="https://google.com"

echo "🚀 Setting up Secure Cage Kiosk..."

# -------------------------------
# 1. Create kiosk user
# -------------------------------
if id "$KIOSK_USER" &>/dev/null; then
    echo "✔ User exists"
else
    echo "➕ Creating user..."
    adduser --gecos "" $KIOSK_USER
fi

# Unlock + fix shell
passwd -d $KIOSK_USER || true
usermod -s /bin/bash $KIOSK_USER

# -------------------------------
# 2. Install packages
# -------------------------------
echo "📦 Installing packages..."
apt update -qq
apt install -y cage firefox-esr dbus-user-session xdg-utils >/dev/null

# -------------------------------
# 3. Create kiosk launcher
# -------------------------------
echo "🧩 Creating kiosk launcher..."

mkdir -p /home/$KIOSK_USER/.local/bin

cat <<EOF > /home/$KIOSK_USER/.local/bin/kiosk.sh
#!/bin/bash

export MOZ_ENABLE_WAYLAND=1

# Kill previous instances
pkill firefox-esr || true

exec cage -- firefox-esr --kiosk --no-remote --private-window "$KIOSK_URL"
EOF

chmod +x /home/$KIOSK_USER/.local/bin/kiosk.sh

# -------------------------------
# 4. Auto-login on TTY1
# -------------------------------
echo "⚙️ Configuring auto-login..."

mkdir -p /etc/systemd/system/getty@tty1.service.d

cat <<EOF > /etc/systemd/system/getty@tty1.service.d/override.conf
[Service]
ExecStart=
ExecStart=-/sbin/agetty --autologin $KIOSK_USER --noclear %I \$TERM
EOF

# -------------------------------
# 5. Start kiosk on login (with admin bypass)
# -------------------------------
echo "🚀 Configuring startup logic..."

cat <<EOF > /home/$KIOSK_USER/.bash_profile

# Admin bypass mode
if [ -f /tmp/admin_mode ]; then
    echo "⚠️ Admin mode enabled — kiosk skipped"
    exit 0
fi

# Start kiosk only on tty1
if [ -z "\$WAYLAND_DISPLAY" ] && [ "\$(tty)" = "/dev/tty1" ]; then
    exec /home/$KIOSK_USER/.local/bin/kiosk.sh
fi
EOF

# -------------------------------
# 6. Permissions
# -------------------------------
chown -R $KIOSK_USER:$KIOSK_USER /home/$KIOSK_USER

# -------------------------------
# 7. Hardening
# -------------------------------
echo "🔒 Applying hardening..."

# Keep tty1 (kiosk) + tty2 (admin)
grep -q "^NAutoVTs=" /etc/systemd/logind.conf && \
sed -i 's/^NAutoVTs=.*/NAutoVTs=2/' /etc/systemd/logind.conf || \
echo "NAutoVTs=2" >> /etc/systemd/logind.conf

grep -q "^ReserveVT=" /etc/systemd/logind.conf && \
sed -i 's/^ReserveVT=.*/ReserveVT=2/' /etc/systemd/logind.conf || \
echo "ReserveVT=2" >> /etc/systemd/logind.conf

# Disable Ctrl+Alt+Del reboot
systemctl mask ctrl-alt-del.target

# -------------------------------
# 8. Self-check
# -------------------------------
echo ""
echo "🔍 Running verification..."
echo "----------------------------"

PASS=true

id "$KIOSK_USER" &>/dev/null && echo "✔ User exists" || PASS=false
passwd -S "$KIOSK_USER" | grep -q "NP" && echo "✔ User unlocked" || PASS=false
[ -x "/home/$KIOSK_USER/.local/bin/kiosk.sh" ] && echo "✔ Kiosk script OK" || PASS=false
[ -f "/etc/systemd/system/getty@tty1.service.d/override.conf" ] && echo "✔ Autologin OK" || PASS=false

echo "----------------------------"

if $PASS; then
    echo "✅ SYSTEM READY FOR KIOSK"
else
    echo "⚠️ SOME CHECKS FAILED"
fi

echo ""
echo "👉 Reboot to start kiosk"
