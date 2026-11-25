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

echo "[3/6] 写入配置（账号 admin / 国内上游DNS）..."
cat > /opt/adguardhome/conf/AdGuardHome.yaml.b64 <<'CEOF'
aHR0cDoKICBkb2g6CiAgICByb3V0ZXM6CiAgICAgIC0gR0VUIC9kbnMtcXVlcnkKICAgICAgLSBQT1NUIC9kbnMtcXVlcnkKICAgICAgLSBHRVQgL2Rucy1xdWVyeS97Q2xpZW50SUR9CiAgICAgIC0gUE9TVCAvZG5zLXF1ZXJ5L3tDbGllbnRJRH0KICAgIGluc2VjdXJlX2VuYWJsZWQ6IGZhbHNlCiAgcHByb2Y6CiAgICBwb3J0OiA2MDYwCiAgICBlbmFibGVkOiBmYWxzZQogIGFkZHJlc3M6IDAuMC4wLjA6MzAwMAogIHNlc3Npb25fdHRsOiAzMGQKdXNlcnM6CiAgLSBuYW1lOiBhZG1pbgogICAgcGFzc3dvcmQ6ICQyYSQxMCQycklXdHpkR2RJNGxTNDk1di94RVIuNHFPSnNNeW9tTG1QMmdHdnRhWDY2aUQ3THFNQ3Y1QwphdXRoX2F0dGVtcHRzOiA1CmJsb2NrX2F1dGhfbWluOiAxNQpodHRwX3Byb3h5OiAiIgpsYW5ndWFnZTogemhfY24KdGhlbWU6IGF1dG8KZG5zOgogIGVkbnNfY2xpZW50X3N1Ym5ldDoKICAgIGN1c3RvbV9pcDogIiIKICAgIGVuYWJsZWQ6IGZhbHNlCiAgICB1c2VfY3VzdG9tOiBmYWxzZQogIHBlbmRpbmdfcmVxdWVzdHM6CiAgICBlbmFibGVkOiB0cnVlCiAgaXBzZXRfZmlsZTogIiIKICB1cHN0cmVhbV9kbnNfZmlsZTogIiIKICB1cHN0cmVhbV9tb2RlOiBsb2FkX2JhbGFuY2UKICBiaW5kX2hvc3RzOgogICAgLSAwLjAuMC4wCiAgcmF0ZWxpbWl0X3doaXRlbGlzdDogW10KICBkbnM2NF9wcmVmaXhlczogW10KICBwcml2YXRlX25ldHdvcmtzOiBbXQogIHRydXN0ZWRfcHJveGllczoKICAgIC0gMTI3LjAuMC4wLzgKICAgIC0gOjoxLzEyOAogIGFsbG93ZWRfY2xpZW50czogW10KICBibG9ja2VkX2hvc3RzOgogICAgLSB2ZXJzaW9uLmJpbmQKICAgIC0gaWQuc2VydmVyCiAgICAtIGhvc3RuYW1lLmJpbmQKICBib2d1c19ueGRvbWFpbjogW10KICBib290c3RyYXBfZG5zOgogICAgLSAxLjAuMC4xCiAgICAtIDEuMS4xLjEKICAgIC0gMjYwNjo0NzAwOjQ3MDA6OjEwMDEKICAgIC0gMjYwNjo0NzAwOjQ3MDA6OjExMTEKICBkaXNhbGxvd2VkX2NsaWVudHM6IFtdCiAgZmFsbGJhY2tfZG5zOiBbXQogIGlwc2V0OiBbXQogIGxvY2FsX3B0cl91cHN0cmVhbXM6IFtdCiAgdXBzdHJlYW1fZG5zOgogICAgLSBodHRwczovL2RvaC5wdWIvZG5zLXF1ZXJ5CiAgICAtIGh0dHBzOi8vZG5zLmFsaWRucy5jb20vZG5zLXF1ZXJ5CiAgICAtIHRsczovLzIyMy41LjUuNQogIGNhY2hlX29wdGltaXN0aWNfYW5zd2VyX3R0bDogMzBzCiAgY2FjaGVfb3B0aW1pc3RpY19tYXhfYWdlOiAxMmgKICBmYXN0ZXN0X3RpbWVvdXQ6IDFzCiAgdXBzdHJlYW1fdGltZW91dDogMTBzCiAgbWF4X2dvcm91dGluZXM6IDMwMAogIHJhdGVsaW1pdF9zdWJuZXRfbGVuX2lwdjQ6IDI0CiAgcmF0ZWxpbWl0X3N1Ym5ldF9sZW5faXB2NjogNTYKICBjYWNoZV90dGxfbWF4OiAwCiAgY2FjaGVfdHRsX21pbjogMAogIGNhY2hlX3NpemU6IDQxOTQzMDQKICByYXRlbGltaXQ6IDIwCiAgcG9ydDogNTMKICBhYWFhX2Rpc2FibGVkOiBmYWxzZQogIGFub255bWl6ZV9jbGllbnRfaXA6IGZhbHNlCiAgYm9vdHN0cmFwX3ByZWZlcl9pcHY2OiBmYWxzZQogIGNhY2hlX2VuYWJsZWQ6IHRydWUKICBjYWNoZV9vcHRpbWlzdGljOiBmYWxzZQogIGVuYWJsZV9kbnNzZWM6IHRydWUKICBoYW5kbGVfZGRyOiB0cnVlCiAgaG9zdHNmaWxlX2VuYWJsZWQ6IHRydWUKICByZWZ1c2VfYW55OiB0cnVlCiAgc2VydmVfaHR0cDM6IGZhbHNlCiAgc2VydmVfcGxhaW5fZG5zOiB0cnVlCiAgdXNlX2RuczY0OiBmYWxzZQogIHVzZV9odHRwM191cHN0cmVhbXM6IGZhbHNlCiAgdXNlX3ByaXZhdGVfcHRyX3Jlc29sdmVyczogZmFsc2UKdGxzOgogIGVuYWJsZWQ6IGZhbHNlCiAgc2VydmVyX25hbWU6ICIiCiAgZm9yY2VfaHR0cHM6IGZhbHNlCiAgcG9ydF9odHRwczogNDQzCiAgcG9ydF9kbnNfb3Zlcl90bHM6IDg1MwogIHBvcnRfZG5zX292ZXJfcXVpYzogODUzCiAgcG9ydF9kbnNjcnlwdDogMAogIGRuc2NyeXB0X2NvbmZpZ19maWxlOiAiIgogIGNlcnRpZmljYXRlX2NoYWluOiAiIgogIHByaXZhdGVfa2V5OiAiIgogIGNlcnRpZmljYXRlX3BhdGg6ICIiCiAgcHJpdmF0ZV9rZXlfcGF0aDogIiIKICBzdHJpY3Rfc25pX2NoZWNrOiBmYWxzZQpxdWVyeWxvZzoKICBkaXJfcGF0aDogIiIKICBpZ25vcmVkOiBbXQogIGludGVydmFsOiA5MGQKICBzaXplX21lbW9yeTogMTAwMAogIGVuYWJsZWQ6IHRydWUKICBmaWxlX2VuYWJsZWQ6IHRydWUKICBpZ25vcmVkX2VuYWJsZWQ6IGZhbHNlCnN0YXRpc3RpY3M6CiAgZGlyX3BhdGg6ICIiCiAgaWdub3JlZDogW10KICBpbnRlcnZhbDogMWQKICBlbmFibGVkOiB0cnVlCiAgaWdub3JlZF9lbmFibGVkOiBmYWxzZQpmaWx0ZXJzOiBbXQp3aGl0ZWxpc3RfZmlsdGVyczogW10KdXNlcl9ydWxlczogW10KZGhjcDoKICBkaGNwdjQ6CiAgICBnYXRld2F5X2lwOiAiIgogICAgcmFuZ2Vfc3RhcnQ6ICIiCiAgICByYW5nZV9lbmQ6ICIiCiAgICBzdWJuZXRfbWFzazogIiIKICAgIG9wdGlvbnM6IFtdCiAgICBpY21wX3RpbWVvdXRfbXNlYzogMTAwMAogICAgbGVhc2VfZHVyYXRpb246IDg2NDAwCiAgZGhjcHY2OgogICAgcmFuZ2Vfc3RhcnQ6ICIiCiAgICBsZWFzZV9kdXJhdGlvbjogODY0MDAKICAgIHJhX3NsYWFjX29ubHk6IGZhbHNlCiAgICByYV9hbGxvd19zbGFhYzogZmFsc2UKICBpbnRlcmZhY2VfbmFtZTogIiIKICBsb2NhbF9kb21haW5fbmFtZTogbGFuCiAgZW5hYmxlZDogZmFsc2UKZmlsdGVyaW5nOgogIGJsb2NraW5nX2lwdjQ6ICIiCiAgYmxvY2tpbmdfaXB2NjogIiIKICBibG9ja2VkX3NlcnZpY2VzOgogICAgc2NoZWR1bGU6CiAgICAgIHRpbWVfem9uZTogVVRDCiAgICBpZHM6IFtdCiAgcHJvdGVjdGlvbl9kaXNhYmxlZF91bnRpbDogbnVsbAogIHNhZmVfc2VhcmNoOgogICAgZW5hYmxlZDogZmFsc2UKICAgIGJpbmc6IHRydWUKICAgIGR1Y2tkdWNrZ286IHRydWUKICAgIGVjb3NpYTogdHJ1ZQogICAgZ29vZ2xlOiB0cnVlCiAgICBwaXhhYmF5OiB0cnVlCiAgICB5YW5kZXg6IHRydWUKICAgIHlvdXR1YmU6IHRydWUKICBibG9ja2luZ19tb2RlOiBkZWZhdWx0CiAgcGFyZW50YWxfYmxvY2tfaG9zdDogZmFtaWx5LWJsb2NrLmRucy5hZGd1YXJkLmNvbQogIHNhZmVicm93c2luZ19ibG9ja19ob3N0OiBzdGFuZGFyZC1ibG9jay5kbnMuYWRndWFyZC5jb20KICByZXdyaXRlczogW10KICBzYWZlX2ZzX3BhdHRlcm5zOgogICAgLSAvb3B0L2FkZ3VhcmRob21lL3dvcmsvdXNlcmZpbHRlcnMvKgogIG1heF9odHRwX3NpemU6IDI1Nk1CCiAgc2FmZWJyb3dzaW5nX2NhY2hlX3NpemU6IDEwNDg1NzYKICBzYWZlc2VhcmNoX2NhY2hlX3NpemU6IDEwNDg1NzYKICBwYXJlbnRhbF9jYWNoZV9zaXplOiAxMDQ4NTc2CiAgY2FjaGVfdGltZTogMzAKICBmaWx0ZXJzX3VwZGF0ZV9pbnRlcnZhbDogMjQKICBibG9ja2VkX3Jlc3BvbnNlX3R0bDogMTAKICBmaWx0ZXJpbmdfZW5hYmxlZDogdHJ1ZQogIHJld3JpdGVzX2VuYWJsZWQ6IHRydWUKICBwYXJlbnRhbF9lbmFibGVkOiBmYWxzZQogIHNhZmVicm93c2luZ19lbmFibGVkOiB0cnVlCiAgcHJvdGVjdGlvbl9lbmFibGVkOiB0cnVlCmNsaWVudHM6CiAgcnVudGltZV9zb3VyY2VzOgogICAgd2hvaXM6IHRydWUKICAgIGFycDogdHJ1ZQogICAgcmRuczogdHJ1ZQogICAgZGhjcDogdHJ1ZQogICAgaG9zdHM6IHRydWUKICBwZXJzaXN0ZW50OiBbXQpsb2c6CiAgZmlsZTogIiIKICBtYXhfYWdlOiAzCiAgbWF4X2JhY2t1cHM6IDAKICBtYXhfc2l6ZTogMTAwCiAgY29tcHJlc3M6IGZhbHNlCiAgZW5hYmxlZDogdHJ1ZQogIGxvY2FsX3RpbWU6IGZhbHNlCiAgdmVyYm9zZTogZmFsc2UKb3M6CiAgZ3JvdXA6ICIiCiAgdXNlcjogIiIKICBybGltaXRfbm9maWxlOiAwCnNjaGVtYV92ZXJzaW9uOiAzNQo=
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
echo " 干净安装完成，登录管理页后自行添加订阅链接。"
echo "=================================="
