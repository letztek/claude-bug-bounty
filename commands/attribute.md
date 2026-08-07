---
description: Find an organization's web assets OUTSIDE its main domain — marketing microsites, campaign/activity sites, vendor-hosted tenants, free-SaaS pages, acquisitions. Cross-domain org attribution for scope expansion (BB) or shadow-asset inventory (ASM / gov 盤點). Pillars — outbound-link crawl of known portals, procurement trail (TW-gov preset), crt.sh footprint, whois/DNS enrich + risk flags. Usage: /attribute --org "<name>" --seed <url> | /attribute --recon <recon-dir> --tw-gov
---

# /attribute

Answer the question **"what does this org run that is NOT under its apex domain?"**
Subdomain enum finds assets *inside* a known domain; this finds the ones that
live *outside* it — exactly where clues hide when the obvious domain is already
picked clean, and exactly what a "委外活動網站 / external-link" inventory needs.

## Usage

```
# generic (bug bounty scope expansion)
/attribute --org "Acme Inc" --seed https://www.acme.com --own-domain acme.com

# reuse an existing recon run as crawl seeds
/attribute --recon recon/acme.com --own-domain acme.com

# Taiwan government / education 盤點 preset
/attribute --tw-gov --org "臺南市政府教育局" \
   --recon recon/tn.edu.tw --own-domain tn.edu.tw --own-domain tainan.gov.tw \
   --unit-match '臺南.*(教育|國民小學|國小|國中|高中|幼兒園|學校)'
```

| Flag | Meaning |
|---|---|
| `--org` | organization name (drives procurement + content attribution) |
| `--seed <url>` | a known portal to crawl for outbound links (repeatable) |
| `--recon <dir>` | reuse a recon dir; auto-derives live portals as seeds |
| `--own-domain <suffix>` | domains to treat as in-scope/compliant and EXCLUDE (repeatable) |
| `--unit-match <regex>` | procurement buyer-unit filter (defaults to `--org`) |
| `--tw-gov` | enable 政府電子採購網 + crt.sh + `.tw` whois + adds gov.tw/edu.tw to exclusions |

## How it works — `tools/asset_attribution.sh`

1. **Outbound-link crawl** of the org's own portals (curl+grep href, katana if
   installed). An org's official sites link out to their campaign sites — highest
   signal, and the same list satisfies a "review all non-gov external links" ask.
2. **Procurement trail** (`--tw-gov`) — 政府電子採購網 via the g0v/openfun API.
   "委外" guarantees a tender; returns website-related case-name **leads** by
   buyer unit. (Leads are case names — you still resolve each to a domain.)
3. **crt.sh footprint** — expand each confirmed off-domain to its full SAN set.
4. **Enrich + risk** — dig A/CNAME, HTTP/Server, whois expiry → flags:
   dangling-CNAME (takeover), expiry-≤1yr (re-registration), no-HTTP-response.

## The step no tool does for you — ATTRIBUTION

Each hit must be tagged **which entity owns it** and a confidence, or you mount
an asset on the wrong org:

- **HIGH** — named in a procurement record / linked from an official page / whois registrant = the org
- **MED** — copyright/footer + contact pivot (phone, address, email domain) match
- **LOW** — merely mentions the org/place → manual queue, do NOT list

De-scope aggressively: a tourism site surfaced next to an education site belongs
to a *different* agency's inventory. Only HIGH/MED go in the deliverable.

## Output

`findings/attribution/<timestamp>/`:
- **`candidates.tsv`** — off-domain assets + DNS/HTTP/expiry + risk (the deliverable)
- `procurement_leads.tsv` — 委外 case names to resolve to domains (`--tw-gov`)
- `outbound_hosts.txt` — doubles as the external-link review list
- `_crt_<domain>.txt` — per-domain SAN footprint

Feed dangling / near-expiry rows into `/takeover`. See
`skills/asset-attribution/SKILL.md` for the full methodology and the pivots that
need API keys (favicon-hash / GA-ID / reverse-whois).
