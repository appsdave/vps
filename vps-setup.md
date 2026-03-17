# VPS Setup Documentation

**Last updated:** 2026-03-16

---

## System Overview

| Property       | Value                                      |
|----------------|--------------------------------------------|
| Hostname       | balls                                      |
| OS             | Ubuntu 24.04.3 LTS (Noble Numbat)          |
| Kernel         | 6.8.0-100-generic (x86_64)                 |
| Public IP      | 88.135.73.195                              |
| CPU cores      | 8                                          |
| RAM            | 16 GB                                      |
| Disk           | 308 GB (4.5 GB used)                       |

## Users

| User  | UID  | Groups                  | Home            |
|-------|------|-------------------------|-----------------|
| root  | 0    | root                    | /root           |
| balls | 1000 | balls, sudo, users      | /home/balls     |

- `balls` has NOPASSWD sudo access via `/etc/sudoers.d/balls`
- Sudo admin hint suppressed via `~/.sudo_as_admin_successful`

## Running Services

| Service              | Status  | Notes                              |
|----------------------|---------|------------------------------------|
| nginx 1.24.0         | active  | Reverse proxy → OpenClaw gateway   |
| openclaw             | active  | OpenClaw gateway on port 18789     |
| sshd (OpenSSH)       | active  | Listening on port 22               |
| fail2ban             | active  | Protecting sshd jail               |
| ufw                  | active  | Firewall                           |
| cron                 | active  | Scheduled tasks                    |
| systemd-resolved     | active  | DNS resolution                     |
| systemd-timesyncd    | active  | NTP time sync                      |
| unattended-upgrades  | active  | Automatic security updates         |
| qemu-guest-agent     | active  | VM guest agent                     |

## Firewall (UFW)

- **Default policy:** DROP incoming
- **Whitelisted IP:** 172.58.127.242 (full access)
- **Allowed ports:**
  - 22/tcp (SSH) — open to all
  - 80/tcp & 443/tcp (Nginx Full) — open to all

## Fail2Ban

- **Jail:** sshd
- **Max retries:** 3
- **Ban time:** 3600s (1 hour)
- **Find time:** 10 minutes
- **Ignored IPs:** 127.0.0.1/8, ::1, 172.58.127.242

## Nginx Configuration

- **Domain:** myopenclawvps.com (+ www.myopenclawvps.com)
- **Document root:** /home/balls/myopenclawvps.com
- **SSL:** Enabled via Let's Encrypt (Certbot)
  - Certificate: /etc/letsencrypt/live/myopenclawvps.com/fullchain.pem
  - Key: /etc/letsencrypt/live/myopenclawvps.com/privkey.pem
- **HTTP → HTTPS redirect:** Yes (managed by Certbot)
- **Reverse proxy:** All requests proxied to OpenClaw gateway at `127.0.0.1:18789` (WebSocket support enabled)
- **Remote URL:** `https://myopenclawvps.com`
- **Health check:** `https://myopenclawvps.com/health` → `{"ok":true,"status":"live"}`

## Website Files

```
/home/balls/myopenclawvps.com/
├── index.html        # Landing page ("myopenclawvps.com is live!")
├── .env              # Shared non-sensitive defaults
├── .env.local        # Local secrets (git-ignored, mode 600)
├── .env.schema       # Varlock schema with @sensitive decorators
├── .gitignore        # Ignores .env.local
└── .git/
    └── hooks/
        └── pre-commit  # Varlock scan — blocks commits with leaked secrets
```

## Secret Management (Varlock)

