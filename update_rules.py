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
LITE_TOTAL = 499998    # 精简版纯拦截条数（50 万上限减 2 条，规避订阅 App 的 50 万硬上限）
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
    "41":"综合hosts",
}
CAP = {}               # 不限制单源，全部保留
ORDER = ["24","25","26","27","28","29","30","31","32","33","34","22",
         "05","12","13","11","14","16","08","09","17","03","10","06","01",
         "21","19","04","20","23","18",
         "41"]   # 41 trli-Pro 超大全球黑名单（1134万），放最后：先到的源优先归属，避免抢占高价值源

# ===== 精简版价值分级（数字越小越优先保留）=====
# 1 = 日常必用：国内广告 / 设备原生广告 / 主流隐私
# 2 = 安全刚需：钓鱼 / 诈骗 / 恶意托管 / 防DoH绕路 / 动态DNS威胁
# 3 = 补充拦截：威胁情报TIF / 国际广告隐私 / 综合hosts
# 99 = 日常用不上：赌博成人 / 冷门聚合 —— 精简版剔除
LITE_VALUE = {
    # 1 国内广告 + 设备原生 + 主流隐私
    "01":1,"03":1,"04":1,"05":1,"06":1,"09":1,"11":1,"12":1,"13":1,"14":1,
    "16":1,"17":1,"19":1,"24":1,"25":1,"26":1,"27":1,"28":1,"29":1,"30":1,
    "31":1,"32":1,"33":1,"34":1,"10":1,
    # 2 安全刚需（含新加的钓鱼/Fake/Hoster/DoH绕过）
    "37":2,"39":2,"40":2,"35":2,"20":2,"22":2,
    # 3 补充
    "21":3,"08":3,"36":3,"38":3,"18":3,"41":3,
    # 99 精简版剔除
    "23":99,
}
LITE_EXCLUDE = {"23"}  # 赌博成人——日常用不上，精简版直接剔除

# 白名单里的广告/统计类顶级父域必须剔除：
# 这类父域会把旗下所有广告子域(google-analytics/doubleclick/facebook pixel 等)
# 一并放行，导致 AdGuard Home 实测大量广告漏拦。具体子域白名单仍保留，防误杀。
ALLOW_BAD_ROOTS = {
    "2o7.net","googlesyndication.com","googleadservices.com","doubleclick.net","google.com",
    "facebook.com","ads-twitter.com","twitter.com","linkedin.com","pinterest.com","reddit.com",
    "redditmedia.com","youtube.com","tiktok.com","yahoo.com","yandex.ru","hotjar.com","bugsnag.com",
    "amazonaws.com","apple.com","icloud.com","mzstatic.com","samsung.com","miui.com","wp.com",
    # 这几个虽是精确条目而非父域，但同属主流统计/追踪，放行会让测试与实测漏拦
    "google-analytics.com","ssl.google-analytics.com","metrics.icloud.com","metrics.mzstatic.com",
}

# 精简版必保：主流广告/统计/追踪域（测试站与实测高频命中），价值级 0 排最前
LITE_MUST = {
    "google-analytics.com","ssl.google-analytics.com","analytics.google.com",
    "adservice.google.com","pagead2.googlesyndication.com","pagead2.googleadservices.com",
    "afs.googlesyndication.com","stats.g.doubleclick.net","ad.doubleclick.net",
    "static.doubleclick.net","m.doubleclick.net","mediavisor.doubleclick.net",
    "pixel.facebook.com","an.facebook.com","ads-api.twitter.com","static.ads-twitter.com",
    "ads.linkedin.com","ads.pinterest.com","log.pinterest.com","trk.pinterest.com",
    "ads.youtube.com","events.reddit.com","events.redditmedia.com",
    "ads.tiktok.com","analytics.tiktok.com","ads-api.tiktok.com","analytics-sg.tiktok.com",
    "bat.bing.com","stats.wp.com","analytics.yahoo.com","geo.yahoo.com","udcm.yahoo.com",
    "adm.hotjar.com","script.hotjar.com","notify.bugsnag.com","api.bugsnag.com",
    "adtago.s3.amazonaws.com","analytics.s3.amazonaws.com","analyticsengine.s3.amazonaws.com",
    "advice-ads.s3.amazonaws.com","metrics.icloud.com","metrics.mzstatic.com",
    "smetrics.samsung.com","nmetrics.samsung.com","gemini.yahoo.com",
}

