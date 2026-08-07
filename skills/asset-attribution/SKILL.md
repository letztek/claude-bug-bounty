---
name: asset-attribution
description: Find an organization's web assets OUTSIDE its main/apex domain — marketing microsites, campaign & activity sites, vendor-hosted tenants, free-SaaS pages (Wix/Google Sites/Strikingly), acquisitions, and dangling/expired domains. Cross-domain organization attribution for bug-bounty scope expansion and for asset-management / government shadow-asset inventory (e.g. TW 委外活動網站 盤點, external-link review). Covers the four attribution tiers (procurement trail, outbound-link crawl, content dorks, infra pivots — favicon-hash / GA-ID / crt.sh / reverse-whois / passive DNS / wayback), attribution confidence grading + de-scoping, dangling/re-registration risk enrichment, and the /attribute + tools/asset_attribution.sh workflow. Use when the apex domain is picked clean and you need sibling assets, when attributing an asset to an owner, or when inventorying off-domain / non-gov sites. 中文触发词：主網域外資產、資產歸屬、委外活動網站、盤點、閒置網域、影子資產、微站、活動網站、非本網域、找出組織所有網站。
---

# ASSET ATTRIBUTION — assets outside the apex domain

Subdomain enumeration finds what lives *under* a domain you already know.
This finds what an organization runs that is **not under that domain at all**:
campaign microsites, event/activity sites, vendor-hosted tenants, free-SaaS
pages, acquired brands, and the abandoned domains that outlive them.

**When this matters**
- BB: the apex is picked clean → sibling domains / acquisitions widen scope and reset the "already-hunted" surface.
- ASM / gov: a mandate to inventory **委外活動網站** (outsourced/campaign sites) not on the agency's own `.gov.tw`/`.edu.tw` domain, or to review all external links — the exact 數位發展部 盤點 driver. Motive: **閒置網域遭惡意使用** (dangling/expired-domain abuse).

The hard part is not finding candidates — it's **attributing** each one to the
right owner with a confidence you can defend. Discovery is cheap; wrong
attribution is worse than a miss.

---

## The four tiers (run by signal/noise, not all-or-nothing)

### Tier 1 — authoritative (do these first, lowest noise)

**1a. Procurement trail.** If a site was *outsourced*, a purchase exists.
- TW: 政府電子採購網. Programmatic via the g0v/openfun mirror:
  `https://pcc-api.openfun.app/api/searchbytitle?query=<kw>&page=N`
  Keywords: `網站建置 網頁設計 活動網站 報名系統 主視覺 入口網 平台建置 APP`.
  Filter `.records[].unit_name` to the buyer org/units. The 決標公告 names the
  vendor + case; resolve the case name → its live domain.
- **Leads ≠ domains.** A tender proves a site was built; you still resolve its
  URL (dork the case name, check the vendor's infra). Many resolve to a
  *compliant* subdomain under the org's own domain — that's a correct negative,
  not a finding.
- **Per-unit pull (thorough):** the mirror also exposes `listbyunit?unit_id=<id>`
  (`.total`/`.total_page`; IDs are hierarchical dotted paths, tree is irregular).
  Harvest unit_ids from a name search, then listbyunit each. **Rate-limited** —
  keep parallelism ≤4 with pacing (`sleep`), or you silently lose most units
  (a spread-but-sparse result set = throttling, not a sparse ID space).
- **Know when it's low-yield.** Procurement finds *large named* projects. When the
  off-domain footprint is a *long tail of small sites* (schools, franchises, local
  branches), those rarely tender — the outbound-link crawl finds ~10× more.
  Validated on Tainan schools: crawl surfaced ~120 off-domain school assets vs
  procurement's ~0 activity sites (bureau tenders were all infrastructure).
- Corporate analog: SEC/press-release M&A lists, `BuiltWith Relationships`, app-store publisher pages.

**1b. Outbound-link crawl of the org's KNOWN portals.** An org's official site
links to its own campaign sites ("報名請點這裡 → event.vendor.com.tw").
- `curl -sL <portal> | grep -oiE 'https?://[a-z0-9._-]+'` → strip to host →
  drop own-domain + CDN/analytics/social noise. `katana -jc -do` for depth.
- Grep the raw HTML; do **not** hand a big page to an LLM summarizer (it truncates).
- Bonus: the resulting non-own-domain link list **is** the "external-link review" deliverable.

### Tier 2 — content attribution (search engines)

Search the *content signature*, not just the name. Use **Google and Bing** (different indexes) and source-code search engines:
- `"指導單位:<Org>"`, `"主辦單位:<Org>"`, `"承辦單位"` `-site:gov.tw -site:edu.tw`
- Footer/copyright: `"© <Org>" "版權所有"`
- Contact pivots: main phone prefix, street address, staff email domain
- `<sub-unit / school name> site:.com.tw OR site:.com OR site:.org`
- **PublicWWW / NerdyData** — search page *source* for the copyright string or a
  shared GA/GTM ID; surfaces sites Google's SERP won't.

### Tier 3 — infrastructure pivots (catch what content search misses)

- **Favicon mmh3 hash** (FOFA / Shodan `http.favicon.hash:` / ZoomEye) — a shared
  template favicon groups siblings across arbitrary domains/IPs. FOFA is strong for TW.
- **Analytics/Tag-ID pivot** — one GA (`UA-`/`G-`), GTM, or AdSense ID reused by a
  vendor across microsites → BuiltWith / SpyOnWeb / DNSlytics / PublicWWW reverse-lookup.
- **crt.sh** — expand a *confirmed* off-domain to its full SAN set to find its
  siblings (`?q=<regdomain>&output=json`). NB: `?q=%<cityname>%` is **too noisy**
  (the city name is in every local cert) — use crt.sh to *confirm/expand*, not to discover.
- **Reverse WHOIS** — registrant = the org's name / email / address (ViewDNS,
  WhoisXML, DomainTools). Catches bare domains registered by the org.
