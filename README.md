# DNS 规则自动订阅

## 项目简介

**这是什么**：一个自动更新的 DNS 广告/追踪/恶意域名拦截规则订阅源，供 [AdGuard Home](https://github.com/AdguardTeam/AdGuardHome) 或手机 DNS App 直接订阅使用。

**解决什么问题**：单个规则源往往覆盖不全、还会失效。本项目把 **89 个开源规则源**（国内广告、隐私追踪、威胁情报、设备原生广告、钓鱼/恶意域名、区域广告等）自动拉下来，统一转换成 DNS 层格式，**全局去重合并**成一份全量母集，再从中按价值切出精简版，提供稳定的订阅地址。你只需订阅一个链接，就能用上几十个源合并后的效果。

**怎么用**：复制下方订阅地址，粘贴到 AdGuard Home 的「订阅」或手机 DNS App 的「自定义规则订阅」即可，规则会自动更新，无需手动维护。

**核心特点**：

| 特点 | 说明 |
|---|---|
| 全自动 | GitHub Actions 每 6 小时无人值守更新，不依赖任何本地设备，源站更新后自动同步 |
| 双版本 | 全量版（约 1159 万条，给 AdGuard Home）+ 精简版（750 万条，给手机 DNS App / 本机服务器） |
| 持续合并 | 89 个源去重合成一个池；新增源只需改 `urls.txt`，无需动脚本 |
| 价值精选 | 精简版每次从全量按价值重切，高价值优先进，类别只作标注 |
| 透明可查 | 每次更新的条数增减、各源变化都记录在 [AUTOLOG.md](AUTOLOG.md) |

> 查看项目的[功能更新历史](CHANGELOG.md)与[每次自动更新的变化明细](AUTOLOG.md)。

## 订阅地址

**精简版（纯拦截 7,500,000 条，不含白名单；约 164MB — 推荐）：**
```
https://gh-proxy.com/https://raw.githubusercontent.com/curtainzhc/dns-rules/main/data/rules-lite.txt
```

**全量版（约 1159 万条，约 258MB — 仅供 AdGuard Home）：**
```
https://github.com/curtainzhc/dns-rules/releases/download/full-rules/rules.txt
```
> 全量文件约 258MB，超过 GitHub 单文件 100MB 限制，故不放仓库、改由 Actions 自动上传到 `full-rules` Release。

**放行白名单（仅全量版可选订阅；精简版为纯拦截、无需白名单）：**
```
https://gh-proxy.com/https://raw.githubusercontent.com/curtainzhc/dns-rules/main/data/allow.txt
```

> 全量文件约 258MB 较大，AdGuard Home 加载需一定内存与时间；手机 DNS App 装不下全量，请用精简版。

## 自动机制

| 文件 | 作用 |
|---|---|
| `.github/workflows/update.yml` | 每 6 小时定时触发，支持手动触发 |
| `update_rules.py` | 并发拉取全部源 → 格式转换 → 清洗 → 全局去重 → 父域折叠 → 白名单优先 → 价值分级 → 输出 |
| `urls.txt` | 规则源清单，每行 `编号\|名称\|URL`；新增源自动纳入，无需改脚本 |
| `data/rules.txt` | 全量拦截规则（产物，约 258MB，上传到 Release 不入库） |
| `data/rules-lite.txt` | 精简版纯拦截 750 万条（产物，不含白名单） |
| `data/allow.txt` | 放行白名单（产物，仅全量版可选） |
| `data/meta.json` | 更新时间、条数、各源贡献、类别分布 |

## 处理规则

- 只保留 DNS 层可用的纯域名规则（`||域名^` / `0.0.0.0 域名`）
- 剔除元素隐藏、`$` 修饰符、URL 路径等网页层规则
- 跨源全局去重、父域折叠、白名单优先剔除冲突拦截
- 白名单剔除了广告/统计类父域（google/doubleclick/facebook/tiktok/yahoo 及 qq/weixin/baidu/jd/taobao/bytedance 等大厂）的误放行，避免旗下广告子域被整片放过；具体业务子域白名单仍保留防误杀
- dnshosts-all 源混入了公共 DNS 服务器地址（DNS 分流配置残留），转换时已剔除，避免误拦公共 DNS
- 全量不裁剪；精简版每次从全量按价值重切，取价值最高的 750 万条
- 类别只作标注、不参与筛选；成人内容无独立源、天然不拦截；赌博源按价值 3 正常参与过滤，不单独剔除

## 当前构成

全量约 1159 万条（11,588,618）：综合 hosts 约 863 万、威胁情报约 204 万、赌博约 51 万、国内广告约 30 万、补充拦截约 8.4 万、国际广告/隐私约 1.1 万、隐私追踪约 1 万、设备原生广告约 2.4 千、动态 DNS/威胁约 1.5 千等；白名单约 1.2 万。

精简版为纯拦截 **7,500,000 条**，不含白名单，每次从全量按价值重切（不是固定保留某一批）。

**精简版价值分档（类别只作标注、不按比例分配）：**
- 价值 0（置顶必保）：主流 App 广告 / 统计 / 追踪高频域（google-analytics、doubleclick、微信、抖音等旗下广告域）
- 价值 1：国内广告、设备原生广告、主流隐私追踪 —— 优先全纳入
- 价值 2：安全刚需（钓鱼、诈骗、恶意托管、恶意软件、动态 DNS 威胁、防 DoH 绕过）
- 价值 3：威胁情报、国际广告/隐私、综合 hosts、赌博 —— 按上档剩余名额补足
- 每轮更新都重新按价值排序取前 750 万：新加的高价值源会挤进精简版，低价值长尾留在全量母集

全量版则不做任何剔除与精选，保留全部规则（就是各类别合并成的统一大池）。

## 规则来源与致谢

本项目的全部规则来自以下开源项目与社区，版权归各自作者所有。感谢他们长期维护与无偿分享，让这份订阅成为可能。

### 国内广告与综合拦截

| 规则源 | 作者 / 组织 | 项目地址 |
|---|---|---|
| 天影 ADS 拦截 / 白名单 | xiaolei7172 | https://github.com/xiaolei7172/ADS |
| anti-AD（easylist / adguard） | anti-AD 团队 | https://anti-ad.net/ |
| 217heidai | 217heidai | https://github.com/217heidai/adblockfilters |
| AWAvenue / AWAvenue2 | uura / TG-Twilight | https://cdn.uura.cn/AWAvenue/AWAvenue-Ads-Rule.txt |
| GOODBYEADS 拦截 / 白名单 | 8680 | https://github.com/8680/GOODBYEADS |
| neoHosts | neoFelhz | https://github.com/neoFelhz/neohosts |
| xinggsf | xinggsf | https://github.com/xinggsf/Adblock-Plus-Rule |
| ADgk | banbendalao | https://github.com/banbendalao/ADgk |
| DD-AD | afwfv | https://github.com/afwfv/DD-AD |
| jiekouAD | damengzhu | https://github.com/damengzhu/banad |
| HG | 2771936993 | https://github.com/2771936993/HG |
| SM-AdHosts | 2Gardon | https://github.com/2Gardon/SM-Ad-FuckU-hosts |
| 666rules | qq5460168 | https://github.com/qq5460168/666 |
| qy-Ads-Rule（源站 WAF 拦截，当前未启用） | rssv | https://github.com/rssv/qy-Ads-Rule |
| dnshosts-all / AdHosts-Pro（trli-Pro，全量最大源） | Potterli20 | https://github.com/Potterli20/file |
| AdRules（plus / DNS） | Cats-Team | https://github.com/Cats-Team/AdRules |
| EasyList China | EasyList / eyeo 社区 | https://easylist.to/ |
| Peter Lowe's Adservers | Peter Lowe | https://pgl.yoyo.org/adservers/ |
| Dan Pollock's Hosts | Dan Pollock | https://someonewhocares.org/hosts/ |
| OISD Big / Small | OISD | https://oisd.nl/ |
| StevenBlack hosts | StevenBlack | https://github.com/StevenBlack/hosts |
| Hufilter | hufilter | https://github.com/hufilter/hufilter |
| YousList | yous | https://github.com/yous/YousList |
| 1Hosts（Lite / Xtra） | badmojr | https://github.com/badmojr/1Hosts |

### 隐私追踪

| 规则源 | 作者 / 组织 | 项目地址 |
|---|---|---|
| EasyPrivacy | EasyList / eyeo 社区 | https://easylist.to/ |
| NoGoogle | nickspaargaren | https://github.com/nickspaargaren/no-google |
| ShadowWhisperer-Tracking | ShadowWhisperer | https://github.com/ShadowWhisperer/BlockLists |

### hagezi 系列（威胁情报 · 设备原生广告 · 防绕路 · 钓鱼托管）

| 规则源 | 作者 / 组织 | 项目地址 |
|---|---|---|
| pro / pro.plus / ultimate / normal / tif / dyndns / gambling / Fake / Hoster / DoH 绕过 / AntiPiracy / URLShortener / AbusedTLD / DNSRebind，及 TikTok、Amazon、Apple、Huawei、Windows/Office、Samsung、LG webOS、Roku、vivo、OPPO/realme、小米等原生广告规则 | hagezi | https://github.com/hagezi/dns-blocklists |

### 安全 · 钓鱼 · 恶意软件

| 规则源 | 作者 / 组织 | 项目地址 |
|---|---|---|
| AdGuard DNS Filter / 钓鱼过滤（filter_30）/ Popup | AdGuard Team | https://github.com/AdguardTeam/AdGuardSDNSFilter |
| URLHaus / Phishing PhishTank | malware-filter | https://gitlab.com/malware-filter |
| Hacked Malware Web Sites | mitchellkrogza | https://github.com/mitchellkrogza/The-Big-List-of-Hacked-Malware-Web-Sites |
| Scam Blocklist | durablenapkin | https://github.com/durablenapkin/scamblocklist |
| Phishing Army | Phishing Army | https://phishing.army/ |
| Dandelion AntiMalware / Nordic / GameConsole / Push | DandelionSprout | https://github.com/DandelionSprout/adfilt |
| ShadowWhisperer-Malware / Dating | ShadowWhisperer | https://github.com/ShadowWhisperer/BlockLists |
| Stalkerware indicators | AssoEchap | https://github.com/AssoEchap/stalkerware-indicators |
| CERT-Polska 域名黑名单 | CERT Polska | https://hole.cert.pl/ |
| uBO Badware | uBlock Origin | https://github.com/uBlockOrigin/uAssets |

### 区域 / 垂直广告

| 规则源 | 作者 / 组织 | 项目地址 |
|---|---|---|
| Dandelion Nordic / GameConsole / Push | DandelionSprout | https://github.com/DandelionSprout/adfilt |
| Perflyst SmartTV | Perflyst | https://github.com/Perflyst/PiHoleBlocklist |
| Polish-Pihole | MajkiIT | https://github.com/MajkiIT/polish-ads-filter |
| ABPVN | ABPVN | https://abpvn.com/ |
| Frellwit's Swedish | lassekongo83 | https://github.com/lassekongo83/Frellwits-filter-lists |
| PersianBlocker | PersianBlocker | https://github.com/PersianBlocker/PersianBlocker |
| Macedonian | cchevy | https://github.com/cchevy/macedonian-pi-hole-blocklist |
| ABPindo | ABPindo | https://github.com/ABPindo/indonesianadblockrules |
| turk-adlist / Turkish-AdHosts | bkrucarci / symbuzzer | https://github.com/bkrucarci/turk-adlist |
| EasyList Lithuania / Hebrew | EasyList 社区 | https://easylist.to/ |
| NoCoin（挖矿） | hoshsadiq | https://github.com/hoshsadiq/adblock-nocoin-list |

> 以上项目按各自开源许可证发布，本订阅仅做格式转换与合并去重，规则归属与解释权归原作者。若某源作者希望移除，可联系我们下架。再次感谢所有维护者的付出。
