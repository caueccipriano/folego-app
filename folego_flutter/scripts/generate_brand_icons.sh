#!/usr/bin/env bash
set -euo pipefail

# Single source of truth for iOS home-screen, browser and Android PWA icons.
# Run before flutter build web; Flutter copies the web/ directory to build/web.
cd "$(dirname "${BASH_SOURCE[0]}")/.."

command -v rsvg-convert >/dev/null || {
  echo "Missing rsvg-convert (install librsvg2-bin)" >&2
  exit 1
}

rsvg-convert -w 512 -h 512 web/icons/folego-logo.svg -o web/icons/Icon-512.png
rsvg-convert -w 512 -h 512 web/icons/folego-logo-maskable.svg -o web/icons/Icon-maskable-512.png
rsvg-convert -w 192 -h 192 web/icons/folego-logo.svg -o web/icons/Icon-192.png
rsvg-convert -w 192 -h 192 web/icons/folego-logo-maskable.svg -o web/icons/Icon-maskable-192.png

# iOS Safari may look for apple-touch-icon.png at the site's root even when
# a manifest exists. Always generate a real, opaque 180px PNG there.
rsvg-convert -w 180 -h 180 web/icons/folego-logo.svg -o web/apple-touch-icon.png
# Keep the legacy path valid for older iOS bookmarks and links.
cp web/apple-touch-icon.png web/icons/Icon-180.png
rsvg-convert -w 64 -h 64 web/icons/folego-logo.svg -o web/favicon.png

# Prevent an empty/malformed icon from silently shipping to the home screen.
python3 - <<'PY'
from pathlib import Path
import struct

icons = {
    "web/apple-touch-icon.png": 180,
    "web/icons/Icon-180.png": 180,
    "web/icons/Icon-192.png": 192,
    "web/icons/Icon-maskable-192.png": 192,
    "web/icons/Icon-512.png": 512,
    "web/icons/Icon-maskable-512.png": 512,
    "web/favicon.png": 64,
}
for name, size in icons.items():
    blob = Path(name).read_bytes()
    if len(blob) < 1024 or blob[:8] != b"\x89PNG\r\n\x1a\n":
        raise SystemExit(f"Invalid/empty brand icon: {name}")
    width, height = struct.unpack(">II", blob[16:24])
    if (width, height) != (size, size):
        raise SystemExit(f"Wrong icon size for {name}: {width}x{height}")
print("Brand icons generated with valid PNG signatures and dimensions")
PY
