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
  $Content = [regex]::Replace(
    $Content,
    "class\s+MainActivity\s*:\s*FlutterActivity\(\)",
    "class MainActivity : FlutterFragmentActivity()"
  )
  if ($Content -match "FlutterActivity") {
    throw "Falha ao migrar MainActivity para FlutterFragmentActivity"
  }
  Set-Content -Path $MainActivity.FullName -Value $Content -NoNewline
}

$Manifest = Join-Path $Root "android\app\src\main\AndroidManifest.xml"
if (Test-Path $Manifest) {
  $ManifestContent = Get-Content $Manifest -Raw
  $ManifestContent = [regex]::Replace(
    $ManifestContent,
    'android:label="[^"]*"',
    'android:label="Fôlego"',
    1
  )
  Set-Content -Path $Manifest -Value $ManifestContent -NoNewline
}

$InfoPlist = Join-Path $Root "ios\Runner\Info.plist"
if (Test-Path $InfoPlist) {
  $PlistContent = Get-Content $InfoPlist -Raw
  $PlistContent = [regex]::Replace(
    $PlistContent,
    '(<key>CFBundleDisplayName</key>\s*<string>)[^<]*(</string>)',
    '$1Fôlego$2'
  )
  $PlistContent = [regex]::Replace(
    $PlistContent,
    '(<key>CFBundleName</key>\s*<string>)[^<]*(</string>)',
    '$1Fôlego$2'
  )
  Set-Content -Path $InfoPlist -Value $PlistContent -NoNewline
}

flutter pub get
dart run flutter_launcher_icons
flutter analyze

Write-Host ""
Write-Host "Base Android pronta. Package: com.caueccipriano.folego"
Write-Host "Para executar:"
Write-Host "  flutter run"
