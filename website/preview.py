"""Local-only static preview with the production Content Security Policy."""
import argparse
from http.server import SimpleHTTPRequestHandler, ThreadingHTTPServer
from pathlib import Path

ROOT = Path(__file__).resolve().parent / 'public'
HEADERS = {}
for line in (ROOT / '_headers').read_text().splitlines():
    if line.startswith('  ') and ': ' in line:
        name, value = line.strip().split(': ', 1)
        HEADERS[name] = value

class Handler(SimpleHTTPRequestHandler):
    def __init__(self, *args, **kwargs):
        super().__init__(*args, directory=str(ROOT), **kwargs)

    def do_GET(self):
        if self.path.split('?')[0] == '/privacy':
            self.path = '/privacy.html'
        super().do_GET()

    def end_headers(self):
        self.send_header('Cache-Control', 'no-store')
        for name, value in HEADERS.items():
            self.send_header(name, value)
        super().end_headers()

if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--port', type=int, default=8095)
    args = parser.parse_args()
    print(f'Ludwig preview: http://127.0.0.1:{args.port}', flush=True)
    ThreadingHTTPServer(('127.0.0.1', args.port), Handler).serve_forever()
