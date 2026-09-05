# Token Monitor Hub — Docker

Docker deployment for the [Token Monitor](https://github.com/Javis603/token-monitor) Node hub (`src/hub/server.js`). For 1Panel + `docker compose` + Watchtower auto-updates.

- Image: `ghcr.io/ec061/token-monitor-hub-node:latest` (rebuilt on upstream change via hourly check + manually by `Build Hub image` workflow)
- Upstream is cloned at **build time** (`UPSTREAM_REF=main`), so every image build = latest upstream hub
- Data persists in `./data/devices.json` (mounted volume)
- Same HTTP protocol as the Cloudflare Worker hub — just point clients at the new URL with the same `TOKEN_MONITOR_SECRET`

## 1Panel quick start

1. Upload `docker-compose.yml`, `Dockerfile`, `.env` (from `.env.example`) to the compose dir
2. Set `TOKEN_MONITOR_SECRET` to your existing Worker secret (token migration = reuse it)
3. Compose → Up. Reverse-proxy `token-hub.edwardcheng.net` → `127.0.0.1:17321` with Let's Encrypt
4. Verify: `GET /api/health` → `{"ok":true,...}`
5. Import data (see below), then flip DNS

## Data migration (Worker → Docker)

```bash
# export (needs Worker secret; works after DO daily reset at 00:00 UTC)
curl -s -H "Authorization: Bearer $TOKEN_MONITOR_SECRET" \
  https://token-hub.edwardcheng.net/api/devices > devices.json
curl -s -H "Authorization: Bearer $TOKEN_MONITOR_SECRET" \
  https://token-hub.edwardcheng.net/api/subscriptions > subscriptions.json
```

Then merge into `./data/devices.json` as `{version:1, devices:{id:record}, subscriptions}` and restart the hub service.
