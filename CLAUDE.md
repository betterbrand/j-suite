# The J Suite

Sovereign, local-first AI onboarding for the Morpheus network. One curl command installs everything — generates a wallet, funds it via invite code, starts the node, and opens a browser-based chat UI connected to decentralized AI models with TEE verification.

## Architecture

### Install flow

The install is a single curl-to-bash pipeline:
1. Downloads the project via GitHub zip (no git required)
2. Generates an Ethereum wallet, stores the private key in macOS Keychain (`morpheus-consumer-wallet`)
3. If `--invite CODE` provided, calls the faucet API to fund the wallet (3 MOR + 0.005 ETH)
4. Validates RPC endpoint, auto-discovers fastest free BASE RPC if needed
5. Pulls and starts the proxy-router Docker container (key injected from Keychain via EXIT trap, restored to sentinel after start)
6. Polls wallet balance until funds arrive (or skips if faucet funded)
7. Opens `chat.html` in the browser

### Chat UI (`chat.html`)

Single-file HTML/CSS/JS app:
- Connects to proxy-router API at `localhost:8082` with Basic Auth
- Checks for existing active sessions on load (resumes if found)
- MOR approval in wei (`100000000000000000000` = 100 MOR)
- Streams responses via SSE (`/v1/chat/completions` with `stream: true`)
- Persists chat history in `localStorage` across sessions and model switches
- Collapsible sidebar: model info, TEE badges, wallet balances, session countdown, network data, Add MOR section with copy button
- Models modal (click model count in sidebar)
- Session expiry banner with "New Session" button or "Add MOR" prompt
- Low balance indicators (amber < 5 MOR, red = 0)
- RPC health monitoring (polls every 30s, banner after 3 failures)
- All model/tag data rendered via DOM construction with `textContent` (no innerHTML for user data)

### Faucet (`faucet/`)

Express server deployed on Railway with Postgres:
- `POST /fund` — redeems invite code, sends MOR + ETH to wallet
- `GET /health` — returns `{ status: 'ok' }` only (no stats)
- `GET /admin/stats` — code counts, disbursement, budget (admin auth)
- `GET /admin/codes` — full code list with assigned names (admin auth)
- `POST /admin/generate` — create new codes (admin auth)
- `POST /admin/assign` — assign a name to a code (admin auth, 100 char max)
- `GET /admin/wallet` — faucet wallet balances and invites remaining (admin auth)
- `GET /admin/analytics` — per-user on-chain metrics via Blockscout + RPC (admin auth)
- `GET /admin/analytics/:wallet/history` — snapshot timeline (admin auth)

Admin auth: `X-Admin-Secret` header, timing-safe comparison via `crypto.timingSafeEqual`.

Admin dashboard (`faucet/admin.html`): single-file HTML, runs from `file://`, secret in `sessionStorage` (tab-scoped). Share/copy/assign buttons per code. Analytics section with summary cards and expandable user rows.

### RPC Fallback (`scripts/rpc-check.sh`)

Standalone tool and sourceable library. Health-checks 8 free public BASE RPCs, returns fastest. Used by `balance.sh` and `setup.sh` funding loop for automatic failover if primary RPC is down.

## File Inventory

| File | Purpose |
|------|---------|
| `install.sh` | Curl one-liner entry point, downloads zip, forwards args to setup |
| `chat.html` | Browser chat UI with sidebar, models modal, session management |
| `docker-compose.yml` | Proxy-router container |
| `.env.example` | Config template |
| `scripts/setup.sh` | Full install: wallet gen, keychain, faucet call, config, docker, fund, launch |
| `scripts/start.sh` | Reads key from Keychain, injects into .env with EXIT trap, starts container |
| `scripts/chat-ui.sh` | Reopens chat (starts node if not running) |
| `scripts/balance.sh` | Checks MOR + ETH with RPC fallback |
| `scripts/health.sh` | Verifies proxy-router container and API |
| `scripts/list-models.sh` | Lists marketplace models with TEE/GLM sections |
| `scripts/open-session.sh` | Auto-selects TEE/glm-5, approves MOR, opens session |
| `scripts/chat.sh` | CLI chat via curl |
| `scripts/teardown.sh` | Closes session (refunds MOR), stops containers |
| `scripts/flush.sh` | Returns all MOR + ETH to faucet wallet |
| `scripts/clean.sh` | Flush + stop + delete keychain + remove install |
| `scripts/rpc-check.sh` | Discovers and health-checks free BASE RPCs |
| `scripts/test.sh` | 53 tests |
| `scripts/eth_address.py` | Pure Python secp256k1 + keccak-256 address derivation |
| `faucet/server.js` | Faucet Express server with Postgres |
| `faucet/admin.html` | Admin dashboard for code management and analytics |
| `faucet/generate-codes.js` | CLI: generate invite codes |
| `faucet/list-codes.js` | CLI: list all codes |
| `faucet/setup-faucet.sh` | Stores faucet wallet key in macOS Keychain |
| `faucet/start-faucet.sh` | Reads key from Keychain, starts faucet (node or docker) |
| `faucet/Dockerfile` | Faucet container |
| `faucet/docker-compose.yml` | Faucet service |

