#!/usr/bin/env bash
set -euo pipefail

# The J Suite Installer
# Usage: curl -fsSL <raw-url>/install.sh | bash
#
# Downloads The J Suite to ~/j-suite and runs setup.

INSTALL_DIR="$HOME/j-suite"
REPO_URL="https://github.com/betterbrand/j-suite"
BRANCH="main"

echo ""
echo "  The J Suite Installer"
echo "  Morpheus Consumer Node + MorpheusUI"
echo ""

# --- Check prerequisites ---
if ! command -v docker &>/dev/null; then
    echo "[FAIL] Docker is not installed."
    echo ""
    echo "  Install Docker Desktop first:"
    echo "  https://docker.com/products/docker-desktop"
    echo ""
    exit 1
fi

if ! command -v python3 &>/dev/null; then
    echo "[FAIL] python3 not found. It ships with macOS -- something is wrong."
    exit 1
fi

if ! command -v security &>/dev/null; then
    echo "[FAIL] This installer requires macOS."
    exit 1
fi

# --- Download ---
if [ -d "$INSTALL_DIR" ]; then
    echo "The J Suite already installed at $INSTALL_DIR"
    echo "To reinstall, remove it first: rm -rf $INSTALL_DIR"
    echo ""
    echo "Running setup..."
    exec "$INSTALL_DIR/scripts/setup.sh" "$@"
fi

echo "Downloading The J Suite..."

TMP_ZIP=$(mktemp /tmp/j-suite-XXXXXX.zip)
TMP_DIR=$(mktemp -d /tmp/j-suite-extract-XXXXXX)

curl -fsSL "$REPO_URL/archive/refs/heads/$BRANCH.zip" -o "$TMP_ZIP"
unzip -q "$TMP_ZIP" -d "$TMP_DIR"
mv "$TMP_DIR/j-suite-$BRANCH" "$INSTALL_DIR"
rm -rf "$TMP_ZIP" "$TMP_DIR"

chmod +x "$INSTALL_DIR"/scripts/*.sh

echo "[OK] Installed to $INSTALL_DIR"
echo ""

# --- Run setup ---
exec "$INSTALL_DIR/scripts/setup.sh" "$@"
