# Gera o pacote distribuivel da retaguarda.
#
# Alem do que o `flutter build` produz, o pacote precisa de DLLs que a maquina
# de destino pode nao ter:
#
#   fbclient.dll        cliente Firebird. Sem ele o sistema abre mas nao conecta
#                       no banco. Nao vem do Flutter e so existe em maquina com
#                       Firebird instalado — o que nao se pode assumir.
#
#   msvcp140.dll        runtime C++ da Microsoft. Exigido pelo fbclient E pelo
#   vcruntime140.dll    proprio executavel Flutter: sem eles o sistema nem abre
#   vcruntime140_1.dll  numa maquina sem o Visual C++ Redistributable.
#
# As api-ms-win-crt-*.dll fazem parte do Windows 10/11 e nao precisam ir junto.
#
# Uso:  .\empacotar.ps1
#       .\empacotar.ps1 -SemBuild        (so reempacota o que ja foi compilado)
#
# Obs.: manter este arquivo somente em ASCII (PowerShell 5.1 le .ps1 como ANSI).

param(
    [switch]$SemBuild,
    [string]$FirebirdDir = 'C:\Program Files\Firebird\Firebird_5_0'
)

$ErrorActionPreference = 'Stop'
Set-Location $PSScriptRoot

$saida = Join-Path $PSScriptRoot 'build\windows\x64\runner\Release'

if (-not $SemBuild) {
    # O build falha sem esta pasta; o sqlite3.dll vem do cache de hooks.
    $nativeAssets = Join-Path $PSScriptRoot 'build\native_assets\windows'
    New-Item -ItemType Directory -Force $nativeAssets | Out-Null
    $sqlite = Get-Item "$PSScriptRoot\.dart_tool\hooks_runner\shared\sqlite3\build\download-*\sqlite3.dll"
    Copy-Item $sqlite.FullName "$nativeAssets\sqlite3.dll" -Force

    Write-Host '==> flutter build windows --release' -ForegroundColor Cyan
    flutter build windows --release
    if ($LASTEXITCODE -ne 0) { throw 'Falha no build.' }
}

if (-not (Test-Path "$saida\flutter_retaguarda.exe")) {
    throw "Executavel nao encontrado em $saida. Rode sem -SemBuild."
}

Write-Host '==> Incluindo dependencias nativas' -ForegroundColor Cyan

# Cliente Firebird
$fbclient = Join-Path $FirebirdDir 'fbclient.dll'
if (-not (Test-Path $fbclient)) {
    throw "fbclient.dll nao encontrado em $FirebirdDir. Informe -FirebirdDir."
}
Copy-Item $fbclient "$saida\fbclient.dll" -Force
$v = (Get-Item $fbclient).VersionInfo.FileVersion
Write-Host "    fbclient.dll ($v)" -ForegroundColor Green

# Runtime C++ — do System32, que tem a versao mais nova (compativel para tras)
foreach ($dll in @('msvcp140.dll', 'vcruntime140.dll', 'vcruntime140_1.dll')) {
    $origem = "C:\Windows\System32\$dll"
    if (-not (Test-Path $origem)) { throw "$dll nao encontrado no System32." }
    Copy-Item $origem "$saida\$dll" -Force
    Write-Host "    $dll" -ForegroundColor Green
}

# Ponte para instalacoes anteriores a 2.10.0
#
# Ate a 2.9.2 o pacote instalava tambem um executavel com o nome da versao
# (ColetaRetaguarda-v2.9.2.exe), e e esse que o usuario abre pelo atalho. O
# atualizador daquela versao apenas extrai o pacote por cima e reabre o mesmo
# arquivo -- entao, se o pacote novo nao trouxer aquele nome, o atalho continua
# abrindo o build velho, que detecta a atualizacao outra vez. O sistema ficava
# em laco, baixando a mesma versao para sempre.
#
# A copia abaixo quebra o laco: o atalho antigo passa a abrir o build novo. A
# partir da 2.10.0 o proprio atualizador sobrescreve o executavel em uso seja
# qual for o nome, entao isto pode sair quando ninguem mais estiver em 2.9.x.
foreach ($legado in @('ColetaRetaguarda-v2.9.2.exe')) {
    Copy-Item "$saida\flutter_retaguarda.exe" "$saida\$legado" -Force
    Write-Host "    $legado (ponte para instalacoes 2.9.x)" -ForegroundColor Yellow
}

# Confere que nada essencial ficou de fora
$obrigatorios = @(
    'flutter_retaguarda.exe', 'flutter_windows.dll', 'sqlite3.dll',
    'fbclient.dll', 'msvcp140.dll', 'vcruntime140.dll', 'vcruntime140_1.dll'
)
$faltando = $obrigatorios | Where-Object { -not (Test-Path (Join-Path $saida $_)) }
if ($faltando) { throw "Faltando no pacote: $($faltando -join ', ')" }
if (-not (Test-Path "$saida\data\flutter_assets")) { throw 'Faltando a pasta data\flutter_assets.' }

$versao = (Get-Item "$saida\flutter_retaguarda.exe").VersionInfo.FileVersion
$tamanho = [math]::Round(((Get-ChildItem $saida -Recurse -File | Measure-Object Length -Sum).Sum / 1MB), 1)
Write-Host "==> Pacote completo: versao $versao, $tamanho MB" -ForegroundColor Green
Write-Host "    $saida"
