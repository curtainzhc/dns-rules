#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""GitHub Actions 专用：拉取原项目 -> 合并去重 -> 裁剪50万 -> 写入 data/。
GitHub runner 在境外，raw.githubusercontent.com 直连即可，无需代理。"""
import os, re, json, time, urllib.request, concurrent.futures

BASE = os.path.dirname(os.path.abspath(__file__))
RAW = os.path.join(BASE, "data", "raw")
DATA = os.path.join(BASE, "data")
TARGET = None          # None = 不裁剪，输出全部去重规则
BUILD_TO = None
SKIP_NUMS = {"15"}       # gitcode WAF 拦截页
SPECIAL_NUMS = {"18"}    # 斜杠分隔聚合格式

CAT = {
    "24":"设备原生广告","25":"设备原生广告","26":"设备原生广告","27":"设备原生广告",
    "28":"设备原生广告","29":"设备原生广告","30":"设备原生广告","31":"设备原生广告",
    "32":"设备原生广告","33":"设备原生广告","34":"设备原生广告","22":"动态DNS/威胁",
    "05":"国内广告","12":"国内广告","13":"国内广告","11":"国内广告","14":"国内广告",
    "16":"国内广告","08":"国际广告/隐私","09":"国内广告","17":"国内广告","03":"国内广告",
    "10":"隐私追踪","06":"国内广告","01":"国内广告","21":"威胁情报","19":"国内广告",
    "04":"国内广告","20":"威胁情报","23":"赌博/成人","18":"综合hosts",
}
CAP = {}               # 不限制单源，全部保留
ORDER = ["24","25","26","27","28","29","30","31","32","33","34","22",
         "05","12","13","11","14","16","08","09","17","03","10","06","01",
         "21","19","04","20","23","18"]

os.makedirs(RAW, exist_ok=True)

def load_urls():
    items = {}
    with open(os.path.join(BASE, "urls.txt"), encoding="utf-8") as f:
        for line in f:
            line = line.strip()
            if line and not line.startswith("#"):
                num, name, url = line.split("|", 2)
                items[num] = (name, url)
    return items

def _try_url(u, timeout=40):
    """尝试单个 URL，成功返回 bytes，失败返回 None。"""
    try:
        req = urllib.request.Request(u, headers={"User-Agent": "Mozilla/5.0"})
        with urllib.request.urlopen(req, timeout=timeout) as resp:
            data = resp.read()
        head = data[:300].decode("utf-8", "ignore").lower()
        if "<!doctype" in head or "<html" in head or "访问被拦截" in data[:500].decode("utf-8", "ignore"):
            return None
        return data
    except Exception:
        return None

def fetch_one(num, name, url):
    """拉取单源：直连与代理候选并行竞速，谁先成功用谁；全失败则沿用旧缓存。"""
    out = os.path.join(RAW, f"{num}_{name}.txt")
    candidates = [url]
    if "github.com" in url:
        candidates += ["https://gh-proxy.com/" + url,
                       "https://ghfast.top/" + url.replace("https://", "")]
    # 所有候选并行发起，取第一个成功
    with concurrent.futures.ThreadPoolExecutor(max_workers=len(candidates)) as ex:
        futs = [ex.submit(_try_url, u) for u in candidates]
        for fut in concurrent.futures.as_completed(futs):
            data = fut.result()
            if data:
                with open(out, "wb") as f:
                    f.write(data)
                return num, True, len(data)
                # 注意：不 cancel 其他 future，让线程自然结束
    if os.path.exists(out) and os.path.getsize(out) > 0:
        return num, False, -os.path.getsize(out)   # 沿用上次缓存
    return num, False, 0

def fetch_all():
    items = load_urls()
    tasks = [(n, name, url) for n, (name, url) in items.items() if n not in SKIP_NUMS]
    results = []
    # 33 个源并发；每个源内部再并发候选，整体耗时≈最慢单源
    with concurrent.futures.ThreadPoolExecutor(max_workers=12) as ex:
        futs = [ex.submit(fetch_one, *t) for t in tasks]
        for fut in concurrent.futures.as_completed(futs):
            r = fut.result()
            results.append(r)
            tag = "OK" if r[1] else ("旧缓存" if r[2] < 0 else "失败")
            print(f"  [{r[0]}] {tag} {r[2]}", flush=True)
    return sorted(results), items

def convert_special(num, name):
    path = os.path.join(RAW, f"{num}_{name}.txt")
    if not os.path.exists(path):
        return 0
    s = open(path, encoding="utf-8", errors="ignore").read()
    pat = re.compile(r'^[0-9a-zA-Z]([0-9a-zA-Z\-._]*[0-9a-zA-Z])?$')
    seen, out = set(), []
    for x in s.split("/"):
        d = x.strip().lower().rstrip(".")
        if "." in d and " " not in d and ":" not in d and "[" not in d and "]" not in d and pat.match(d):
            if d not in seen:
                seen.add(d); out.append(f"0.0.0.0 {d}")
    with open(path, "w", encoding="utf-8") as f:
        f.write("\n".join(out) + "\n")
    return len(out)

re_hosts = re.compile(r'^(?:0\.0\.0\.0|127\.0\.0\.1|::1?)\s+(.+)$', re.I)
re_clean = re.compile(r'^[0-9a-zA-Z]([0-9a-zA-Z\-._]*[0-9a-zA-Z])?$')
SKIP_DOM = {"localhost","localhost.localdomain","broadcasthost","ip6-localhost","ip6-loopback","local"}

def norm(d): return d.strip().lower().rstrip(".")
def valid(d): return "." in d and "*" not in d and re_clean.match(d) is not None

def atomic_write(path, content):
    tmp = path + ".tmp"
    with open(tmp, "w", encoding="utf-8") as f:
        f.write(content)
    os.replace(tmp, path)

def build():
    items = load_urls()
    allow_set, allow_wild = set(), []
    for num in ("02", "07"):
        name = items.get(num, (str(num),))[0]
        p = os.path.join(RAW, f"{num}_{name}.txt")
        if not os.path.exists(p):
            continue
        for line in open(p, encoding="utf-8", errors="ignore"):
            s = line.strip()
            if not s or s.startswith(("!", "#")) or "##" in s or not s.startswith("@@"):
                continue
            core = s[2:].replace("‖", "||")
            m = re_hosts.match(core)
            if m:
                for raw_d in m.group(1).split():
                    d = norm(raw_d)
                    if valid(d): allow_set.add(d)
                continue
            if core.startswith("||"):
                c = core[2:].split("^")[0].split("/")[0]
                if "*" in c: allow_wild.append(s)
                else:
                    d = norm(c)
                    if valid(d): allow_set.add(d)

    def has_allowed_parent(d):
        parts = d.split(".")
        for i in range(1, len(parts) - 1):
            if ".".join(parts[i:]) in allow_set:
                return True
        return False

    cand = {}
    per_src = {}
    def add(d, outfmt, cat):
        if d in cand or d in allow_set or has_allowed_parent(d):
            return False
        cand[d] = (outfmt, cat)
        return True

    for num in ORDER:
        if num in SKIP_NUMS or num not in items:
            continue
        name = items[num][0]
        p = os.path.join(RAW, f"{num}_{name}.txt")
        if not os.path.exists(p):
            per_src[num] = 0
            continue
        added = 0
        with open(p, encoding="utf-8", errors="ignore") as fh:
            for line in fh:
                s = line.strip()
                if not s or s.startswith(("!", "#", "[")) or "##" in s:
                    continue
                body = s.replace("‖", "||")
                if body.startswith("@@"):
                    continue
                cat = CAT.get(num, "其他")
                m = re_hosts.match(body)
                if m:
                    for raw_d in m.group(1).split():
                        d = norm(raw_d)
                        if d in SKIP_DOM or not valid(d):
                            continue
                        if add(d, f"0.0.0.0 {d}", cat): added += 1
                    continue
                if body.startswith("||"):
                    core = body[2:]
                    if "$" in core or "/" in core or "*" in core:
                        continue
                    d = norm(core.split("^")[0].split("$")[0].split("/")[0])
                    if valid(d) and add(d, f"||{d}^", cat): added += 1
                    continue
                d = norm(body)
                if valid(d) and add(d, f"0.0.0.0 {d}", cat): added += 1
        per_src[num] = added

    net_domains = {d for d, (v, _) in cand.items() if v.startswith("||")}
    removed = 0
    for d in list(cand):
        if not cand[d][0].startswith("0.0.0.0 "):
            continue
        parts = d.split(".")
        for i in range(1, len(parts)):
            if ".".join(parts[i:]) in net_domains:
                del cand[d]; removed += 1; break

    final_items = list(cand.items())
    final_rules = sorted(v for d, (v, _) in final_items)
    cat_count = {}
    for d, (v, c) in final_items:
        cat_count[c] = cat_count.get(c, 0) + 1

    ts = time.strftime("%Y-%m-%d %H:%M:%S UTC", time.gmtime())
    rule_text = (f"! 自动更新订阅规则 | 更新于 {ts}\n"
                 f"! 共 {len(final_rules):,} 条 | 源项目合并去重裁剪\n"
                 + "=" * 60 + "\n\n" + "\n".join(final_rules) + "\n")
    allow_text = (f"! 放行白名单 | 与拦截规则一并导入，优先级最高\n"
                  f"! 纯域名 {len(allow_set)} + 通配符 {len(allow_wild)}\n"
                  + "=" * 60 + "\n\n"
                  + "\n".join(f"@@||{d}^" for d in sorted(allow_set)) + "\n"
                  + "\n".join(sorted(allow_wild)) + "\n")
    atomic_write(os.path.join(DATA, "rules.txt"), rule_text)
    atomic_write(os.path.join(DATA, "allow.txt"), allow_text)
    meta = {"updated_at": ts, "updated_ts": int(time.time()), "total": len(final_rules),
            "allow": len(allow_set) + len(allow_wild), "removed_sub": removed,
            "cat": cat_count, "per_src": per_src}
    atomic_write(os.path.join(DATA, "meta.json"), json.dumps(meta, ensure_ascii=False, indent=2))
    return meta

if __name__ == "__main__":
    t0 = time.time()
    fetch_res, items = fetch_all()
    ok = sum(1 for n, s, b in fetch_res if s)
    for num in SPECIAL_NUMS:
        name = items.get(num, (str(num),))[0]
        print(f"  [{num}] {name} 转换 {convert_special(num, name)} 条", flush=True)
    meta = build()
    print(f"更新完成: 源 {ok}/{len(fetch_res)} 成功, 规则 {meta['total']:,}, 耗时 {time.time()-t0:.0f}s", flush=True)
