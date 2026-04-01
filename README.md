# The J Suite on Morpheus

Sovereign, local-first AI for when privacy matters.

Be up and running on the Morpheus network with a single curl command. This consumer node is your gateway to a decentralized marketplace of open source AI models, offering P2P with TEE (Trusted Execution Environment) verification.

### Prerequisites

The installer checks for these automatically:
- macOS
- Docker Desktop installed and running (https://docker.com/products/docker-desktop)

## Install

### With an invite code (instant, no funding needed)

```bash
curl -fsSL https://raw.githubusercontent.com/betterbrand/j-suite/main/install.sh | bash -s -- --invite YOUR_CODE
```

The invite code funds your wallet automatically. The installer generates a wallet, starts the node, and opens the chat in your browser. Nothing else to do.

### Without an invite code (manual funding)

```bash
curl -fsSL https://raw.githubusercontent.com/betterbrand/j-suite/main/install.sh | bash
```

The installer generates a wallet and shows you the address. Send 3 MOR and a small amount of ETH on BASE to that address. The installer waits for the funds to arrive, then opens the chat.

### What the installer does

1. Downloads The J Suite to `~/j-suite`
2. Checks that Docker is installed
3. Generates a wallet (key stored in macOS Keychain, never on disk)
4. If invite code provided, requests funds from the faucet
5. Configures and starts the Morpheus proxy-router in Docker
6. Waits for funds to arrive
7. Opens the chat UI in your browser

## Using the Chat

The chat opens automatically after install. To reopen it later:

```bash
~/j-suite/scripts/chat-ui.sh
```

The chat UI runs in your browser and connects to the local proxy-router. From the chat you can:
- Pick a model from the marketplace (TEE providers highlighted)
- Open a session and chat with streaming responses
- Switch models (closes current session, opens a new one)
- Renew a session when it expires
- See your wallet balance, session countdown, and network info in the sidebar
- Click the model count in the sidebar to browse all available models

Each model switch costs a small amount of ETH for gas. Your wallet address is shown on the model selection screen if you need to add more.

## Script Reference

| Script | Purpose |
|--------|---------|
| `chat-ui.sh` | Opens the chat (starts the node if not running) |
| `start.sh` | Starts the proxy-router |
| `health.sh` | Verifies the node is running |
| `balance.sh` | Checks MOR + ETH balance |
| `list-models.sh` | Lists models on the marketplace |
| `open-session.sh` | Opens a session via CLI |
| `chat.sh` | Sends a message via CLI |
| `teardown.sh` | Closes session, stops the node |
| `flush.sh` | Returns all MOR + ETH to the faucet wallet |
| `clean.sh` | Flush + stop containers + delete keychain + remove install |
| `rpc-check.sh` | Discovers and health-checks free BASE RPC endpoints |

## Shut Down

Stop the node (keeps your wallet and install):

```bash
~/j-suite/scripts/teardown.sh
```

## Uninstall

Return funds to the faucet and remove everything:

```bash
~/j-suite/scripts/clean.sh
```

This checks for remaining MOR and ETH, returns them to the faucet, stops containers, removes the keychain, and deletes the install directory.

## Wallet Security

Your private key is stored in macOS Keychain, not in any plaintext file:
- Keychain: `~/.morpheus-wallet.keychain-db`
- Service name: `morpheus-consumer-wallet` (visible in Keychain Access.app)
- The `.env` file uses a sentinel value, not the actual key
- The key is read from Keychain at runtime and passed to Docker in memory

## Troubleshooting

**"Insufficient funds for gas"** -- Each model switch uses ETH for gas. Send ETH on BASE to your wallet address (shown on the model selection screen).

**"Session failed"** -- Check MOR balance. Need at least 3 MOR for a session.

**"Connection refused on 8082"** -- Node not running. Run `~/j-suite/scripts/start.sh`.

**"No models found"** -- Node may still be syncing. Wait a minute and try again. Run `~/j-suite/scripts/rpc-check.sh` to verify RPC connectivity.

**"API not responding"** -- The proxy-router takes 30-60 seconds to start. Run `~/j-suite/scripts/health.sh` to check.
