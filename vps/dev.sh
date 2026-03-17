#!/usr/bin/env bash
#
# dev.sh — Manage the local dev proxy for myopenclawvps.com
#
# When the dev proxy is active, requests to http://localhost:8080 are routed
# to https://myopenclawvps.com so the local dev server forwards through the
# production domain.
#
# Usage:
#   sudo bash vps/dev.sh start    # enable dev proxy and reload nginx
#   sudo bash vps/dev.sh stop     # disable dev proxy and reload nginx
#   sudo bash vps/dev.sh status   # show current state
#
set -euo pipefail

DOMAIN="myopenclawvps.com"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DEV_CONF_SRC="${SCRIPT_DIR}/nginx/dev"
NGINX_AVAILABLE="/etc/nginx/sites-available/dev"
NGINX_ENABLED="/etc/nginx/sites-enabled/dev"

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
        echo "==> Installing dev proxy config..."
        cp "${DEV_CONF_SRC}" "${NGINX_AVAILABLE}"

        if [[ ! -L "${NGINX_ENABLED}" ]]; then
            ln -s "${NGINX_AVAILABLE}" "${NGINX_ENABLED}"
            echo "    Enabled dev proxy symlink."
        else
            echo "    Dev proxy symlink already exists."
        fi

        echo "==> Testing nginx configuration..."
        nginx -t

        echo "==> Reloading nginx..."
        systemctl reload nginx

        echo ""
        echo "==> Dev proxy active!"
        echo "    Local:   http://localhost:8080"
        echo "    Routes → https://${DOMAIN}"
        echo ""
        echo "To verify: curl -s http://localhost:8080/health"
        ;;

    stop)
        if [[ -L "${NGINX_ENABLED}" ]]; then
            rm "${NGINX_ENABLED}"
            echo "==> Removed dev proxy symlink."
        else
            echo "==> Dev proxy symlink not found — already inactive."
        fi

        if [[ -f "${NGINX_AVAILABLE}" ]]; then
            rm "${NGINX_AVAILABLE}"
            echo "==> Removed dev proxy config from sites-available."
        fi

        echo "==> Testing nginx configuration..."
        nginx -t

        echo "==> Reloading nginx..."
        systemctl reload nginx

        echo ""
        echo "==> Dev proxy stopped."
        ;;

    status)
        if [[ -L "${NGINX_ENABLED}" ]]; then
            echo "Dev proxy: ACTIVE (http://localhost:8080 → https://${DOMAIN})"
        else
            echo "Dev proxy: INACTIVE"
        fi
        ;;

    *)
        echo "Usage: sudo bash vps/dev.sh {start|stop|status}" >&2
        exit 1
        ;;
esac
