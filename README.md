# DNS 规则自动订阅

多规则源自动拉取 → 清洗 → 全局去重 → 合并 → 全量输出。GitHub Actions 定时无人值守运行，不依赖任何本地设备。

> 查看项目的[完整更新历史](CHANGELOG.md)。

## 订阅地址

**精简版（纯拦截精确 50 万条，不含白名单；约 11MB — 推荐）：**
```
https://gh-proxy.com/https://raw.githubusercontent.com/curtainzhc/dns-rules/main/data/rules-lite.txt
```

**全量版（约 1147 万条，256MB — 仅供 AdGuard Home，超出 App 50 万上限）：**
```
https://github.com/curtainzhc/dns-rules/releases/download/full-rules/rules.txt
```
> 全量文件 256MB，超过 GitHub 单文件 100MB 限制，故不放仓库、改由 Actions 自动上传到 `full-rules` Release。

**放行白名单（仅全量版可选订阅；精简版为纯拦截、无需白名单）：**
```
https://gh-proxy.com/https://raw.githubusercontent.com/curtainzhc/dns-rules/main/data/allow.txt
```

> 全量文件 256MB 较大，AdGuard Home 加载需一定内存与时间；手机 DNS App 有 50 万条上限，装不下全量，请用精简版。

## 自动机制

| 文件 | 作用 |
|---|---|
| `.github/workflows/update.yml` | 每 6 小时定时触发，支持手动触发 |
| `update_rules.py` | 并发拉取全部源 → 格式转换 → 清洗 → 全局去重 → 父域折叠 → 白名单优先 → 输出 |
| `urls.txt` | 规则源清单，每行 `编号\|名称\|URL`；新增源自动纳入，无需改脚本 |
| `data/rules.txt` | 全量拦截规则（产物，256MB，上传到 Release 不入库） |
| `data/rules-lite.txt` | 精简版纯拦截 50 万条（产物，不含白名单） |
| `data/allow.txt` | 放行白名单（产物，仅全量版可选） |
| `data/meta.json` | 更新时间、条数、各源贡献、类别分布 |

## 处理规则

- 只保留 DNS 层可用的纯域名规则（`||域名^` / `0.0.0.0 域名`）
- 剔除元素隐藏、`$` 修饰符、URL 路径等网页层规则
- 跨源全局去重、父域折叠、白名单优先剔除冲突拦截
- 白名单剔除了广告/统计类父域（google/doubleclick/facebook/tiktok/yahoo 及 qq/weixin/baidu/jd/taobao/bytedance 等大厂）的误放行，避免旗下广告子域被整片放过；具体业务子域白名单仍保留防误杀
- dnshosts-all 源混入了 55 个公共 DNS 服务器地址（DNS 分流配置残留），转换时已剔除，避免误拦公共 DNS
- 全量不裁剪；精简版从全量里按「重要性/有用性」排序，挑最有用的 50 万条

## 当前构成

全量约 1147 万条：综合 hosts 约 862 万、威胁情报约 201 万、赌博/成人约 51 万、国内广告约 30 万、防绕路约 1.5 万、其他；白名单约 1.2 万。

精简版为纯拦截精确 50 万条，**不含白名单**。AdGuard Home 合并去重后显示略低于 50 万，属正常现象。

**精简版从全量里按「重要性」挑最有用的 50 万条，类别只作标注、不按比例分配：**
- 置顶：主流 App 广告 / 统计 / 追踪必保域（酷安、微信、抖音、google-analytics、doubleclick 等旗下广告域）
- 价值1 全纳入：国内广告 30.4 万、设备原生广告、国际广告/隐私、隐私追踪、动态 DNS/威胁
- 价值2/3 补足：威胁情报 TIF ~15.3 万，把 50 万填满
- 赌博/成人价值最低排最后，挤不进 50 万；白名单不纳入精简版（全量版如需放行可单独订阅 `allow.txt`）

全量版则不做任何剔除与精选，保留全部规则（就是各类别合并成的统一大池）。

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
