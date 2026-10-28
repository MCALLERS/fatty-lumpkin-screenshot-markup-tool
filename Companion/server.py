#!/usr/bin/env python3
"""Paired local screenshot companion. Standard library only; no cloud service."""
import argparse
import hashlib
import hmac
import http.cookies
import ipaddress
import json
import os
from pathlib import Path
import re
import secrets
import signal
import stat
import struct
import subprocess
import threading
import time
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
from urllib.parse import urlsplit
import zlib

MAX_BODY = 40 * 1024 * 1024
ID = re.compile(r"^[a-f0-9]{24}$")
REQUEST_ID = re.compile(r"^[a-f0-9-]{36}$")
SESSION_REQUEST_ID = re.compile(r"^[a-f0-9]{8}-[a-f0-9]{4}-[a-f0-9]{4}-[a-f0-9]{4}-[a-f0-9]{12}$", re.IGNORECASE)

class StalePreview(ValueError):
    pass

def atomic_json(path, value):
    temp = path.with_suffix('.tmp')
    temp.write_text(json.dumps(value))
    os.chmod(temp, 0o600)
    temp.replace(path)

def png_size(data, complete=False):
    if len(data) < 33 or data[:8] != b'\x89PNG\r\n\x1a\n' or data[12:16] != b'IHDR':
        raise ValueError('A PNG image is required.')
    w, h = struct.unpack('>II', data[16:24])
    if not 0 < w <= 16000 or not 0 < h <= 16000 or w * h > 40000000:
        raise ValueError('Image is too large. Capture a smaller area.')
    if complete:
        offset, has_pixels, ended = 8, False, False
        while offset + 12 <= len(data):
            length = struct.unpack('>I', data[offset:offset+4])[0]
            end = offset + 12 + length
            if end > len(data):
                raise ValueError('The image upload was incomplete.')
            kind = data[offset+4:offset+8]
            payload = data[offset+4:offset+8+length]
            checksum = struct.unpack('>I', data[offset+8+length:end])[0]
            if zlib.crc32(payload) & 0xffffffff != checksum:
                raise ValueError('The image upload was damaged.')
            has_pixels |= kind == b'IDAT'
            offset = end
            if kind == b'IEND':
                ended = length == 0 and offset == len(data)
                break
        if not has_pixels or not ended:
            raise ValueError('The image upload was incomplete.')
    return w, h

