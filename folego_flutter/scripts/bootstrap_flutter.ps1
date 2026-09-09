$ErrorActionPreference = "Stop"

if (-not (Get-Command flutter -ErrorAction SilentlyContinue)) {
  Write-Host "Flutter não encontrado. Instale o Flutter SDK e rode: flutter doctor"
  exit 1
}

$Root = Split-Path -Parent (Split-Path -Parent $MyInvocation.MyCommand.Path)
Set-Location $Root

# No Windows, geramos apenas o runner Android. O runner iOS deve ser gerado
# em um Mac, onde também será possível compilar e assinar o aplicativo iOS.
if (-not (Test-Path "android")) {
  $Temp = Join-Path ([System.IO.Path]::GetTempPath()) ("folego_shell_" + [guid]::NewGuid().ToString())
  flutter create $Temp --project-name folego --org br.com.folego --platforms android
  Copy-Item -Recurse (Join-Path $Temp "android") (Join-Path $Root "android")
  if (-not (Test-Path ".metadata")) {
    Copy-Item (Join-Path $Temp ".metadata") (Join-Path $Root ".metadata")
  }
  Remove-Item -Recurse -Force $Temp
}

flutter pub get
flutter analyze

Write-Host ""
Write-Host "Base Android pronta. Para executar:"
Write-Host "  flutter run"
