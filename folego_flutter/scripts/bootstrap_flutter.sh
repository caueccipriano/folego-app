#!/usr/bin/env bash
set -euo pipefail

if ! command -v flutter >/dev/null 2>&1; then
  echo "Flutter não encontrado. Instale o Flutter SDK e rode: flutter doctor"
  exit 1
fi

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

# Gera runners nativos sem sobrescrever o código Dart do Fôlego.
if [[ ! -d android || ! -d ios ]]; then
  TMP_DIR="$(mktemp -d)"
  trap 'rm -rf "$TMP_DIR"' EXIT

  flutter create "$TMP_DIR/folego_shell" \
    --project-name folego \
    --org com.caueccipriano \
    --platforms android,ios

  [[ -d android ]] || cp -R "$TMP_DIR/folego_shell/android" ./android
  [[ -d ios ]] || cp -R "$TMP_DIR/folego_shell/ios" ./ios
  [[ -f .metadata ]] || cp "$TMP_DIR/folego_shell/.metadata" ./.metadata
fi

# RevenueCat Paywalls no Android precisam de FlutterFragmentActivity.
MAIN_ACTIVITY="$(find android/app/src/main -name MainActivity.kt -print -quit 2>/dev/null || true)"
if [[ -n "$MAIN_ACTIVITY" ]]; then
  python3 - "$MAIN_ACTIVITY" <<'PY'
from pathlib import Path
import re
import sys

path = Path(sys.argv[1])
content = path.read_text()
content = content.replace(
    "import io.flutter.embedding.android.FlutterActivity",
    "import io.flutter.embedding.android.FlutterFragmentActivity",
)
content = re.sub(
    r"class\s+MainActivity\s*:\s*FlutterActivity\(\)",
    "class MainActivity : FlutterFragmentActivity()",
    content,
)
if "FlutterActivity" in content:
    print("Falha ao migrar MainActivity para FlutterFragmentActivity:")
    print(content)
    raise SystemExit(1)
path.write_text(content)
PY
fi

flutter pub get
flutter analyze

echo
echo "Base nativa pronta. Package Android: com.caueccipriano.folego"
echo "Para executar:"
echo "  flutter run"