# 白名单里这些主流广告/统计子域条目同样是误放行，一并剔除（与 LITE_MUST 对齐）
ALLOW_BAD_ROOTS |= LITE_MUST
ALLOW_BAD_ROOTS |= {
    "s3.amazonaws.com","analyticsengine.s3.amazonaws.com","advice-ads.s3.amazonaws.com",
    "analytics-query.yahoo.com","partnerads.ysm.yahoo.com","log.fc.yahoo.com",
    "appmetrica.yandex.ru","adfstat.yandex.ru","metrika.yandex.ru","adfox.yandex.ru",
    "events.reddit.com","ads-sg.tiktok.com","analytics-api.samsung.com",
    # 测试站复核发现的误放行：这 4 个父域/精确条目放行了主流广告统计域
    "g.doubleclick.net","media.net","sentry-cdn.com","112.2o7.net",
    "static.media.net","browser.sentry-cdn.com",
    # 主流大厂父域误放行：白名单源整片放行这些父域，导致旗下所有广告子域
    # （ad.qq.com / adnet.qq.com / 抖音广告等）被放过。剔除父域放行，
    # 旗下具体业务子域白名单仍保留，避免误杀正常功能。
    "qq.com","weixin.qq.com","baidu.com","jd.com","taobao.com",
    "bytedance.com","sogou.com","163.com","sohu.com",
}

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
            data = bytearray()
            t0 = time.time()
            while True:
                chunk = resp.read(65536)
                if not chunk:
                    break
                data.extend(chunk)
                if time.time() - t0 > timeout:
                    return None   # 慢速流整体超时，避免单个源拖死整轮更新
            data = bytes(data)
        head = data[:300].decode("utf-8", "ignore").lower()
        if "<!doctype" in head or "<html" in head or "访问被拦截" in data[:500].decode("utf-8", "ignore"):
            return None
        return data
    except Exception:
        return None

def fetch_large_range(url, out, total, parts=24, workers=12, timeout=120):
    """大文件用 HTTP Range 并行分片下载（gh-proxy 支持 206），避免慢速流整体超时。"""
    import urllib.error
    with open(out, "wb") as f:
        f.truncate(total)
    size = total // parts
    def get(i):
        s = i * size
        e = total - 1 if i == parts - 1 else (i + 1) * size - 1
        for _ in range(4):
            try:
                req = urllib.request.Request(url, headers={"Range": f"bytes={s}-{e}", "User-Agent": "Mozilla/5.0"})
                with urllib.request.urlopen(req, timeout=timeout) as resp:
                    buf = resp.read()
                if len(buf) == e - s + 1:
                    with open(out, "r+b") as f:
                        f.seek(s); f.write(buf)
                    return True
            except Exception:
                pass
        return False
    with concurrent.futures.ThreadPoolExecutor(max_workers=workers) as ex:
        ok = sum(1 for r in ex.map(get, range(parts)) if r)
    return ok == parts

def fetch_one(num, name, url):
    """拉取单源：直连与代理候选并行竞速，谁先成功用谁；全失败则沿用旧缓存。"""
    out = os.path.join(RAW, f"{num}_{name}.txt")
    # 41 trli-Pro 是 247MB 超大文件，走 Range 分片下载
    if num == "41":
        proxy = "https://gh-proxy.com/" + url
        total = 258925616
        if fetch_large_range(proxy, out, total) and os.path.getsize(out) == total:
            return num, True, total
        if os.path.exists(out) and os.path.getsize(out) > 0:
            return num, False, -os.path.getsize(out)
        return num, False, 0
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

# dnshosts-all 是 AdGuard Home 的 DNS 分流配置，域名块里混入了公共 DNS 服务器地址
# （tls://dns.google:853、https://dns.nextdns.io/dns-query 等被斜杠切碎后的 hostname）。
# 这些不是广告域名，拦截它们会导致公共 DNS 解析失败，必须剔除。
DNS_SERVER_HOSTS = {
    "dns.google","dns.google.com","1dot1dot1dot1.cloudflare-dns.com","chrome.cloudflare-dns.com",
    "edge.nextdns.io","dns.nextdns.io","anycast.dns.nextdns.io","doh3.dns.nextdns.io",
    "firefox.dns.nextdns.io","dns1.nextdns.io","dns2.nextdns.io","steering.nextdns.io","nextdns.io",
    "dns-unfiltered.adguard.com","unfiltered.adguard-dns.com","adguard-dns.com","dns.adguard.com",
    "dns12.quad9.net","alpha-dns.quad9.net","dns.quad9.net","doh.opendns.com","ordns.he.net",
    "dns.twnic.tw","common.dot.dns.yandex.net","dns.mullvad.net","doh.dns.sb","dns.sb",
}
# 兜底：这些后缀/关键词基本可判定为公共 DNS 服务端，而非广告域名
DNS_SERVER_PAT = re.compile(r'(cloudflare-dns|nextdns|adguard-dns|quad9|opendns|dns\.google|dns\.twnic|dns\.mullvad|dot\.dns\.yandex)')

