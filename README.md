# DNS 规则自动订阅

多规则源自动拉取 → 清洗 → 全局去重 → 合并 → 全量输出。GitHub Actions 定时无人值守运行，不依赖任何本地设备。

> 查看项目的[完整更新历史](CHANGELOG.md)。

## 订阅地址

**精简版（拦截 + 白名单合计精确 50 万条，拦截 48.8 万 + 白名单 1.2 万；约 11MB — 推荐）：**
```
https://gh-proxy.com/https://raw.githubusercontent.com/curtainzhc/dns-rules/main/data/rules-lite.txt
```

**全量版（约 328 万条，66MB）：**
```
https://gh-proxy.com/https://raw.githubusercontent.com/curtainzhc/dns-rules/main/data/rules.txt
```

**放行白名单（两个版本共用，务必一并订阅）：**
```
https://gh-proxy.com/https://raw.githubusercontent.com/curtainzhc/dns-rules/main/data/allow.txt
```

> 全量文件约 66MB，超过 jsDelivr 的 20MB 单文件限制，必须走 gh-proxy 加速通道。手机内存有限时优先用精简版。

## 自动机制

| 文件 | 作用 |
|---|---|
| `.github/workflows/update.yml` | 每 6 小时定时触发，支持手动触发 |
| `update_rules.py` | 并发拉取全部源 → 格式转换 → 清洗 → 全局去重 → 父域折叠 → 白名单优先 → 输出 |
| `urls.txt` | 规则源清单，每行 `编号\|名称\|URL`；新增源自动纳入，无需改脚本 |
| `data/rules.txt` | 全量拦截规则（产物） |
| `data/rules-lite.txt` | 精简版 50 万条（产物） |
| `data/allow.txt` | 放行白名单（产物，两版共用） |
| `data/meta.json` | 更新时间、条数、各源贡献、类别分布 |

## 处理规则

- 只保留 DNS 层可用的纯域名规则（`||域名^` / `0.0.0.0 域名`）
- 剔除元素隐藏、`$` 修饰符、URL 路径等网页层规则
- 跨源全局去重、父域折叠、白名单优先剔除冲突拦截
- 白名单剔除了广告/统计类父域（google/doubleclick/facebook/tiktok/yahoo 等）的误放行，避免主流广告被整片放过；具体子域白名单仍保留防误杀
- dnshosts-all 源混入了 55 个公共 DNS 服务器地址（DNS 分流配置残留），转换时已剔除，避免误拦公共 DNS
- 全量不裁剪；精简版按价值精选取前 50 万条（设备原生/国内广告/威胁情报优先）

## 当前构成

全量约 328 万条：威胁情报约 201 万、赌博/成人约 51 万、综合 hosts 约 39 万、国内广告约 30 万、防绕路约 1.4 万、其他；白名单约 1.2 万。

精简版合计精确 50 万条 = 拦截 48.8 万 + 白名单 1.2 万（白名单完整保留，拦截数自动补齐）。AdGuard Home 合并去重后显示约 49.96 万条，属正常现象。

**精简版不是机械截断，而是按「日常能用上」的价值精选：**
- 完整保留：国内广告 ~30 万、设备原生广告、隐私追踪、钓鱼/诈骗/恶意托管/防 DoH 绕路（新加的安全源全部纳入）
- 补充保留：威胁情报 TIF ~18 万
- **剔除：赌博/成人（日常用不上）**——只要域名出现在赌博源就剔除，即使它也被其他源收录
- 白名单 1.2 万条完整保留（防误杀，不动）

全量版则不做任何剔除与精选，保留全部规则。

## 规则来源与致谢

本项目的全部规则来自以下开源项目与社区，版权归各自作者所有。感谢他们长期维护与无偿分享，让这份订阅成为可能。

### 国内广告与综合拦截

| 规则源 | 作者 / 组织 | 项目地址 |
|---|---|---|
| 天影 ADS 拦截 / 白名单 | xiaolei7172 | https://github.com/xiaolei7172/ADS |
| anti-AD | anti-AD 团队 | https://anti-ad.net/ |
| 217heidai | 217heidai | https://github.com/217heidai/adblockfilters |
| AWAvenue | uura | https://cdn.uura.cn/AWAvenue/AWAvenue-Ads-Rule.txt |
| GOODBYEADS 拦截 / 白名单 | 8680 | https://github.com/8680/GOODBYEADS |
| neoHosts | neoFelhz | https://github.com/neoFelhz/neohosts |
| xinggsf | xinggsf | https://github.com/xinggsf/Adblock-Plus-Rule |
| ADgk | banbendalao | https://github.com/banbendalao/ADgk |
| DD-AD | afwfv | https://github.com/afwfv/DD-AD |
| jiekouAD | damengzhu | https://github.com/damengzhu/banad |
| HG | 2771936993 | https://github.com/2771936993/HG |
| SM-AdHosts | 2Gardon | https://github.com/2Gardon/SM-Ad-FuckU-hosts |
| 666rules | qq5460168 | https://github.com/qq5460168/666 |
| dnshosts-all | Potterli20 | https://github.com/Potterli20/file |
| AdRules | Cats-Team | https://github.com/Cats-Team/AdRules |

### 隐私追踪

| 规则源 | 作者 / 组织 | 项目地址 |
|---|---|---|
| EasyPrivacy | EasyList / eyeo 社区 | https://easylist.to/ |

### hagezi 系列（威胁情报 · 设备原生广告 · 防绕路 · 钓鱼托管）

| 规则源 | 作者 / 组织 | 项目地址 |
|---|---|---|
| pro / tif / dyndns / gambling / Fake / Hoster / DoH 绕过，及 TikTok、Amazon、Apple、Huawei、Windows/Office、Samsung、LG webOS、Roku、vivo、OPPO/realme、小米等原生广告规则 | hagezi | https://github.com/hagezi/dns-blocklists |

### 官方安全过滤

| 规则源 | 作者 / 组织 | 项目地址 |
|---|---|---|
| AdGuard DNS Filter | AdGuard Team | https://github.com/AdguardTeam/AdGuardSDNSFilter |
| AdGuard 钓鱼过滤（filter_30） | AdGuard Team | https://github.com/AdguardTeam/HostlistsRegistry |
| OISD Big | OISD | https://oisd.nl/ |

> 以上项目按各自开源许可证发布，本订阅仅做格式转换与合并去重，规则归属与解释权归原作者。若某源作者希望移除，可联系我们下架。再次感谢所有维护者的付出。