class Store:
    def __init__(self, library, state, token=None):
        self.library, self.state = Path(library), Path(state)
        self.state.mkdir(parents=True, exist_ok=True)
        os.chmod(self.state, 0o700)
        self.receipts = self.state / 'receipts'
        self.receipts.mkdir(exist_ok=True)
        for folder in ('Inbox', 'Annotated', 'Ready'):
            (self.library / folder).mkdir(parents=True, exist_ok=True)
        token_path = self.state / 'pairing-token'
        if token is None:
            if not token_path.exists():
                token_path.write_text(secrets.token_urlsafe(32))
                os.chmod(token_path, 0o600)
            token = token_path.read_text().strip()
        self.token = token
        self.lock = threading.RLock()
        self.trash = Path.home() / '.Trash'
        self.cleanup_previews = {}
        self.last_seen = 0
        session_path = self.state / 'sessions.json'
        if session_path.exists():
            # Do not silently forget previous-session boundaries if state is damaged.
            session_state = json.loads(session_path.read_text())
            self.session = session_state['session']
            self.archived = set(session_state['archived'])
            self.reset_receipts = session_state['resets']
        else:
            self.session = dict(id=secrets.token_hex(16), startedAt=time.time())
            self.archived, self.reset_receipts = set(), {}
            self.persist_sessions()
        try:
            self.capture_ids = json.loads((self.state / 'capture-identities.json').read_text())
        except (OSError, ValueError):
            self.capture_ids = {}
        self.completed = set()
        for receipt in self.receipts.glob('*.json'):
            try:
                result = json.loads(receipt.read_text())
                if ID.fullmatch(result.get('source', '')):
                    self.completed.add(result['source'])
            except (OSError, ValueError, TypeError):
                continue

    def persist_sessions(self):
        atomic_json(self.state / 'sessions.json', dict(session=self.session, archived=sorted(self.archived), resets=self.reset_receipts))

    def safe_folder(self, folder):
        return not self.library.is_symlink() and not folder.is_symlink() and folder.is_dir()

    def files(self, folders=('Inbox', 'Annotated', 'Ready')):
        """All top-level PNGs, including captures outside the UI's hundred-image window."""
        files = []
        for name in folders:
            folder = self.library / name
            if not self.safe_folder(folder):
                continue
            for path in folder.glob('*.png'):
                try:
                    info = path.lstat()
                    if not stat.S_ISREG(info.st_mode):
                        continue
                    relative = str(path.relative_to(self.library))
                    identity = relative + '|' + str(info.st_mtime_ns) + '|' + str(info.st_ino)
                    # Size and change time also guard cleanup against in-place changes.
                    signature = (identity, info.st_size, info.st_ctime_ns, info.st_dev)
                    files.append(dict(path=path, relative=relative, identity=identity, signature=signature, size=info.st_size, modified=info.st_mtime))
                except OSError:
                    continue
        return files

    def captures(self, historical=False):
        with self.lock:
            return self._captures(historical)

    def _captures(self, historical=False):
        captures = []
        files = self.files(('Inbox',))
        # The existing Pencil test is available until the first real capture.
        if not files or historical:
            files += self.files(('Annotated',))
        for item in files:
            path, identity = item['path'], item['identity']
            try:
                if (not historical and identity in self.archived) or time.time() - item['modified'] < .7 or item['size'] > MAX_BODY:
                    continue
                with os.fdopen(os.open(path, os.O_RDONLY | os.O_NOFOLLOW), 'rb') as handle:
                    w, h = png_size(handle.read(33))
                key = self.capture_ids.get(identity) or hashlib.sha256(identity.encode()).hexdigest()[:24]
                captures.append(dict(id=key, title=path.stem, width=w, height=h, modified=item['modified'], saved=key in self.completed, path=path))
            except (OSError, ValueError):
                continue
        captures.sort(key=lambda x: x['modified'], reverse=True)
        return captures if historical else captures[:100]

    def library_response(self):
        with self.lock:
            return dict(captures=[{k: v for k, v in item.items() if k != 'path'} for item in self.captures()], session=self.session, supportsSessions=True)

    def reset_session(self, request_id):
        if not isinstance(request_id, str) or not SESSION_REQUEST_ID.fullmatch(request_id):
            raise ValueError('Invalid session request.')
        with self.lock:
            if request_id in self.reset_receipts:
                return self.reset_receipts[request_id]
            archived = self.archived | {item['identity'] for item in self.files()}
            session = dict(id=secrets.token_hex(16), startedAt=time.time())
            result = dict(session=session, captures=[], supportsSessions=True)
            # Persist the boundary and retry receipt together before publishing either.
            atomic_json(self.state / 'sessions.json', dict(session=session, archived=sorted(archived), resets={**self.reset_receipts, request_id: result}))
            self.session, self.archived = session, archived
            self.reset_receipts[request_id] = result
            return result

    def previous_files(self):
        return [item for item in self.files() if item['identity'] in self.archived]

    def cleanup_preview(self):
        with self.lock:
            now = time.time()
            self.cleanup_previews = {key: item for key, item in self.cleanup_previews.items() if item['expires'] > now}
            # Bound an authenticated client's outstanding confirmations.
            if len(self.cleanup_previews) >= 32:
                self.cleanup_previews.pop(next(iter(self.cleanup_previews)))
            files = self.previous_files()
            token = secrets.token_urlsafe(32)
            self.cleanup_previews[token] = dict(files=files, expires=now+300)
            return dict(token=token, captureCount=sum(not item['relative'].startswith('Ready/') for item in files), fileCount=len(files), byteCount=sum(item['size'] for item in files))

    def cleanup(self, token):
        with self.lock:
            preview = self.cleanup_previews.get(token) if isinstance(token, str) else None
            if not preview or preview['expires'] < time.time():
                raise StalePreview('This cleanup preview expired. Review the previous sessions again.')
            if 'result' in preview:
                return preview['result']
            files = self.previous_files()
            expected = sorted(item['signature'] for item in preview['files'])
            if sorted(item['signature'] for item in files) != expected:
                raise StalePreview('The previous sessions changed. Review the updated file count before moving them to Trash.')
            moved = []
            if files:
                if self.trash.is_symlink():
                    raise ValueError('The Mac Trash folder is unavailable. Manage older screenshots in Finder instead.')
                self.trash.mkdir(mode=0o700, exist_ok=True)
                batch = self.trash / ('Fatty Lumpkin ' + time.strftime('%Y-%m-%d %H.%M.%S') + ' ' + secrets.token_hex(6))
                batch.mkdir(mode=0o700)
                try:
                    for item in files:
                        destination = batch / item['relative']
                        destination.parent.mkdir(mode=0o700, exist_ok=True)
                        # rename is atomic and never permanently deletes the original.
                        # Libraries on another volume remain untouched on EXDEV.
                        item['path'].rename(destination)
                        moved.append((item, destination))
                except OSError as error:
                    # Roll back a partially moved batch where possible; never overwrite
                    # files newly created by the screenshot service or by the user.
                    for item, destination in reversed(moved):
                        try:
                            if not item['path'].exists():
                                destination.rename(item['path'])
                        except OSError:
                            pass  # Any remainder is safely recoverable in Mac Trash.
                    raise ValueError('The Mac could not finish moving these files to Trash. Check Finder and review the library again.') from error
            result = dict(movedFiles=len(files), movedBytes=sum(item['size'] for item in files))
            preview['result'] = result
            return result

    def find(self, key):
        # An in-progress drawing on another client survives a session reset.
        return next((x for x in self.captures(historical=True) if x['id'] == key), None)

    def image(self, key):
        with self.lock:
            item = self.find(key)
            if item:
                try:
                    with os.fdopen(os.open(item['path'], os.O_RDONLY | os.O_NOFOLLOW), 'rb') as handle:
                        return handle.read(MAX_BODY + 1)
                except OSError:
                    pass
            return None

    def save(self, key, request_id, data):
        if not ID.fullmatch(key or '') or not REQUEST_ID.fullmatch(request_id or ''):
            raise ValueError('Invalid save request.')
        digest = hashlib.sha256(data).hexdigest()
        with self.lock:
            receipt = self.receipts / (request_id + '.json')
            if receipt.exists():
                result = json.loads(receipt.read_text())
                if result['source'] != key or result['digest'] != digest:
                    raise ValueError('This save identifier belongs to a different image.')
                return result
            source = self.find(key)
            if source is None:
                raise ValueError('The original image has moved or changed. Your drawing is still on this iPad.')
            if png_size(data, complete=True) != (source['width'], source['height']):
                raise ValueError('The image dimensions changed. Please try again.')
            filename = time.strftime('%Y-%m-%d %H.%M.%S') + ' — annotated ' + request_id[:8] + '.png'
            if not self.safe_folder(self.library / 'Ready'):
                raise ValueError('The Ready folder is unavailable. Check the screenshot library on your Mac.')
            destination = self.library / 'Ready' / filename
            temp = destination.with_suffix('.upload')
            temp.write_bytes(data)
            temp.replace(destination)
            result = dict(id=request_id, source=key, digest=digest, filename=filename, savedAt=time.time())
            atomic_json(receipt, result)
            atomic_json(self.state / 'last-completion.json', result)
            self.completed.add(key)
            source_identity = next((item['identity'] for item in self.files() if item['path'] == source['path']), None)
            if source_identity in self.archived:
                self.archived.update(item['identity'] for item in self.files(('Ready',)) if item['path'] == destination)
                self.persist_sessions()
            return result

