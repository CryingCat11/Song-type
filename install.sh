#!/bin/bash
# Устанавливает игру «Допой строчку» на сервер: nginx отдаёт её по HTTP.
# Повторный запуск обновляет игру до последней версии из репозитория.
set -e
SRC=https://raw.githubusercontent.com/CryingCat11/Song-type/main
export DEBIAN_FRONTEND=noninteractive
command -v nginx >/dev/null || { apt-get update -y && apt-get install -y nginx curl; }
command -v ss >/dev/null || apt-get install -y iproute2 >/dev/null
mkdir -p /var/www/song-type
curl -fsSL "$SRC/index.html?t=$(date +%s)" -o /var/www/song-type/index.html

systemctl stop nginx 2>/dev/null || true
# Порт 80, если он свободен; если занят другой программой — 8080.
PORT=80
if ss -ltnH "sport = :80" | grep -q .; then
  echo "Порт 80 занят другой программой:"; ss -ltnp "sport = :80" | tail -n +2
  PORT=8080
  if ss -ltnH "sport = :8080" | grep -q .; then PORT=8088; fi
  echo "Ставлю игру на порт $PORT"
fi
# IPv6 слушаем, только если он включён на сервере.
V6=""
if [ -f /proc/net/if_inet6 ] && [ "$(cat /proc/sys/net/ipv6/conf/all/disable_ipv6 2>/dev/null)" != "1" ]; then
  V6="listen [::]:$PORT;"
fi
cat > /etc/nginx/sites-available/song-type <<NG
server {
  listen $PORT;
  $V6
  root /var/www/song-type;
  index index.html;
  location / { try_files \$uri /index.html; add_header Cache-Control "no-cache"; }
}
NG
rm -f /etc/nginx/sites-enabled/default
ln -sf /etc/nginx/sites-available/song-type /etc/nginx/sites-enabled/song-type
nginx -t
systemctl enable nginx >/dev/null 2>&1 || true
if ! systemctl restart nginx; then
  echo "=== nginx не запустился, вот почему: ==="
  journalctl -xeu nginx.service --no-pager | grep -iE "emerg|error|fail" | tail -n 8
  exit 1
fi
if command -v ufw >/dev/null && ufw status | grep -q "Status: active"; then ufw allow $PORT/tcp; fi
IP=$(hostname -I | cut -d' ' -f1)
if [ "$PORT" = 80 ]; then echo "ГОТОВО: http://$IP/"; else echo "ГОТОВО: http://$IP:$PORT/"; fi
