# 规则自动订阅（GitHub Actions 版）

每 6 小时自动从 30+ 个开源项目拉取广告/威胁情报规则，合并、去重后输出**全量规则**（约 270 万条，不裁剪），提交回本仓库。你的 DNS 过滤 App 订阅本仓库的文件即可，全程无人值守、不依赖任何电脑或 AI。

## 一、部署（一次性，约 3 分钟）

1. 打开 https://github.com/new 新建一个仓库：
   - Repository name：随便填，例如 `dns-rules`
   - **必须选 Public（公开）**——只有公开仓库才能用免登录的 CDN 订阅，且 Actions 免费无限
   - 不要勾选 README / .gitignore 等初始化选项（保持空仓库）
2. 把本压缩包里的**全部文件**（含隐藏的 `.github` 文件夹）上传到这个仓库：
   - 网页上传：进入仓库点 `Add file` → `Upload files`，把文件全选拖进去；
   - 或命令行：
     ```
     cd 仓库文件夹
     git init
     git add .
     git commit -m "init"
     git branch -M main
     git remote add origin https://github.com/curtainzhc/dns-rules.git
     git push -u origin main
     ```
3. 上传后，进入仓库的 **Actions** 标签页 → 左侧点 **自动更新规则** → 右侧点 **Run workflow** → **Run workflow**，手动跑一次确认成功（首次跑约 3 分钟）。
4. 之后它会自动每 6 小时运行，无需再管。

> 关键：上传时 `.github` 这个隐藏文件夹一定要带上，否则定时任务不会生效。用网页上传时先把压缩包解压，选中 `.github` 文件夹整体拖入。

## 二、拿到订阅链接

把下面地址里的 `curtainzhc` 和 `dns-rules` 换成你自己的：

**拦截规则（填 App 的「规则订阅 URL」）：**
```
https://cdn.jsdelivr.net/gh/curtainzhc/dns-rules@main/data/rules.txt
```

**放行白名单（防误杀，一并订阅）：**
```
https://cdn.jsdelivr.net/gh/curtainzhc/dns-rules@main/data/allow.txt
```

jsDelivr 是免费 CDN，国内可直连、自动缓存。`@main` 表示始终取最新版本。如果某次更新后 CDN 没立刻刷新，等几分钟或把 `@main` 换成 `@latest` 再试。

备用直链（不走 CDN，实时但国内可能较慢）：
```
https://raw.githubusercontent.com/curtainzhc/dns-rules/main/data/rules.txt
https://raw.githubusercontent.com/curtainzhc/dns-rules/main/data/allow.txt
```

## 三、验证自动更新是否正常

- 打开仓库的 `data/meta.json`，看 `updated_at` 字段是不是新的；
- 或访问 `https://cdn.jsdelivr.net/gh/curtainzhc/dns-rules@main/data/meta.json` 查看；
- Actions 页面能看到每次运行记录和耗时。

## 四、可调项

| 想改什么 | 改哪里 |
|---|---|
| 更新频率 | `.github/workflows/update.yml` 里的 `cron: '0 */6 * * *'`（UTC 时间） |
| 是否裁剪条数 | `update_rules.py` 里的 `TARGET`（当前 `None`=全量；设为数字如 500000 则裁剪）|
| 单源限额 | `update_rules.py` 里的 `CAP`（当前 `{}`=不限）|
| 增删规则源 | `urls.txt`（每行 `编号\|名称\|URL`） |

改完提交后，下次定时运行自动生效；也可以手动 Run workflow 立即验证。

## 五、规则构成（全量，约 270 万条）

- 威胁情报（钓鱼/恶意/僵尸网络）：约 189 万
- 赌博/成人：约 53 万
- 国内广告：约 30 万
- 隐私追踪、设备原生广告等：约 1.5 万
- 另有约 1.2 万条放行白名单配套

清理逻辑：元素隐藏规则、`$` 修饰符、带路径的网页请求规则已剔除（DNS 层用不上）；跨源全局去重、父域折叠、白名单优先剔除冲突拦截。不裁剪条数，输出全部有效规则。

> 注意：全量规则文件约 56MB，超过 jsDelivr CDN 的 20MB 单文件限制。若 CDN 订阅失败，请改用 raw 直链：
> ```
> https://raw.githubusercontent.com/curtainzhc/dns-rules/main/data/rules.txt
> ```
> 或在 App 中直接用「更新订阅」手动导入。