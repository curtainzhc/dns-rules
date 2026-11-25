#!/bin/bash
set -e
echo "=================================="
echo "   AdGuard Home 原生一键部署"
echo "=================================="
[ "$(id -u)" = "0" ] || { echo "请用 root 运行"; exit 1; }

echo "[1/6] 释放 53 端口..."
systemctl stop systemd-resolved 2>/dev/null || true
systemctl disable systemd-resolved 2>/dev/null || true

echo "[2/6] 下载 AdGuard Home（多源兜底）..."
cd /tmp
URL="https://github.com/AdguardTeam/AdGuardHome/releases/latest/download/AdGuardHome_linux_amd64.tar.gz"
OK=0
for p in "https://gh-proxy.com/" "https://ghfast.top/" ""; do
  echo "  源: ${p:-直连}"
  if curl -fL --max-time 240 "${p}${URL}" -o agh.tar.gz && [ -s agh.tar.gz ]; then OK=1; break; fi
done
[ "$OK" = "1" ] || { echo "下载失败，请检查网络"; exit 1; }
tar -xzf agh.tar.gz
mkdir -p /opt/adguardhome/work /opt/adguardhome/conf
cp AdGuardHome/AdGuardHome /opt/adguardhome/agh
chmod +x /opt/adguardhome/agh

