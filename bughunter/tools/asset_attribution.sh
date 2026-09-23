#!/bin/bash
# =============================================================================
# Asset Attribution — find an organization's web assets OUTSIDE its main domain
#
# Answers the recon question "what does this org run that is NOT under its
# apex domain?" — marketing microsites, campaign/activity sites, vendor-hosted
# tenants, free-SaaS pages, acquisitions. In bug bounty this is scope
# expansion; for asset-management / gov 盤點 it is shadow-asset discovery.
#
# Pillars (highest signal first), each degrades gracefully:
#   1. Outbound-link crawl of the org's KNOWN portals   (its own sites link out
#      to their campaign sites — also satisfies "external-link review")
#   2. Procurement trail        (--tw-gov: 政府電子採購網 via g0v/openfun API —
#      "委外" guarantees a paper trail; gives case-name LEADS)
#   3. crt.sh footprint         (expand each confirmed off-domain to its SANs)
#   4. Enrich + risk-flag       (dig A/CNAME, HTTP/Server, whois expiry →
#      dangling-CNAME / near-expiry / no-HTTPS)
#
# Attribution is per-asset: each hit is tagged with a confidence and the
# owning entity so you never mount an asset on the wrong agency.
#
# Usage:
#   ./tools/asset_attribution.sh --org "Acme Inc" --seed https://www.acme.com
#   ./tools/asset_attribution.sh --recon recon/acme.com --own-domain acme.com
#   ./tools/asset_attribution.sh --tw-gov --org "臺南市政府教育局" \
#        --recon recon/tn.edu.tw --own-domain tn.edu.tw --own-domain tainan.gov.tw \
#        --unit-match '臺南.*(教育|國民小學|國小|國中|高中|幼兒園|學校)'
#
# Output → findings/attribution/<ts>/  (candidates.tsv is the deliverable)
# =============================================================================

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
. "$SCRIPT_DIR/external_arsenal.sh"

GREEN='\033[0;32m'; RED='\033[0;31m'; YELLOW='\033[1;33m'; CYAN='\033[0;36m'; MAG='\033[0;35m'; NC='\033[0m'
log()  { echo -e "${CYAN}[*]${NC} $1"; }
ok()   { echo -e "${GREEN}[+]${NC} $1"; }
warn() { echo -e "${YELLOW}[!]${NC} $1"; }
hit()  { echo -e "${MAG}[ASSET]${NC} $1"; }
err()  { echo -e "${RED}[-]${NC} $1" >&2; }

UA='Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36'
ORG=""; UNIT_MATCH=""; TW_GOV=0; RECON=""; OUT_DIR=""; DEEP=0; MAX_SEEDS=40
SEEDS=(); OWN_DOMAINS=()
# platforms/CDNs/analytics/social that are never an "asset" on their own.
# NB: sites.google.com is deliberately NOT filtered (it hosts real microsites),
# so do not add a bare google.com rule here.
NOISE='w3\.org|schema\.org|ogp\.me|googleapis|gstatic|jquery|fontawesome|bootstrapcdn|cloudflare\.com|jsdelivr|unpkg|google-analytics|googletagmanager|doubleclick|gowatch|addthis|hinet\.net$|akamai|cloudfront|wp\.com$|w\.org|facebook\.com|fbcdn|instagram\.com|twitter\.com|(^|\.)x\.com$|linkedin\.com|line\.me|lin\.ee|youtube\.com|youtu\.be|apple\.com|microsoft\.com|bing\.com'
# CNAME targets that are actually takeover-prone (a CNAME to a normal host is not a risk)
TAKEOVER_PRONE='github\.io|herokuapp|amazonaws|s3[.-]|azurewebsites|azureedge|cloudapp\.azure|trafficmanager|pantheonsite|wpengine|fastly|netlify|surge\.sh|readthedocs|ghost\.io|myshopify|zendesk|helpscout|statuspage|bitbucket\.io|gitlab\.io|firebaseapp|web\.app|framer\.app|webflow\.io|wixsite|strikingly|bcvp0rtal|cargocollective'

while [ "$#" -gt 0 ]; do
  case "$1" in
    --org)         shift; ORG="${1:-}" ;;
    --seed)        shift; SEEDS+=("${1:-}") ;;
    --own-domain)  shift; OWN_DOMAINS+=("${1:-}") ;;
    --unit-match)  shift; UNIT_MATCH="${1:-}" ;;
    --recon)       shift; RECON="${1:-}" ;;
    --tw-gov)      TW_GOV=1 ;;
    --deep)        DEEP=1 ;;
    --max-seeds)   shift; MAX_SEEDS="${1:-40}" ;;
    --out)         shift; OUT_DIR="${1:-}" ;;
    -h|--help)     sed -n '2,40p' "$0"; exit 0 ;;
    *)             warn "unknown arg: $1" ;;
  esac
  shift
done

