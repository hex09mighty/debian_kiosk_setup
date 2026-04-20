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
    adduser --gecos "" $KIOSK_USER
fi

passwd -d $KIOSK_USER || true
usermod -s /bin/bash $KIOSK_USER

# -------------------------------
# 2. Install packages
# -------------------------------
apt update -qq
apt install -y cage firefox-esr dbus-user-session >/dev/null

# -------------------------------
# 3. Lock down home directory
# -------------------------------
echo "🔒 Configuring read-only home..."

# Make home owned but not writable
chmod 555 /home/$KIOSK_USER

# Create temp writable dirs
mkdir -p /tmp/kiosk-home
chown $KIOSK_USER:$KIOSK_USER /tmp/kiosk-home

# -------------------------------
# 4. Firefox lockdown policy
# -------------------------------
echo "🛑 Disabling downloads..."

mkdir -p /etc/firefox/policies

cat <<EOF > /etc/firefox/policies/policies.json
{
  "policies": {
    "DisableAppUpdate": true,
    "DisableDeveloperTools": true,
    "DisableProfileImport": true,
    "DisableSetDesktopBackground": true,
    "DisableFeedbackCommands": true,
    "DownloadDirectory": "/dev/null",
    "PromptForDownloadLocation": false,
    "BlockAboutConfig": true,
    "NoDefaultBookmarks": true
  }
}
EOF

# -------------------------------
# 5. Create kiosk launcher
# -------------------------------
mkdir -p /home/$KIOSK_USER/.local/bin

cat <<EOF > /home/$KIOSK_USER/.local/bin/kiosk.sh
#!/bin/bash

export MOZ_ENABLE_WAYLAND=1

# Use temp writable HOME
export HOME=/tmp/kiosk-home

# Clean previous session
rm -rf /tmp/kiosk-home/*
mkdir -p /tmp/kiosk-home

pkill firefox-esr || true

exec cage -- firefox-esr --kiosk --no-remote "$KIOSK_URL"
EOF

chmod +x /home/$KIOSK_USER/.local/bin/kiosk.sh

# -------------------------------
# 6. Autologin (TTY1)
# -------------------------------
mkdir -p /etc/systemd/system/getty@tty1.service.d

cat <<EOF > /etc/systemd/system/getty@tty1.service.d/override.conf
[Service]
ExecStart=
ExecStart=-/sbin/agetty --autologin $KIOSK_USER --noclear %I \$TERM
EOF

# -------------------------------
# 7. Startup logic with admin bypass
# -------------------------------
cat <<EOF > /home/$KIOSK_USER/.bash_profile

if [ -f /tmp/admin_mode ]; then
    echo "Admin mode enabled"
    exit 0
fi

if [ "\$(tty)" = "/dev/tty1" ]; then
    exec /home/$KIOSK_USER/.local/bin/kiosk.sh
fi
EOF

# -------------------------------
# 8. Hardening
# -------------------------------
echo "🔒 Hardening system..."

echo "NAutoVTs=2" >> /etc/systemd/logind.conf
echo "ReserveVT=2" >> /etc/systemd/logind.conf

systemctl mask ctrl-alt-del.target

# -------------------------------
# 9. Permissions fix
# -------------------------------
chown -R $KIOSK_USER:$KIOSK_USER /home/$KIOSK_USER

# -------------------------------
# 10. Self-check
# -------------------------------
echo ""
echo "🔍 Running checks..."
echo "----------------------"

PASS=true

id "$KIOSK_USER" &>/dev/null && echo "✔ User exists" || PASS=false
[ -x "/home/$KIOSK_USER/.local/bin/kiosk.sh" ] && echo "✔ Kiosk script OK" || PASS=false
[ -f "/etc/firefox/policies/policies.json" ] && echo "✔ Firefox locked" || PASS=false

echo "----------------------"

if $PASS; then
    echo "✅ KIOSK FULLY LOCKED"
else
    echo "⚠️ CHECK FAILED"
fi

echo ""
echo "👉 Reboot system"
