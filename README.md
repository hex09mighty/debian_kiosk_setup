# 🖥️ Debian Kiosk Setup (Cage + Firefox)

This script configures a **secure, browser-only kiosk system** on Debian.

---

# 🚀 What This Script Does

After running the script:

### 👤 Kiosk User (`agent`)

* Auto-login on boot (TTY1)
* Runs **Firefox in full-screen kiosk mode**
* No desktop environment (no GNOME, no apps)
* No access to:

  * Terminal
  * File Manager
  * App Center
* Downloads disabled
* Uploads disabled
* Browser auto-restarts if closed

### 👨‍💻 Admin User

* Full system access (no restrictions)
* Can switch via TTY

---

# 🧱 Architecture

```text
Boot
 → TTY1 auto-login (agent)
 → Cage (Wayland kiosk compositor)
 → Firefox (kiosk mode)
```

👉 No GNOME / no desktop → nothing to escape into

This follows best practice for kiosk systems, where **desktop environments are avoided to reduce attack surface** ([willhaley.com][1])

---

# 📦 Requirements

* Debian 12 / 13 (minimal install recommended)
* sudo/root access
* Internet connection

---

# ⚙️ Installation

## 1. Download script

```bash
wget https://raw.githubusercontent.com/hex09mighty/debian_kiosk_setup/refs/heads/main/kisok_setup.sh
```

---

## 2. Make executable

```bash
chmod +x kisok_setup.sh
```

---

## 3. Run script

```bash
sudo ./kisok_setup.sh
```

---

## 4. Reboot

```bash
sudo reboot
```

---

# 🔁 After Reboot

* System logs in automatically as `agent`
* Browser opens full screen
* User cannot exit or access system

---
[1]: https://www.willhaley.com/blog/debian-fullscreen-gui-kiosk/ "https://www.willhaley.com/blog/debian-fullscreen-gui-kiosk/"
[2]: https://github.com/josfaber/debian-kiosk-installer "https://github.com/josfaber/debian-kiosk-installer"