## Key Constants

- Chain: BASE mainnet (8453)
- Diamond Contract: `0x6aBE1d282f72B474E54527D93b979A4f64d3030a`
- MOR Token: `0x7431aDa8a591C955a994a21710752EF9b882b8e3`
- Faucet Wallet: `0xbAdf61e49f606576b3D932D641c21787317cD0CC`
- Docker Image: `ghcr.io/morpheusais/morpheus-lumerin-node:latest`
- Proxy-Router API: `http://localhost:8082`
- Faucet API: `https://faucet-production-d8c8.up.railway.app`
- Blockscout API: `https://base.blockscout.com/api/v2`

## Security

- Private keys in macOS Keychain, never in files. `start.sh` uses EXIT trap to guarantee sentinel restore.
- Admin auth via `X-Admin-Secret` header with `crypto.timingSafeEqual`.
- Admin secret in `sessionStorage` (not `localStorage`) — tab-scoped, no cross-file:// leak.
- All user data rendered via DOM `textContent`, never innerHTML with inline event handlers.
- CORS: `origin: 'null'` (allows file:// only).
- Rate limiting via `req.ip` with `trust proxy` enabled for Railway.
- IPs stored as SHA-256 hash (first 16 chars), not raw.
- `assigned_to` capped at 100 chars.
- `/health` returns only `{ status: 'ok' }`. All stats behind admin auth.
- Faucet transactions sequential (ETH waits for confirmation before MOR) to prevent nonce collision.
- Codes marked `used: true` with `in-flight` status before transactions — can't be reused even on partial failure.

## Lessons Learned

- **Approve amount is in wei.** `amount=100` approves 100 wei (nothing). Must use `100000000000000000000` for 100 MOR.
- **Models response is `{"models": [...]}`, not a bare array.**
- **Model name is `glm-5`, not `glmb5`.**
- **`WALLET_PRIVATE_KEY` via `env_file` overrides shell env vars.** Must write key into `.env` before `docker compose up`, restore sentinel after.
- **Proxy-router reads `.env` from `/app/.env` inside the container.** Must mount it.
- **`PROXY_STORAGE_PATH` validation requires the directory to exist.** `mkdir -p data/data`.
- **`/dev/tty` not available when piped from curl.** No interactive prompts.
- **Public BASE RPC rate-limits aggressively.** Alchemy key required for reliability, with free RPC fallback.
- **macOS Keychain ACL: `-T ""` blocks access.** Use `-T /usr/bin/security`.
- **Session fees are 1 wei/second.** Real cost is gas (~0.000003 ETH at 0.006 gwei on BASE).
- **Python `hashlib.sha3_256` is NIST SHA-3, not keccak-256.** Implemented keccak-256 from scratch.
- **MorpheusUI crashes when Docker proxy-router uses port 8082.** Use `chat.html` instead.
- **chat.html runs via `file://`.** A localhost server adds complexity for no benefit.
- **GitHub raw content CDN caches ~5 minutes.** Use commit SHA URLs during testing.
- **Filter `Mistral-Fake:TEE` and `Negtest` tagged models.**
- **Faucet nonce collision.** Two simultaneous transactions (ETH + MOR) fail. Must `await ethTx.wait()` before sending MOR.
- **`esc()` (HTML entity encoding) doesn't protect JS string contexts in inline event handlers.** Use DOM construction with `addEventListener`.
- **CORS `origin: false` blocks file:// requests.** Use `origin: 'null'` for file:// compatibility.

## Conventions

- Never hardcode model names (marketplace is dynamic)
- Private keys in macOS Keychain, never in files
- Approve amounts always in wei
- No AI attributions in commits, PRs, or code
- No security implementation details in commit messages
- Alchemy API key injected at install time, not committed
- Faucet URL hardcoded in setup.sh (overridable via FAUCET_URL env var)
