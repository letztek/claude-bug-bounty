#!/usr/bin/env bash
# Probe greennet.taipower.com.tw vhost through service.taipower.com.tw IP
# Authorized security research on taipower.com.tw (HITCON ZeroDay, 2026-04-01 to 2026-06-30)

CURL=/usr/bin/curl
COOKIE=".AspNetCore.Session=CfDJ8Pprv6evUlhDk27eIdxIVPJWl2HAlM4dFTXQViijNxDlB2UqBba9kwQjnMMx8ZonlH1gu9rFCH7wiTiWxeOh5mXuosSmAZiG8SAl%2BEg9x08l0DFZy5ycRKb18w8xvjEdxsG4z0fdeKKDUbXe%2BvKYroERGbt1AjG5kR6Htih5onUW"

echo "=========================================="
echo "Probing greennet.taipower.com.tw vhost via service.taipower.com.tw (203.74.177.5)"
echo "=========================================="

paths=(
  "/"
  "/mng"
  "/mng/"
  "/mng/login"
  "/mng/index"
  "/mng/home"
  "/mng/dashboard"
  "/management"
  "/admin"
  "/login"
  "/cms"
  "/backstage"
  "/backend"
  "/console"
  "/greennet/mng"
  "/greennet/mng/"
  "/greennet/mng/login"
  "/greennet/management"
  "/index.html"
)

for path in "${paths[@]}"; do
  STATUS=$($CURL -s -o /dev/null -w "%{http_code}" \
    -H "Host: greennet.taipower.com.tw" \
    "https://service.taipower.com.tw${path}" -k \
    --max-time 8 2>/dev/null)
  SIZE=$($CURL -s -w "%{size_download}" -o /dev/null \
    -H "Host: greennet.taipower.com.tw" \
    "https://service.taipower.com.tw${path}" -k \
    --max-time 8 2>/dev/null)
  echo "HTTP $STATUS (${SIZE}B) → $path"
done

echo ""
echo "=========================================="
echo "Check with IsTaipowerStaff cookie via Host override"
echo "=========================================="

for path in "/mng" "/mng/" "/greennet/mng" "/greennet/mng/"; do
  STATUS=$($CURL -s -o /dev/null -w "%{http_code}" \
    -H "Host: greennet.taipower.com.tw" \
    -b "$COOKIE" \
    "https://service.taipower.com.tw${path}" -k \
    --max-time 8 2>/dev/null)
  REDIR=$($CURL -s -o /dev/null -w "%{url_effective}" \
    -H "Host: greennet.taipower.com.tw" \
    -b "$COOKIE" \
    "https://service.taipower.com.tw${path}" -k -L \
    --max-time 8 2>/dev/null)
  SIZE=$($CURL -s -w "%{size_download}" -o /dev/null \
    -H "Host: greennet.taipower.com.tw" \
    -b "$COOKIE" \
    "https://service.taipower.com.tw${path}" -k -L \
    --max-time 8 2>/dev/null)
  echo "HTTP $STATUS (${SIZE}B) → $path [final: $REDIR]"
done

echo ""
echo "=========================================="
echo "Check greennet1.taipower.com.tw"
echo "=========================================="

for path in "/" "/mng" "/greennet/mng" "/management"; do
  STATUS=$($CURL -s -o /dev/null -w "%{http_code}" \
    "https://greennet1.taipower.com.tw${path}" -k \
    --max-time 8 2>/dev/null)
  SIZE=$($CURL -s -w "%{size_download}" -o /dev/null \
    "https://greennet1.taipower.com.tw${path}" -k -L \
    --max-time 8 2>/dev/null)
  echo "HTTP $STATUS (${SIZE}B) → greennet1.taipower.com.tw${path}"
done

echo ""
echo "=========================================="
echo "Check IP range from background scan"
echo "=========================================="
# Already done in background - skip

echo ""
echo "Done."
