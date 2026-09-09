#!/usr/bin/env bash
set -euo pipefail

if ! command -v flutter >/dev/null 2>&1; then
  echo "Flutter não encontrado. Instale o Flutter SDK e rode: flutter doctor"
  exit 1
fi

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

# O pacote entregue contém o código do Fôlego, mas não carrega os diretórios
# gerados pelo Flutter SDK. Criamos os runners nativos em uma pasta temporária
# para não sobrescrever lib/, pubspec.yaml ou qualquer código do projeto.
if [[ ! -d android || ! -d ios ]]; then
  TMP_DIR="$(mktemp -d)"
  trap 'rm -rf "$TMP_DIR"' EXIT

  flutter create "$TMP_DIR/folego_shell" \
    --project-name folego \
    --org br.com.folego \
    --platforms android,ios

  [[ -d android ]] || cp -R "$TMP_DIR/folego_shell/android" ./android
  [[ -d ios ]] || cp -R "$TMP_DIR/folego_shell/ios" ./ios
  [[ -f .metadata ]] || cp "$TMP_DIR/folego_shell/.metadata" ./.metadata
fi

flutter pub get
flutter analyze

echo
echo "Base nativa pronta. Para executar:"
echo "  flutter run"
