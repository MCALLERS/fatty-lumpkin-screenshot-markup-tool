import importlib.util
import json
import os
from pathlib import Path
import struct
import tempfile
import threading
import time
import unittest
import urllib.error
import urllib.request
import uuid
import zlib

ROOT = Path(__file__).resolve().parents[1]
spec = importlib.util.spec_from_file_location('companion', ROOT / 'Companion/server.py')
module = importlib.util.module_from_spec(spec)
spec.loader.exec_module(module)

def png(red, width=12, height=8):
    def chunk(kind, payload):
        return struct.pack('>I', len(payload)) + kind + payload + struct.pack('>I', zlib.crc32(kind + payload) & 0xffffffff)
    pixels = (b'\0' + (bytes([red, 0, 255-red]) * width)) * height
    return b'\x89PNG\r\n\x1a\n' + chunk(b'IHDR', struct.pack('>IIBBBBB', width, height, 8, 2, 0, 0, 0)) + chunk(b'IDAT', zlib.compress(pixels)) + chunk(b'IEND', b'')

class CompanionTest(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        root = Path(self.temp.name)
        self.store = module.Store(root / 'library', root / 'state', token='test-only-token')
        self.original = self.store.library / 'Inbox/capture.png'
        self.original.write_bytes(png(255))
        os.utime(self.original, (time.time()-2, time.time()-2))
        self.server = module.Server(('127.0.0.1', 0), module.Handler)
        self.server.store = self.store
        self.server.assets = ROOT / 'Companion'
        self.host = '127.0.0.1:' + str(self.server.server_port)
        self.server.hosts = {self.host}
        self.thread = threading.Thread(target=self.server.serve_forever, daemon=True)
        self.thread.start()
        self.key = self.store.captures()[0]['id']

    def tearDown(self):
        self.server.shutdown(); self.server.server_close(); self.thread.join()
        self.temp.cleanup()

    def request(self, path, body=None, headers=None, auth=True):
        hdr = {'Authorization': 'Bearer test-only-token'} if auth else {}
        hdr.update(headers or {})
        request = urllib.request.Request('http://' + self.host + path, data=body, headers=hdr)
        try:
            with urllib.request.urlopen(request) as response:
                return response.status, response.read(), response.headers
        except urllib.error.HTTPError as error:
            return error.code, error.read(), error.headers

    def save(self, body=None, key=None, request_id=None):
        return self.request('/api/save', body or png(0), {'X-Capture-ID': key or self.key, 'X-Submission-ID': request_id or str(uuid.uuid4())})

    def test_pairing_required_for_images_and_saves(self):
        self.assertEqual(self.request('/api/library', auth=False)[0], 401)
        self.assertEqual(self.request('/api/image/' + self.key, auth=False)[0], 401)
        self.assertEqual(self.request('/api/save', png(0), auth=False)[0], 401)
        status, _, headers = self.request('/api/pair', b'{}')
        self.assertEqual(status, 200)
        self.assertIn('HttpOnly', headers['Set-Cookie'])
        self.assertIn('SameSite=Strict', headers['Set-Cookie'])
        cookie = headers['Set-Cookie'].split(';')[0]
        self.assertEqual(self.request('/api/library', headers={'Cookie': cookie}, auth=False)[0], 200)

    def test_cross_origin_and_unrecognized_hosts_rejected(self):
        self.assertEqual(self.request('/api/library', headers={'Origin':'https://untrusted.example'})[0], 403)
        self.assertEqual(self.request('/api/library', headers={'Host':'untrusted.example'})[0], 403)
        self.assertEqual(self.request('/api/image/../../state/pairing-token')[0], 404)

    def test_save_preserves_original_and_retry_is_idempotent(self):
        request_id = str(uuid.uuid4())
        before = self.original.read_bytes()
        status, data, _ = self.save(request_id=request_id)
        self.assertEqual(status, 200)
        result = json.loads(data)
        self.assertEqual((self.store.library / 'Ready' / result['filename']).read_bytes(), png(0))
        self.assertEqual(self.original.read_bytes(), before)
        retry = self.save(request_id=request_id)
        self.assertEqual(json.loads(retry[1]), result)
        self.assertEqual(len(list((self.store.library / 'Ready').glob('*.png'))), 1)
        self.assertEqual(self.save(body=png(64), request_id=request_id)[0], 400)

    def test_broken_uploads_and_wrong_dimensions_not_saved(self):
        self.assertEqual(self.save(body=png(0)[:-4])[0], 400)
        self.assertEqual(self.save(body=png(0, width=11))[0], 400)
        self.assertEqual(self.save(body=b'not a PNG')[0], 400)
        self.assertEqual(self.save(key='a'*24)[0], 400)
        self.assertFalse(list((self.store.library / 'Ready').glob('*.png')))

    def test_symlink_does_not_expose_other_files(self):
        (self.store.library / 'Inbox/outside.png').symlink_to(self.original)
        self.assertEqual(len(self.store.captures()), 1)

    def test_clipboard_ack_is_separate_from_saved_file(self):
        status, data, _ = self.save()
        result = json.loads(data)
        self.assertEqual(status, 200)
        self.assertIsNone(json.loads(self.request('/api/status')[1])['lastCopied'])
        module.atomic_json(self.store.state / 'clipboard-ack.json', {'id': result['id']})
        self.assertEqual(json.loads(self.request('/api/status')[1])['lastCopied'], result['id'])

    def test_finished_captures_remain_finished_after_restart(self):
        self.assertFalse(json.loads(self.request('/api/library')[1])['captures'][0]['saved'])
        self.assertEqual(self.save()[0], 200)
        restarted = module.Store(self.store.library, self.store.state, token='test-only-token')
        self.assertTrue(restarted.captures()[0]['saved'])

    def test_moving_library_preserves_capture_identity(self):
        destination = self.store.library.parent / 'moved-library'
        self.store.library.rename(destination)
        moved = module.Store(destination, self.store.state, token='test-only-token')
        self.assertEqual(moved.captures()[0]['id'], self.key)

if __name__ == '__main__':
    unittest.main()
