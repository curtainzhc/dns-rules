#!/bin/bash
# LuckDNS 规则自动同步：与 GitHub 项目统一，从 Release 拉精简版 750万，直接替换 AdGuard 缓存
# 每6小时检查；先读小 meta.json 判断是否有更新，有更新才下 163MB，失败自动回滚
set -u
LOG=/var/log/luckdns-sync.log
BASE=/opt/luckdns-site
CACHE=/opt/adguardhome/work/data/filters/1795611427.txt
LAST=$BASE/last_sync_ts
TMP=/tmp/luckdns-sync
mkdir -p $TMP

log(){ echo "[$(date '+%F %T')] $*" | tee -a $LOG; }

RAWBASE="https://raw.githubusercontent.com/curtainzhc/dns-rules/main/data"
REL="https://github.com/curtainzhc/dns-rules/releases/download/full-rules/rules-lite.txt"
PROXIES=("https://ghfast.top/")

# 多通道下载：成功返回0。$1=完整URL $2=输出
fetch_url(){
  local url="$1" out="$2" p
  for p in "${PROXIES[@]}"; do
    if curl -fsSL --retry 1 --max-time 1800 -o "$out" "${p}${url}"; then
      return 0
    fi
  done
  return 1
}

# 查询规则数（失败回退0）
get_count(){
  curl -s -u admin:Admin123456 http://127.0.0.1:3000/control/filtering/status 2>/dev/null \
    | python3 -c "import sys,json
try:
    d=json.load(sys.stdin); f=d.get('filters') or []
    print(f[0]['rules_count'] if f else 0)
except Exception: print(0)" 2>/dev/null || echo 0
}

# 查询本机 DNS 是否正常解析（OK/FAIL）
get_dns(){
  python3 -c "
import socket,struct
q=b'\x12\x34\x01\x00\x00\x01\x00\x00\x00\x00\x00\x00'+b'\x05baidu\x03com\x00'+struct.pack('>HH',1,1)
s=socket.socket(socket.AF_INET,socket.SOCK_DGRAM);s.settimeout(5)
try:
    s.sendto(q,('127.0.0.1',53));d,_=s.recvfrom(4096);print('OK' if d[3]&15==0 else 'FAIL')
except Exception: print('FAIL')" 2>/dev/null || echo FAIL
}

log "=== 检查更新开始 ==="

# 1) 拉小元文件判断是否有更新
if ! fetch_url "${RAWBASE}/meta.json" "$TMP/meta.json"; then
  log "meta.json 拉取失败，本次跳过"; exit 1
fi
TS=$(python3 -c "import json;print(json.load(open('$TMP/meta.json'))['updated_ts'])" 2>/dev/null)
LT=$(python3 -c "import json;print(json.load(open('$TMP/meta.json'))['lite_total'])" 2>/dev/null)
if [ -z "$TS" ]; then log "meta 解析失败，跳过"; exit 1; fi
if [ "$LT" != "7500000" ]; then log "项目精简版条数=$LT 非750万，跳过"; exit 1; fi
OLD=$(cat "$LAST" 2>/dev/null || echo 0)
if [ "$TS" = "$OLD" ] && [ -f "$CACHE" ]; then
  log "与项目一致 (ts=$TS)，跳过"; exit 0
fi
log "项目有更新 ts=$TS (本地=$OLD)，开始同步 750万精简版"

# 2) 从 Release 拉 163MB 精简版
if ! fetch_url "$REL" "$TMP/rules-lite.txt"; then
  log "精简版下载失败，本次跳过"; exit 1
fi
LINES=$(grep -vcE '^\s*$|^!' "$TMP/rules-lite.txt" 2>/dev/null || echo 0)
if [ "$LINES" -lt 7490000 ] || [ "$LINES" -gt 7510000 ]; then
  log "精简版行数异常 $LINES(应约750万)，跳过"; exit 1
fi
SIZE=$(stat -c%s "$TMP/rules-lite.txt" 2>/dev/null || echo 0)
if [ "$SIZE" -lt 150000000 ]; then log "文件大小异常 $SIZE 字节(<150MB)，疑似截断，跳过"; exit 1; fi
log "下载完成 $LINES 条 $SIZE 字节（赌博按价值3正常参与，不做类别剔除）"

# 3) 备份→替换→重启→轮询验证（750万加载需60-90秒，固定sleep会误判，改轮询最多等180秒）
CUR=$(grep -vcE '^\s*$|^!' "$CACHE" 2>/dev/null || echo 0)
GOLD=/opt/adguardhome/work/data/filters/gold-750w.txt
# 黄金备份：仅当不存在或当前缓存确为750万时更新，永不被坏文件覆盖
if [ ! -f "$GOLD" ] || [ "$CUR" -ge 7490000 ]; then cp "$CACHE" "$GOLD"; fi
cp "$CACHE" "$CACHE.baksync"
cp "$TMP/rules-lite.txt" "$CACHE"
systemctl restart adguardhome
CNT=0; DNS=FAIL; ALIVE=inactive
for i in $(seq 1 36); do
  sleep 5
  CNT=$(get_count); DNS=$(get_dns); ALIVE=$(systemctl is-active adguardhome)
  CNT=${CNT:-0}
  if [ "$CNT" -ge 7400000 ] && [ "$ALIVE" = "active" ]; then
    log "第${i}次轮询就绪: 规则=$CNT DNS=$DNS 服务=$ALIVE"
    break
  fi
done
log "验证: 规则=$CNT DNS=$DNS 服务=$ALIVE"

if [ "$CNT" -ge 7400000 ] && [ "$ALIVE" = "active" ]; then
  echo "$TS" > "$LAST"
  rm -f "$CACHE.baksync"
  log "=== 同步成功，与项目一致 (ts=$TS) ==="
else
  if [ -f "$GOLD" ]; then cp "$GOLD" "$CACHE"; else cp "$CACHE.baksync" "$CACHE"; fi
  systemctl restart adguardhome
  log "=== 验证失败，已从黄金备份回滚 ==="
  exit 1
fi
