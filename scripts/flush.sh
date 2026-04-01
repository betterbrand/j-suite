#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
FAUCET_ADDR="0xbAdf61e49f606576b3D932D641c21787317cD0CC"
API_URL="http://localhost:8082"

# --- Load auth ---
if [ ! -f "$PROJECT_DIR/.env" ]; then
    echo "[FAIL] No .env found."
    exit 1
fi

COOKIE_CONTENT=$(grep '^COOKIE_CONTENT=' "$PROJECT_DIR/.env" | cut -d= -f2)
AUTH_USER="${COOKIE_CONTENT%%:*}"
AUTH_PASS="${COOKIE_CONTENT#*:}"

echo "=== Flush Wallet ==="
echo ""
echo "  Returning funds to faucet: $FAUCET_ADDR"
echo ""

# Check if proxy-router is running
cd "$PROJECT_DIR"
if ! docker compose ps --status running 2>/dev/null | grep -q proxy-router; then
    echo "  Starting proxy-router..."
    "$SCRIPT_DIR/start.sh"
    sleep 5
fi

# Get balances
BALANCE=$(curl -sf -u "$AUTH_USER:$AUTH_PASS" "$API_URL/blockchain/balance" 2>/dev/null || echo "")
if [ -z "$BALANCE" ]; then
    echo "[FAIL] Could not reach proxy-router."
    exit 1
fi

MOR_WEI=$(echo "$BALANCE" | python3 -c "import sys,json; print(json.load(sys.stdin).get('mor','0'))")
ETH_WEI=$(echo "$BALANCE" | python3 -c "import sys,json; print(json.load(sys.stdin).get('eth','0'))")
MOR_DISPLAY=$(echo "$MOR_WEI" | python3 -c "import sys; print(f'{int(sys.stdin.read().strip()) / 1e18:.4f}')")
ETH_DISPLAY=$(echo "$ETH_WEI" | python3 -c "import sys; print(f'{int(sys.stdin.read().strip()) / 1e18:.6f}')")

echo "  MOR: $MOR_DISPLAY"
echo "  ETH: $ETH_DISPLAY"
echo ""

SENT=false

# Send MOR back if any
if [ "$MOR_WEI" != "0" ]; then
    echo "  Sending MOR back..."
    RESP=$(curl -sf -u "$AUTH_USER:$AUTH_PASS" -X POST "$API_URL/blockchain/send/mor" \
        -H "Content-Type: application/json" \
        -d "{\"to\":\"$FAUCET_ADDR\",\"amount\":\"$MOR_WEI\"}" 2>/dev/null || echo "")
    if [ -n "$RESP" ]; then
        TX=$(echo "$RESP" | python3 -c "import sys,json; print(json.load(sys.stdin).get('tx',''))" 2>/dev/null || echo "")
        echo "  [OK] MOR sent: $TX"
        SENT=true
    else
        echo "  [WARN] MOR send failed"
    fi
else
    echo "  No MOR to return."
fi

# Send ETH back (keep dust for the MOR tx gas if we just sent MOR)
if [ "$SENT" = true ]; then
    echo "  Waiting for MOR tx to confirm..."
    sleep 5
    # Re-check ETH balance after MOR send used gas
    BALANCE=$(curl -sf -u "$AUTH_USER:$AUTH_PASS" "$API_URL/blockchain/balance" 2>/dev/null || echo "")
    ETH_WEI=$(echo "$BALANCE" | python3 -c "import sys,json; print(json.load(sys.stdin).get('eth','0'))")
fi

# Leave 0.00001 ETH for the send tx itself, send the rest
ETH_TO_SEND=$(echo "$ETH_WEI" | python3 -c "
import sys
wei = int(sys.stdin.read().strip())
gas_reserve = 100000000000000  # 0.0001 ETH reserve for this tx's gas
sendable = wei - gas_reserve
print(str(sendable) if sendable > 0 else '0')
")

if [ "$ETH_TO_SEND" != "0" ] && [ "$(echo "$ETH_TO_SEND" | python3 -c "import sys; print('yes' if int(sys.stdin.read().strip()) > 0 else 'no')")" = "yes" ]; then
    echo "  Sending ETH back..."
    RESP=$(curl -sf -u "$AUTH_USER:$AUTH_PASS" -X POST "$API_URL/blockchain/send/eth" \
        -H "Content-Type: application/json" \
        -d "{\"to\":\"$FAUCET_ADDR\",\"amount\":\"$ETH_TO_SEND\"}" 2>/dev/null || echo "")
    if [ -n "$RESP" ]; then
        TX=$(echo "$RESP" | python3 -c "import sys,json; print(json.load(sys.stdin).get('tx',''))" 2>/dev/null || echo "")
        echo "  [OK] ETH sent: $TX"
    else
        echo "  [WARN] ETH send failed"
    fi
else
    echo "  No ETH to return (or not enough to cover gas)."
fi

echo ""
echo "  Flush complete."
echo ""