- **Passive DNS / scan corpora** — SecurityTrails, Netlas, FOFA/ZoomEye full-text body search for the org name.
- **Wayback CDX** — historical outbound links from the known estate; catches
  *already-dead* campaign sites = the actual dangling-domain risk.

### Tier 4 — social footprints

FB / IG / LINE official account / YouTube for the org's campaigns → bio/about
links to the microsite. Not domains themselves, but signposts to them.

---

## Attribution confidence + de-scope (the load-bearing step)

Tag every candidate:
- **HIGH** — named in a procurement record / linked from an official page / whois registrant = the org.
- **MED** — copyright/footer + a matching contact pivot (phone, address, email domain).
- **LOW** — merely mentions the org or place → manual-review queue, **do not list**.

**De-scope per owner.** Inventories are per-entity. A tourism site sitting next
to an education site belongs to a *different* agency; a central-ministry liaison
office is not the city bureau. Say who owns each asset; only HIGH/MED ship.

---

## Risk enrichment — why a security team adds value beyond a flat list

The inventory is just names until you attach the risk the mandate actually fears
("防範閒置網域遭惡意使用"). Per asset:
- **Dangling CNAME** → subdomain takeover — pipe into `/takeover` (`tools/takeover_scanner.sh`).
- **whois expiry ≤ ~1yr** → re-registration hijack once the org stops renewing.
- **Vendor-tenant subdomain** (e.g. `<org>.<saas>.tw`) → reverts to the vendor at contract end.
- **No HTTPS / abandoned CMS / known-CVE stack** → direct compromise.

This turns a compliance checkbox into real attack-surface reduction.

---

## Deliverable mapping

**BB:** confirmed sibling domains → run `/scope` on each (is it in program scope?)
→ feed in-scope ones to `/recon` as fresh targets.

**TW gov 委外活動網站 盤點表** columns → how to fill:
| 機關名稱 | 委外活動網站(名稱/網域) | 是否繼續使用 | 公告/轉址≥1年 | 是否完成移轉 | 預計移轉日 | *(加值)* 資安風險 |
|---|---|---|---|---|---|---|
| owning unit | name + off-domain (+confidence) | httpx live probe | manual/wayback | 承辦回填 | 承辦回填 | expiry / CNAME / no-HTTPS |

Ship `outbound_hosts.txt` alongside as the "external-link review" evidence.

---

## Workflow

```
/attribute --tw-gov --org "<Org>" --recon recon/<t> \
   --own-domain <apex> --unit-match '<buyer regex>'
```
`tools/asset_attribution.sh` runs Tier-1 outbound crawl + procurement, Tier-3
crt.sh, and enrich/risk automatically → `findings/attribution/<ts>/candidates.tsv`.
Tier-2 content dorks, favicon/GA-ID/reverse-whois pivots are **manual or
key-gated** (FOFA/Shodan/PublicWWW/WhoisXML accounts) — the skill lists them;
wire keys before automating.

Then, by hand: attribute + de-scope each row, resolve procurement leads to
domains, and pipe dangling/near-expiry hosts to `/takeover`.

---

## Worked example — 臺南市政府教育局 (2026-07-03, validated)

Seeds = bureau portals on `tn.edu.tw`; exclude `tn.edu.tw` + `tainan.gov.tw`.
- **Outbound crawl** → `tainanelo.tw` (教育部臺南市聯絡處/校外會; `.tw` expiry 2027-06-06 → re-reg risk), `twtainan.net` (台南旅遊網 → **de-scoped to 觀光局**), a `sites.google.com` school microsite.
- **Procurement** → `臺南400全民教育活動網站` which resolved to `tedu400.tn.edu.tw` — **on the edu domain = compliant**, a correct negative (proves the method separates compliant from not).
- **Cross-source** → `tainan.cloudhr.tw` (臺南市立學校差勤系統 on a commercial HR-SaaS; live IIS) confirmed via both crt.sh and search.

Round 2 (crawl expanded to **291 school portals**, procurement to per-unit `listbyunit`):
- Crawl → **532 off-domain hosts → ~120 real school assets** (67 vendor-hosted: `teamslite.com.tw`×21, `ailead365.com`×12, `uschoolnet.com`, `eduweb.com.tw`; 48 free-SaaS: `canva.site`×11, `blogspot`×22, `weebly`, `wixsite`, `github.io`; 5 personal `idv.tw` incl. a JHS timetable), **32 HIGH-attribution** by school code (`*jhtn`/`*estn`). 412 third-party tools correctly de-scoped.
- Procurement (per-unit, all-pages) → rate-limited + **all infrastructure, 0 activity sites** → confirmed crawl ≫ procurement for a school-district long tail.

Lessons that shaped the tool: outbound-crawl is the highest-signal automatable
pillar (and scales — parallelize it); `crt.sh %tainan%` was noise; `.tw` whois
hides registrant but exposes expiry (the risk signal); attribution/de-scope is
mandatory (tourism vs education vs central-ministry); vendor-domain clustering
(same school codes across teamslite+ailead365) means you can盤點 by *vendor*, not
just by site. Full dossier: `recon/tn.edu.tw/attribution/DOSSIER.md`.