- **Tool:** [varlock](https://github.com/dmno-dev/varlock) (installed at ~/.config/varlock/bin/varlock)
- **PATH:** Added via `export PATH="${XDG_CONFIG_HOME:-~/.config}/varlock/bin:$PATH"` in ~/.bashrc
- **Schema file:** .env.schema uses `@sensitive`, `@required`, and `@type` decorators
- **Secrets storage:** .env.local (git-ignored, permissions 600)
- **Pre-commit hook:** Installed — runs `varlock scan` before every git commit to prevent secret leaks
- **Managed secrets:**
  - `HF_TOKEN` — HuggingFace API token (marked @sensitive @required)

## SSH Access

- **Port:** 22
- **Key type:** Ed25519
- **Key files:** /home/balls/.ssh/balls (private), /home/balls/.ssh/balls.pub (public)
- **Authorized keys:** /home/balls/.ssh/authorized_keys
- **Password auth:** Disabled (key-only)

## Login Banner (MOTD)

- **Custom script:** `/etc/update-motd.d/00-custom`
  - Purple ASCII art "Balls" banner
  - Live system stats: uptime, load, memory, disk, process count
  - Security status: fail2ban banned IPs, UFW status
  - Site & varlock info
- **Default Ubuntu MOTD scripts:** All disabled (chmod -x) to keep login clean
  - Disabled: 00-header, 10-help-text, 50-landscape-sysinfo, 50-motd-news, 85-fwupd, 90-updates-available, 91-contract-ua-esm-status, 91-release-upgrade, 92-unattended-upgrades, 95-hwe-eol, 97-overlayroot, 98-fsck-at-reboot, 98-reboot-required

## Shell Customization (~/.bashrc)

### Custom Prompt
- Purple lightning bolt `⚡` prefix with colored user@host, working directory, and git branch display
- Single PS1 definition (no duplicate/conflicting prompts)

### Aliases

| Alias       | Command                                    | Category     |
|-------------|--------------------------------------------|--------------|
| `site`      | `cd ~/myopenclawvps.com`                   | Navigation   |
| `docs`      | `cd ~/vps`                                 | Navigation   |
| `..` / `...`| Go up 1 or 2 directories                  | Navigation   |
| `lt`        | `ls -lhtr` (by time)                       | Listing      |
| `lsize`     | `ls -lhS` (by size)                        | Listing      |
| `mem`       | `free -h`                                  | System       |
| `disk`      | `df -h /`                                  | System       |
| `cpu`       | `nproc && uptime`                          | System       |
| `top5`      | Top 5 processes by memory                  | System       |
| `ports`     | `ss -tlnp`                                 | System       |
| `myip`      | Public IP via ifconfig.me                  | System       |
| `reload`    | Source ~/.bashrc                           | Shell        |
| `sob`       | Source ~/.bashrc (alias for reload)        | Shell        |
| `ngx`       | Restart nginx                              | Nginx        |
| `ngxtest`   | Test nginx config                          | Nginx        |
| `ngxlog`    | Tail nginx access log                      | Nginx        |
| `ngxerr`    | Tail nginx error log                       | Nginx        |
| `sshlog`    | Tail SSH journal log                       | Security     |
| `fw`        | UFW status numbered                        | Security     |
| `banned`    | Fail2ban sshd status                       | Security     |
| `unban <ip>`| Unban an IP from fail2ban                  | Security     |
| `vscan`     | Run varlock scan                           | Varlock      |
| `vload`     | Run varlock load                           | Varlock      |
| `h`         | Last 30 history entries                    | Misc         |
| `hg <term>` | Search command history                    | Misc         |
| `cls`       | Clear terminal                             | Misc         |
| `path`      | Print PATH entries (one per line)          | Misc         |

### Functions

| Function       | Description                                |
|----------------|--------------------------------------------|
| `mkcd <dir>`   | Create directory and cd into it           |
| `extract <f>`  | Extract any archive (tar, gz, zip, 7z…)   |
| `sysinfo`      | Full system + services overview            |
| `cheat`        | Display the full VPS cheatsheet            |

### History Settings
- **HISTSIZE:** 10000
- **HISTFILESIZE:** 20000
- **HISTTIMEFORMAT:** `%F %T  ` (timestamps in history)
- **cmdhist:** enabled (multi-line commands saved as one)
