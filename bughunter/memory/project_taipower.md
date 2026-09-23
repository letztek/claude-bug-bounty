---
name: project-taipower
description: taipower.com.tw bug bounty hunt — findings, dead ends, and next steps (updated 2026-06-03)
metadata:
  type: project
---

# taipower.com.tw Hunt

## greennet member-API DEEP HUNT (2026-06-15) — surface largely hardened
- **member-info: NO IDOR** — page is server-rendered (only XHR = zipcode.json); no JSON data-load endpoint, no id param.
- **Mass-assignment: value dropped post-CSRF-fix** (self-service only now); form exposes no privileged hidden fields (only __RequestVerificationToken, ROCBirthYear, City, District). IsTaipowerStaff is self-selectable at /register by DESIGN (身份別 radio 台電員工/其他) — so original IsTaipowerStaff finding was only valid as the cross-user CSRF flip (now fixed).
- **SMS OTP flow (member-send-sms / member-verify-sms): SECURE on high-sev axes** — send-sms response does NOT leak OTP (data:null); wrong verify → "驗證失敗，請重新發送" (invalidates OTP, 1 guess each); send-sms takes no Mobile param (no arbitrary-number bombing). Endpoints now CSRF-token gated.
- **Legacy greennet.taipower.com.tw (.aspx _FourInOne/Page_Theme id= IDOR candidates): DEAD** — resolves 203.74.176.24/177.24 (in-scope IPs) but 443/80 don't respond → internal-only, not publicly served. idor-candidates.txt entries were historical crawl data.
- **UNTESTED high-value leads (need side-effects / hunter action):** (B) /member-register hidden fields IsThirdResgister/LoginProvider/ThirdValue → possible third-party-registration pre-ATO (needs a captcha-gated test registration; Claude can't create accounts). (C) /member-reset-password: UserName readonly + validation skips it → reset identity likely on a token; if token not account-bound → horizontal ATO (needs triggering a reset email + inspecting token).
- Taipower clearly did a security pass on greennet (state validation, anti-forgery tokens, SameSite=Lax, bind whitelist, OTP no-leak).

## RETEST (2026-06-15) — both submitted greennet reports CONFIRMED FIXED
- **Report 1 Google OAuth CSRF (`/greennet/signin-google`): FIXED.** Defect1: client `state` now per-session 256-bit hex (was hardcoded `pass-through value`), bound to fresh `.AspNetCore.Session`. Defect2: server validates `state` — same-session matching state → 200 (proceeds); mismatched/empty → 302 `/login` (was: any state → 302 `/myaccount` = success). Session cookie now `Secure;HttpOnly;SameSite=Lax`.
- **Report 2 `member-update-info` CSRF+mass-assign: FIXED.** Defect A: POST w/ valid token + `IsTaipowerStaff=1` → `succeeded:true` BUT reload shows still `0` (field dropped from binding / `[Bind]` whitelist). Defect B: form now has `__RequestVerificationToken`; authed POST w/o token → 400 (was `succeeded:true`).
- Tested via Claude-in-Chrome on user's own logged-in session; no account data altered. Retest report: findings/taipower.com.tw/RETEST_greennet_2026-06-15.md
- NOTE: greennet account fields (name/Mobile/email) are server-MASKED in DOM (`T******e`), server ignores masked values on save; `member-update-info` save = `$('#personal-info-form').serialize()` (urlencoded, token auto-included).


**Why:** HITCON ZeroDay bug bounty (2026-04-01 to 2026-06-30). NT$200萬 prize pool. Scope: domain taipower.com.tw, 203.74.176.0/24, 203.74.177.0/24, 203.75.48.0/24, 203.66.37.0/24. Submit to bugbounty@taipower.com.tw in Word format.

**How to apply:** Report to SESSION.md in recon/ for full context. File findings in findings/taipower.com.tw/\<category\>/BUG-NNN.md.

## Confirmed Findings

| Bug | File | Status | Severity |
|---|---|---|---|
| BUG-001: CCMS email OTP flood (no rate limit) | findings/.../SESSION.md | Documented | Medium |
| BUG-002: CCMS OTP brute force → CCTV access | findings/.../SESSION.md | Documented | High |
| BUG-005: HVCS ResetPassword SQL error disclosure | findings/.../misconfig/BUG-005 | On hold | Medium |
| BUG-006: Greennet Google OAuth CSRF → session hijack | findings/.../auth_bypass/BUG-006 | Ready to submit | Medium |
| BUG-007: ETP+ERCM CORS reflection + Credentials | findings/.../cors/BUG-007 | Ready to submit | Medium (6.8) |
| BUG-008: Hardcoded internal IPs in public JS bundles | findings/.../exposure/BUG-008 | Documented | Low/Medium |

## New Findings (2026-05-31): mobilesignin.taipower.com.tw

**Architecture:** mobilesignin:443 = IIS proxy → service.taipower.com.tw/mobilesignin/ (real ASP.NET WebAPI app). mobilesignin:80 = HTTP 307 redirect to service.taipower.com.tw/mobilesignin/*

**BUG-015 (candidate): ASP.NET WebAPI Help Page Exposed — no auth**
- URL: `https://service.taipower.com.tw/mobilesignin/Help`
- Exposes all 35+ endpoint names, HTTP methods, full parameter schemas (AttendEmpNo, StudentIdentNo, StudentCellPhone, LineUserID)
- XML namespace leaks: `http://schemas.datacontract.org/2004/07/TWPowerAPI.Models`
- This is a Taiwan Power employee attendance/check-in system (not a customer-facing app)
- Severity: LOW-MEDIUM

**BUG-016 (candidate): Internal backend URL disclosure in JSON 404 errors**
- GET `https://mobilesignin.taipower.com.tw/api/v1` → `{"Message":"找不到與要求 URI 'https://service.taipower.com.tw/mobilesignin/api/v1' 相符的 HTTP 資源。"}`
- Leaks service.taipower.com.tw as the backend (was in "dead ends" — actually accessible!)
- Severity: INFO/LOW

**BUG-017 (candidate): Default ValuesController deployed to production**
- `GET https://service.taipower.com.tw/mobilesignin/api/Values` → `["value1","value2"]`
- Leftover scaffolding code from ASP.NET WebAPI template in production
- Severity: LOW

**Auth token required for all TWPowerAPI endpoints** — "AuthToken驗證有誤" blocks access. Response format: `{"ApiStatus":bool,"Message":str,"ResultData":data}`. WRITE endpoints exist (CreateStudentInfo, CreateUserAuth, AddCheckIn, UpdaUserType, RemoveLineID) — worth re-testing if AuthToken obtained.

**LINE Bot webhooks** accept unauthenticated POST:
- `POST /mobilesignin/line/api/TWPowerCheckIn` → 200 OK
- `POST /mobilesignin/api/LineBot` → 200 OK

## Dead Ends

- service.taipower.com.tw: under maintenance as of 2026-05-25 (except /Exam/DownloadFile.aspx which serves public PDFs — intended); /mobilesignin/ sub-app IS accessible (see above)
- SSL VPN: CVE-2024-24919 not vulnerable
- GMS, nbmi, elearning, phpBB hosts: no connectivity from public IP
- tpcm-cctv: admin-only system (no contractor registration)
- ETP captcha bypass: not achieved (session-bound properly)
- ERCM /ercmapi/ backend path: same auth, different nginx prefix

## Architecture Notes

- ETP (etp.taipower.com.tw): Spring Boot + React, API at /api, ASAPI backend at 59.120.103.216:8181
- ERCM (ercm.taipower.com.tw): Spring Boot + React, API at /api (proxied from /ercmapi/ backend), download backend at 59.127.248.71:8383
- CCMS-CCTV (ccms-cctv.taipower.com.tw): Laravel PHP + Vue.js, API routes without /api prefix
- TPCM-CCTV (tpcm-cctv.taipower.com.tw): Same codebase as CCMS but admin-only (no contractor reg)
- service.taipower.com.tw: IIS/.NET aggregator for greennet, hvcs, ebpps2, csms

## Session 3 (2026-06-03) — New Findings

**BUG-018: MyHR 無驗證碼 + 帳號列舉**
- URL: `https://service.taipower.com.tw/hrstatistics/Login/SignIn`
- NO CAPTCHA on login form
- Account enumeration: "帳號或密碼錯誤" (not exist) vs "Server Error" (exists)
- Confirmed existing: admin, test, guest, root, hr, demo, 00001, A0001
- No rate limiting
- 5 HR systems share SSO: hrstatistics, ei/LTRWD, EI/PARWD, hrmap (SignIn + SignInlr)
- Severity: HIGH

**etp-practice.taipower.com.tw — Captcha Bypass + Account Enumeration**
- `IsPracticeArea` flag skips captcha on practice environment (server-side confirmed)
- Prod requires captcha, practice doesn't
- Login fields: userAccount, userPassword, captchaCode, companyId, plantCname
- Admin login fields: userUid, userPwd, captchaCode
- Same CORS reflection as prod (BUG-007)
- CORS headers leak auth scheme: userId, token, Authorization, Module-Name headers
- Status: holding — need weak password test to prove test/prod not properly isolated

**mobilesignin (台電員工行動打卡系統)**
- Help page still exposed: 35+ endpoints with PII schemas
- LINE Bot endpoints accept unauthenticated POST but return empty body (likely non-functional)
- System is attendance/check-in, not really a LINE Bot
- AuthToken required for all functional endpoints; no bypass found
- NullReferenceException disclosure on missing params

**Newly discovered internal HR systems on service.taipower.com.tw:**
- `/hrstatistics/` — MyHR 行動人資 (ASP.NET Core)
- `/ei/LTRWD/Login` — 行動假單 (ASP.NET WebForms, has captcha, MD5_BASE64 password)
- `/EI/PARWD/Login` — 行動加班通報 (ASP.NET WebForms, has captcha)
- `/hrmap/Login/SignIn` — 員工權益 (ASP.NET Core)
- `/hrmap/Login/SignInlr` — 人資法遵專區 (ASP.NET Core)

## Dead Ends (Session 3)

- eecms.taipower.com.tw: IIS 403, X-Original-URL returns 200 empty (not real bypass)
- dr.taipower.com.tw: AWS WAF JS challenge → infinite redirect loop; /admin 403 WAF deny
- SmartRobot chatbot port 4433: unreachable
- FilesDownload.ashx: service.taipower.com.tw now behind nginx, 404
- LINE Bot send-message: 200 empty, likely non-functional (channel token expired?)

## Session 3 continued — BUG-019 (CRITICAL)

**BUG-019: 甄試報名系統弱密碼 + PII 洩露**
- URL: `https://service.taipower.com.tw/recruit-reg3/recruit115/`
- Forgot password: no CAPTCHA, leaks email + 報名序號 on ID+birthday match
- Login: no CAPTCHA, no rate limit, no lockout
- Account 00061 cracked with password `123456` (test data: 黃小明/A123456789)
- Login後**密碼明文顯示**在頁面上
- 可存取完整 PII: 姓名、身分證、生日、性別、學歷
- 可「修正報名資料」→ 竄改考生資訊
- 還需探索: IDOR on other 報名序號, file upload, SQL injection on search

## Session 3 deep hunt results (2026-06-04)

**Confirmed additional findings on recruit system:**
- BUG-020: XSS on examNotify subscribe.php — name field injected into JS confirm()
  - Payload: `x'),alert(document.domain),confirm('` — alert(document.domain) DID fire (browser-confirmed)
  - **DOWNGRADED**: csrf_token is enforced + session-bound (tested: no-token/fake-token/cross-session all rejected "網頁已過期")
  - → Reflected part = Self-XSS, NOT cross-user exploitable, NOT reportable alone
  - → Stored-XSS-on-admin = data persists to writeData.php BUT admin render UNCONFIRMED (no admin access)
  - Verdict: informational only unless admin panel unsafe-render proven
- BUG-021: modRegAlready.php → revuRegAlready.php has NO CSRF token
- Password complexity not enforced retroactively (123456 = 6 chars, rule says 8+)
- Exam system WebService has 20+ endpoints but all auth-protected (302 to 500.aspx)
- GetFileByKeyNoneUser.aspx only serves public Announce files (DataKey is hashed)

**Dead ends (Session 3 deep hunt):**
- SQLi: NOT exploitable — parameterized queries confirmed across all endpoints
- File upload: Not found (registration period closed)
- IDOR: Session-based, no user ID in URLs
- LFI via loginTo: Just a redirect path, not file inclusion
- SSTI: Not vulnerable ({{7*7}} returned as-is)
- exam114: Different system, same 「核對不符」for all passwords
- d079-fund: SSO-protected, captcha bypass doesn't help
- psvs1/outageweb: No XSS or injection found

## Broad surface sweep (2026-06-04) — all dead ends

- **info/tc** search (電協金核定案件, ASP.NET WebForms tbKey1/tbKey2): no reflection, no SQLi
- **collection** (文物典藏): search = Google CSE; WAF blocks quote/SQL→`~/xss.html`, but angle brackets pass yet reflect in safe context. Not exploitable.
- **hvcs** CheckCertID: param name is `s` (leaked via exception) but always "系統維護中" + null exception = maintenance mode, BUG-013 only. ResetPassword = master-account only.
- **csms** /api/gettoken = 403 (FAQ JS stale); other /api/* = 404
- **tpcjournal** (台電月刊 e-magazine SPA): /api/Config/env + /api/public/* unauth but only public store config/ebooks (no secrets). Biz* (BizAccount/BizUser/Merchants) are FRONTEND router paths → SPA HTML; real admin API behind auth (/api/User=401)
- **etp-practice** account enum: company login needs real 統編 (can't enumerate without valid pairs); admin login (userUid) = uniform "登入失敗" (no enum)
- **ebpps2**: 503 down; **smartgrid** trace.axd/web.config = 200 but 0 bytes (handler-blocked)
- **d079-fund**: SSO-walled; **Exam/WebService/** 20+ endpoints all 302→500.aspx (auth)

## CONCLUSION: external attack surface comprehensively covered
Most high-value systems are auth-walled, in maintenance, or internal-only.

## Reportable inventory (confirmed)
- BUG-007 CORS (etp/ercm) — SUBMITTED
- BUG-006/011 (greennet OAuth CSRF + mass assignment) — SUBMITTED
- BUG-011/012 — SUBMITTED
- etp-practice captcha bypass + same CORS as prod (Low-Med, clean)
- hcweb/geohc unauth GIS API + CORS reflection (Low-Med)
- recruit115 systemic auth weakness: no rate-limit/CAPTCHA/lockout + plaintext pw display + forgot-pw PII leak (Medium, honeypot-demonstrated)
- BUG-008/013/015/016 info disclosure (Low)

## BUG-022 — Recruit login Open Redirect (filter bypass) — CONFIRMED (2026-06-04)
- `loginTo` param in recruit115 login → `header("Location: <loginTo>")` after successful login
- Filter blocks `//`, `://`, `\\` BUT bypass: `http:evil.com` (different scheme + no slashes)
- WHATWG URL parser resolves `http:evil.com` to host=evil.com (https base + http payload)
- `loginTo` auto-filled from `login.php?loginTo=` URL query → single malicious link
- Browser-verified end-to-end: login.php?loginTo=http:example.com → after login lands on http://example.com/ (screenshot saved)
- **Does NOT depend on honeypot** — works with any valid account (victim's own)
- Severity: Low-Med (CWE-601, post-auth phishing). File: findings/.../redirects/BUG-022_*.md
- Traversal on load_image.php: NO param (session-based), no vector. loginTo = redirect not include (no LFI).

## taipowerdsm DSM TOU calculator (2026-06-20) — HARDENED, near-clean
- **App:** 簡易型時間電價試算評估 — public stateless time-of-use tariff calculator. Spring Boot/MVC behind service.taipower.com.tw/taipowerdsm/ (taipowerdsm.taipower.com.tw:80 = 307 facade). Imperva WAF fronts service host.
- **Hardening confirmed:** strong sec headers (HSTS/XFO DENY/nosniff/XSS); DSM_SESSION Secure+HttpOnly+SameSite=Lax; CSRF enforced (Spring _csrf token; token-less POST → Imperva "Request Rejected" support-ID page); valid-token POST → 302 PRG, server-side compute (預估電費 元/年).
- **NO PII / NO IDOR:** customerNumber input is discarded (not echoed, not re-populated, no customer lookup); result = 3 tariff plans (非時間/二段式/三段式) computed server-side; no reflection of any input (HTML-inj surface absent).
- **★ Only finding: `POST /taipowerdsm/validate-customer-number` {custno,_csrf} = 電號 validation oracle.** 3-state text/plain response: `請檢查電號格式`(checksum-invalid) / not-success→JS alerts 請檢查輸入電號是否正確 (format-valid-nonexistent) / `電號檢核成功`(valid+exists). Potential account-number enumeration BUT: CSRF-token gated, returns boolean string only (NO PII/JSON, 21 bytes), needs checksum-valid 電號 to separate exists vs nonexistent. Did NOT enumerate real accounts (ROE). Severity LOW (info/enum at most).
- Static JS (customize/script.min): no internal IPs, no secrets, no API keys. Tomcat edge (taipowerdsm:443) = hardened dead-end (431-byte 404 everywhere, manager not deployed).

## Next Steps
1. Package findings into reports (BUG-022 open redirect is cleanest/non-honeypot)
2. Test if other recruit-family systems (exam114) share the loginTo open redirect
3. External taipower surface largely exhausted
