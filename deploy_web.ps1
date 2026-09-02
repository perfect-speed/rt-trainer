param(
  [Parameter(Mandatory=$true)]
  [string]$BackendUrl,
  [string]$RepoName = "rt-trainer"
)

$ErrorActionPreference = "Stop"
$backend = $BackendUrl.TrimEnd('/')

Write-Host "Building RT Trainer web against $backend"
flutter pub get
flutter test
flutter build web --release --base-href "/$RepoName/" --dart-define="RT_API_URL=$backend"

if (Test-Path docs) {
  Remove-Item docs -Recurse -Force
}
New-Item -ItemType Directory -Path docs | Out-Null
Copy-Item build\web\* docs -Recurse -Force

Write-Host ""
Write-Host "Web build copied to docs/."
Write-Host "Next: git add . ; git commit -m 'Publish RT Trainer v0.5 demo' ; git push"
Write-Host "Expected GitHub Pages URL: https://perfect-speed.github.io/$RepoName/"