def is_dns_server(d):
    return d in DNS_SERVER_HOSTS or bool(DNS_SERVER_PAT.search(d))

def convert_special(num, name):
    path = os.path.join(RAW, f"{num}_{name}.txt")
    if not os.path.exists(path):
        return 0
    s = open(path, encoding="utf-8", errors="ignore").read()
    pat = re.compile(r'^[0-9a-zA-Z]([0-9a-zA-Z\-._]*[0-9a-zA-Z])?$')
    seen, out, dropped = set(), [], 0
    for x in s.split("/"):
        d = x.strip().lower().rstrip(".")
        if "." in d and " " not in d and ":" not in d and "[" not in d and "]" not in d and pat.match(d):
            if is_dns_server(d):
                dropped += 1
                continue
            if d not in seen:
                seen.add(d); out.append(f"0.0.0.0 {d}")
    if not out:
        return 0   # 转换结果为空时不覆盖缓存，避免下载异常导致该源永久失效
    with open(path, "w", encoding="utf-8") as f:
        f.write("\n".join(out) + "\n")
    print(f"    [{num}] 剔除 {dropped} 个公共DNS服务器地址", flush=True)
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

def write_change(meta, old_meta, items):
    """对比更新前后的 meta，生成本次变更摘要 data/change.json。"""
    old = old_meta if isinstance(old_meta, dict) else {}
    def delta(key):
        nv, ov = meta.get(key, 0), old.get(key, 0)
        return nv - ov if isinstance(nv, (int, float)) and isinstance(ov, (int, float)) else 0
    ev = os.environ.get("GITHUB_EVENT_NAME", "")
    event = "定时" if ev == "schedule" else ("手动" if ev == "workflow_dispatch" else "本地")
    # 北京时间（runner 多为 UTC，这里手动 +8 避免时区误差）
    ts_bj = time.strftime("%Y-%m-%d %H:%M", time.gmtime(time.time() + 8 * 3600))
    old_ps, new_ps = old.get("per_src", {}), meta.get("per_src", {})
    src_changed = []
    for num in set(list(old_ps) + list(new_ps)):
        d = new_ps.get(num, 0) - old_ps.get(num, 0)
        if d:
            src_changed.append({"num": num, "name": items.get(num, (num,))[0],
                                "old": old_ps.get(num, 0), "new": new_ps.get(num, 0), "delta": d})
    src_changed.sort(key=lambda x: -abs(x["delta"]))
    change = {
        "time": ts_bj, "event": event, "first": not bool(old),
        "total": {"new": meta.get("total", 0), "old": old.get("total", 0), "delta": delta("total")},
        "lite": {"new": meta.get("lite_total", 0), "old": old.get("lite_total", 0), "delta": delta("lite_total")},
        "allow": {"new": meta.get("allow", 0), "old": old.get("allow", 0), "delta": delta("allow")},
        "src_changed": src_changed,
    }
    atomic_write(os.path.join(DATA, "change.json"), json.dumps(change, ensure_ascii=False, indent=2))


