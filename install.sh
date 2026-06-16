#!/usr/bin/env bash
#
# NiCoLpy installer.
#
# One-line install (paste into Terminal):
#   curl -fsSL https://raw.githubusercontent.com/vemsom/NiCoLpy/main/install.sh | bash
#
# What it does:
#   1. Checks you're on macOS 13+.
#   2. Makes sure Apple's Command Line Tools are installed (prompts if not).
#   3. Downloads (or updates) NiCoLpy into ~/Library/Application Support/NiCoLpy/src.
#   4. Builds the app.
#   5. Installs it to /Applications.
#   6. Removes the "downloaded from the internet" quarantine flag so it opens
#      without the right-click dance.
#   7. Launches NiCoLpy.
#
set -euo pipefail

REPO_URL="https://github.com/vemsom/NiCoLpy.git"
APP_NAME="NiCoLpy"
SRC_DIR="$HOME/Library/Application Support/NiCoLpy/src"

# --- pretty output -----------------------------------------------------------
BOLD="$(tput bold 2>/dev/null || true)"
DIM="$(tput dim 2>/dev/null || true)"
RED="$(tput setaf 1 2>/dev/null || true)"
GREEN="$(tput setaf 2 2>/dev/null || true)"
BLUE="$(tput setaf 4 2>/dev/null || true)"
RESET="$(tput sgr0 2>/dev/null || true)"

step() { printf "\n${BOLD}${BLUE}==>${RESET} ${BOLD}%s${RESET}\n" "$1"; }
info() { printf "    %s\n" "$1"; }
ok()   { printf "    ${GREEN}✓${RESET} %s\n" "$1"; }
warn() { printf "    ${RED}!${RESET} %s\n" "$1"; }
die()  { printf "\n${RED}${BOLD}Error:${RESET} %s\n" "$1" >&2; exit 1; }

printf "${BOLD}NiCoLpy installer${RESET}\n"
printf "${DIM}A lightweight clipboard manager for macOS.${RESET}\n"

# --- 1. macOS version check --------------------------------------------------
step "Checking your Mac"
if [[ "$(uname)" != "Darwin" ]]; then
    die "NiCoLpy only runs on macOS."
fi
os_major="$(sw_vers -productVersion | cut -d. -f1)"
if (( os_major < 13 )); then
    die "NiCoLpy needs macOS 13 (Ventura) or newer. You have $(sw_vers -productVersion)."
fi
ok "macOS $(sw_vers -productVersion) detected"

# --- 2. Command Line Tools ---------------------------------------------------
step "Checking for Apple's developer tools"
if xcode-select -p >/dev/null 2>&1; then
    ok "Developer tools already installed"
else
    warn "Developer tools are needed to build the app."
    info "A window will pop up — click Install, then Agree."
    xcode-select --install >/dev/null 2>&1 || true

    info "Waiting for the tools to finish installing…"
    # Wait (up to ~30 min) for the install to complete.
    until xcode-select -p >/dev/null 2>&1; do
        sleep 5
        printf "."
    done
    printf "\n"
    ok "Developer tools installed"
fi

# Make sure git is actually usable.
if ! command -v git >/dev/null 2>&1; then
    die "git isn't available yet. Please re-run this installer in a minute."
fi

# --- 3. Download or update source -------------------------------------------
step "Downloading NiCoLpy"
mkdir -p "$(dirname "$SRC_DIR")"
if [[ -d "$SRC_DIR/.git" ]]; then
    info "Found an existing copy — updating it."
    git -C "$SRC_DIR" fetch --quiet origin
    git -C "$SRC_DIR" reset --hard --quiet origin/main
    ok "Updated to the latest version"
else
    rm -rf "$SRC_DIR"
    git clone --quiet "$REPO_URL" "$SRC_DIR"
    ok "Downloaded"
fi

# --- 4. Build ----------------------------------------------------------------
step "Setting up a stable signing identity"
cd "$SRC_DIR"
chmod +x setup-signing.sh build-app.sh
# Creates the "NiCoLpy Local" certificate once so the Accessibility permission
# survives future updates. Safe to run every time — it's a no-op if it exists.
./setup-signing.sh || warn "Couldn't set up signing identity; continuing with ad-hoc."

step "Building the app (this takes a minute)"
./build-app.sh release
[[ -d "build/$APP_NAME.app" ]] || die "Build did not produce $APP_NAME.app."
ok "Built $APP_NAME.app"

# --- 5. Quit any running instance, then install ------------------------------
step "Installing the app"
if pgrep -x "$APP_NAME" >/dev/null 2>&1; then
    info "Quitting the running copy first."
    osascript -e "quit app \"$APP_NAME\"" >/dev/null 2>&1 || pkill -x "$APP_NAME" || true
    sleep 1
fi

# Prefer /Applications, but fall back to ~/Applications if it isn't writable
# (common on managed Macs, and never needs a password).
INSTALL_DIR="/Applications"
if [[ ! -w "$INSTALL_DIR" ]]; then
    INSTALL_DIR="$HOME/Applications"
    mkdir -p "$INSTALL_DIR"
    info "Installing to your personal Applications folder (no password needed)."
fi

rm -rf "${INSTALL_DIR:?}/$APP_NAME.app"
if ! cp -R "build/$APP_NAME.app" "$INSTALL_DIR/" 2>/dev/null; then
    die "Couldn't copy to $INSTALL_DIR. Try running the installer again, or move build/$APP_NAME.app to Applications manually."
fi
ok "Installed to $INSTALL_DIR/$APP_NAME.app"

# --- 6. Remove quarantine so Gatekeeper doesn't block it ---------------------
# The app is ad-hoc signed (no paid Apple Developer account). Stripping the
# quarantine attribute lets it open normally without the right-click → Open step.
xattr -dr com.apple.quarantine "$INSTALL_DIR/$APP_NAME.app" 2>/dev/null || true
ok "Cleared the download quarantine"

# --- 7. Launch ---------------------------------------------------------------
step "Launching NiCoLpy"
open "$INSTALL_DIR/$APP_NAME.app"

cat <<EOF

${GREEN}${BOLD}Done!${RESET} Look for the clipboard icon ${BOLD}📋${RESET} in your menu bar (top-right).

${BOLD}How to use it${RESET}
  • Copy things normally with ⌘C — NiCoLpy remembers them.
  • Press ${BOLD}⌘⇧V${RESET} anywhere to open the list, right next to your cursor.
  • Pick a clip: click it, press a number (1–9), or use ↑/↓ then Return.
  • Right-click the 📋 icon for Settings, Launch at Login, and Quit.

${BOLD}One more thing — auto-paste${RESET}
  To let NiCoLpy paste for you automatically, allow it under:
  System Settings → Privacy & Security → Accessibility → turn on NiCoLpy.
  (Without this, your picked clip is still copied — just paste it with ⌘V.)

EOF