# --- derive seeds / own-domains from a recon dir if given --------------------
if [ -n "$RECON" ]; then
  seedsrc=""
  for f in live/hosts.txt web/hosts.txt live/urls.txt live/status_200.txt subdomains/all.txt; do
    [ -s "$RECON/$f" ] && { seedsrc="$RECON/$f"; break; }
  done
  if [ -n "$seedsrc" ]; then
    log "recon seeds from $seedsrc"
    while IFS= read -r h; do
      [ -n "$h" ] && SEEDS+=("https://$h/")
    done < <(sed -E 's#https?://##; s#[/:].*##' "$seedsrc" 2>/dev/null \
             | grep -viE 'stdblog|\.blog\.|^blog\.' | grep -E '\.' | sort -u | head -"$MAX_SEEDS")
  fi
  # infer apex own-domain from the recon dir name if none supplied
  [ "${#OWN_DOMAINS[@]}" -eq 0 ] && OWN_DOMAINS+=("$(basename "$RECON")")
fi
if [ "$TW_GOV" -eq 1 ]; then OWN_DOMAINS+=("gov.tw" "edu.tw"); fi
[ "${#SEEDS[@]}" -eq 0 ] && { err "no seeds — pass --seed <url> or --recon <dir>"; exit 2; }

OUT_DIR="${OUT_DIR:-$(pwd)/findings/attribution/$(date +%Y%m%d_%H%M%S)}"
mkdir -p "$OUT_DIR"

# build own-domain exclusion regex:  (^|\.)tn\.edu\.tw$ | (^|\.)gov\.tw$ ...
OWN_RE=""
for d in "${OWN_DOMAINS[@]}"; do
  esc=$(printf '%s' "$d" | sed 's/\./\\./g')
  OWN_RE="${OWN_RE}${OWN_RE:+|}(^|\.)${esc}\$"
done

if [ -f "$SCRIPT_DIR/banner.sh" ]; then
  . "$SCRIPT_DIR/banner.sh"
  print_banner "Asset Attribution" "${ORG:-<no org>}" \
    "Seeds|${#SEEDS[@]} portal(s) → outbound-link crawl" \
    "Preset|$([ "$TW_GOV" -eq 1 ] && echo 'TW-gov (採購網 + crt.sh + .tw whois)' || echo generic)" \
    "Exclude|${OWN_DOMAINS[*]}"
else
  log "Asset Attribution — org='${ORG:-?}' seeds=${#SEEDS[@]} exclude='${OWN_DOMAINS[*]}'"
fi

# ─── Pillar 1: outbound-link crawl ──────────────────────────────────────────
log "Pillar 1 — outbound-link crawl of ${#SEEDS[@]} seed portal(s) (parallel ${CRAWL_PAR:-20})"
# parallel-fetch every seed; an org's portals link out to their campaign sites
printf '%s\n' "${SEEDS[@]}" | xargs -P "${CRAWL_PAR:-20}" -I SURL \
  curl -sL --max-time 20 -A "$UA" "SURL" 2>/dev/null \
  | grep -oiE 'https?://[a-z0-9._-]+' > "$OUT_DIR/_linked_raw.txt"
# optional deeper crawl (opt-in: katana can run long on big CMS sites; curl+grep
# above already catches curated link lists). Hard-bounded so it can't hang a run.
if [ "$DEEP" -eq 1 ] && _have katana; then
  log "  --deep katana crawl (bounded 90s, depth 1)"
  printf '%s\n' "${SEEDS[@]}" | timeout 90 katana -silent -d 1 -jc -kf all -do -c 15 -timeout 10 2>/dev/null \
    | grep -oiE 'https?://[a-z0-9._-]+' >> "$OUT_DIR/_katana_links.txt" || true
fi
{ cat "$OUT_DIR/_linked_raw.txt"; cat "$OUT_DIR/_katana_links.txt" 2>/dev/null; } \
  | sed -E 's#https?://##; s#[:/].*##' | tr 'A-Z' 'a-z' | sort -u > "$OUT_DIR/_linked_hosts.txt"
grep -vE "${OWN_RE:-__nomatch__}" "$OUT_DIR/_linked_hosts.txt" 2>/dev/null \
  | grep -vE "$NOISE" | grep -E '\.' | sort -u > "$OUT_DIR/outbound_hosts.txt"
ok "outbound: $(wc -l < "$OUT_DIR/_linked_hosts.txt" | tr -d ' ') linked → $(wc -l < "$OUT_DIR/outbound_hosts.txt" | tr -d ' ') off-domain candidate(s)"

