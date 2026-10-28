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
        self.store.trash = root / 'Trash'
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
            with error:
                return error.code, error.read(), error.headers

    def save(self, body=None, key=None, request_id=None):
        return self.request('/api/save', body or png(0), {'X-Capture-ID': key or self.key, 'X-Submission-ID': request_id or str(uuid.uuid4())})

    def json_request(self, path, payload=None, **kwargs):
        body = json.dumps(payload).encode() if payload is not None else None
        status, data, headers = self.request(path, body, {'Content-Type': 'application/json'}, **kwargs)
        return status, json.loads(data), headers

    def reset_session(self, request_id=None):
        return self.json_request('/api/session/reset', {'requestID': request_id or str(uuid.uuid4())})

    def new_capture(self, name='new.png'):
        path = self.store.library / 'Inbox' / name
        path.write_bytes(png(42))
        os.utime(path, (time.time()-2, time.time()-2))
        return path

    def test_session_reset_persists_and_preserves_all_originals_and_exports(self):
        self.assertEqual(self.save()[0], 200)
        before = {str(p.relative_to(self.store.library)): p.read_bytes() for p in self.store.library.glob('*/*.png')}
        old_session = self.json_request('/api/library')[1]['session']['id']
        status, reset, _ = self.reset_session()
        self.assertEqual(status, 200)
        self.assertNotEqual(reset['session']['id'], old_session)
        self.assertEqual(reset['captures'], [])
        self.assertTrue(reset['supportsSessions'])
        self.assertEqual(self.json_request('/api/library')[1]['captures'], [])
        restarted = module.Store(self.store.library, self.store.state, token='test-only-token')
        self.assertEqual(restarted.captures(), [])
        self.assertEqual(restarted.session['id'], reset['session']['id'])
        self.assertEqual(before, {str(p.relative_to(self.store.library)): p.read_bytes() for p in self.store.library.glob('*/*.png')})
        self.new_capture()
        self.assertEqual(len(self.store.captures()), 1)
        self.assertNotEqual(self.store.captures()[0]['id'], self.key)

    def test_session_reset_includes_files_older_than_visible_hundred_and_fresh_files(self):
        for n in range(102):
            self.new_capture(str(n) + '.png')
        fresh = self.store.library / 'Inbox/fresh.png'
        fresh.write_bytes(png(24))
        self.assertEqual(len(self.store.captures()), 100)
        self.assertEqual(self.reset_session()[0], 200)
        time.sleep(.8)
        self.assertEqual(self.store.captures(), [])
        preview = self.json_request('/api/library/cleanup')[1]
        self.assertEqual(preview['captureCount'], 104)
        self.assertEqual(preview['fileCount'], 104)

    def test_retrying_session_reset_does_not_hide_new_work(self):
        request_id = str(uuid.uuid4())
        first = self.reset_session(request_id)
        self.new_capture()
        self.assertEqual(self.reset_session(request_id)[1], first[1])
        self.assertEqual(len(self.store.captures()), 1)
        restarted = module.Store(self.store.library, self.store.state, token='test-only-token')
        self.server.store = restarted
        self.assertEqual(self.reset_session(request_id)[1], first[1])
        self.assertEqual(len(restarted.captures()), 1)

    def test_session_and_cleanup_endpoints_require_auth_and_exact_payloads(self):
        self.assertEqual(self.json_request('/api/session/reset', {'requestID': str(uuid.uuid4())}, auth=False)[0], 401)
        self.assertEqual(self.json_request('/api/library/cleanup', auth=False)[0], 401)
        self.assertEqual(self.json_request('/api/library/cleanup', {'token': 'anything'}, auth=False)[0], 401)
        for payload in ({}, [], {'requestID': '../escape'}, {'requestID': str(uuid.uuid4()), 'path': '/tmp'}):
            self.assertEqual(self.json_request('/api/session/reset', payload)[0], 400)
        self.assertEqual(self.json_request('/api/library/cleanup', {'token': '../escape'})[0], 409)
        self.assertEqual(len(self.store.captures()), 1)

    def test_cleanup_moves_only_previewed_previous_session_pngs_to_trash(self):
        self.assertEqual(self.save()[0], 200)
        annotated = self.store.library / 'Annotated/pencil-test.png'
        annotated.write_bytes(png(8))
        unrelated = self.store.library / 'Inbox/notes.txt'
        unrelated.write_text('keep')
        self.assertEqual(self.reset_session()[0], 200)
        current = self.new_capture()
        status, preview, _ = self.json_request('/api/library/cleanup')
        self.assertEqual(status, 200)
        self.assertEqual(preview['captureCount'], 2)
        self.assertEqual(preview['fileCount'], 3)
        expected = {str(p.relative_to(self.store.library)): p.read_bytes() for p in self.store.library.glob('*/*.png') if p != current}
        self.assertEqual(preview['byteCount'], sum(map(len, expected.values())))
        status, result, _ = self.json_request('/api/library/cleanup', {'token': preview['token']})
        self.assertEqual(status, 200)
        self.assertEqual(result['movedFiles'], 3)
        self.assertEqual(result['movedBytes'], preview['byteCount'])
        batch = next(self.store.trash.iterdir())
        self.assertEqual(expected, {str(p.relative_to(batch)): p.read_bytes() for p in batch.glob('*/*.png')})
        self.assertTrue(current.exists())
        self.assertTrue(unrelated.exists())
        self.assertFalse(self.original.exists())
        self.assertEqual(self.json_request('/api/library/cleanup', {'token': preview['token']})[1], result)
        self.assertEqual(self.json_request('/api/library/cleanup')[1]['fileCount'], 0)
        self.assertEqual(self.save()[0], 400)

    def test_cleanup_rejects_stale_preview_without_moving_any_files(self):
        self.reset_session()
        preview = self.json_request('/api/library/cleanup')[1]
        self.original.write_bytes(png(64))
        self.assertEqual(self.json_request('/api/library/cleanup', {'token': preview['token']})[0], 409)
        self.assertTrue(self.original.exists())
        self.assertFalse(self.store.trash.exists())

    def test_historical_drawing_can_save_and_invalidates_cleanup_preview(self):
        self.reset_session()
        preview = self.json_request('/api/library/cleanup')[1]
        self.assertEqual(self.request('/api/image/' + self.key)[0], 200)
        request_id = str(uuid.uuid4())
        status, data, _ = self.save(request_id=request_id)
        self.assertEqual(status, 200)
        self.assertEqual(self.json_request('/api/library/cleanup', {'token': preview['token']})[0], 409)
        self.assertEqual(self.save(request_id=request_id)[1], data)
        self.assertEqual(self.json_request('/api/library/cleanup')[1]['fileCount'], 2)
        self.assertEqual(self.store.captures(), [])

    def test_symlinked_library_folders_and_trash_are_never_followed(self):
        outside = self.store.library.parent / 'outside'
        outside.mkdir()
        secret = outside / 'secret.png'
        secret.write_bytes(png(42))
        os.utime(secret, (time.time()-2, time.time()-2))
        self.original.unlink()
        inbox = self.store.library / 'Inbox'
        inbox.rmdir()
        inbox.symlink_to(outside, target_is_directory=True)
        self.assertEqual(self.store.captures(), [])
        self.reset_session()
        self.assertEqual(self.json_request('/api/library/cleanup')[1]['fileCount'], 0)
        inbox.unlink()
        inbox.mkdir()
        self.new_capture()
        self.reset_session()
        self.store.trash.symlink_to(outside, target_is_directory=True)
        preview = self.json_request('/api/library/cleanup')[1]
        self.assertEqual(self.json_request('/api/library/cleanup', {'token': preview['token']})[0], 400)
        self.assertTrue(secret.exists())
        self.assertTrue((inbox / 'new.png').exists())

    def test_cleanup_serializes_with_historical_save(self):
        self.reset_session()
        preview = self.json_request('/api/library/cleanup')[1]
        outcomes = []
        barrier = threading.Barrier(3)
        def save():
            barrier.wait()
            outcomes.append(('save', self.save()[0]))
        def cleanup():
            barrier.wait()
            outcomes.append(('cleanup', self.json_request('/api/library/cleanup', {'token': preview['token']})[0]))
        workers = [threading.Thread(target=save), threading.Thread(target=cleanup)]
        for worker in workers:
            worker.start()
        barrier.wait()
        for worker in workers:
            worker.join()
        results = dict(outcomes)
        self.assertIn(results, ({'save': 200, 'cleanup': 409}, {'save': 400, 'cleanup': 200}))

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