class Server(ThreadingHTTPServer):
    daemon_threads = True
    allow_reuse_address = True

class Handler(BaseHTTPRequestHandler):
    server_version = 'ScreenshotTool'
    def log_message(self, *args):
        pass  # Never record URLs, screenshots, pairing secrets, or cookies.

    def setup(self):
        super().setup()
        self.connection.settimeout(20)

    @property
    def store(self):
        return self.server.store

    def response(self, status, body=b'', kind='application/json', cookie=None):
        if isinstance(body, dict):
            body = json.dumps(body).encode()
        self.send_response(status)
        self.send_header('Content-Type', kind)
        self.send_header('Content-Length', str(len(body)))
        self.send_header('Cache-Control', 'no-store')
        self.send_header('X-Content-Type-Options', 'nosniff')
        self.send_header('Referrer-Policy', 'no-referrer')
        self.send_header('Content-Security-Policy', "default-src 'self'; script-src 'self'; style-src 'self'; img-src 'self' blob: data:; connect-src 'self'; frame-ancestors 'none'; base-uri 'none'; form-action 'self'")
        if cookie:
            self.send_header('Set-Cookie', cookie)
        self.end_headers()
        self.wfile.write(body)

    def safe_request(self):
        host = self.headers.get('Host', '')
        if host not in self.server.hosts:
            self.response(403, {'error': 'Unrecognized host.'})
            return False
        origin = self.headers.get('Origin')
        if origin and origin != 'http://' + host:
            self.response(403, {'error': 'Cross-site requests are not allowed.'})
            return False
        return True

    def authorized(self):
        value = self.headers.get('Authorization', '').removeprefix('Bearer ')
        try:
            cookies = http.cookies.SimpleCookie(self.headers.get('Cookie', ''))
            if 'screenshot_pair' in cookies:
                value = cookies['screenshot_pair'].value
        except http.cookies.CookieError:
            value = ''
        return hmac.compare_digest(value, self.store.token)

    def do_GET(self):
        if not self.safe_request():
            return
        path = urlsplit(self.path).path
        assets = {'/brandmark.png': ('brandmark.png', 'image/png'), '/pony.png': ('brandmark.png', 'image/png'), '/': ('index.html', 'text/html; charset=utf-8'), '/app.js': ('app.js', 'text/javascript; charset=utf-8'), '/style.css': ('style.css', 'text/css; charset=utf-8')}
        if path in assets:
            file, kind = assets[path]
            return self.response(200, (self.server.assets / file).read_bytes(), kind)
        if not self.authorized():
            return self.response(401, {'error': 'Pair this iPad using the QR code in Screenshot Tool on your Mac.'})
        if path == '/api/library':
            self.store.last_seen = time.time()
            return self.response(200, self.store.library_response())
        if path == '/api/library/cleanup':
            return self.response(200, self.store.cleanup_preview())
        if path == '/api/status':
            try:
                copied = json.loads((self.store.state / 'clipboard-ack.json').read_text()).get('id')
            except (OSError, ValueError):
                copied = None
            return self.response(200, {'lastSeen': self.store.last_seen, 'lastCopied': copied})
        if path.startswith('/api/image/') and ID.fullmatch(path.rsplit('/', 1)[-1]):
            data = self.store.image(path.rsplit('/', 1)[-1])
            if data:
                return self.response(200, data, 'image/png')
        self.response(404, {'error': 'Image not found.'})

    def do_POST(self):
        if not self.safe_request():
            return
        path = urlsplit(self.path).path
        try:
            length = int(self.headers.get('Content-Length', '0'))
        except ValueError:
            return self.response(400, {'error': 'Invalid upload length.'})
        if not 0 < length <= MAX_BODY:
            return self.response(413, {'error': 'The image is too large. Capture a smaller area.'})
        if not self.authorized():
            return self.response(401, {'error': 'This iPad needs to be paired again.'})
        if path in ('/api/session/reset', '/api/library/cleanup'):
            if length > 1024:
                return self.response(400, {'error': 'Invalid library request.'})
            try:
                data = self.rfile.read(length)
                if len(data) != length:
                    raise ValueError('The request was interrupted. Try again.')
                payload = json.loads(data)
                field = 'requestID' if path == '/api/session/reset' else 'token'
                if not isinstance(payload, dict) or set(payload) != {field}:
                    raise ValueError('Invalid library request.')
                result = self.store.reset_session(payload[field]) if field == 'requestID' else self.store.cleanup(payload[field])
                return self.response(200, result)
            except StalePreview as error:
                return self.response(409, {'error': str(error)})
            except (ValueError, UnicodeError) as error:
                return self.response(400, {'error': str(error)})
            except OSError:
                return self.response(400, {'error': 'The Mac could not update the library. Check file permissions and available storage.'})
        if path == '/api/pair':
            if length > 128:
                return self.response(400, {'error': 'Invalid pairing request.'})
            self.rfile.read(length)
            cookie = 'screenshot_pair=' + self.store.token + '; Path=/; HttpOnly; SameSite=Strict; Max-Age=31536000'
            return self.response(200, {'paired': True}, cookie=cookie)
        if path == '/api/save':
            data = self.rfile.read(length)
            if len(data) != length:
                return self.response(400, {'error': 'The upload was interrupted. Try Done again.'})
            try:
                result = self.store.save(self.headers.get('X-Capture-ID'), self.headers.get('X-Submission-ID'), data)
                return self.response(200, result)
            except ValueError as error:
                return self.response(400, {'error': str(error)})
        self.response(404, {'error': 'Not found.'})

