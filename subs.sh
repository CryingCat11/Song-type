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
