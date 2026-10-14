#!/usr/bin/env python3
"""Package an already tested Flutter root build. Does not deploy or access secrets."""
from pathlib import Path
import argparse
p=argparse.ArgumentParser()
p.add_argument('--build', default='folego_flutter/build/web')
p.add_argument('--version', required=True)
a=p.parse_args()
root=Path(a.build)
if not (root/'index.html').is_file() or not (root/'main.dart.js').is_file():
    raise SystemExit('Build Flutter Web first with --base-href /')
for name in ['index.html','manifest.json','folego_push_sw.js']:
    file=root/name
    if file.is_file():
        file.write_text(file.read_text().replace('__FOLEGO_BUILD_VERSION__',a.version).replace('__FOLEGO_CACHE_VERSION__',a.version))
(root/'_headers').write_text('''/*
  X-Content-Type-Options: nosniff
  Referrer-Policy: strict-origin-when-cross-origin
  X-Frame-Options: DENY
/
  Cache-Control: no-cache, no-store, must-revalidate
/index.html
  Cache-Control: no-cache, no-store, must-revalidate
/flutter_bootstrap.js
  Cache-Control: no-cache, no-store, must-revalidate
/main.dart.js
  Cache-Control: no-cache, no-store, must-revalidate
/manifest.json
  Cache-Control: no-cache, must-revalidate
/folego_push_sw.js
  Cache-Control: no-cache, must-revalidate
''')
(root/'_redirects').write_text('/* /index.html 200\n')
print('Cloudflare candidate packaged; no deployment performed.')