def lan_address():
    for interface in ('en0', 'en1'):
        result = subprocess.run(['/usr/sbin/ipconfig', 'getifaddr', interface], capture_output=True, text=True)
        value = result.stdout.strip()
        try:
            if ipaddress.ip_address(value).is_private and not ipaddress.ip_address(value).is_loopback:
                return value
        except ValueError:
            pass
    return None

def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('--library', required=True)
    parser.add_argument('--state', required=True)
    parser.add_argument('--parent', type=int)
    parser.add_argument('--assets', type=Path, default=Path(__file__).parent)
    args = parser.parse_args()
    store = Store(args.library, args.state)
    lan = lan_address()
    servers = []
    for port in range(8765, 8786):
        try:
            servers = [Server(('127.0.0.1', port), Handler)]
            if lan:
                servers.append(Server((lan, port), Handler))
            break
        except OSError:
            for server in servers:
                server.server_close()
            servers = []
    if not servers:
        raise SystemExit('No available local port.')
    hosts = {'127.0.0.1:' + str(port)}
    if lan:
        hosts.add(lan + ':' + str(port))
    for server in servers:
        server.store, server.hosts, server.assets = store, hosts, args.assets
        threading.Thread(target=server.serve_forever, daemon=True).start()
    atomic_json(store.state / 'server.json', dict(pid=os.getpid(), port=port, lan=lan, token=store.token))
    stop = threading.Event()
    signal.signal(signal.SIGTERM, lambda *args: stop.set())
    signal.signal(signal.SIGINT, lambda *args: stop.set())
    while not stop.wait(1):
        if args.parent and os.getppid() != args.parent:
            break
    for server in servers:
        server.shutdown()
        server.server_close()

if __name__ == '__main__':
    main()
