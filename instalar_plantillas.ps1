# Instala PatronesGoF.xml en IntelliJ IDEA y despues borra los 3 archivos
# (PatronesGoF.xml, instalar_plantillas.ps1 e instalar_plantillas.bat). Sin papelera.
# Si estan dentro de Descargas\design_patterns-main\..., borra tambien esas carpetas y el .zip.
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

# --- Limpieza de la descarga de GitHub (solo si esta dentro de Descargas/Downloads) ---
# Estructura esperada: <Descargas>\design_patterns-main.zip  y  <Descargas>\design_patterns-main\design_patterns-main\
# Windows no distingue mayusculas de minusculas, por eso las comparaciones lo ignoran.
$aBorrar = $null   # carpeta de primer nivel dentro de Descargas (la externa)
$zip = $null
$candidatos = @()
try { $candidatos += (New-Object -ComObject Shell.Application).NameSpace('shell:Downloads').Self.Path } catch {}
$candidatos += (Join-Path $env:USERPROFILE 'Downloads')
$candidatos += (Join-Path $env:USERPROFILE 'Descargas')
$aqui = $PSScriptRoot.TrimEnd('\')
foreach ($c in $candidatos) {
    if (-not $c) { continue }
    $dl = $c.TrimEnd('\')
    if ($aqui.StartsWith($dl + '\', [System.StringComparison]::OrdinalIgnoreCase)) {
        $primero = $aqui.Substring($dl.Length + 1).Split('\')[0]
        if ($primero -ieq 'design_patterns-main') {
            $aBorrar = Join-Path $dl $primero
            $zip = Join-Path $dl 'design_patterns-main.zip'
        }
        break
    }
}

if ($aBorrar -or $zip) {
    # Un proceso aparte (oculto) espera a que este script y el .bat terminen y luego borra
    # la carpeta (los dos niveles) y el .zip, porque una carpeta en uso no se puede borrar.
    function Q([string]$t) { return "'" + $t.Replace("'", "''") + "'" }
    $j = 'Start-Sleep -Seconds 2; '
    if ($aBorrar) {
        $j += "`$t = $(Q $aBorrar); for (`$i = 0; `$i -lt 20 -and (Test-Path -LiteralPath `$t); `$i++) { Remove-Item -LiteralPath `$t -Recurse -Force -ErrorAction SilentlyContinue; if (Test-Path -LiteralPath `$t) { Start-Sleep -Seconds 1 } }; "
    }
    if ($zip) {
        $j += "Remove-Item -LiteralPath $(Q $zip) -Force -ErrorAction SilentlyContinue"
    }
    $enc = [Convert]::ToBase64String([System.Text.Encoding]::Unicode.GetBytes($j))
    Start-Process -FilePath 'powershell.exe' -WindowStyle Hidden -WorkingDirectory $env:TEMP `
        -ArgumentList @('-NoProfile', '-ExecutionPolicy', 'Bypass', '-EncodedCommand', $enc)
}

# Borrado definitivo (Remove-Item no usa la papelera)
Remove-Item -LiteralPath $xml -Force
if (-not $DesdeBat) {
    # Si se ejecuto el .ps1 directamente, tambien se borra el .bat
    if (Test-Path -LiteralPath $bat) { Remove-Item -LiteralPath $bat -Force }
}
Remove-Item -LiteralPath $PSCommandPath -Force
Write-Host "Archivos de instalacion eliminados." -ForegroundColor Green
exit 0
