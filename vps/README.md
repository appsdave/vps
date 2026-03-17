# VPS Hosting Configuration

Hosting configuration for **myopenclawvps.com** — serves the OpenClaw gateway on a custom domain instead of localhost.

## Directory Structure

```
vps/
├── README.md                    # This file
├── setup.sh                     # Deployment script (run with sudo)
├── dev.sh                       # Dev proxy manager (run with sudo)
├── test_config.sh               # Configuration validation tests
├── nginx/
│   ├── myopenclawvps.com        # Nginx site config (SSL + reverse proxy)
│   └── dev                      # Dev proxy config (localhost:8080 → domain)
└── systemd/
    └── openclaw.service         # Systemd unit for OpenClaw gateway
```

## Architecture

```
Client (browser)
  │
  ▼
nginx (port 443, SSL)
  │  reverse proxy
  ▼
OpenClaw gateway (127.0.0.1:18789)
```

- **Nginx** terminates SSL and proxies all traffic (including WebSocket) to the OpenClaw gateway.
- **HTTP → HTTPS** redirect is handled by the port-80 server block.
- **SSL certificates** are managed by Certbot (Let's Encrypt).

## Dev Proxy

When developing locally, activate the dev proxy to route `http://localhost:8080`
through to `https://myopenclawvps.com`:

```bash
# Start dev proxy (nginx must be running)
sudo bash vps/dev.sh start

# Verify routing
curl -s http://localhost:8080/health
# Expected: {"ok":true,"status":"live"}

# Stop dev proxy when done
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
| App port         | 18789                          |
| Site root        | /home/balls/myopenclawvps.com  |
| SSL cert         | /etc/letsencrypt/live/myopenclawvps.com/fullchain.pem |
| SSL key          | /etc/letsencrypt/live/myopenclawvps.com/privkey.pem   |
| Service user     | balls                          |
| Working dir      | /home/balls/.openclaw          |
