#!/usr/bin/env bash
#
# test_config.sh — Validate hosting configuration files for myopenclawvps.com
#
# Runs offline checks on the config files (no root required) and optional
# live checks when running on the actual VPS.
#
# Usage: bash vps/test_config.sh
#
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DOMAIN="myopenclawvps.com"
PASS=0
FAIL=0

pass() { PASS=$((PASS + 1)); echo "  ✓ $1"; }
fail() { FAIL=$((FAIL + 1)); echo "  ✗ $1" >&2; }

# =============================================================================
echo "=== File existence checks ==="
# =============================================================================

[[ -f "${SCRIPT_DIR}/nginx/${DOMAIN}" ]]       && pass "nginx config exists"       || fail "nginx config missing"
[[ -f "${SCRIPT_DIR}/systemd/openclaw.service" ]] && pass "systemd service exists" || fail "systemd service missing"
[[ -f "${SCRIPT_DIR}/setup.sh" ]]               && pass "setup.sh exists"          || fail "setup.sh missing"
[[ -x "${SCRIPT_DIR}/setup.sh" ]]               && pass "setup.sh is executable"   || fail "setup.sh not executable"
[[ -f "${SCRIPT_DIR}/README.md" ]]              && pass "README.md exists"         || fail "README.md missing"

# =============================================================================
echo "=== Nginx config validation ==="
# =============================================================================

NGINX_CONF="${SCRIPT_DIR}/nginx/${DOMAIN}"

grep -q "server_name.*${DOMAIN}" "${NGINX_CONF}" \
    && pass "nginx config has correct server_name" \
    || fail "nginx config missing server_name for ${DOMAIN}"

grep -q "proxy_pass http://127.0.0.1:18789" "${NGINX_CONF}" \
    && pass "nginx proxies to port 18789" \
    || fail "nginx config missing proxy_pass to 18789"

grep -q "listen 443 ssl" "${NGINX_CONF}" \
    && pass "nginx listens on 443 with SSL" \
    || fail "nginx config missing SSL listener"

grep -q "listen 80" "${NGINX_CONF}" \
    && pass "nginx listens on port 80 (HTTP redirect)" \
    || fail "nginx config missing port 80 listener"

grep -q "return 301 https" "${NGINX_CONF}" \
    && pass "nginx redirects HTTP to HTTPS" \
    || fail "nginx config missing HTTP→HTTPS redirect"

grep -q "proxy_set_header Upgrade" "${NGINX_CONF}" \
    && pass "nginx has WebSocket upgrade header" \
    || fail "nginx config missing WebSocket support"

grep -q "ssl_certificate " "${NGINX_CONF}" \
    && pass "nginx has SSL certificate path" \
    || fail "nginx config missing SSL certificate"

grep -q "X-Forwarded-For" "${NGINX_CONF}" \
    && pass "nginx forwards client IP" \
    || fail "nginx config missing X-Forwarded-For"

# =============================================================================
echo "=== Systemd service validation ==="
# =============================================================================

SERVICE="${SCRIPT_DIR}/systemd/openclaw.service"

grep -q "ExecStart=.*openclaw gateway --port 18789" "${SERVICE}" \
    && pass "service starts openclaw on port 18789" \
    || fail "service ExecStart incorrect"

grep -q "User=balls" "${SERVICE}" \
    && pass "service runs as user balls" \
    || fail "service user incorrect"

grep -q "Restart=on-failure" "${SERVICE}" \
    && pass "service restarts on failure" \
    || fail "service missing restart policy"

grep -q "After=network.target" "${SERVICE}" \
    && pass "service starts after network" \
    || fail "service missing network dependency"

grep -q "WantedBy=multi-user.target" "${SERVICE}" \
    && pass "service installs to multi-user target" \
    || fail "service missing install target"

# =============================================================================
echo "=== Setup script validation ==="
# =============================================================================

SETUP="${SCRIPT_DIR}/setup.sh"

grep -q "set -euo pipefail" "${SETUP}" \
    && pass "setup.sh uses strict mode" \
    || fail "setup.sh missing strict mode"

grep -q 'EUID -ne 0' "${SETUP}" \
    && pass "setup.sh checks for root" \
    || fail "setup.sh missing root check"

grep -q "nginx -t" "${SETUP}" \
    && pass "setup.sh tests nginx config" \
    || fail "setup.sh missing nginx test"

grep -q "systemctl daemon-reload" "${SETUP}" \
    && pass "setup.sh reloads systemd" \
    || fail "setup.sh missing daemon-reload"

grep -q "certbot" "${SETUP}" \
    && pass "setup.sh mentions certbot for SSL" \
    || fail "setup.sh missing SSL reminder"

# =============================================================================
echo "=== Live service checks (skipped if not on VPS) ==="
# =============================================================================

if systemctl is-active nginx &>/dev/null; then
    pass "nginx is running"

    if sudo nginx -t 2>/dev/null; then
        pass "nginx config syntax OK"
    else
        fail "nginx config syntax error"
    fi
else
    echo "  - skipped (nginx not running)"
fi

if systemctl is-active openclaw &>/dev/null; then
    pass "openclaw service is running"
else
    echo "  - skipped (openclaw not running)"
fi

if curl -sf --max-time 5 "https://${DOMAIN}/health" &>/dev/null; then
    pass "health endpoint reachable at https://${DOMAIN}/health"
else
    echo "  - skipped (health endpoint not reachable)"
fi

# =============================================================================
echo ""
echo "=== Results: ${PASS} passed, ${FAIL} failed ==="

if [[ ${FAIL} -gt 0 ]]; then
    exit 1
fi