def append_autolog():
    """把本次变更追加一行到 AUTOLOG.md；仅在 workflow 环境（WRITE_AUTOLOG=1）执行。"""
    if os.environ.get("WRITE_AUTOLOG") != "1":
        return
    cp = os.path.join(DATA, "change.json")
    if not os.path.exists(cp):
        return
    c = json.load(open(cp, encoding="utf-8"))
    fm = lambda x: f"{x:,}"
    dl = lambda x: "±0" if x == 0 else f"{x:+,}"
    if c.get("first"):
        detail = "首次构建"
    elif c["total"]["delta"] == 0 and c["lite"]["delta"] == 0 and not c["src_changed"]:
        detail = "规则无实质变化"
    else:
        parts = [f"源{s['num']} {s['name']} {dl(s['delta'])}" for s in c["src_changed"][:8]]
        if len(c["src_changed"]) > 8:
            rest = sum(abs(s["delta"]) for s in c["src_changed"][8:])
            parts.append(f"其余{len(c['src_changed'])-8}源合计变动{fm(rest)}")
        detail = "；".join(parts) if parts else "条数微调"
    row = (f"| {c['time']} | {c['event']} | "
           f"{fm(c['total']['new'])} ({dl(c['total']['delta'])}) | "
           f"{fm(c['lite']['new'])} ({dl(c['lite']['delta'])}) | "
           f"{dl(c['allow']['delta'])} | {detail} |")
    logp = os.path.join(BASE, "AUTOLOG.md")
    if os.path.exists(logp):
        old = open(logp, encoding="utf-8").read().rstrip("\n")
    else:
        old = ("# 自动更新日志\n\n"
               "GitHub Actions 每 6 小时自动拉取、清洗、去重合并规则，本表逐条记录每次更新的实质变化。\n"
               "人工功能里程碑见 [CHANGELOG.md](CHANGELOG.md)。\n\n"
               "| 时间(北京) | 触发 | 全量条数(增减) | 精简版(增减) | 白名单增减 | 本次变化明细 |\n"
               "|---|---|---|---|---|---|")
    open(logp, "w", encoding="utf-8").write(old + "\n" + row + "\n")


