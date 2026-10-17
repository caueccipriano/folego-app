#!/usr/bin/env python3
"""Embed the canonical PNG directly in the PWA HTML for iOS 27 installation.

On affected iOS 27.2 devices the native Add-to-Home-Screen icon loader may fail
its independent network request even though the same image opens in Safari.
Inlining the *same* approved 180x180 PNG avoids that separate fetch.
Only changes the built HTML. The external PNG and the manifest remain available.
"""
from __future__ import annotations

import argparse
import base64
from pathlib import Path
import struct

PLACEHOLDER = "__FOLEGO_IOS_INSTALL_ICON_DATA_URI__"
PNG_SIGNATURE = b"\x89PNG\r\n\x1a\n"


def embed(html_path: Path, icon_path: Path) -> None:
    icon = icon_path.read_bytes()
    if len(icon) < 1024 or icon[:8] != PNG_SIGNATURE:
        raise SystemExit(f"Refusing to embed an invalid iOS icon: {icon_path}")
    width, height = struct.unpack(">II", icon[16:24])
    if (width, height) != (180, 180):
        raise SystemExit(f"iOS icon must be 180x180, got {width}x{height}")
    if len(icon) > 200_000:
        raise SystemExit("iOS icon is unexpectedly large")

    html = html_path.read_text(encoding="utf-8")
    if html.count(PLACEHOLDER) != 1:
        raise SystemExit(f"Expected one iOS icon placeholder, found {html.count(PLACEHOLDER)}")
    uri = "data:image/png;base64," + base64.b64encode(icon).decode("ascii")
    final = html.replace(PLACEHOLDER, uri)
    html_path.write_text(final, encoding="utf-8")
    print(f"Embedded opaque-design iOS touch icon in {html_path} ({len(icon)} PNG bytes)")


if __name__ == "__main__":
    parser = argparse.ArgumentParser()
    parser.add_argument("--html", type=Path, default=Path("build/web/index.html"))
    parser.add_argument(
        "--icon", type=Path, default=Path("build/web/apple-touch-icon-ios-v2.png")
    )
    args = parser.parse_args()
    embed(args.html, args.icon)
