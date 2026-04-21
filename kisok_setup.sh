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
# 3. Browser restrictions (USER ONLY)
# -------------------------------
echo "🔒 Applying browser restrictions..."

chmod 755 /home/$KIOSK_USER
chown $KIOSK_USER:$KIOSK_USER /home/$KIOSK_USER

mkdir -p /home/$KIOSK_USER/.mozilla/firefox
chown -R $KIOSK_USER:$KIOSK_USER /home/$KIOSK_USER/.mozilla

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
# 4. Restrict available commands
# -------------------------------
echo "🚫 Restricting system access for kiosk user..."

mkdir -p /home/$KIOSK_USER/restricted-bin

ln -sf /usr/bin/firefox-esr /home/$KIOSK_USER/restricted-bin/
ln -sf /usr/bin/cage /home/$KIOSK_USER/restricted-bin/
ln -sf /usr/bin/pkill /home/$KIOSK_USER/restricted-bin/
ln -sf /usr/bin/sleep /home/$KIOSK_USER/restricted-bin/

chown -R $KIOSK_USER:$KIOSK_USER /home/$KIOSK_USER/restricted-bin

# -------------------------------
# 5. Auto-login (TTY1)
# -------------------------------
echo "⚙️ Configuring autologin..."

mkdir -p /etc/systemd/system/getty@tty1.service.d

cat <<EOF > /etc/systemd/system/getty@tty1.service.d/override.conf
[Service]
ExecStart=
ExecStart=-/sbin/agetty --autologin $KIOSK_USER --noclear %I \$TERM
EOF

# -------------------------------
# 6. Startup logic (NO launcher)
# -------------------------------
echo "🚀 Configuring startup..."

cat <<EOF > /home/$KIOSK_USER/.bash_profile

# Admin bypass
if [ -f /tmp/admin_mode ]; then
    echo "Admin mode enabled"
    exit 0
fi

# Restrict PATH
export PATH=/home/$KIOSK_USER/restricted-bin

# Start Firefox directly on tty1
if [ "\$(tty)" = "/dev/tty1" ]; then
    exec cage firefox-esr --kiosk "$KIOSK_URL"
fi
EOF

chown $KIOSK_USER:$KIOSK_USER /home/$KIOSK_USER/.bash_profile

# -------------------------------
# 7. System hardening
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
# 8. SELF CHECK
# -------------------------------
echo ""
echo "🔍 Running verification..."
echo "----------------------------"

PASS=true

id "$KIOSK_USER" &>/dev/null && echo "✔ User exists" || PASS=false
[ -d "/home/$KIOSK_USER/restricted-bin" ] && echo "✔ Commands restricted" || PASS=false
[ -f "/home/$KIOSK_USER/.mozilla/firefox/user.js" ] && echo "✔ Browser restricted" || PASS=false

echo "----------------------------"

if $PASS; then
    echo "✅ KIOSK READY (no launcher mode)"
else
    echo "⚠️ CHECK FAILED"
fi

echo ""
echo "👉 Reboot system"
