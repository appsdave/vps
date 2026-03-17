#!/usr/bin/env bash
#
# dev.sh — Route myopenclawvps.com through the bun dev server via nginx
#
# When dev mode is active, nginx proxies https://myopenclawvps.com to the
# bun dev server running on 127.0.0.1:3000 instead of the OpenClaw gateway.
#
# Usage:
#   sudo bash vps/dev.sh start    # swap to dev config and reload nginx
#   sudo bash vps/dev.sh stop     # restore production config and reload nginx
#   sudo bash vps/dev.sh status   # show current state
#
set -euo pipefail

DOMAIN="myopenclawvps.com"
BUN_DEV_PORT="3000"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

DEV_CONF_SRC="${SCRIPT_DIR}/nginx/dev"
PROD_CONF_SRC="${SCRIPT_DIR}/nginx/myopenclawvps.com"

NGINX_AVAILABLE_DEV="/etc/nginx/sites-available/dev"
NGINX_AVAILABLE_PROD="/etc/nginx/sites-available/myopenclawvps.com"
NGINX_ENABLED_DEV="/etc/nginx/sites-enabled/dev"
NGINX_ENABLED_PROD="/etc/nginx/sites-enabled/myopenclawvps.com"

# --- Preflight checks --------------------------------------------------------

if [[ $EUID -ne 0 ]]; then
    echo "Error: This script must be run as root (use sudo)." >&2
    exit 1
fi

if ! command -v nginx &>/dev/null; then
    echo "Error: nginx is not installed." >&2
    exit 1
fi

CMD="${1:-}"

# --- Commands ----------------------------------------------------------------

case "${CMD}" in
    start)
        echo "==> Installing dev nginx config..."
        cp "${DEV_CONF_SRC}" "${NGINX_AVAILABLE_DEV}"

        echo "==> Disabling production site..."
        if [[ -L "${NGINX_ENABLED_PROD}" ]]; then
            rm "${NGINX_ENABLED_PROD}"
            echo "    Removed production symlink."
        else
            echo "    Production symlink not found — skipping."
        fi

        echo "==> Enabling dev site..."
        if [[ ! -L "${NGINX_ENABLED_DEV}" ]]; then
            ln -s "${NGINX_AVAILABLE_DEV}" "${NGINX_ENABLED_DEV}"
            echo "    Created dev symlink."
        else
            echo "    Dev symlink already exists."
        fi

        echo "==> Testing nginx configuration..."
        nginx -t

        echo "==> Reloading nginx..."
        systemctl reload nginx

        echo ""
        echo "==> Dev mode active!"
        echo "    https://${DOMAIN} → bun dev server on 127.0.0.1:${BUN_DEV_PORT}"
        echo ""
        echo "Make sure bun dev is running:  bun dev"
        echo "To verify:                     curl -s https://${DOMAIN}/health"
        ;;

    stop)
        echo "==> Disabling dev site..."
        if [[ -L "${NGINX_ENABLED_DEV}" ]]; then
            rm "${NGINX_ENABLED_DEV}"
            echo "    Removed dev symlink."
        else
            echo "    Dev symlink not found — already inactive."
        fi

        if [[ -f "${NGINX_AVAILABLE_DEV}" ]]; then
            rm "${NGINX_AVAILABLE_DEV}"
            echo "    Removed dev config from sites-available."
        fi

        echo "==> Restoring production site..."
        if [[ ! -L "${NGINX_ENABLED_PROD}" ]]; then
            ln -s "${NGINX_AVAILABLE_PROD}" "${NGINX_ENABLED_PROD}"
            echo "    Created production symlink."
        else
            echo "    Production symlink already exists."
        fi

        echo "==> Testing nginx configuration..."
        nginx -t

        echo "==> Reloading nginx..."
        systemctl reload nginx

        echo ""
        echo "==> Production mode restored."
        echo "    https://${DOMAIN} → OpenClaw gateway"
        ;;

    status)
        if [[ -L "${NGINX_ENABLED_DEV}" ]]; then
            echo "Dev mode:  ACTIVE   (https://${DOMAIN} → bun dev on 127.0.0.1:${BUN_DEV_PORT})"
        else
            echo "Dev mode:  INACTIVE (https://${DOMAIN} → OpenClaw gateway)"
        fi
        ;;

    *)
        echo "Usage: sudo bash vps/dev.sh {start|stop|status}" >&2
        exit 1
        ;;
esac
