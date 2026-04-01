#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
KEYCHAIN_PATH="$HOME/.morpheus-faucet.keychain-db"
KEYCHAIN_PASS_FILE="$HOME/.morpheus-faucet-pass"
KEYCHAIN_SERVICE="morpheus-faucet-wallet"
KEYCHAIN_ACCOUNT="j-suite-faucet"

echo "=== Starting Faucet ==="

# Read key from Keychain
if [ ! -f "$KEYCHAIN_PATH" ]; then
    echo "[FAIL] No faucet keychain found. Run ./setup-faucet.sh first."
    exit 1
fi

KEYCHAIN_PASS=$(cat "$KEYCHAIN_PASS_FILE")
security unlock-keychain -p "$KEYCHAIN_PASS" "$KEYCHAIN_PATH"

FAUCET_KEY=$(security find-generic-password \
    -s "$KEYCHAIN_SERVICE" \
    -a "$KEYCHAIN_ACCOUNT" \
    -w "$KEYCHAIN_PATH")

if [ -z "$FAUCET_KEY" ]; then
    echo "[FAIL] Could not read faucet key from Keychain."
    exit 1
fi

unset KEYCHAIN_PASS
echo "[OK] Faucet key loaded from Keychain"

cd "$SCRIPT_DIR"

MODE="${1:-node}"

if [ "$MODE" = "docker" ]; then
    echo "Starting via Docker..."
    FAUCET_PRIVATE_KEY="$FAUCET_KEY" docker compose up -d
    unset FAUCET_KEY
    echo "[OK] Faucet running in Docker on port 3456"
else
    echo "Starting via Node..."
    FAUCET_PRIVATE_KEY="$FAUCET_KEY" node server.js
fi
