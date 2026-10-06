# Instala PatronesGoF.xml en IntelliJ IDEA y despues borra los 3 archivos
# (PatronesGoF.xml, instalar_plantillas.ps1 e instalar_plantillas.bat). Sin papelera.
param([switch]$DesdeBat)
$ErrorActionPreference = 'Stop'

$xml = Join-Path $PSScriptRoot 'PatronesGoF.xml'
$bat = Join-Path $PSScriptRoot 'instalar_plantillas.bat'
if (-not (Test-Path -LiteralPath $xml)) {
    Write-Host "No encuentro PatronesGoF.xml en: $PSScriptRoot" -ForegroundColor Red
    exit 1
}

$base = Join-Path $env:APPDATA 'JetBrains'
if (-not (Test-Path -LiteralPath $base)) {
    Write-Host "No existe $base. Abre IntelliJ al menos una vez." -ForegroundColor Red
    exit 1
}

# Busca IntelliJ IDEA (Ultimate o Community) y se queda con la version mas nueva
$cfg = Get-ChildItem -LiteralPath $base -Directory |
    Where-Object { $_.Name -match '^(IntelliJIdea|IdeaIC)\d' } |
    ForEach-Object {
        $v = [version]'0.0'
        try { $v = [version](($_.Name -replace '^\D+', '')) } catch {}
        [pscustomobject]@{ Path = $_.FullName; Ver = $v }
    } |
    Sort-Object Ver -Descending |
    Select-Object -First 1

if (-not $cfg) {
    Write-Host "No encontre ninguna carpeta IntelliJIdea* en $base" -ForegroundColor Red
    exit 1
}

if (Get-Process -Name 'idea64' -ErrorAction SilentlyContinue) {
    Write-Host "AVISO: IntelliJ esta abierto. Cierralo y vuelve a abrirlo para ver las plantillas." -ForegroundColor Yellow
}

$tpl = Join-Path $cfg.Path 'templates'
if (-not (Test-Path -LiteralPath $tpl)) {
    New-Item -ItemType Directory -Path $tpl | Out-Null
    Write-Host "Carpeta creada: $tpl"
}

$dest = Join-Path $tpl 'PatronesGoF.xml'
$existia = Test-Path -LiteralPath $dest
Copy-Item -LiteralPath $xml -Destination $dest -Force

# Solo se borra si la copia quedo identica al original
if ((Get-FileHash -LiteralPath $xml).Hash -ne (Get-FileHash -LiteralPath $dest).Hash) {
    Write-Host "La copia no coincide con el original. No se borro nada." -ForegroundColor Red
    exit 1
}

if ($existia) { Write-Host "Plantillas reemplazadas en: $dest" -ForegroundColor Green }
else          { Write-Host "Plantillas instaladas en: $dest" -ForegroundColor Green }
Write-Host "Reinicia IntelliJ y revisa Settings > Editor > Live Templates > Patrones GoF."

# Borrado definitivo (Remove-Item no usa la papelera)
Remove-Item -LiteralPath $xml -Force
if (-not $DesdeBat) {
    # Si se ejecuto el .ps1 directamente, tambien se borra el .bat
    if (Test-Path -LiteralPath $bat) { Remove-Item -LiteralPath $bat -Force }
}
Remove-Item -LiteralPath $PSCommandPath -Force
Write-Host "Archivos de instalacion eliminados." -ForegroundColor Green
exit 0
