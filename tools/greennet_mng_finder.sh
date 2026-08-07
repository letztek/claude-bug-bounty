#!/usr/bin/env bash
# Greennet management backend finder
# Authorized security research on taipower.com.tw (HITCON ZeroDay, 2026-04-01 to 2026-06-30)

COOKIE=".AspNetCore.Session=CfDJ8Pprv6evUlhDk27eIdxIVPJWl2HAlM4dFTXQViijNxDlB2UqBba9kwQjnMMx8ZonlH1gu9rFCH7wiTiWxeOh5mXuosSmAZiG8SAl%2BEg9x08l0DFZy5ycRKb18w8xvjEdxsG4z0fdeKKDUbXe%2BvKYroERGbt1AjG5kR6Htih5onUW"
CURL=/usr/bin/curl

echo "=========================================="
echo "STEP 4 — Path probe on service.taipower.com.tw"
echo "=========================================="

paths=(
  "/greennet/mng"
  "/greennet/mng/"
  "/greennet/mng/index"
  "/greennet/mng/home"
  "/greennet/mng/dashboard"
  "/greennet/mng/member"
  "/greennet/mng/activity"
  "/greennet/mng/news"
  "/greennet/management"
  "/greennet/manage"
  "/greennet/administrator"
  "/greennet/staffPortal"
  "/greennet/staff-portal"
  "/greennet/staffportal"
  "/greennet/emp"
  "/greennet/employee"
  "/mng"
  "/management"
  "/admin"
  "/staff"
  "/employee-portal"
)

for path in "${paths[@]}"; do
  STATUS=$($CURL -s -o /dev/null -w "%{http_code}" \
    "https://service.taipower.com.tw${path}" \
    -b "$COOKIE" --max-time 10 -L 2>/dev/null)
  SIZE=$($CURL -s -w "%{size_download}" -o /dev/null \
    "https://service.taipower.com.tw${path}" \
    -b "$COOKIE" --max-time 10 -L 2>/dev/null)
  echo "HTTP $STATUS (${SIZE}B) → service.taipower.com.tw${path}"
done

echo ""
echo "=========================================="
echo "STEP 4b — Path probe on greennet.taipower.com.tw"
echo "=========================================="

for path in "/" "/greennet" "/greennet/" "/mng" "/greennet/mng" "/greennet/mng/"; do
  STATUS=$($CURL -s -o /dev/null -w "%{http_code}" \
    "https://greennet.taipower.com.tw${path}" --max-time 10 -k -L 2>/dev/null)
  SIZE=$($CURL -s -w "%{size_download}" -o /dev/null \
    "https://greennet.taipower.com.tw${path}" --max-time 10 -k -L 2>/dev/null)
  REDIR=$($CURL -s -o /dev/null -w "%{url_effective}" \
    "https://greennet.taipower.com.tw${path}" --max-time 10 -k -L 2>/dev/null)
  echo "HTTP $STATUS (${SIZE}B) → greennet.taipower.com.tw${path} [final: $REDIR]"
done

echo ""
echo "=========================================="
echo "STEP 5 — Fetch nav/footer hrefs from myaccount (IsTaipowerStaff=1)"
echo "=========================================="

$CURL -s "https://service.taipower.com.tw/greennet/myaccount" \
  -b "$COOKIE" --max-time 15 2>/dev/null | \
  grep -E 'href=|data-href=|ng-href=|router-link|to="/' | \
  grep -v 'javascript:void' | head -40

echo ""
echo "=========================================="
echo "STEP 5b — Look for mng in full page source"
echo "=========================================="

$CURL -s "https://service.taipower.com.tw/greennet/myaccount" \
  -b "$COOKIE" --max-time 15 2>/dev/null | \
  grep -iE 'mng|manage|staff|IsTaipowerStaff|系統維護|admin' | head -30

echo ""
echo "=========================================="
echo "STEP 6 — JS bundle grep for mng routes"
echo "=========================================="

echo "--- commons.js ---"
$CURL -s "https://service.taipower.com.tw/greennet/assets/js/commons.js" \
  --max-time 30 2>/dev/null | \
  grep -oP '"(mng|manage|staff|admin|employee|IsTaipowerStaff)[^"]{0,100}"' | head -20

echo "--- 00-cms.js ---"
$CURL -s "https://service.taipower.com.tw/greennet/assets/js/00-cms.js" \
  --max-time 15 2>/dev/null | \
  grep -oP '(mng|manage|staff|admin|employee|IsTaipowerStaff)[^"]{0,80}' | head -20

echo ""
echo "=========================================="
echo "STEP 7 — Probe employee/staff portal subdomains"
echo "=========================================="

hosts=(
  "employee.taipower.com.tw"
  "staff.taipower.com.tw"
  "intranet.taipower.com.tw"
  "portal.taipower.com.tw"
  "eportal.taipower.com.tw"
  "my.taipower.com.tw"
  "hr.taipower.com.tw"
  "ehr.taipower.com.tw"
  "erp.taipower.com.tw"
  "mng.taipower.com.tw"
  "manage.taipower.com.tw"
  "greennet-admin.taipower.com.tw"
  "gn.taipower.com.tw"
  "gnadmin.taipower.com.tw"
  "greennet1.taipower.com.tw"
  "greennet.taipower.com.tw"
)

for host in "${hosts[@]}"; do
  STATUS=$($CURL -s -o /dev/null -w "%{http_code}" \
    "https://${host}/" --max-time 8 -k 2>/dev/null)
  REDIR=$($CURL -s -o /dev/null -w "%{url_effective}" \
    "https://${host}/" --max-time 8 -k -L 2>/dev/null)
  echo "HTTP $STATUS → $host [final: $REDIR]"
done

echo ""
echo "=========================================="
echo "STEP 7b — HTTP (port 80) probe for subdomains"
echo "=========================================="

for host in "greennet.taipower.com.tw" "greennet1.taipower.com.tw"; do
  STATUS=$($CURL -s -o /dev/null -w "%{http_code}" \
    "http://${host}/" --max-time 8 2>/dev/null)
  REDIR=$($CURL -s -o /dev/null -w "%{url_effective}" \
    "http://${host}/" --max-time 8 -L 2>/dev/null)
  echo "HTTP $STATUS → http://$host [final: $REDIR]"
done

echo ""
echo "Done."
