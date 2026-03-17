#!/usr/bin/env bash
#
# setup.sh — Deploy hosting configuration for myopenclawvps.com
#
# This script installs the nginx site config and openclaw systemd service,
# then enables and starts the services so the app is accessible via the
# custom domain instead of localhost.
#
# Usage: sudo bash vps/setup.sh
#
set -euo pipefail

DOMAIN="myopenclawvps.com"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
NGINX_CONF_SRC="${SCRIPT_DIR}/nginx/${DOMAIN}"
SYSTEMD_SRC="${SCRIPT_DIR}/systemd/openclaw.service"
NGINX_AVAILABLE="/etc/nginx/sites-available/${DOMAIN}"
NGINX_ENABLED="/etc/nginx/sites-enabled/${DOMAIN}"
SYSTEMD_DEST="/etc/systemd/system/openclaw.service"
SITE_ROOT="/home/balls/${DOMAIN}"

# --- Preflight checks --------------------------------------------------------

if [[ $EUID -ne 0 ]]; then
    echo "Error: This script must be run as root (use sudo)." >&2
    exit 1
fi

if ! command -v nginx &>/dev/null; then
    echo "Error: nginx is not installed. Install it first:" >&2
    echo "  apt install -y nginx" >&2
    exit 1
fi

if [[ ! -f "${NGINX_CONF_SRC}" ]]; then
    echo "Error: nginx config not found at ${NGINX_CONF_SRC}" >&2
    exit 1
fi

if [[ ! -f "${SYSTEMD_SRC}" ]]; then
    echo "Error: systemd service not found at ${SYSTEMD_SRC}" >&2
    exit 1
fi

# --- Nginx setup --------------------------------------------------------------

echo "==> Installing nginx site config for ${DOMAIN}..."
cp "${NGINX_CONF_SRC}" "${NGINX_AVAILABLE}"

if [[ ! -L "${NGINX_ENABLED}" ]]; then
    ln -s "${NGINX_AVAILABLE}" "${NGINX_ENABLED}"
    echo "    Enabled site symlink created."
else
    echo "    Site symlink already exists."
fi

# Remove default site if it exists (avoids conflicts)
if [[ -L /etc/nginx/sites-enabled/default ]]; then
    rm /etc/nginx/sites-enabled/default
    echo "    Removed default site."
fi

echo "==> Testing nginx configuration..."
nginx -t

echo "==> Reloading nginx..."
systemctl reload nginx

# --- Site root ----------------------------------------------------------------

if [[ ! -d "${SITE_ROOT}" ]]; then
    echo "==> Creating site root at ${SITE_ROOT}..."
    mkdir -p "${SITE_ROOT}"
    chown balls:balls "${SITE_ROOT}"
fi

# --- Systemd service ----------------------------------------------------------

echo "==> Installing openclaw systemd service..."
cp "${SYSTEMD_SRC}" "${SYSTEMD_DEST}"
systemctl daemon-reload

echo "==> Enabling openclaw service..."
systemctl enable openclaw

echo "==> Starting openclaw service..."
systemctl restart openclaw

# --- SSL (Certbot) reminder ---------------------------------------------------

if [[ ! -d "/etc/letsencrypt/live/${DOMAIN}" ]]; then
    echo ""
    echo "WARNING: SSL certificates not found for ${DOMAIN}."
    echo "Run the following to obtain certificates:"
    echo "  sudo certbot --nginx -d ${DOMAIN} -d www.${DOMAIN}"
    echo ""
fi

# --- Done ---------------------------------------------------------------------

echo ""
echo "==> Hosting setup complete!"
echo "    Domain:  https://${DOMAIN}"
echo "    Nginx:   $(systemctl is-active nginx)"
echo "    OpenClaw: $(systemctl is-active openclaw)"
echo ""
echo "To verify: curl -s https://${DOMAIN}/health"