echo "[3/6] 写入配置（账号 admin / 50万规则 / 国内上游）..."
cat > /opt/adguardhome/conf/AdGuardHome.yaml.b64 <<'CEOF'
aHR0cDoKICBkb2g6CiAgICByb3V0ZXM6CiAgICAgIC0gR0VUIC9kbnMtcXVlcnkKICAgICAgLSBQT1NUIC9kbnMtcXVlcnkKICAgICAgLSBHRVQgL2Rucy1xdWVyeS97Q2xpZW50SUR9CiAgICAgIC0gUE9TVCAvZG5zLXF1ZXJ5L3tDbGllbnRJRH0KICAgIGluc2VjdXJlX2VuYWJsZWQ6IGZhbHNlCiAgcHByb2Y6CiAgICBwb3J0OiA2MDYwCiAgICBlbmFibGVkOiBmYWxzZQogIGFkZHJlc3M6IDAuMC4wLjA6MzAwMAogIHNlc3Npb25fdHRsOiAzMGQKdXNlcnM6CiAgLSBuYW1lOiBhZG1pbgogICAgcGFzc3dvcmQ6ICQyYSQxMCQycklXdHpkR2RJNGxTNDk1di94RVIuNHFPSnNNeW9tTG1QMmdHdnRhWDY2aUQ3THFNQ3Y1QwphdXRoX2F0dGVtcHRzOiA1CmJsb2NrX2F1dGhfbWluOiAxNQpodHRwX3Byb3h5OiAiIgpsYW5ndWFnZTogemhfY24KdGhlbWU6IGF1dG8KZG5zOgogIGVkbnNfY2xpZW50X3N1Ym5ldDoKICAgIGN1c3RvbV9pcDogIiIKICAgIGVuYWJsZWQ6IGZhbHNlCiAgICB1c2VfY3VzdG9tOiBmYWxzZQogIHBlbmRpbmdfcmVxdWVzdHM6CiAgICBlbmFibGVkOiB0cnVlCiAgaXBzZXRfZmlsZTogIiIKICB1cHN0cmVhbV9kbnNfZmlsZTogIiIKICB1cHN0cmVhbV9tb2RlOiBsb2FkX2JhbGFuY2UKICBiaW5kX2hvc3RzOgogICAgLSAwLjAuMC4wCiAgcmF0ZWxpbWl0X3doaXRlbGlzdDogW10KICBkbnM2NF9wcmVmaXhlczogW10KICBwcml2YXRlX25ldHdvcmtzOiBbXQogIHRydXN0ZWRfcHJveGllczoKICAgIC0gMTI3LjAuMC4wLzgKICAgIC0gOjoxLzEyOAogIGFsbG93ZWRfY2xpZW50czogW10KICBibG9ja2VkX2hvc3RzOgogICAgLSB2ZXJzaW9uLmJpbmQKICAgIC0gaWQuc2VydmVyCiAgICAtIGhvc3RuYW1lLmJpbmQKICBib2d1c19ueGRvbWFpbjogW10KICBib290c3RyYXBfZG5zOgogICAgLSAxLjAuMC4xCiAgICAtIDEuMS4xLjEKICAgIC0gMjYwNjo0NzAwOjQ3MDA6OjEwMDEKICAgIC0gMjYwNjo0NzAwOjQ3MDA6OjExMTEKICBkaXNhbGxvd2VkX2NsaWVudHM6IFtdCiAgZmFsbGJhY2tfZG5zOiBbXQogIGlwc2V0OiBbXQogIGxvY2FsX3B0cl91cHN0cmVhbXM6IFtdCiAgdXBzdHJlYW1fZG5zOgogICAgLSBodHRwczovL2RvaC5wdWIvZG5zLXF1ZXJ5CiAgICAtIGh0dHBzOi8vZG5zLmFsaWRucy5jb20vZG5zLXF1ZXJ5CiAgICAtIHRsczovLzIyMy41LjUuNQogIGNhY2hlX29wdGltaXN0aWNfYW5zd2VyX3R0bDogMzBzCiAgY2FjaGVfb3B0aW1pc3RpY19tYXhfYWdlOiAxMmgKICBmYXN0ZXN0X3RpbWVvdXQ6IDFzCiAgdXBzdHJlYW1fdGltZW91dDogMTBzCiAgbWF4X2dvcm91dGluZXM6IDMwMAogIHJhdGVsaW1pdF9zdWJuZXRfbGVuX2lwdjQ6IDI0CiAgcmF0ZWxpbWl0X3N1Ym5ldF9sZW5faXB2NjogNTYKICBjYWNoZV90dGxfbWF4OiAwCiAgY2FjaGVfdHRsX21pbjogMAogIGNhY2hlX3NpemU6IDQxOTQzMDQKICByYXRlbGltaXQ6IDIwCiAgcG9ydDogNTMKICBhYWFhX2Rpc2FibGVkOiBmYWxzZQogIGFub255bWl6ZV9jbGllbnRfaXA6IGZhbHNlCiAgYm9vdHN0cmFwX3ByZWZlcl9pcHY2OiBmYWxzZQogIGNhY2hlX2VuYWJsZWQ6IHRydWUKICBjYWNoZV9vcHRpbWlzdGljOiBmYWxzZQogIGVuYWJsZV9kbnNzZWM6IHRydWUKICBoYW5kbGVfZGRyOiB0cnVlCiAgaG9zdHNmaWxlX2VuYWJsZWQ6IHRydWUKICByZWZ1c2VfYW55OiB0cnVlCiAgc2VydmVfaHR0cDM6IGZhbHNlCiAgc2VydmVfcGxhaW5fZG5zOiB0cnVlCiAgdXNlX2RuczY0OiBmYWxzZQogIHVzZV9odHRwM191cHN0cmVhbXM6IGZhbHNlCiAgdXNlX3ByaXZhdGVfcHRyX3Jlc29sdmVyczogZmFsc2UKdGxzOgogIGVuYWJsZWQ6IGZhbHNlCiAgc2VydmVyX25hbWU6ICIiCiAgZm9yY2VfaHR0cHM6IGZhbHNlCiAgcG9ydF9odHRwczogNDQzCiAgcG9ydF9kbnNfb3Zlcl90bHM6IDg1MwogIHBvcnRfZG5zX292ZXJfcXVpYzogODUzCiAgcG9ydF9kbnNjcnlwdDogMAogIGRuc2NyeXB0X2NvbmZpZ19maWxlOiAiIgogIGNlcnRpZmljYXRlX2NoYWluOiAiIgogIHByaXZhdGVfa2V5OiAiIgogIGNlcnRpZmljYXRlX3BhdGg6ICIiCiAgcHJpdmF0ZV9rZXlfcGF0aDogIiIKICBzdHJpY3Rfc25pX2NoZWNrOiBmYWxzZQpxdWVyeWxvZzoKICBkaXJfcGF0aDogIiIKICBpZ25vcmVkOiBbXQogIGludGVydmFsOiA5MGQKICBzaXplX21lbW9yeTogMTAwMAogIGVuYWJsZWQ6IHRydWUKICBmaWxlX2VuYWJsZWQ6IHRydWUKICBpZ25vcmVkX2VuYWJsZWQ6IGZhbHNlCnN0YXRpc3RpY3M6CiAgZGlyX3BhdGg6ICIiCiAgaWdub3JlZDogW10KICBpbnRlcnZhbDogMWQKICBlbmFibGVkOiB0cnVlCiAgaWdub3JlZF9lbmFibGVkOiBmYWxzZQpmaWx0ZXJzOgogIC0gZW5hYmxlZDogdHJ1ZQogICAgdXJsOiBodHRwczovL2doLXByb3h5LmNvbS9odHRwczovL3Jhdy5naXRodWJ1c2VyY29udGVudC5jb20vY3VydGFpbnpoYy9kbnMtcnVsZXMvbWFpbi9kYXRhL3J1bGVzLWxpdGUudHh0CiAgICBuYW1lOiBORVhVUyDnsr7nroDniYggNTDkuIcKICAgIGlkOiAxNzk1NTc2NzQ3CndoaXRlbGlzdF9maWx0ZXJzOiBbXQp1c2VyX3J1bGVzOiBbXQpkaGNwOgogIGRoY3B2NDoKICAgIGdhdGV3YXlfaXA6ICIiCiAgICByYW5nZV9zdGFydDogIiIKICAgIHJhbmdlX2VuZDogIiIKICAgIHN1Ym5ldF9tYXNrOiAiIgogICAgb3B0aW9uczogW10KICAgIGljbXBfdGltZW91dF9tc2VjOiAxMDAwCiAgICBsZWFzZV9kdXJhdGlvbjogODY0MDAKICBkaGNwdjY6CiAgICByYW5nZV9zdGFydDogIiIKICAgIGxlYXNlX2R1cmF0aW9uOiA4NjQwMAogICAgcmFfc2xhYWNfb25seTogZmFsc2UKICAgIHJhX2FsbG93X3NsYWFjOiBmYWxzZQogIGludGVyZmFjZV9uYW1lOiAiIgogIGxvY2FsX2RvbWFpbl9uYW1lOiBsYW4KICBlbmFibGVkOiBmYWxzZQpmaWx0ZXJpbmc6CiAgYmxvY2tpbmdfaXB2NDogIiIKICBibG9ja2luZ19pcHY2OiAiIgogIGJsb2NrZWRfc2VydmljZXM6CiAgICBzY2hlZHVsZToKICAgICAgdGltZV96b25lOiBVVEMKICAgIGlkczogW10KICBwcm90ZWN0aW9uX2Rpc2FibGVkX3VudGlsOiBudWxsCiAgc2FmZV9zZWFyY2g6CiAgICBlbmFibGVkOiBmYWxzZQogICAgYmluZzogdHJ1ZQogICAgZHVja2R1Y2tnbzogdHJ1ZQogICAgZWNvc2lhOiB0cnVlCiAgICBnb29nbGU6IHRydWUKICAgIHBpeGFiYXk6IHRydWUKICAgIHlhbmRleDogdHJ1ZQogICAgeW91dHViZTogdHJ1ZQogIGJsb2NraW5nX21vZGU6IGRlZmF1bHQKICBwYXJlbnRhbF9ibG9ja19ob3N0OiBmYW1pbHktYmxvY2suZG5zLmFkZ3VhcmQuY29tCiAgc2FmZWJyb3dzaW5nX2Jsb2NrX2hvc3Q6IHN0YW5kYXJkLWJsb2NrLmRucy5hZGd1YXJkLmNvbQogIHJld3JpdGVzOiBbXQogIHNhZmVfZnNfcGF0dGVybnM6CiAgICAtIC9vcHQvYWRndWFyZGhvbWUvd29yay91c2VyZmlsdGVycy8qCiAgbWF4X2h0dHBfc2l6ZTogMjU2TUIKICBzYWZlYnJvd3NpbmdfY2FjaGVfc2l6ZTogMTA0ODU3NgogIHNhZmVzZWFyY2hfY2FjaGVfc2l6ZTogMTA0ODU3NgogIHBhcmVudGFsX2NhY2hlX3NpemU6IDEwNDg1NzYKICBjYWNoZV90aW1lOiAzMAogIGZpbHRlcnNfdXBkYXRlX2ludGVydmFsOiAyNAogIGJsb2NrZWRfcmVzcG9uc2VfdHRsOiAxMAogIGZpbHRlcmluZ19lbmFibGVkOiB0cnVlCiAgcmV3cml0ZXNfZW5hYmxlZDogdHJ1ZQogIHBhcmVudGFsX2VuYWJsZWQ6IGZhbHNlCiAgc2FmZWJyb3dzaW5nX2VuYWJsZWQ6IHRydWUKICBwcm90ZWN0aW9uX2VuYWJsZWQ6IHRydWUKY2xpZW50czoKICBydW50aW1lX3NvdXJjZXM6CiAgICB3aG9pczogdHJ1ZQogICAgYXJwOiB0cnVlCiAgICByZG5zOiB0cnVlCiAgICBkaGNwOiB0cnVlCiAgICBob3N0czogdHJ1ZQogIHBlcnNpc3RlbnQ6IFtdCmxvZzoKICBmaWxlOiAiIgogIG1heF9hZ2U6IDMKICBtYXhfYmFja3VwczogMAogIG1heF9zaXplOiAxMDAKICBjb21wcmVzczogZmFsc2UKICBlbmFibGVkOiB0cnVlCiAgbG9jYWxfdGltZTogZmFsc2UKICB2ZXJib3NlOiBmYWxzZQpvczoKICBncm91cDogIiIKICB1c2VyOiAiIgogIHJsaW1pdF9ub2ZpbGU6IDAKc2NoZW1hX3ZlcnNpb246IDM1Cg==
CEOF
base64 -d /opt/adguardhome/conf/AdGuardHome.yaml.b64 > /opt/adguardhome/conf/AdGuardHome.yaml
rm -f /opt/adguardhome/conf/AdGuardHome.yaml.b64

