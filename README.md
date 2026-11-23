# DNS 规则自动订阅

多规则源自动拉取 → 清洗 → 全局去重 → 合并 → 全量输出。GitHub Actions 定时无人值守运行，不依赖任何本地设备。

## 订阅地址

拦截规则：
```
https://gh-proxy.com/https://raw.githubusercontent.com/curtainzhc/dns-rules/main/data/rules.txt
```

放行白名单：
```
https://gh-proxy.com/https://raw.githubusercontent.com/curtainzhc/dns-rules/main/data/allow.txt
```

> 全量文件约 66MB，超过 jsDelivr 的 20MB 单文件限制，必须走上面的 gh-proxy 加速通道。

## 自动机制

| 文件 | 作用 |
|---|---|
| `.github/workflows/update.yml` | 每 6 小时定时触发，支持手动触发 |
| `update_rules.py` | 并发拉取全部源 → 格式转换 → 清洗 → 全局去重 → 父域折叠 → 白名单优先 → 输出 |
| `urls.txt` | 规则源清单，每行 `编号\|名称\|URL`；新增源自动纳入，无需改脚本 |
| `data/rules.txt` | 合并后的拦截规则（产物） |
| `data/allow.txt` | 放行白名单（产物） |
| `data/meta.json` | 更新时间、条数、各源贡献、类别分布 |

## 处理规则

- 只保留 DNS 层可用的纯域名规则（`||域名^` / `0.0.0.0 域名`）
- 剔除元素隐藏、`$` 修饰符、URL 路径等网页层规则
- 跨源全局去重、父域折叠、白名单优先剔除冲突拦截
- 不裁剪条数，输出全量

## 当前构成

约 328 万条：威胁情报约 201 万、赌博/成人约 51 万、综合 hosts 约 39 万、国内广告约 30 万、防绕路约 1.4 万、其他；白名单约 1.2 万。
