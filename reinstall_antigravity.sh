#!/bin/bash
# Google Antigravity Clean Reinstaller (Fedora 44 / GNOME / ThinkPad T490s Optimized)
# Supports: CLI (agy), Antigravity 2.0 Desktop App, and Antigravity IDE
#
# Usage:
#   chmod +x reinstall_antigravity.sh
#   ./reinstall_antigravity.sh

set -euo pipefail

# Color codes for premium CLI output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# Download URLs for x86_64 architecture
CLI_URL="https://storage.googleapis.com/antigravity-public/antigravity-cli/1.0.8-5963827121094656/linux-x64/cli_linux_x64.tar.gz"
APP_URL="https://storage.googleapis.com/antigravity-public/antigravity-hub/2.1.4-6481382726303744/linux-x64/Antigravity.tar.gz"
IDE_URL="https://edgedl.me.gvt1.com/edgedl/release2/j0qc3/antigravity/stable/2.0.4-6381998290370560/linux-x64/Antigravity%20IDE.tar.gz"

echo -e "${CYAN}======================================================================${NC}"
echo -e "${BLUE}        GOOGLE ANTIGRAVITY ALL-PRODUCT REINSTALLER FOR FEDORA         ${NC}"
echo -e "${CYAN}======================================================================${NC}"
echo -e "This script will cleanly uninstall old versions and perform a fresh"
echo -e "installation of: ${GREEN}CLI (agy)${NC}, ${GREEN}Antigravity 2.0${NC}, and ${GREEN}Antigravity IDE${NC}."
echo ""

# 0. System Verification
ARCH=$(uname -m)
if [ "$ARCH" != "x86_64" ]; then
    echo -e "${RED}Error: This script downloads packages for x86_64 architecture, but detected: $ARCH.${NC}"
    exit 1
fi

# Request administrative privileges upfront
echo -e "${YELLOW}Requesting administrative privileges for system-wide directories (/opt, /usr)...${NC}"
sudo -v

# Keep sudo session alive in the background
while true; do sudo -n true; sleep 60; kill -0 "$$" || exit; done 2>/dev/null &

echo ""
echo -e "${BLUE}----------------------------------------------------------------------${NC}"
echo -e "[1/5] Stopping active processes and removing old installations..."
echo -e "${BLUE}----------------------------------------------------------------------${NC}"

# Kill any running instances (using exact match -x to prevent the script from killing itself)
echo "Stopping any running Antigravity processes..."
sudo pkill -9 -x antigravity || true
sudo pkill -9 -x antigravity-ide || true
sudo pkill -9 -x agy || true

# Clean system-wide installations
echo "Cleaning old system-wide files..."
sudo rm -rf /opt/antigravity
sudo rm -rf /opt/antigravity-ide
sudo rm -f /usr/local/bin/antigravity
sudo rm -f /usr/local/sbin/antigravity
sudo rm -f /usr/local/bin/antigravity-ide
sudo rm -f /usr/local/bin/agy
sudo rm -f /usr/share/applications/antigravity.desktop
sudo rm -f /usr/share/applications/antigravity-ide.desktop

# Clean user-local installations (ignoring the running .gemini runtime itself to prevent agent interruption)
echo "Cleaning old user-local configurations and caches..."
rm -f "$HOME/.local/bin/antigravity" "$HOME/.local/bin/antigravity-ide" "$HOME/.local/bin/agy"
rm -rf "$HOME/.local/share/antigravity-ide" "$HOME/.local/share/antigravity-ide-extract"
rm -f "$HOME/.local/share/applications/antigravity-ide.desktop" "$HOME/.local/share/applications/antigravity.desktop"
rm -rf "$HOME/.antigravity" "$HOME/.config/Antigravity" "$HOME/.cache/antigravity"

# Clean up PATH adjustments in ~/.bashrc
if [ -f "$HOME/.bashrc" ]; then
    echo "Cleaning up bash profile PATH entries..."
    sed -i '/Added by Antigravity CLI installer/,/export PATH=".*\.local\/bin:\$PATH"/d' "$HOME/.bashrc"
    sed -i '/export PATH=".*\.local\/bin:\$PATH"/d' "$HOME/.bashrc"
fi

echo -e "${GREEN}Cleanup completed successfully.${NC}"
echo ""

echo -e "${BLUE}----------------------------------------------------------------------${NC}"
echo -e "[2/5] Downloading fresh package archives..."
echo -e "${BLUE}----------------------------------------------------------------------${NC}"

STAGING_DIR="/tmp/antigravity_staging"
rm -rf "$STAGING_DIR"
mkdir -p "$STAGING_DIR"

# Download with progress bar, retry 3 times, fail on server error
echo -e "${YELLOW}Downloading Antigravity CLI...${NC}"
curl -fsSL --retry 3 --progress-bar -o "$STAGING_DIR/cli.tar.gz" "$CLI_URL"

echo -e "${YELLOW}Downloading Antigravity 2.0 Desktop App...${NC}"
curl -fsSL --retry 3 --progress-bar -o "$STAGING_DIR/app.tar.gz" "$APP_URL"

echo -e "${YELLOW}Downloading Antigravity IDE...${NC}"
curl -fsSL --retry 3 --progress-bar -o "$STAGING_DIR/ide.tar.gz" "$IDE_URL"

echo -e "${GREEN}All files downloaded successfully to $STAGING_DIR.${NC}"
echo ""

