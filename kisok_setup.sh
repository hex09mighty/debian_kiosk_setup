#!/bin/bash

set -e

KIOSK_USER="agent"
KIOSK_URL="https://google.com"

echo "🚀 Setting up CAGE Wayland Kiosk..."

# -------------------------------
# 1. Create kiosk user
# -------------------------------
if id "$KIOSK_USER" &>/dev/null; then
    echo "✔ User exists"
else
    echo "➕ Creating user..."
    adduser --gecos "" $KIOSK_USER
fi

# Unlock user
passwd -d $KIOSK_USER || true
usermod -s /bin/bash $KIOSK_USER

# -------------------------------
# 2. Install minimal packages
# -------------------------------
echo "📦 Installing packages..."

apt update
apt install -y \
    cage \
    firefox-esr \
    dbus-user-session \
    xdg-utils \
    systemd-sysv

# -------------------------------
# 3. Create kiosk launcher
# -------------------------------
echo "🧩 Creating kiosk launcher..."

mkdir -p /home/$KIOSK_USER/.local/bin

cat <<EOF > /home/$KIOSK_USER/.local/bin/kiosk.sh
#!/bin/bash

export MOZ_ENABLE_WAYLAND=1

# Kill old instances
pkill firefox-esr || true

exec cage -- firefox-esr --kiosk --private-window "$KIOSK_URL"
EOF

chmod +x /home/$KIOSK_USER/.local/bin/kiosk.sh

# -------------------------------
# 4. Create systemd autologin service
# -------------------------------
echo "⚙️ Configuring auto-login (TTY)..."

mkdir -p /etc/systemd/system/getty@tty1.service.d

cat <<EOF > /etc/systemd/system/getty@tty1.service.d/override.conf
[Service]
ExecStart=
ExecStart=-/sbin/agetty --autologin $KIOSK_USER --noclear %I \$TERM
EOF

# -------------------------------
# 5. Auto start kiosk on login
# -------------------------------
echo "🚀 Configuring auto start..."

cat <<EOF >> /home/$KIOSK_USER/.bash_profile

# Start kiosk automatically
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

# Disable VT switching
grep -q "^NAutoVTs=" /etc/systemd/logind.conf && \
sed -i 's/^NAutoVTs=.*/NAutoVTs=1/' /etc/systemd/logind.conf || \
echo "NAutoVTs=1" >> /etc/systemd/logind.conf

grep -q "^ReserveVT=" /etc/systemd/logind.conf && \
sed -i 's/^ReserveVT=.*/ReserveVT=1/' /etc/systemd/logind.conf || \
echo "ReserveVT=1" >> /etc/systemd/logind.conf

# Disable Ctrl+Alt+Del reboot
systemctl mask ctrl-alt-del.target

# -------------------------------
# 8. Self-check
# -------------------------------
echo ""
echo "🔍 Running checks..."
echo "--------------------------"

PASS=true

id "$KIOSK_USER" &>/dev/null && echo "✔ User exists" || PASS=false
passwd -S "$KIOSK_USER" | grep -q "NP" && echo "✔ User unlocked" || PASS=false
[ -x "/home/$KIOSK_USER/.local/bin/kiosk.sh" ] && echo "✔ Kiosk script OK" || PASS=false
systemctl is-enabled getty@tty1 &>/dev/null && echo "✔ Autologin configured" || PASS=false

echo "--------------------------"

if $PASS; then
    echo "✅ READY FOR KIOSK MODE"
else
    echo "⚠️ CHECK FAILED"
fi

echo ""
echo "👉 Reboot system"
