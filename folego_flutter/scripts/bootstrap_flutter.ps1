$ErrorActionPreference = "Stop"

if (-not (Get-Command flutter -ErrorAction SilentlyContinue)) {
  Write-Host "Flutter não encontrado. Instale o Flutter SDK e rode: flutter doctor"
  exit 1
}

$Root = Split-Path -Parent (Split-Path -Parent $MyInvocation.MyCommand.Path)
Set-Location $Root

if (-not (Test-Path "android")) {
  $Temp = Join-Path ([System.IO.Path]::GetTempPath()) ("folego_shell_" + [guid]::NewGuid().ToString())
  flutter create $Temp --project-name folego --org com.caueccipriano --platforms android
  Copy-Item -Recurse (Join-Path $Temp "android") (Join-Path $Root "android")
  if (-not (Test-Path ".metadata")) {
    Copy-Item (Join-Path $Temp ".metadata") (Join-Path $Root ".metadata")
  }
  Remove-Item -Recurse -Force $Temp
}

# RevenueCat Paywalls no Android precisam de FlutterFragmentActivity.
$MainActivity = Get-ChildItem -Path "android/app/src/main" -Filter "MainActivity.kt" -Recurse | Select-Object -First 1
if ($MainActivity) {
  $Content = Get-Content $MainActivity.FullName -Raw
  $Content = $Content.Replace(
    "import io.flutter.embedding.android.FlutterActivity",
    "import io.flutter.embedding.android.FlutterFragmentActivity"
  )
  $Content = $Content.Replace(
    "class MainActivity: FlutterActivity()",
    "class MainActivity: FlutterFragmentActivity()"
  )
  Set-Content -Path $MainActivity.FullName -Value $Content -NoNewline
}

flutter pub get
flutter analyze

Write-Host ""
Write-Host "Base Android pronta. Package: com.caueccipriano.folego"
Write-Host "Para executar:"
Write-Host "  flutter run"
