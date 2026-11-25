#!/bin/bash
set -e
echo "================================"
echo "   NEXUS DNS 一键部署"
echo "================================"
[ "$(id -u)" = "0" ] || { echo "请用 root 运行"; exit 1; }

echo "[1/6] 安装 Docker..."
if ! command -v docker >/dev/null 2>&1; then
  curl -fsSL https://get.docker.com | sh -s docker --mirror Aliyun
fi
systemctl enable --now docker 2>/dev/null || true
(command -v apt-get >/dev/null && apt-get install -y unzip curl openssl >/dev/null 2>&1) || true

echo "[2/6] 释放 53 端口..."
if systemctl is-active systemd-resolved >/dev/null 2>&1; then
  systemctl stop systemd-resolved; systemctl disable systemd-resolved
fi

echo "[3/6] 下载部署包..."
mkdir -p /opt/nexus-dns && cd /opt/nexus-dns
RAW="https://raw.githubusercontent.com/curtainzhc/dns-rules/main/panel/dns-panel.zip"
OK=0
for p in "https://gh-proxy.com/" "https://ghfast.top/" ""; do
  echo "  源: ${p:-直连}"
  if curl -fsSL --max-time 180 "${p}${RAW}" -o dns-panel.zip && [ -s dns-panel.zip ]; then OK=1; break; fi
done
[ "$OK" = "1" ] || { echo "下载失败"; exit 1; }

echo "[4/6] 解压与配置..."
unzip -oq dns-panel.zip
cd dns-panel
cp -f .env.example .env
TOKEN=$(openssl rand -hex 16 2>/dev/null || echo nexus$RANDOM)
sed -i "s/change-me-to-a-random-string/$TOKEN/" .env

echo "[5/6] 启动容器（首次拉50万规则约3-5分钟）..."
docker compose up -d --build

echo "[6/6] 放行本机防火墙..."
(command -v ufw >/dev/null && ufw allow 53/tcp && ufw allow 53/udp && ufw allow 3000/tcp) >/dev/null 2>&1 || true

IP=$(curl -s --max-time 5 ifconfig.me 2>/dev/null || echo "你的公网IP")
echo ""
echo "================================"
echo " 部署完成！"
echo " 面板: http://$IP:3000"
echo " 账号: admin / Admin123456"
echo " DNS : $IP:53"
echo ""
echo " [重要] 去阿里云控制台放行安全组端口:"
echo "    TCP 3000  /  TCP 53  /  UDP 53"
echo " 首次加载规则需3-5分钟，稍后访问面板。"
echo "================================"
