#!/usr/bin/env bash
# POST probe for /greennet/mng paths
# Authorized security research on taipower.com.tw (HITCON ZeroDay, 2026-04-01 to 2026-06-30)

CURL=/usr/bin/curl
COOKIE=".AspNetCore.Session=CfDJ8Pprv6evUlhDk27eIdxIVPJWl2HAlM4dFTXQViijNxDlB2UqBba9kwQjnMMx8ZonlH1gu9rFCH7wiTiWxeOh5mXuosSmAZiG8SAl%2BEg9x08l0DFZy5ycRKb18w8xvjEdxsG4z0fdeKKDUbXe%2BvKYroERGbt1AjG5kR6Htih5onUW"

echo "POST probe for /greennet/mng/* paths"
echo "======================================"

paths=(
  "/greennet/mng"
  "/greennet/mng/"
  "/greennet/mng/login"
  "/greennet/mng/Login"
  "/greennet/mng/home"
  "/greennet/mng/index"
  "/greennet/mng/dashboard"
  "/greennet/mng/member"
  "/greennet/mng/activity"
  "/greennet/mng/news"
  "/greennet/mng/article"
  "/greennet/mng/banner"
  "/greennet/mng/api"
  "/greennet/mng/api/member"
  "/greennet/mng/api/login"
)

for path in "${paths[@]}"; do
  STATUS=$($CURL -s -o /dev/null -w "%{http_code}" \
    -b "$COOKIE" \
    -X POST \
    "https://service.taipower.com.tw${path}" \
    --max-time 8 2>/dev/null)
  SIZE=$($CURL -s -w "%{size_download}" -o /dev/null \
    -b "$COOKIE" \
    -X POST \
    "https://service.taipower.com.tw${path}" \
    --max-time 8 2>/dev/null)
  echo "POST HTTP $STATUS (${SIZE}B) → $path"
done

echo ""
echo "GET vs POST comparison for /greennet/mng:"
echo "GET:"
$CURL -s -D - "https://service.taipower.com.tw/greennet/mng" \
  -b "$COOKIE" --max-time 10 2>/dev/null
echo ""
echo "POST:"
$CURL -s -D - "https://service.taipower.com.tw/greennet/mng" \
  -b "$COOKIE" -X POST --max-time 10 2>/dev/null
echo ""
echo "Done."
