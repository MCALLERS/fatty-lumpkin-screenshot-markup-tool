#!/usr/bin/env python3
"""Exercise the shipped runtime against a disposable synthetic library."""
import argparse, importlib.util, json, os, pathlib, subprocess, tempfile, time, urllib.request, urllib.error, uuid
root=pathlib.Path(__file__).resolve().parents[1]
p=argparse.ArgumentParser(); p.add_argument('app',type=pathlib.Path);args=p.parse_args()
spec=importlib.util.spec_from_file_location('fixtures',root/'tests/test_companion.py');fixtures=importlib.util.module_from_spec(spec);spec.loader.exec_module(fixtures)
with tempfile.TemporaryDirectory(prefix='fatty-lumpkin-package-test-') as tmp:
    temp=pathlib.Path(tmp);lib=temp/'library';state=temp/'state';(lib/'Inbox').mkdir(parents=True)
    original=fixtures.png(255);file=lib/'Inbox/Synthetic.png';file.write_bytes(original);os.utime(file,(time.time()-3,time.time()-3))
    helper=args.app/'Contents/Helpers/FattyLumpkinCompanion.app/Contents/MacOS/FattyLumpkinCompanion'
    process=subprocess.Popen([str(helper.resolve()),'--library',str(lib),'--state',str(state),'--parent',str(os.getpid()),'--assets',str((args.app/'Contents/Resources/Companion').resolve())],env={'PATH':'/usr/bin:/bin','HOME':str(temp)},stdout=subprocess.DEVNULL,stderr=subprocess.PIPE)
    try:
        for _ in range(100):
            if (state/'server.json').exists():break
            if process.poll() is not None:raise RuntimeError(process.stderr.read().decode())
            time.sleep(.1)
        config=json.loads((state/'server.json').read_text());base='http://127.0.0.1:'+str(config['port'])
        def request(path, data=None, auth=True, headers=None):
            h={'Authorization':'Bearer '+config['token']} if auth else {};h.update(headers or {})
            with urllib.request.urlopen(urllib.request.Request(base+path,data=data,headers=h),timeout=5) as response:return response.read()
        assert b'Fatty Lumpkin' in request('/',auth=False)
        assert request('/pony.png',auth=False).startswith(b'\x89PNG')
        try:request('/api/library',auth=False);raise AssertionError('Unauthenticated access accepted')
        except urllib.error.HTTPError as error: assert error.code==401;error.close()
        capture=json.loads(request('/api/library'))['captures'][0]
        submission=str(uuid.uuid4());headers={'X-Capture-ID':capture['id'],'X-Submission-ID':submission}
        data=fixtures.png(0);saved=json.loads(request('/api/save',data,headers=headers));again=json.loads(request('/api/save',data,headers=headers))
        assert saved==again
        exports=list((lib/'Ready').glob('*.png'));assert len(exports)==1 and exports[0].read_bytes()==data
        assert file.read_bytes()==original
        print('PASS: packaged runtime starts without Homebrew PATH; branded assets, authenticated library, PNG save, idempotent retry, original preservation.')
    finally:
        process.terminate();process.wait(timeout=10)
