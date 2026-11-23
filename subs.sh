#!/bin/bash
# Скачивает субтитры YouTube (обычные или автоматические) для всех клипов игры.
# По ним игра узнаёт, на какой секунде клипа звучит каждое слово, и текст идёт точно под звук.
# Запуск: curl -fsSL https://raw.githubusercontent.com/CryingCat11/Song-type/main/subs.sh | bash -s <коммит>
REF=${1:-main}
SRC=https://raw.githubusercontent.com/CryingCat11/Song-type/$REF
DIR=/var/www/song-type
export DEBIAN_FRONTEND=noninteractive
set -e
curl -fsSL "$SRC/index.html?t=$(date +%s)" -o $DIR/index.html
echo "Игра обновлена до версии $REF"
command -v unzip >/dev/null || { apt-get update -y >/dev/null && apt-get install -y unzip >/dev/null; }
# yt-dlp (качает только субтитры, видео не трогает) и deno, который ему теперь нужен для YouTube
curl -fsSL https://github.com/yt-dlp/yt-dlp/releases/latest/download/yt-dlp_linux -o /usr/local/bin/yt-dlp
chmod +x /usr/local/bin/yt-dlp
command -v deno >/dev/null || curl -fsSL https://deno.land/install.sh | DENO_INSTALL=/usr/local sh -s -- -y >/dev/null 2>&1 || true
set +e
mkdir -p $DIR/subs
# Сервис, который сам докачивает субтитры, когда игра просит клип, которого ещё нет (в том числе для своих песен)
command -v python3 >/dev/null || apt-get install -y python3 >/dev/null
curl -fsSL "$SRC/subs-server.py?t=$(date +%s)" -o /usr/local/bin/song-subs.py
cat > /etc/systemd/system/song-subs.service <<UNIT
[Unit]
Description=Song-type subtitles
After=network.target
[Service]
ExecStart=/usr/bin/python3 /usr/local/bin/song-subs.py
Restart=always
[Install]
WantedBy=multi-user.target
UNIT
systemctl daemon-reload; systemctl enable song-subs >/dev/null 2>&1; systemctl restart song-subs
CONF=/etc/nginx/sites-available/song-type
if [ -f $CONF ] && ! grep -q "location /subs/" $CONF; then
  cp $CONF /tmp/song-type.nginx.bak
  sed -i 's|^\(\s*\)location / {|\1location /subs/ { try_files $uri @subs; add_header Cache-Control "no-cache"; }\n\1location @subs { proxy_pass http://127.0.0.1:8090; proxy_read_timeout 120s; }\n\1location / {|' $CONF
  if nginx -t 2>/dev/null; then systemctl reload nginx; echo "nginx: субтитры подключены"; else cp /tmp/song-type.nginx.bak $CONF; echo "nginx: не получилось, оставил как было"; fi
fi
sleep 1; systemctl is-active --quiet song-subs && echo "Сервис субтитров работает" || echo "Сервис субтитров НЕ запустился: $(journalctl -u song-subs -n 3 --no-pager)"
IDS=$(grep -o "yt:\[[^]]*\]" $DIR/index.html | grep -o "'[A-Za-z0-9_-]\{11\}'" | tr -d "'" | sort -u)
ok=0; bad=0
for id in $IDS; do
  if ls $DIR/subs/$id.*.json3 >/dev/null 2>&1; then ok=$((ok+1)); echo "уже есть $id"; continue; fi
  rm -f /tmp/st_$id.*
  yt-dlp --quiet --no-warnings --skip-download --write-subs --write-auto-subs \
    --sub-langs "ru-orig,ru,en-orig,en" --sub-format json3 -o "/tmp/st_%(id)s" "https://www.youtube.com/watch?v=$id" 2>/tmp/st_err
  got=""
  for l in ru en; do
    f=$(ls /tmp/st_$id.$l-orig.json3 /tmp/st_$id.$l.json3 2>/dev/null | head -1)
    [ -n "$f" ] && { cp "$f" $DIR/subs/$id.$l.json3; got="$got $l"; }
  done
  if [ -n "$got" ]; then ok=$((ok+1)); echo "OK  $id:$got"
  else bad=$((bad+1)); echo "нет $id: $(tail -1 /tmp/st_err)"; fi
  sleep 5
done
chmod -R a+r $DIR/subs
echo "Готово: субтитры есть у $ok клипов, нет у $bad."
