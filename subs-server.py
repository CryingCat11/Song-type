#!/usr/bin/env python3
"""Отдаёт субтитры YouTube для игры. Если файла ещё нет, скачивает его через yt-dlp.
Слушает только 127.0.0.1:8090, nginx передаёт сюда запросы /subs/<id>.<ru|en>.json3, которых нет на диске."""
import os, re, subprocess, threading, time, glob, shutil
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
DIR = '/var/www/song-type/subs'
LOCK = threading.Lock()
PAT = re.compile(r'^/subs/([A-Za-z0-9_-]{11})\.(ru|en)\.json3$')

def fetch(vid):
    none = os.path.join(DIR, vid + '.none')
    if os.path.exists(none) and time.time() - os.path.getmtime(none) < 6 * 3600:
        return
    tmp = '/tmp/ss_' + vid
    for f in glob.glob(tmp + '.*'):
        os.remove(f)
    try:
        subprocess.run(['/usr/local/bin/yt-dlp', '--quiet', '--no-warnings', '--skip-download',
                        '--write-subs', '--write-auto-subs', '--sub-langs', 'ru-orig,ru,en-orig,en',
                        '--sub-format', 'json3', '-o', tmp, '--', vid], timeout=90)
    except Exception:
        pass
    got = False
    for l in ('ru', 'en'):
        for src in (tmp + '.' + l + '-orig.json3', tmp + '.' + l + '.json3'):
            if os.path.exists(src):
                shutil.copy(src, os.path.join(DIR, vid + '.' + l + '.json3'))
                os.chmod(os.path.join(DIR, vid + '.' + l + '.json3'), 0o644)
                got = True
                break
    if not got:
        open(none, 'w').close()

class H(BaseHTTPRequestHandler):
    def do_GET(self):
        m = PAT.match(self.path.split('?')[0])
        if not m:
            return self.send_error(404)
        vid, lang = m.groups()
        path = os.path.join(DIR, vid + '.' + lang + '.json3')
        if not os.path.exists(path):
            with LOCK:  # one download at a time, so YouTube doesn't answer "too many requests"
                if not os.path.exists(path):
                    fetch(vid)
        if not os.path.exists(path):
            return self.send_error(404)
        data = open(path, 'rb').read()
        self.send_response(200)
        self.send_header('Content-Type', 'application/json')
        self.send_header('Content-Length', str(len(data)))
        self.end_headers()
        self.wfile.write(data)
    def log_message(self, *a):
        pass

os.makedirs(DIR, exist_ok=True)
ThreadingHTTPServer(('127.0.0.1', 8090), H).serve_forever()
