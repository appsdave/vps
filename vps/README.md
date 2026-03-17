# VPS Hosting Configuration

Hosting configuration for **myopenclawvps.com** — serves the OpenClaw gateway on a custom domain instead of localhost.

## Directory Structure

```
vps/
├── README.md                    # This file
├── setup.sh                     # Deployment script (run with sudo)
├── dev.sh                       # Dev mode manager (run with sudo)
├── test_config.sh               # Configuration validation tests
├── nginx/
│   ├── myopenclawvps.com        # Nginx site config (SSL + reverse proxy → OpenClaw)
│   └── dev                      # Dev nginx config (SSL + reverse proxy → bun dev)
└── systemd/
    └── openclaw.service         # Systemd unit for OpenClaw gateway
```

## Architecture

**Production**
```
Client (browser)
  │
  ▼
nginx (port 443, SSL)
  │  reverse proxy
  ▼
OpenClaw gateway (127.0.0.1:18789)
```

**Dev mode** (while `bun dev` is running)
```
Client (browser)
  │
  ▼
nginx (port 443, SSL)
  │  reverse proxy
  ▼
bun dev server (127.0.0.1:3001)
```

- **Nginx** terminates SSL and proxies all traffic (including WebSocket) to the active backend.
- **HTTP → HTTPS** redirect is handled by the port-80 server block.
- **SSL certificates** are managed by Certbot (Let's Encrypt).
- In dev mode, `dev.sh run` swaps the production nginx config for the dev one, reloads nginx, and starts the bun dev server headlessly (logs → `/tmp/ocha-dev-server.log`). `dev.sh stop` restores production.

## Dev Mode

When developing on the VPS, activate dev mode to route `https://myopenclawvps.com`
through to the local bun dev server on port 3001:

```bash
# Start nginx dev routing + bun dev server (headless, logs → /tmp/ocha-dev-server.log)
sudo bash vps/dev.sh run

# Tail the dev server logs
tail -f /tmp/ocha-dev-server.log

# Verify routing
curl -s https://myopenclawvps.com/health

# Stop just the dev server process
sudo bash vps/dev.sh stop-server

# Stop dev mode and restore production when done
sudo bash vps/dev.sh stop

# Check current state
sudo bash vps/dev.sh status
```

## Quick Deploy

```bash
# From the project root
sudo bash vps/setup.sh
```

The setup script will:
1. Install the nginx site config to `/etc/nginx/sites-available/`
2. Enable the site and reload nginx
3. Install and start the openclaw systemd service
4. Warn if SSL certificates are missing (run `certbot` to fix)

## Manual Steps

### First-time SSL setup

```bash
sudo certbot --nginx -d myopenclawvps.com -d www.myopenclawvps.com
```

### Check service status

```bash
systemctl status nginx
systemctl status openclaw
```

### Verify the site

```bash
curl -s https://myopenclawvps.com/health
# Expected: {"ok":true,"status":"live"}
```

## Configuration Details

| Setting          | Value                          |
|------------------|--------------------------------|
| Domain           | myopenclawvps.com              |
| Production port  | 18789 (OpenClaw gateway)       |
| Dev port         | 3001 (bun dev server)          |
| Site root        | /home/balls/myopenclawvps.com  |
| SSL cert         | /etc/letsencrypt/live/myopenclawvps.com/fullchain.pem |
| SSL key          | /etc/letsencrypt/live/myopenclawvps.com/privkey.pem   |
| Service user     | balls                          |
| Working dir      | /home/balls/.openclaw          |
