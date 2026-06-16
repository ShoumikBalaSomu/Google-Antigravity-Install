# Google Antigravity Installer

[![License: MIT](https://img.shields.io/badge/License-MIT-blue.svg)](LICENSE)
[![Platform](https://img.shields.io/badge/Platform-Fedora%20%7C%20Linux-orange.svg)](#system-compatibility)

A clean, premium, and fully automated installation suite for the Google Antigravity product line, optimized for Fedora (GNOME desktop environment). 

This repository provides scripts to install, configure, and cleanly reset your Google Antigravity environment, including launcher shortcuts, custom icons, Wayland optimizations, and SELinux sandbox compatibility.

---

## ⚡ Quick Install (Single-Line Command)

You can run the installation directly from your terminal without downloading any files manually. Run the following command:

```bash
bash -c "$(curl -fsSL https://raw.githubusercontent.com/ShoumikBalaSomu/Google-Antigravity-Install/main/reinstall_antigravity.sh)"
```

### 🔄 Updating Google Antigravity

Since the Antigravity product suite is installed directly from official binary packages rather than an RPM package repository, running `sudo dnf update` will not update them.

To update all components (CLI, Desktop App, and IDE) to the latest versions, simply re-run the Quick Install command above. The script will automatically stop any running instances, clean up old binaries, and install the newest versions, while keeping your local workspace configurations and settings intact.

### 🧹 Clean Uninstall & Reinstall
If you are experiencing issues or want to perform a complete clean reinstall (removing all existing application caches, settings, and profile adjustments), run this command:


```bash
bash -c "$(curl -fsSL https://raw.githubusercontent.com/ShoumikBalaSomu/Google-Antigravity-Install/main/uninstall_and_reinstall_antigravity.sh)"
```

---

## 📦 What gets installed?

The installation scripts setup the entire Google Antigravity suite:

1. **Antigravity CLI (`agy`)**
   * Installed locally at `~/.local/bin/agy`
   * Soft-linked to `/usr/local/bin/agy` for system-wide availability
   * Automatically configures user shell paths (`.bashrc`)
2. **Antigravity 2.0 Desktop App**
   * Installed system-wide at `/opt/antigravity`
   * Configured sandbox permissions (`chrome-sandbox`)
   * Soft-linked to `/usr/local/bin/antigravity`
   * GNOME App Launcher shortcut with native icons
3. **Antigravity IDE**
   * Installed system-wide at `/opt/antigravity-ide`
   * Configured sandbox permissions
   * Soft-linked to `/usr/local/bin/antigravity-ide`
   * GNOME App Launcher shortcut with native icons

---

## 🛠️ System Compatibility & Requirements

* **OS**: Fedora Linux (optimized for Fedora 44, GNOME, Wayland)
* **Architecture**: `x86_64` (Intel/AMD)
* **Privileges**: Sudo privileges are required during script execution to install packages into `/opt` and link to `/usr/local/bin`.
* **Dependencies**: `curl` and `tar` (installed by default on Fedora).

---

## 📄 License

This project is licensed under the MIT License. See the [LICENSE](LICENSE) file for details.
