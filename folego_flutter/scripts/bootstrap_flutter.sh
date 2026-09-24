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
  sed -i 's/import io\.flutter\.embedding\.android\.FlutterActivity/import io.flutter.embedding.android.FlutterFragmentActivity/' "$MAIN_ACTIVITY"
  sed -E -i 's/class MainActivity[[:space:]]*:[[:space:]]*FlutterActivity\(\)/class MainActivity : FlutterFragmentActivity()/' "$MAIN_ACTIVITY"

  if grep -q 'FlutterActivity' "$MAIN_ACTIVITY"; then
    echo "Falha ao migrar MainActivity para FlutterFragmentActivity:"
    cat "$MAIN_ACTIVITY"
    exit 1
  fi
fi

flutter pub get
flutter analyze

echo
echo "Base nativa pronta. Package Android: com.caueccipriano.folego"
echo "Para executar:"
echo "  flutter run"
