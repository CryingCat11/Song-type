#!/bin/bash
# Устанавливает игру «Допой строчку» на сервер: nginx отдаёт её на 80 порту.
# Повторный запуск обновляет игру до последней версии из репозитория.
set -e
SRC=https://raw.githubusercontent.com/CryingCat11/Song-type/main
export DEBIAN_FRONTEND=noninteractive
command -v nginx >/dev/null || { apt-get update -y && apt-get install -y nginx curl; }
mkdir -p /var/www/song-type
curl -fsSL "$SRC/index.html?t=$(date +%s)" -o /var/www/song-type/index.html
cat > /etc/nginx/sites-available/song-type <<'NG'
server {
  listen 80 default_server;
  listen [::]:80 default_server;
  root /var/www/song-type;
  index index.html;
  location / { try_files $uri /index.html; add_header Cache-Control "no-cache"; }
}
NG
rm -f /etc/nginx/sites-enabled/default
ln -sf /etc/nginx/sites-available/song-type /etc/nginx/sites-enabled/song-type
nginx -t
systemctl enable nginx >/dev/null 2>&1 || true
systemctl restart nginx
if command -v ufw >/dev/null && ufw status | grep -q "Status: active"; then ufw allow 80/tcp; fi
echo "ГОТОВО: http://$(hostname -I | cut -d' ' -f1)/"
