#!/bin/bash
# Даёт игре адрес с https через уже установленный Caddy: https://201-58-142-13.sslip.io
# Существующие сайты в Caddyfile не трогает. Если проверка конфига не прошла, всё откатывает.
set -e
IP=$(hostname -I | tr ' ' '\n' | grep -m1 -E '^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$')
DOMAIN="$(echo "$IP" | tr . -).sslip.io"
CF=/etc/caddy/Caddyfile
cp "$CF" "$CF.bak-song-type"
if ! grep -q "$DOMAIN" "$CF"; then
  printf '\n%s {\n\tencode gzip\n\treverse_proxy 127.0.0.1:8080\n}\n' "$DOMAIN" >> "$CF"
fi
if caddy validate --config "$CF" --adapter caddyfile >/dev/null 2>&1; then
  systemctl reload caddy
  sleep 8
  echo "ГОТОВО: https://$DOMAIN/"
else
  cp "$CF.bak-song-type" "$CF"
  echo "Конфиг Caddy не прошёл проверку, вернул как было:"; caddy validate --config "$CF" --adapter caddyfile 2>&1 | tail -3
  exit 1
fi
