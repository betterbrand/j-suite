#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
KEYCHAIN_PATH="$HOME/.morpheus-faucet.keychain-db"
KEYCHAIN_PASS_FILE="$HOME/.morpheus-faucet-pass"
KEYCHAIN_SERVICE="morpheus-faucet-wallet"
KEYCHAIN_ACCOUNT="j-suite-faucet"

echo "=== Faucet Setup ==="
echo ""

# Check for existing keychain
if [ -f "$KEYCHAIN_PATH" ]; then
    echo "Faucet keychain already exists at $KEYCHAIN_PATH"
    echo "To start fresh: rm $KEYCHAIN_PATH $KEYCHAIN_PASS_FILE"
    echo ""
    exit 0
fi

# Prompt for the private key
echo "Enter the faucet wallet private key (funded with MOR + ETH on BASE)."
echo "The key will be stored in macOS Keychain, not on disk."
echo ""
read -r -s -p "Private key (hidden): " FAUCET_KEY
echo ""

if [ -z "$FAUCET_KEY" ]; then
    echo "[FAIL] No key provided."
    exit 1
fi

# Strip 0x prefix if present
FAUCET_KEY="${FAUCET_KEY#0x}"

if [ ${#FAUCET_KEY} -ne 64 ]; then
    echo "[FAIL] Key must be 64 hex characters (got ${#FAUCET_KEY})."
    exit 1
fi

# Create keychain
KEYCHAIN_PASS=$(openssl rand -hex 32)
security create-keychain -p "$KEYCHAIN_PASS" "$KEYCHAIN_PATH"
security set-keychain-settings "$KEYCHAIN_PATH"

security add-generic-password \
    -s "$KEYCHAIN_SERVICE" \
    -a "$KEYCHAIN_ACCOUNT" \
    -w "$FAUCET_KEY" \
    -T /usr/bin/security \
    "$KEYCHAIN_PATH"

echo "$KEYCHAIN_PASS" > "$KEYCHAIN_PASS_FILE"
chmod 0400 "$KEYCHAIN_PASS_FILE"

unset FAUCET_KEY
unset KEYCHAIN_PASS

echo ""
echo "[OK] Faucet key stored in Keychain"
echo "     Keychain: $KEYCHAIN_PATH"
echo "     Service:  $KEYCHAIN_SERVICE"
echo ""

# Create .env from example if needed
if [ ! -f "$SCRIPT_DIR/.env" ]; then
    cp "$SCRIPT_DIR/.env.example" "$SCRIPT_DIR/.env"
    echo "[OK] Created .env from template"
    echo "     Edit RPC_URL if needed."
fi

echo ""
echo "Next: node generate-codes.js 20"
echo "Then: ./start-faucet.sh"
echo ""