def build():
    items = load_urls()
    old_meta = None
    _mp = os.path.join(DATA, "meta.json")
    if os.path.exists(_mp):
        try:
            old_meta = json.load(open(_mp, encoding="utf-8"))
        except Exception:
            old_meta = None
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

    # 剔除广告/统计类顶级父域的放行，避免旗下广告子域被整片放过
    allow_set -= ALLOW_BAD_ROOTS

    def has_allowed_parent(d):
        parts = d.split(".")
        for i in range(1, len(parts) - 1):
            if ".".join(parts[i:]) in allow_set:
                return True
        return False

    cand = {}          # d -> (outfmt, cat)
    # 内存优化：源用位掩码(int)记录，41 个源 = 41 位，每域名一个 int 而非一个 set。
    # 1134 万条 trli 域名下，set 会吃 2-3GB 直接撑爆 8GB cgroup；int 仅 ~28B/个。
    def bit(n): return 1 << int(n)
    src_mask = {}      # d -> 收录它的源位掩码
    src_of = {}        # d -> 价值最优的源编号（精简版按此排价值）
    LITE_EXCLUDE_MASK = sum(bit(n) for n in LITE_EXCLUDE)
    # 每个源编号对应的价值，用于 refresh 时按位取最优。
    # 注意 LITE_VALUE 的键是字符串（"01"），src_of 必须存字符串编号，
    # 否则 LITE_VALUE.get(int, 3) 永远命中不了、全部退回默认值 3，价值排序失效。
    NUM_VALUE = [(int(n), n, LITE_VALUE.get(n, 3)) for n in sorted(items)]  # (int编号, 字符串编号, 价值)
    per_src = {}
    def add(d, outfmt, cat, num):
        m = bit(num)
        src_mask[d] = src_mask.get(d, 0) | m
        if d in cand or d in allow_set or has_allowed_parent(d):
            return False
        cand[d] = (outfmt, cat)
        src_of[d] = num
        return True
    def refresh_src_of():
        # 每个域名取「收录它的源里价值最小」的那个，供精简版排序；按位扫描避免存 set
        for d, mask in src_mask.items():
            if d not in cand:
                continue
            best, bestv = None, 99
            for n_int, n_str, v in NUM_VALUE:
                if (mask >> n_int) & 1 and v < bestv:
                    best, bestv = n_str, v   # 存字符串编号，与 LITE_VALUE 键类型一致
                    if bestv == 0:
                        break
            if best is not None:
                src_of[d] = best

    for num in ORDER + [n for n in sorted(items) if n not in ORDER and n not in SKIP_NUMS]:
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
                        if add(d, f"0.0.0.0 {d}", cat, num): added += 1
                    continue
                if body.startswith("||"):
                    core = body[2:]
                    if "$" in core or "/" in core or "*" in core:
                        continue
                    d = norm(core.split("^")[0].split("$")[0].split("/")[0])
                    if valid(d) and add(d, f"||{d}^", cat, num): added += 1
                    continue
                # 41 trli-Pro 用单竖线 |域名^ 格式（AdGuard Home 风格）
                if body.startswith("|") and body.endswith("^"):
                    core = body[1:-1]
                    if "$" in core or "/" in core or "*" in core:
                        continue
                    d = norm(core)
                    if valid(d) and add(d, f"||{d}^", cat, num): added += 1
                    continue
                d = norm(body)
                if valid(d) and add(d, f"0.0.0.0 {d}", cat, num): added += 1
        per_src[num] = added

    refresh_src_of()   # 重算每个域名的最优价值来源

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

    # 精简版：纯拦截 LITE_TOTAL 条（不含白名单）。
    # 按「类别子池」取，而非按来源价值取：
    #   广告类(国内/设备原生/国际) + 隐私 + 动态DNS 全部纳入（保证广告都能屏蔽），
    #   威胁情报补足到 50 万；纯赌博/成人剔除；广告域即使被赌博源收录也保留。
    n_allow = len(allow_set) + len(allow_wild)
    # 精简版：从全量里按「重要性/有用性」挑最有用的 LITE_TOTAL 条。
    # 类别只作标注区分，不按类别池配额取。
    # LITE_MUST（酷安/微信/抖音等主流 App 广告、主流统计追踪域）置顶；
    # 其余按 LITE_VALUE 分级：1 必用（国内广告/设备原生/隐私）> 2 安全 > 3 补充 > 99 赌博成人。
    # 赌博/成人值 99 排最后，自然挤不进前 50 万；
    # 不再因一个域出现在赌博源就硬剔除，避免主流广告域被牵连漏拦。
    lite_items = sorted(
        final_items,
        key=lambda kv: (0 if kv[0] in LITE_MUST else LITE_VALUE.get(src_of.get(kv[0]), 3)),
    )[:LITE_TOTAL]
    lite_rules = sorted(v for d, (v, _) in lite_items)
    lite_cat = {}
    for d, (v, c) in lite_items:
        lite_cat[c] = lite_cat.get(c, 0) + 1

    ts = time.strftime("%Y-%m-%d %H:%M:%S UTC", time.gmtime())
    rule_text = (f"! 自动更新订阅规则 | 更新于 {ts}\n"
                 f"! 共 {len(final_rules):,} 条 | 源项目合并去重裁剪\n"
                 + "=" * 60 + "\n\n" + "\n".join(final_rules) + "\n")
    allow_text = (f"! 放行白名单 | 全量版可选导入，优先级最高\n"
                  f"! 纯域名 {len(allow_set)} + 通配符 {len(allow_wild)}\n"
                  + "=" * 60 + "\n\n"
                  + "\n".join(f"@@||{d}^" for d in sorted(allow_set)) + "\n"
                  + "\n".join(sorted(allow_wild)) + "\n")
    lite_text = (f"! 精简版订阅规则 | 更新于 {ts}\n"
                 f"! 纯拦截 {len(lite_rules):,} 条 | 不含白名单 | 高价值优先\n"
                 + "=" * 60 + "\n\n" + "\n".join(lite_rules) + "\n")
    atomic_write(os.path.join(DATA, "rules.txt"), rule_text)
    atomic_write(os.path.join(DATA, "rules-lite.txt"), lite_text)
    atomic_write(os.path.join(DATA, "allow.txt"), allow_text)
    meta = {"updated_at": ts, "updated_ts": int(time.time()), "total": len(final_rules),
            "lite_total": len(lite_rules), "lite_allow": 0,
            "lite_sum": len(lite_rules), "lite_cat": lite_cat,
            "allow": len(allow_set) + len(allow_wild), "removed_sub": removed,
            "cat": cat_count, "per_src": per_src}
    atomic_write(os.path.join(DATA, "meta.json"), json.dumps(meta, ensure_ascii=False, indent=2))
    write_change(meta, old_meta, items)
    return meta

if __name__ == "__main__":
    t0 = time.time()
    fetch_res, items = fetch_all()
    ok = sum(1 for n, s, b in fetch_res if s)
    for num in SPECIAL_NUMS:
        name = items.get(num, (str(num),))[0]
        print(f"  [{num}] {name} 转换 {convert_special(num, name)} 条", flush=True)
    meta = build()
    append_autolog()
    print(f"更新完成: 源 {ok}/{len(fetch_res)} 成功, 规则 {meta['total']:,}, 耗时 {time.time()-t0:.0f}s", flush=True)