echo "[4/6] 注册 systemd 服务..."
cat > /etc/systemd/system/adguardhome.service <<'SEOF'
[Unit]
Description=AdGuard Home
After=network-online.target
Wants=network-online.target
[Service]
Type=simple
ExecStart=/opt/adguardhome/agh -c /opt/adguardhome/conf/AdGuardHome.yaml -w /opt/adguardhome/work --no-check-update
Restart=on-failure
RestartSec=5
LimitNOFILE=1048576
[Install]
WantedBy=multi-user.target
SEOF
systemctl daemon-reload
systemctl enable adguardhome
systemctl restart adguardhome

echo "[5/6] 放行本机防火墙..."
(command -v ufw >/dev/null && ufw allow 53/tcp && ufw allow 53/udp && ufw allow 3000/tcp) >/dev/null 2>&1 || true

echo "[6/6] 等待服务就绪..."
sleep 6
systemctl is-active adguardhome && echo "服务运行中"
IP=$(curl -s --max-time 5 ifconfig.me 2>/dev/null || echo "你的公网IP")
echo ""
echo "=================================="
echo " 部署完成！"
echo " 管理页: http://$IP:3000"
echo " 账号: admin / Admin123456"
echo " DNS  : $IP:53"
echo ""
echo " [重要] 阿里云安全组放行入方向:"
echo "    TCP 3000  /  TCP 53  /  UDP 53"
echo " 首次加载50万规则需3-5分钟，请稍后访问。"
echo "=================================="
