# 服务器同步方案（Actions 直连推送）

## 架构
项目规则每 6 小时更新（update.yml + watchdog.yml 兜底），更新后 GitHub Actions
**直连 scp** 把 `data/rules-lite.txt`（750万）推送到服务器，绕开不稳定的 GitHub 代理下载。

## 服务器侧
- 免密公钥：GitHub Actions 专用 ed25519 密钥（私钥存 GitHub Secrets: SERVER_SSH_KEY）
- 接收脚本：`/opt/luckdns-site/push-receive.sh`（严格校验 750万行 + >=150MB，
  替换生效缓存与 8080 站点文件，重启 AdGuard，轮询验证，失败回滚到黄金备份）
- 黄金备份：`/opt/adguardhome/work/data/filters/gold-750w.txt`（永不覆盖，最终回滚点）
- 日志：`/var/log/rules-push.log`

## GitHub Secrets
- `SERVER_IP` = 8.134.182.253
- `SERVER_USER` = root
- `SERVER_SSH_KEY` = 专用 ed25519 私钥

## 旧的 pull 同步（luckdns-sync.sh）
已加固（严格校验 + 黄金备份回滚 + 只用 ghfast.top），保留为备用，
crontab `25 */6 * * *` 仍在，但因 ts 一致通常会跳过，不干扰 push 主链路。

## 修复历史
2026-11-25 曾因 pull 代理拉大文件被截断 + DNS 偶发失败误判回滚，导致规则掉到 400万。
已通过黄金备份恢复 750万，并改用 Actions 直连推送彻底解决。

## 校验说明（重要）
规则文件含两种格式：`||domain^` 和 `0.0.0.0 domain`（用户要求），共 750 万条。
**校验必须用 `grep -vcE '^\s*$|^!'` 数所有有效规则行**，不能用 `grep -c '^||'`
（后者只数 710 万，会误判失败）。阈值 749万~751万。

## 2026-11-25 端到端实测
首次触发因校验方法错误（`^||` 只数出 709 万）被拒，服务器规则未受影响（证明保护机制有效）。
修正校验后重测：scp 直连推 172MB 仅 14 秒，接收脚本校验 7500001 行通过，
替换→重启→轮询第9次就绪→黄金备份更新，全流程成功。