echo -e "${BLUE}----------------------------------------------------------------------${NC}"
echo -e "[3/5] Extracting and installing components..."
echo -e "${BLUE}----------------------------------------------------------------------${NC}"

# A. Install CLI
echo "Installing CLI..."
mkdir -p "$HOME/.local/bin"
tar -xzf "$STAGING_DIR/cli.tar.gz" -C "$HOME/.local/bin/"
if [ -f "$HOME/.local/bin/antigravity" ]; then
    mv "$HOME/.local/bin/antigravity" "$HOME/.local/bin/agy"
fi
chmod +x "$HOME/.local/bin/agy"

# Run the CLI path installation setup
"$HOME/.local/bin/agy" install
# Add system-wide link for CLI
sudo ln -sf "$HOME/.local/bin/agy" /usr/local/bin/agy

# B. Install Antigravity 2.0 Desktop App
echo "Installing Antigravity 2.0 Desktop App..."
sudo mkdir -p /opt/antigravity
sudo tar -xzf "$STAGING_DIR/app.tar.gz" -C /opt/antigravity --strip-components=1
# Configure setuid root sandbox permissions
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

# C. Install Antigravity IDE
echo "Installing Antigravity IDE..."
sudo mkdir -p /opt/antigravity-ide
sudo tar -xzf "$STAGING_DIR/ide.tar.gz" -C /opt/antigravity-ide --strip-components=1
# Configure setuid root sandbox permissions
sudo chown root:root /opt/antigravity-ide/chrome-sandbox
sudo chmod 4755 /opt/antigravity-ide/chrome-sandbox

# Find binary inside the IDE installation folder
if [ -f /opt/antigravity-ide/antigravity-ide ]; then
    IDE_BIN="antigravity-ide"
elif [ -f /opt/antigravity-ide/antigravity ]; then
    IDE_BIN="antigravity"
else
    IDE_BIN=$(find /opt/antigravity-ide -maxdepth 1 -type f -executable -not -name "*.so*" -not -name "*.sh" -not -name "chrome-sandbox" -printf "%f\n" | head -n 1)
fi
sudo ln -sf "/opt/antigravity-ide/$IDE_BIN" /usr/local/bin/antigravity-ide

echo -e "${GREEN}Extraction and installation completed.${NC}"
echo ""

echo -e "${BLUE}----------------------------------------------------------------------${NC}"
echo -e "[4/5] Creating application shortcuts (GNOME / Wayland optimized)..."
echo -e "${BLUE}----------------------------------------------------------------------${NC}"

# Search for program icons in installation directories
ICON_APP=$(find /opt/antigravity -maxdepth 5 -name "antigravity.png" -o -name "icon.png" -o -name "code.png" | head -n 1)
[ -z "$ICON_APP" ] && ICON_APP="utilities-terminal"

ICON_IDE=$(find /opt/antigravity-ide -maxdepth 5 -name "antigravity.png" -o -name "icon.png" -o -name "code.png" | head -n 1)
[ -z "$ICON_IDE" ] && ICON_IDE="accessories-text-editor"

# Create Antigravity 2.0 Desktop entry
# Note: --no-sandbox is used here to ensure compatibility with SELinux in Enforcing mode on Fedora 44
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

echo -e "${GREEN}Launcher shortcuts created successfully in /usr/share/applications/.${NC}"
echo ""

echo -e "${BLUE}----------------------------------------------------------------------${NC}"
echo -e "[5/5] Verifying installations..."
echo -e "${BLUE}----------------------------------------------------------------------${NC}"

# Check CLI
if [ -x "$HOME/.local/bin/agy" ]; then
    CLI_VER=$("$HOME/.local/bin/agy" --version 2>/dev/null || echo "1.0.8")
    echo -e "${GREEN}✔ Antigravity CLI (agy) is available at ~/.local/bin/agy (Version: $CLI_VER)${NC}"
else
    echo -e "${RED}✘ Antigravity CLI binary not found or not executable!${NC}"
fi

# Check App
if [ -x "/usr/local/bin/antigravity" ]; then
    echo -e "${GREEN}✔ Antigravity 2.0 Desktop App is available at /usr/local/bin/antigravity${NC}"
else
    echo -e "${RED}✘ Antigravity 2.0 Desktop App binary not found!${NC}"
fi

# Check IDE
if [ -x "/usr/local/bin/antigravity-ide" ]; then
    echo -e "${GREEN}✔ Antigravity IDE is available at /usr/local/bin/antigravity-ide${NC}"
else
    echo -e "${RED}✘ Antigravity IDE binary not found!${NC}"
fi

# Clean up staging directory
rm -rf "$STAGING_DIR"

echo ""
echo -e "${CYAN}======================================================================${NC}"
echo -e "${GREEN}               REINSTALLATION COMPLETED SUCCESSFULLY                  ${NC}"
echo -e "${CYAN}======================================================================${NC}"
echo -e "You can launch the applications using:"
echo -e "  - ${YELLOW}agy${NC}                   (CLI Tool)"
echo -e "  - ${YELLOW}antigravity${NC}           (Desktop App)"
echo -e "  - ${YELLOW}antigravity-ide${NC}       (IDE)"
echo -e ""
echo -e "Or search for \"Google Antigravity\" / \"Google Antigravity IDE\""
echo -e "in your GNOME Applications Menu."
echo -e "${CYAN}======================================================================${NC}"
