#!/usr/bin/env python3
"""Garante que literais visuais existam apenas no arquivo central de tokens."""
from pathlib import Path
import re
import sys

root = Path(__file__).resolve().parents[1] / "lib"
tokens = root / "core" / "theme" / "app_color_tokens.dart"
literal = re.compile(r"\bColor\s*\(\s*0x[0-9a-fA-F]{8}\s*\)|\bColors\.[a-zA-Z_]\w*")
errors = []

for file in root.rglob("*.dart"):
    if file == tokens:
        continue
    for line_number, line in enumerate(file.read_text(encoding="utf-8").splitlines(), 1):
        # Ignore comments; capture actual Dart code.
        if line.lstrip().startswith(("///", "//", "*")):
            continue
        if literal.search(line):
            errors.append(f"{file.relative_to(root)}:{line_number}: {line.strip()}")

if errors:
    print("Cores fixas fora dos tokens centrais:")
    print("\n".join(errors))
    sys.exit(1)
print("OK: sem Colors.* ou Color(0x...) fora de app_color_tokens.dart")
