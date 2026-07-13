#!/bin/bash
# Google Antigravity Clean Uninstaller & Fresh Installer
# Supports: CLI (agy), Antigravity 2.0 Desktop App, and Antigravity IDE

set -euo pipefail

# Download URLs
CLI_URL="https://storage.googleapis.com/antigravity-public/antigravity-cli/1.0.8-5963827121094656/linux-x64/cli_linux_x64.tar.gz"
APP_URL="https://storage.googleapis.com/antigravity-public/antigravity-hub/2.1.4-6481382726303744/linux-x64/Antigravity.tar.gz"
IDE_URL="https://edgedl.me.gvt1.com/edgedl/release2/j0qc3/antigravity/stable/2.0.4-6381998290370560/linux-x64/Antigravity%20IDE.tar.gz"

echo "=================================================="
echo "    GOOGLE ANTIGRAVITY ALL-PRODUCT INSTALLER      "
echo "=================================================="
echo "This script will completely uninstall older versions and"
echo "install fresh versions of: CLI, Antigravity 2.0, and IDE."
echo ""

# Acquire administrative privileges early
echo "Requesting administrative privileges..."
sudo -v

# Keep sudo session alive
while true; do sudo -n true; sleep 60; kill -0 "$$" || exit; done 2>/dev/null &

echo ""
echo "--------------------------------------------------"
echo "[1/3] Uninstalling and cleaning old files..."
echo "--------------------------------------------------"

# Kill running processes (using exact match -x to prevent the script from killing itself)
echo "Stopping any running Antigravity processes..."
sudo pkill -9 -x antigravity || true
sudo pkill -9 -x antigravity-ide || true
sudo pkill -9 -x agy || true

# System-wide removals
echo "Removing old system-wide files..."
sudo rm -rf /opt/antigravity
sudo rm -rf /opt/antigravity-ide
sudo rm -f /usr/local/bin/antigravity
sudo rm -f /usr/local/sbin/antigravity
sudo rm -f /usr/local/bin/antigravity-ide
sudo rm -f /usr/local/bin/agy
sudo rm -f /usr/share/applications/antigravity.desktop
sudo rm -f /usr/share/applications/antigravity-ide.desktop

# User-local removals
echo "Removing user-local files, config, and cache..."
rm -f "$HOME/.local/bin/antigravity" "$HOME/.local/bin/antigravity-ide" "$HOME/.local/bin/agy"
rm -rf "$HOME/.local/share/antigravity-ide" "$HOME/.local/share/antigravity-ide-extract"
rm -f "$HOME/.local/share/applications/antigravity-ide.desktop" "$HOME/.local/share/applications/antigravity.desktop"
rm -rf "$HOME/.antigravity" "$HOME/.config/Antigravity" "$HOME/.cache/antigravity"

# Clean PATH configuration in bashrc
if [ -f "$HOME/.bashrc" ]; then
    echo "Cleaning up bash profile..."
    sed -i '/Added by Antigravity CLI installer/,/export PATH=".*\.local\/bin:\$PATH"/d' "$HOME/.bashrc"
    sed -i '/export PATH=".*\.local\/bin:\$PATH"/d' "$HOME/.bashrc"
fi

echo "Cleanup completed."
echo ""

echo "--------------------------------------------------"
echo "[2/3] Downloading fresh installation packages..."
echo "--------------------------------------------------"

STAGING_DIR="/tmp/antigravity_staging"
rm -rf "$STAGING_DIR"
mkdir -p "$STAGING_DIR"

echo "Downloading Antigravity CLI..."
curl -fsSL --retry 3 -o "$STAGING_DIR/cli.tar.gz" "$CLI_URL"

echo "Downloading Antigravity 2.0 Desktop App..."
curl -fsSL --retry 3 -o "$STAGING_DIR/app.tar.gz" "$APP_URL"

echo "Downloading Antigravity IDE..."
curl -fsSL --retry 3 -o "$STAGING_DIR/ide.tar.gz" "$IDE_URL"

echo "Downloads completed successfully."
echo ""

echo "--------------------------------------------------"
echo "[3/3] Installing products..."
echo "--------------------------------------------------"

# 1. Install CLI
echo "Installing CLI..."
mkdir -p "$HOME/.local/bin"
tar -xzf "$STAGING_DIR/cli.tar.gz" -C "$HOME/.local/bin/"
if [ -f "$HOME/.local/bin/antigravity" ]; then
    mv "$HOME/.local/bin/antigravity" "$HOME/.local/bin/agy"
fi
chmod +x "$HOME/.local/bin/agy"

# Run CLI installation config helper (configures shell path)
"$HOME/.local/bin/agy" install

# Make CLI available system-wide as well
sudo ln -sf "$HOME/.local/bin/agy" /usr/local/bin/agy

