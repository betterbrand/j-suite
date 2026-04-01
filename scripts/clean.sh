#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
INSTALL_DIR="$HOME/j-suite"
KEYCHAIN_PATH="$HOME/.morpheus-wallet.keychain-db"
KEYCHAIN_PASS_FILE="$HOME/.morpheus-keychain-pass"

echo "=== Clean J Suite ==="
echo ""

# --- Flush funds first ---
if [ -f "$PROJECT_DIR/.env" ]; then
    COOKIE_CONTENT=$(grep '^COOKIE_CONTENT=' "$PROJECT_DIR/.env" | cut -d= -f2 || echo "")
    AUTH_USER="${COOKIE_CONTENT%%:*}"
    AUTH_PASS="${COOKIE_CONTENT#*:}"
    API_URL="http://localhost:8082"

    # Start proxy-router if needed to check balance
    cd "$PROJECT_DIR"
    STARTED=false
    if ! docker compose ps --status running 2>/dev/null | grep -q proxy-router; then
        if [ -f "$KEYCHAIN_PATH" ]; then
            echo "  Starting proxy-router to check balances..."
            "$SCRIPT_DIR/start.sh" 2>/dev/null || true
            sleep 5
            STARTED=true
        fi
    fi

    # Check balances
    BALANCE=$(curl -sf -u "$AUTH_USER:$AUTH_PASS" "$API_URL/blockchain/balance" 2>/dev/null || echo "")
    if [ -n "$BALANCE" ]; then
        MOR_WEI=$(echo "$BALANCE" | python3 -c "import sys,json; print(json.load(sys.stdin).get('mor','0'))" 2>/dev/null || echo "0")
        ETH_WEI=$(echo "$BALANCE" | python3 -c "import sys,json; print(json.load(sys.stdin).get('eth','0'))" 2>/dev/null || echo "0")
        HAS_MOR=$(echo "$MOR_WEI" | python3 -c "import sys; print('yes' if int(sys.stdin.read().strip()) > 0 else 'no')")
        HAS_ETH=$(echo "$ETH_WEI" | python3 -c "import sys; print('yes' if int(sys.stdin.read().strip()) > 1000000000000 else 'no')")

        if [ "$HAS_MOR" = "yes" ] || [ "$HAS_ETH" = "yes" ]; then
            MOR_DISPLAY=$(echo "$MOR_WEI" | python3 -c "import sys; print(f'{int(sys.stdin.read().strip()) / 1e18:.4f}')")
            ETH_DISPLAY=$(echo "$ETH_WEI" | python3 -c "import sys; print(f'{int(sys.stdin.read().strip()) / 1e18:.6f}')")
            echo ""
            echo "  Wallet has funds: $MOR_DISPLAY MOR, $ETH_DISPLAY ETH"
            echo "  Returning to faucet..."
            echo ""
            "$SCRIPT_DIR/flush.sh"
        else
            echo "  Wallet is empty."
        fi
    else
        echo "  Could not check balance (proxy-router not responding)."
    fi
fi

# --- Stop containers ---
echo "  Stopping containers..."
cd "$PROJECT_DIR" 2>/dev/null && docker compose down 2>/dev/null || true

# --- Remove keychain ---
if [ -f "$KEYCHAIN_PATH" ]; then
    echo "  Removing keychain..."
    rm -f "$KEYCHAIN_PATH" "$KEYCHAIN_PASS_FILE"
    echo "  [OK] Keychain removed"
else
    echo "  No keychain to remove."
fi

# --- Remove install ---
if [ -d "$INSTALL_DIR" ]; then
    echo "  Removing $INSTALL_DIR..."
    rm -rf "$INSTALL_DIR"
    echo "  [OK] Install removed"
else
    echo "  No install to remove."
fi

echo ""
echo "  Clean complete. Ready for fresh install."
echo ""
