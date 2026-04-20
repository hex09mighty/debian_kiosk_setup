# 🖥️ Debian Kiosk Setup

This project provides a script to convert a Debian system into a **fully automated kiosk mode** using Firefox.

---

## 🚀 Features

* Auto login with dedicated `kiosk` user
* Firefox launches in fullscreen (`--kiosk`)
* Disable screen lock & idle timeout
* Hide mouse cursor (idle)
* Minimal GNOME-based kiosk setup
* Basic system hardening

---

## 📦 Requirements

* Debian 12 / 13 with GNOME
* Internet connection
* Root / sudo access

---

## ⚡ Quick Install (Recommended)

### 1️⃣ Download script

```bash
wget https://raw.githubusercontent.com/hex09mighty/debian-kiosk/main/kisok_setup.sh
```

---

### 2️⃣ Make executable

```bash
chmod +x kisok_setup.sh
```

---

### 3️⃣ Fix missing dependency (IMPORTANT)

Some minimal Debian installs don’t include `adduser`.

```bash
sudo apt update
sudo apt install adduser -y
```

---

### 4️⃣ Edit configuration (IMPORTANT)

```bash
nano kisok_setup.sh
```

Update:

```bash
KIOSK_URL="https://your-url.com"
```

Examples:

* Local app → `http://localhost:3000`
* Website → `https://example.com`

---

### 5️⃣ Run setup

```bash
sudo ./kisok_setup.sh
```

---

### 6️⃣ Reboot

```bash
sudo reboot
```

---

## ⚡ One-line Install (Advanced)

```bash
wget -O kisok_setup.sh https://raw.githubusercontent.com/hex09mighty/debian-kiosk/main/kisok_setup.sh && chmod +x kisok_setup.sh && sudo apt update && sudo apt install adduser -y && sudo ./kisok_setup.sh
```

---

## ✅ Expected Behavior

After reboot:

* System auto logs into `kiosk` user
* GNOME starts automatically
* Firefox opens in fullscreen kiosk mode
* No lock screen or sleep

---

## 🔐 Optional Hardening

You can extend security with:

* Disable TTY switching
* Disable USB ports
* Restrict terminal access
* Disable keyboard shortcuts (Alt+Tab, Ctrl+Alt+Fx)
* BIOS / bootloader password

---

## 🧠 Troubleshooting

### ❌ `adduser: command not found`

```bash
sudo apt update
sudo apt install adduser -y
```

---

### ❌ Firefox not opening

```bash
journalctl -xe
```

---

### ❌ Auto login not working

Check:

```bash
sudo nano /etc/gdm3/daemon.conf
```

Ensure:

```ini
AutomaticLoginEnable = true
AutomaticLogin = kiosk
```

---

### ❌ Script failed midway

Re-run safely:

```bash
sudo ./kisok_setup.sh
```

---

## 📁 Project Structure

```
.
├── kisok_setup.sh
└── README.md
```

---

## ⚠️ Notes

* This is a **functional kiosk setup**, not fully hardened
* For production use, apply additional security controls

---
