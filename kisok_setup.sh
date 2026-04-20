#!/bin/bash

set -e

KIOSK_USER="agent"
KIOSK_URL="https://google.com"

echo "🚀 Setting up Call Center Kiosk..."

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
echo "📦 Installing packages..."
apt update -qq
apt install -y cage firefox-esr dbus-user-session >/dev/null

# -------------------------------
# 3. Create kiosk launcher
# -------------------------------
echo "🧩 Creating kiosk launcher..."

mkdir -p /home/$KIOSK_USER/.local/bin

cat <<EOF > /home/$KIOSK_USER/.local/bin/kiosk.sh
#!/bin/bash

export MOZ_ENABLE_WAYLAND=1

pkill firefox-esr || true

while true; do
    firefox-esr \
        --kiosk \
        --no-remote \
        --new-instance \
        "$KIOSK_URL"

    sleep 2
done
EOF

chmod +x /home/$KIOSK_USER/.local/bin/kiosk.sh

# -------------------------------
# 4. Browser restrictions (USER ONLY)
# -------------------------------
echo "🔒 Applying browser restrictions..."

# Fix permissions (self-healing)
chmod 755 /home/$KIOSK_USER
chown $KIOSK_USER:$KIOSK_USER /home/$KIOSK_USER

# Firefox profile
mkdir -p /home/$KIOSK_USER/.mozilla/firefox
chown -R $KIOSK_USER:$KIOSK_USER /home/$KIOSK_USER/.mozilla

# Firefox restrictions
cat <<EOF > /home/$KIOSK_USER/.mozilla/firefox/user.js
user_pref("browser.download.useDownloadDir", true);
user_pref("browser.download.dir", "/home/$KIOSK_USER/blocked");
user_pref("browser.helperApps.neverAsk.saveToDisk", "application/octet-stream");
user_pref("dom.disable_open_during_load", true);
user_pref("devtools.enabled", false);
EOF

mkdir -p /home/$KIOSK_USER/blocked
chmod 000 /home/$KIOSK_USER/blocked

chown -R $KIOSK_USER:$KIOSK_USER /home/$KIOSK_USER

# -------------------------------
# 5. Restrict available commands (USER ONLY)
# -------------------------------
echo "🚫 Restricting system access for kiosk user..."

mkdir -p /home/$KIOSK_USER/restricted-bin

ln -sf /usr/bin/firefox-esr /home/$KIOSK_USER/restricted-bin/
ln -sf /usr/bin/cage /home/$KIOSK_USER/restricted-bin/
ln -sf /usr/bin/pkill /home/$KIOSK_USER/restricted-bin/
ln -sf /usr/bin/sleep /home/$KIOSK_USER/restricted-bin/

chown -R $KIOSK_USER:$KIOSK_USER /home/$KIOSK_USER/restricted-bin

# -------------------------------
# 6. Auto-login (TTY1)
# -------------------------------
echo "⚙️ Configuring autologin..."

mkdir -p /etc/systemd/system/getty@tty1.service.d

cat <<EOF > /etc/systemd/system/getty@tty1.service.d/override.conf
[Service]
ExecStart=
ExecStart=-/sbin/agetty --autologin $KIOSK_USER --noclear %I \$TERM
EOF

# -------------------------------
# 7. Startup logic (USER ONLY)
# -------------------------------
echo "🚀 Configuring startup..."

cat <<EOF > /home/$KIOSK_USER/.bash_profile

# Admin bypass
if [ -f /tmp/admin_mode ]; then
    echo "Admin mode enabled"
    exit 0
fi

# Restrict PATH (VERY IMPORTANT)
export PATH=/home/$KIOSK_USER/restricted-bin

# Start kiosk only on tty1
if [ "\$(tty)" = "/dev/tty1" ]; then
    exec /home/$KIOSK_USER/.local/bin/kiosk.sh
fi
EOF

chown $KIOSK_USER:$KIOSK_USER /home/$KIOSK_USER/.bash_profile

# -------------------------------
# 8. System hardening (safe)
# -------------------------------
echo "🔒 Applying system hardening..."

grep -q "^NAutoVTs=" /etc/systemd/logind.conf && \
sed -i 's/^NAutoVTs=.*/NAutoVTs=2/' /etc/systemd/logind.conf || \
echo "NAutoVTs=2" >> /etc/systemd/logind.conf

grep -q "^ReserveVT=" /etc/systemd/logind.conf && \
sed -i 's/^ReserveVT=.*/ReserveVT=2/' /etc/systemd/logind.conf || \
echo "ReserveVT=2" >> /etc/systemd/logind.conf

systemctl mask ctrl-alt-del.target

# -------------------------------
# 9. SELF CHECK
# -------------------------------
echo ""
echo "🔍 Running verification..."
echo "----------------------------"

PASS=true

id "$KIOSK_USER" &>/dev/null && echo "✔ User exists" || PASS=false
[ -x "/home/$KIOSK_USER/.local/bin/kiosk.sh" ] && echo "✔ Kiosk script OK" || PASS=false
[ -d "/home/$KIOSK_USER/restricted-bin" ] && echo "✔ Commands restricted" || PASS=false
[ -f "/home/$KIOSK_USER/.mozilla/firefox/user.js" ] && echo "✔ Browser restricted" || PASS=false

echo "----------------------------"

if $PASS; then
    echo "✅ KIOSK READY (fully locked for agent)"
else
    echo "⚠️ CHECK FAILED"
fi

echo ""
echo "👉 Reboot system"
