# Build do Coleta Retaguarda (Windows) + geracao do instalador.
#
# Existe por causa de uma falha do passo INSTALL do CMake: quando
# build\native_assets\windows nao existe, o CMake aborta a instalacao e o
# Release fica SEM data\app.so e data\flutter_assets - o exe compila mas nao
# abre (encerra com codigo 1). O mesmo diretorio e a origem do sqlite3.dll
# (native asset do pacote sqlite3), sem o qual o banco local nao abre.
#
# Uso:  .\build_release.ps1          (build + instalador)
#       .\build_release.ps1 -SkipInstaller
#
# Obs.: manter este arquivo somente em ASCII (PowerShell 5.1 le .ps1 como ANSI).

param(
    [switch]$SkipInstaller
)

$ErrorActionPreference = 'Stop'
Set-Location $PSScriptRoot

$nativeAssets = Join-Path $PSScriptRoot 'build\native_assets\windows'
$releaseDir   = Join-Path $PSScriptRoot 'build\windows\x64\runner\Release'
$issc         = 'C:\Program Files (x86)\Inno Setup 6\ISCC.exe'

Write-Host '==> Preparando native assets' -ForegroundColor Cyan
New-Item -ItemType Directory -Force $nativeAssets | Out-Null

$sqlite = Get-ChildItem -Path (Join-Path $PSScriptRoot '.dart_tool\hooks_runner') `
    -Filter 'sqlite3.dll' -Recurse -ErrorAction SilentlyContinue |
    Sort-Object LastWriteTime -Descending | Select-Object -First 1

if ($sqlite) {
    Copy-Item $sqlite.FullName $nativeAssets -Force
    Write-Host "    sqlite3.dll <- $($sqlite.FullName)"
} else {
    Write-Warning 'sqlite3.dll nao encontrado em .dart_tool\hooks_runner (rode "flutter pub get" antes).'
}

Write-Host '==> flutter build windows --release' -ForegroundColor Cyan
flutter build windows --release
if ($LASTEXITCODE -ne 0) { throw 'Falha no flutter build.' }

Write-Host '==> Conferindo o pacote gerado' -ForegroundColor Cyan
$obrigatorios = @(
    'flutter_retaguarda.exe',
    'flutter_windows.dll',
    'sqlite3.dll',
    'data\app.so',
    'data\flutter_assets\AssetManifest.bin'
)
$faltando = $obrigatorios | Where-Object { -not (Test-Path (Join-Path $releaseDir $_)) }
if ($faltando) {
    $lista = $faltando -join ', '
    throw "Build incompleto. Faltando: $lista"
}
Write-Host '    OK: exe, DLLs, app.so e flutter_assets presentes.' -ForegroundColor Green

if ($SkipInstaller) { return }

if (-not (Test-Path $issc)) {
    Write-Warning "Inno Setup nao encontrado em $issc - instalador nao gerado."
    return
}

Write-Host '==> Gerando instalador' -ForegroundColor Cyan
& $issc 'installer\coleta_retaguarda.iss'
if ($LASTEXITCODE -ne 0) { throw 'Falha ao gerar o instalador.' }

Get-ChildItem 'installer\dist\*.exe' | Sort-Object LastWriteTime -Descending |
    Select-Object -First 1 Name, @{n = 'MB'; e = { [math]::Round($_.Length / 1MB, 1) } }, LastWriteTime