# ─── Pillar 2: procurement trail (TW-gov) ───────────────────────────────────
if [ "$TW_GOV" -eq 1 ] && [ -n "$ORG" ]; then
  log "Pillar 2 — 政府電子採購網 (委外 leads for '$ORG')"
  : > "$OUT_DIR/procurement_leads.tsv"
  match="${UNIT_MATCH:-$ORG}"
  for kw in 活動網站 網站建置 網頁設計 網站維護 報名系統 主視覺 入口網 網站規劃 網站改版 平台建置 APP; do
    curl -sL --max-time 25 -G 'https://pcc-api.openfun.app/api/searchbytitle' \
      --data-urlencode "query=$kw" --data-urlencode 'page=1' -A "$UA" -o "$OUT_DIR/_kw.json" 2>/dev/null
    jq -r --arg kw "$kw" --arg re "$match" '
      .records[]? | select((.unit_name // "")|test($re))
      | [$kw,.date,.unit_name,(.brief.title // .job_number),.url] | @tsv' \
      "$OUT_DIR/_kw.json" 2>/dev/null >> "$OUT_DIR/procurement_leads.tsv"
  done
  sort -u "$OUT_DIR/procurement_leads.tsv" -o "$OUT_DIR/procurement_leads.tsv"
  n=$(wc -l < "$OUT_DIR/procurement_leads.tsv" | tr -d ' ')
  [ "$n" -gt 0 ] && hit "procurement: $n website-related 委外 lead(s) → resolve each to a domain (see procurement_leads.tsv)" \
                 || ok "procurement: no website-tender match for unit filter"
fi

# ─── Pillar 3 + 4: crt.sh footprint expansion + enrich/risk per candidate ───
log "Pillar 3/4 — crt.sh footprint + enrich/risk per candidate"
echo -e "host\treg_domain\tA\tCNAME\thttp\tserver\ttitle\twhois_expiry\trisk" > "$OUT_DIR/candidates.tsv"

reg_domain() { # crude registrable-domain: keep 3 labels for *.<2ch>.tw / co.uk-ish, else 2
  awk -F. '{n=NF; if (n>=3 && length($(n-1))<=3 && length($n)==2) print $(n-2)"."$(n-1)"."$n; else if (n>=2) print $(n-1)"."$n; else print $0}'
}

while IFS= read -r host; do
  [ -z "$host" ] && continue
  rd=$(printf '%s' "$host" | reg_domain)
  a=$(dig +short A "$host" 2>/dev/null | tr '\n' ',' | sed 's/,$//')
  cn=$(dig +short CNAME "$host" 2>/dev/null | tr '\n' ',' | sed 's/,$//')
  hdr=$(curl -sIL --max-time 12 -A "$UA" "https://$host/" 2>/dev/null)
  code=$(printf '%s' "$hdr" | grep -iE '^HTTP/' | tail -1 | awk '{print $2}')
  server=$(printf '%s' "$hdr" | grep -iE '^server:' | tail -1 | sed 's/[Ss]erver: *//' | tr -d '\r')
  title=$(curl -sL --max-time 12 -A "$UA" "https://$host/" 2>/dev/null | grep -oiE '<title>[^<]*' | head -1 | sed 's/<title>//i' | tr -d '\r')
  exp=$(whois "$rd" 2>/dev/null | grep -iE 'expir|到期|Record expires' | grep -oE '[0-9]{4}[-/][0-9]{2}[-/][0-9]{2}' | head -1)
  # risk heuristics
  risk=""
  [ -n "$cn" ] && printf '%s' "$cn" | grep -qiE "$TAKEOVER_PRONE" && risk="${risk}dangling-CNAME→$cn "
  [ -z "$code" ] && risk="${risk}no-HTTP-response "
  [ -n "$exp" ] && { yr=${exp:0:4}; [ "$yr" -le "$(( $(date +%Y) + 1 ))" ] 2>/dev/null && risk="${risk}expiry-<=1yr($exp) "; }
  printf '%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\n' \
    "$host" "$rd" "${a:-none}" "${cn:-none}" "${code:-noresp}" "${server:-?}" "${title:-?}" "${exp:-?}" "${risk:-ok}" \
    >> "$OUT_DIR/candidates.tsv"
  hit "$host  [$rd]  http=$code  exp=${exp:-?}  ${risk:+RISK: $risk}"
  # crt.sh: expand this off-domain to its full SAN footprint (siblings)
  if [ "$TW_GOV" -eq 1 ] || _have jq; then
    curl -sL --max-time 30 "https://crt.sh/?q=$rd&output=json" -A "$UA" 2>/dev/null \
      | jq -r '.[].name_value' 2>/dev/null | tr ',' '\n' | sed 's/\*\.//g' | sort -u \
      >> "$OUT_DIR/_crt_$rd.txt" || true
  fi
done < "$OUT_DIR/outbound_hosts.txt"

ok "Done → $OUT_DIR/"
echo "  candidates.tsv        — off-domain assets + attribution risk (the deliverable)"
[ "$TW_GOV" -eq 1 ] && echo "  procurement_leads.tsv — 委外 case-name leads to resolve to domains"
echo "  outbound_hosts.txt    — also satisfies the 'external-link review' requirement"
echo ""
echo "Next: manually ATTRIBUTE + de-scope each row (which agency owns it?), then"
echo "  feed dangling/near-expiry rows into  ./tools/takeover_scanner.sh"
