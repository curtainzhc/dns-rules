#!/bin/bash
# 接收 GitHub Actions 推送的 750万规则并安全替换
# 用法: push-receive.sh <上传的临时文件路径>
set -u
LOG=/var/log/rules-push.log
CACHE=/opt/adguardhome/work/data/filters/1795611427.txt
SITE=/opt/luckdns-site/rules-lite.txt
GOLD=/opt/adguardhome/work/data/filters/gold-750w.txt
LAST=/opt/luckdns-site/last_sync_ts
UP="$1"
log(){ echo "[$(date '+%F %T')] $*" | tee -a "$LOG"; }

log "=== 收到推送，开始校验 ==="
if [ -z "$UP" ] || [ ! -f "$UP" ]; then log "文件不存在"; exit 1; fi

# 1) 严格校验：正好750万条 + 体积>=150MB
LINES=$(grep -vcE '^\s*$|^!' "$UP" 2>/dev/null || echo 0)
SIZE=$(stat -c%s "$UP" 2>/dev/null || echo 0)
log "校验: 规则行=$LINES 字节=$SIZE"
if [ "$LINES" -lt 7490000 ] || [ "$LINES" -gt 7510000 ] || [ "$SIZE" -lt 150000000 ]; then
  log "校验失败(应约750万行/>=150MB)，拒绝替换，保留现有规则"; rm -f "$UP"; exit 1
fi

# 2) 备份当前生效规则（仅当它本身是750万才作为回滚点，否则用gold）
CUR=$(grep -vcE '^\s*$|^!' "$CACHE" 2>/dev/null || echo 0)
if [ "$CUR" -ge 7490000 ]; then cp "$CACHE" "$CACHE.pre-push"; ROLLBACK="$CACHE.pre-push"
else ROLLBACK="$GOLD"; fi

# 3) 替换生效缓存 + 站点文件
cp "$UP" "$CACHE"
cp "$UP" "$SITE"
chmod 600 "$CACHE"
log "已替换生效缓存与站点文件"

# 4) 重启 + 轮询验证（只看规则数+进程，DNS偶发失败不回滚）
systemctl restart adguardhome
CNT=0; ALIVE=inactive
for i in $(seq 1 36); do
  sleep 5
  CNT=$(curl -s -u admin:Admin123456 http://127.0.0.1:3000/control/filtering/status 2>/dev/null \
    | python3 -c "import sys,json
try:
 d=json.load(sys.stdin); f=d.get('filters') or []; print(f[0]['rules_count'] if f else 0)
except Exception: print(0)" 2>/dev/null || echo 0)
  ALIVE=$(systemctl is-active adguardhome)
  if [ "$CNT" -ge 7400000 ] && [ "$ALIVE" = "active" ]; then
    log "第${i}次轮询就绪: 规则=$CNT 服务=$ALIVE"; break
  fi
done

if [ "$CNT" -ge 7400000 ] && [ "$ALIVE" = "active" ]; then
  # 成功：更新黄金备份、更新时间戳
  cp "$UP" "$GOLD"
  TS=$(python3 -c "import json;print(json.load(open('/tmp/push_meta.json'))['updated_ts'])" 2>/dev/null || echo "")
  [ -n "$TS" ] && echo "$TS" > "$LAST"
  rm -f "$UP"
  log "=== 推送成功，规则已更新并生效 (ts=$TS) ==="
else
  cp "$ROLLBACK" "$CACHE"; cp "$ROLLBACK" "$SITE"
  systemctl restart adguardhome
  log "=== 验证失败，已回滚 ==="
  rm -f "$UP"
  exit 1
fi