# 2. Install Antigravity 2.0 Desktop App
echo "Installing Antigravity 2.0..."
sudo mkdir -p /opt/antigravity
sudo tar -xzf "$STAGING_DIR/app.tar.gz" -C /opt/antigravity --strip-components=1
sudo chown root:root /opt/antigravity/chrome-sandbox
sudo chmod 4755 /opt/antigravity/chrome-sandbox
# Create launcher wrapper to automatically terminate headless zombie background processes
echo "Creating wrapper at /usr/local/bin/antigravity..."
sudo tee /usr/local/bin/antigravity > /dev/null << 'EOF'
#!/bin/bash
# Google Antigravity 2.0 Launcher Wrapper
# Resolves the issue where closing the application leaves zombie processes in the background,
# preventing future launches.

# Pattern to detect the main process (using bracket classes to avoid matching the pgrep command itself)
MAIN_PATTERN="(/opt/antigravity/[a]ntigravity|/usr/local/bin/[a]ntigravity)"
RENDERER_PATTERN="(/opt/antigravity/antigravity|/usr/local/bin/antigravity).*--type=[r]enderer"

# Check if main process is running
if pgrep -f "$MAIN_PATTERN" > /dev/null; then
    # Check if there are any active renderer processes (UI windows)
    if ! pgrep -f "$RENDERER_PATTERN" > /dev/null; then
        echo "Detected zombie Google Antigravity processes (no active UI windows). Cleaning up..."
        # Kill all existing processes associated with this app (including language_server)
        pkill -9 -f "/opt/antigravity/" || true
        # Wait a moment for processes to clear
        sleep 0.5
    fi
fi

# Launch the actual application, forwarding all arguments
exec /opt/antigravity/antigravity "$@"
EOF
sudo chmod +x /usr/local/bin/antigravity

# 3. Install Antigravity IDE
echo "Installing Antigravity IDE..."
sudo mkdir -p /opt/antigravity-ide
sudo tar -xzf "$STAGING_DIR/ide.tar.gz" -C /opt/antigravity-ide --strip-components=1
sudo chown root:root /opt/antigravity-ide/chrome-sandbox
sudo chmod 4755 /opt/antigravity-ide/chrome-sandbox

# Resolve the IDE binary name dynamically
if [ -f /opt/antigravity-ide/antigravity-ide ]; then
    IDE_BIN="antigravity-ide"
elif [ -f /opt/antigravity-ide/antigravity ]; then
    IDE_BIN="antigravity"
else
    # Fallback to finding the main executable
    IDE_BIN=$(find /opt/antigravity-ide -maxdepth 1 -type f -executable -not -name "*.so*" -not -name "*.sh" -not -name "chrome-sandbox" -printf "%f\n" | head -n 1)
fi
sudo ln -sf "/opt/antigravity-ide/$IDE_BIN" /usr/local/bin/antigravity-ide

# 4. Create desktop menu shortcuts with auto-located icons
echo "Creating application launchers..."

# Find icons dynamically
ICON_APP=$(find /opt/antigravity -maxdepth 5 -name "antigravity.png" -o -name "icon.png" -o -name "code.png" | head -n 1)
[ -z "$ICON_APP" ] && ICON_APP="utilities-terminal"

ICON_IDE=$(find /opt/antigravity-ide -maxdepth 5 -name "antigravity.png" -o -name "icon.png" -o -name "code.png" | head -n 1)
[ -z "$ICON_IDE" ] && ICON_IDE="accessories-text-editor"

# Create Antigravity 2.0 Desktop entry
sudo tee /usr/share/applications/antigravity.desktop > /dev/null << EOL
[Desktop Entry]
Name=Google Antigravity
Comment=Experience liftoff (Desktop App)
Exec=/usr/local/bin/antigravity --no-sandbox --ozone-platform-hint=auto --enable-features=WaylandWindowDecorations %F
Icon=$ICON_APP
Type=Application
StartupNotify=true
Categories=Development;Utility;
EOL

# Create Antigravity IDE Desktop entry
sudo tee /usr/share/applications/antigravity-ide.desktop > /dev/null << EOL
[Desktop Entry]
Name=Google Antigravity IDE
Comment=Experience liftoff (IDE)
Exec=/usr/local/bin/antigravity-ide --no-sandbox --ozone-platform-hint=auto --enable-features=WaylandWindowDecorations %F
Icon=$ICON_IDE
Type=Application
StartupNotify=true
Categories=Development;TextEditor;IDE;
EOL

# Clean up staging files
rm -rf "$STAGING_DIR"

echo ""
echo "=================================================="
echo "        INSTALLATION COMPLETED SUCCESSFULLY       "
echo "=================================================="
echo "The following products are installed and ready:"
echo "1. CLI (agy)           -> launch with: agy"
echo "2. Antigravity 2.0     -> launch with: antigravity"
echo "3. Antigravity IDE     -> launch with: antigravity-ide"
echo ""
echo "Desktop menu entries have also been successfully created."
echo "=================================================="
