#!/bin/bash
# ==============================================================================
# Tsjaad Olifant — one-click build
# ==============================================================================
# Double-click this file to build the macOS app. It will:
#   1. Check for Node.js (install via Homebrew if missing — fully automatic)
#   2. Run npm install if needed
#   3. Generate the app icon
#   4. Build the .app with electron-builder
#   5. Package everything as a ready-to-run zip
# ==============================================================================

set -e

cd "$(dirname "$0")"

RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'; CYAN='\033[0;36m'; RESET='\033[0m'
info()  { echo -e "${CYAN}[tsjaad]${RESET} $*"; }
ok()    { echo -e "${GREEN}[tsjaad]${RESET} $*"; }
warn()  { echo -e "${YELLOW}[tsjaad]${RESET} $*"; }
err()   { echo -e "${RED}[tsjaad]${RESET} $*" >&2; }

# --- Helper: ask for sudo password up front if we'll need it later ----------
ensure_sudo() {
  if ! sudo -n true 2>/dev/null; then
    info "This script needs admin rights to install missing tools."
    sudo -v
  fi
}

# --- Helper: install Homebrew if missing -------------------------------------
install_homebrew() {
  if command -v brew >/dev/null 2>&1; then return 0; fi
  info "Homebrew not found. Installing Homebrew..."
  ensure_sudo
  NONINTERACTIVE=1 /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"

  # Add brew to PATH for this session (Apple Silicon puts it in /opt/homebrew)
  if [ -f /opt/homebrew/bin/brew ]; then
    eval "$(/opt/homebrew/bin/brew shellenv)"
  elif [ -f /usr/local/bin/brew ]; then
    eval "$(/usr/local/bin/brew shellenv)"
  fi
  ok "Homebrew installed."
}

# --- Step 1: ensure Node.js is installed ------------------------------------
if ! command -v node >/dev/null 2>&1; then
  warn "Node.js not found. Installing it now..."
  install_homebrew
  info "Installing Node.js via Homebrew..."
  brew install node
  # Re-source brew env in case PATH wasn't picked up
  if [ -f /opt/homebrew/bin/brew ]; then
    eval "$(/opt/homebrew/bin/brew shellenv)"
  fi
  if ! command -v node >/dev/null 2>&1; then
    err "Node.js still not on PATH. Try opening a new Terminal window and re-running this script."
    exit 1
  fi
fi
ok "Node.js $(node -v) ready."

# --- Step 2: ensure Command Line Tools (needed by electron-builder native deps)
if ! xcode-select -p >/dev/null 2>&1; then
  warn "Xcode Command Line Tools not found. Triggering install (a GUI popup will appear)..."
  xcode-select --install
  # Wait for the install to finish
  until xcode-select -p >/dev/null 2>&1; do
    sleep 5
  done
  ok "Command Line Tools installed."
fi

# --- Step 3: run the builder -------------------------------------------------
info "Starting build..."
echo

node tsjaadbuilder.js --mac

echo
ok "Build finished!"

ZIP_FILE="TsjaadOlifant-mac-arm64.zip"
if [ -f "$ZIP_FILE" ]; then
  STAGE_DIR=$(mktemp -d -t tsjaad)
  ditto -x -k "$ZIP_FILE" "$STAGE_DIR"
  APP_DIR="$STAGE_DIR/TsjaadOlifant"

  info "Opening the result in Finder..."
  open -R "$APP_DIR/TsjaadOlifant.command" 2>/dev/null || open "$APP_DIR"

  echo
  echo -e "${GREEN}============================================================${RESET}"
  echo -e "${GREEN}  Done! To launch the elephant:${RESET}"
  echo -e "${GREEN}    Double-click 'TsjaadOlifant.command' in Finder${RESET}"
  echo -e "${GREEN}    (one-time setup, it strips Gatekeeper for you)${RESET}"
  echo -e "${GREEN}============================================================${RESET}"
  echo
  read -r -p "Press Enter to launch it now, or Ctrl+C to quit..." _
  open "$APP_DIR/TsjaadOlifant.command"
fi
