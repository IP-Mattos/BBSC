@echo off
rem BBSC co-op on BBport 1.9.7, next to this file. Downloads BBport and BBSC, no game files.
set "BBSC_SELF=%~f0"
powershell -NoProfile -ExecutionPolicy Bypass -Command "$s = [IO.File]::ReadAllText($env:BBSC_SELF); & ([ScriptBlock]::Create($s.Substring($s.IndexOf('#' + 'PS-START'))))"
set "BBSC_RESULT=%errorlevel%"
if not "%BBSC_RESULT%"=="0" echo. & echo La instalacion no termino. Puedes volver a ejecutar este archivo.
if not defined BBSC_INSTALL_TEST pause
exit /b %BBSC_RESULT%
#PS-START
$ErrorActionPreference = "Stop"
$ProgressPreference = "SilentlyContinue"

# Bump per release. sha256 = GitHub release asset digest.
$PortUrl = "https://github.com/Supermedo/bloodborne_pc/releases/download/windows-v1.9.7/Bloodborne-Windows.zip"
$PortSha = "b3444c6a4d201e75f2b3ea80f2f4663bfa8e78eda7652054819ba8622cc7a759"
$KitUrl = "https://github.com/IP-Mattos/BBSC/releases/download/v0.0.2-bbport197-test2/BBSC-0.0.2-BBport-1.9.7-coop-test2.zip"
$KitSha = "35a2cc7c09a9df5e67e32f451714a4f692dc4bfb133602f175e33823f5a4fd86"
$DllUrl = "https://github.com/IP-Mattos/BBSC/releases/download/v0.0.2-bbport197-coop/bbsc.dll"
$DllSha = "b11b64a6d34f9bdd13cde5e3f146152d6acb553b2237b71747c18bb207045edf"
$PortVersion = "1.9.7"
$NeededFreeGb = 2

$testRun = [bool]$env:BBSC_INSTALL_TEST
$root = Join-Path (Split-Path $env:BBSC_SELF -Parent) "BBSC-Coop"
$port = Join-Path $root "BBport"
$kit = Join-Path $root "BBSC-0.0.2-BBport"
$downloads = Join-Path $root "_descargas"

function Step([string]$text) { Write-Host ""; Write-Host "== $text" -ForegroundColor Cyan }

function Get-Verified([string]$url, [string]$file, [string]$sha) {
    if ((Test-Path -LiteralPath $file) -and (Get-FileHash -LiteralPath $file -Algorithm SHA256).Hash -eq $sha) { return }
    & curl.exe -L --fail --retry 3 --progress-bar -o $file $url
    if ($LASTEXITCODE -ne 0) { throw "No se pudo descargar $url (curl $LASTEXITCODE). Revisa tu internet." }
    if ((Get-FileHash -LiteralPath $file -Algorithm SHA256).Hash -ne $sha) {
        Remove-Item -LiteralPath $file -Force
        throw "El archivo descargado no coincide: $url"
    }
}

# Moved to $target last, so a failed run leaves no half folder.
function Expand-To([string]$zip, [string]$marker, [string]$target) {
    $temp = "$target.tmp"
    if (Test-Path -LiteralPath $temp) { Remove-Item -LiteralPath $temp -Recurse -Force }
    Expand-Archive -LiteralPath $zip -DestinationPath $temp
    $found = Get-ChildItem -LiteralPath $temp -Recurse -File -Filter $marker | Sort-Object { $_.FullName.Length } | Select-Object -First 1
    if (-not $found) { throw "No encuentro $marker dentro de $zip" }
    $folder = if ($marker -eq "bbsc.dll") { $found.Directory.Parent } else { $found.Directory }
    Move-Item -LiteralPath $folder.FullName -Destination $target
    if (Test-Path -LiteralPath $temp) { Remove-Item -LiteralPath $temp -Recurse -Force }
}

if (Get-Process -Name "bb-probe" -ErrorAction SilentlyContinue) { throw "Cierra el juego primero." }
New-Item -ItemType Directory -Force $root, $downloads | Out-Null
$free = (Get-Item -LiteralPath $root).PSDrive.Free
if ($null -ne $free -and $free -lt $NeededFreeGb * 1GB) { throw "Necesitas al menos $NeededFreeGb GB libres en ese disco." }
Write-Host "Instalando en: $root"

Step "BBport 1.9.7"
if (Test-Path -LiteralPath (Join-Path $port "Bloodborne.exe")) {
    Write-Host "Ya esta instalado, no lo toco."
} else {
    $zip = Join-Path $downloads "Bloodborne-Windows.zip"
    Get-Verified $PortUrl $zip $PortSha
    Write-Host "Descomprimiendo..."
    Expand-To $zip "Bloodborne.exe" $port
}

Step "BBSC"
if (Test-Path -LiteralPath (Join-Path $kit "bbsc\bbsc.dll")) {
    Write-Host "Ya esta instalado, solo actualizo el mod."
} else {
    $zip = Join-Path $downloads "BBSC-kit.zip"
    Get-Verified $KitUrl $zip $KitSha
    Write-Host "Descomprimiendo..."
    Expand-To $zip "bbsc.dll" $kit
}
$dll = Join-Path $downloads "bbsc.dll"
Get-Verified $DllUrl $dll $DllSha
Copy-Item -LiteralPath $dll -Destination (Join-Path $kit "bbsc\bbsc.dll") -Force

Step "Preparando BBport para co-op"
$bin = Join-Path $port "bin"
$kitFiles = Join-Path $kit "BBSC-197-kit"
if (-not (Test-Path -LiteralPath (Join-Path $kitFiles "probe-bin\bb-probe.exe"))) { throw "Falta BBSC-197-kit en el paquete de BBSC." }
$original = Join-Path $port "bin-original"
if (-not (Test-Path -LiteralPath $original)) {
    $copy = "$original.tmp"
    if (Test-Path -LiteralPath $copy) { Remove-Item -LiteralPath $copy -Recurse -Force }
    Copy-Item -LiteralPath $bin -Destination $copy -Recurse
    Move-Item -LiteralPath $copy -Destination $original
}
# BBport warns at every start when bin\bb-probe.exe differs from bbport-files.json.
$manifestFile = Join-Path $port "bbport-files.json"
$manifest = Get-Content -LiteralPath $manifestFile -Raw -Encoding UTF8 | ConvertFrom-Json
if ($manifest.version -eq $PortVersion) {
    $probeBin = Join-Path $kitFiles "probe-bin"
    Copy-Item -Path (Join-Path $probeBin "*") -Destination $bin -Recurse -Force
    foreach ($file in Get-ChildItem -LiteralPath $probeBin -Recurse -File) {
        $name = "bin/" + $file.FullName.Substring($probeBin.Length + 1).Replace("\", "/")
        $entry = $manifest.files.PSObject.Properties[$name]
        if ($entry) { $entry.Value = (Get-FileHash -LiteralPath $file.FullName -Algorithm SHA256).Hash.ToLower() }
    }
    [IO.File]::WriteAllText($manifestFile, ($manifest | ConvertTo-Json -Depth 4), (New-Object Text.UTF8Encoding $false))
} else {
    Write-Host "Tu BBport es la version $($manifest.version), no la $PortVersion. No cambio sus archivos; el co-op puede fallar." -ForegroundColor Yellow
}
Copy-Item -LiteralPath (Join-Path $kitFiles "bbsc-launch.exe") -Destination (Join-Path $kit "bbsc\bbsc-launch.exe") -Force
# play-bbport.ps1 prefers emulator\bb-probe.exe, an older build that fails on BBport 1.9.7.
$oldProbe = Join-Path $kit "emulator\bb-probe.exe"
if (Test-Path -LiteralPath $oldProbe) { Move-Item -LiteralPath $oldProbe -Destination "$oldProbe.bak" -Force }

Step "Tu juego"
$settings = Join-Path $kit "tools\bbport-paths.json"
$bloodborne = Join-Path $port "Bloodborne.exe"
$eboot = $null
if (Test-Path -LiteralPath $settings) {
    $saved = Get-Content -LiteralPath $settings -Raw -Encoding UTF8 | ConvertFrom-Json
    if ($saved.eboot -and (Test-Path -LiteralPath $saved.eboot)) { $eboot = $saved.eboot }
}
if (-not $eboot -and $testRun) { $eboot = $env:BBSC_EBOOT }
if (-not $eboot) {
    Write-Host "Elige el eboot.bin de tu Bloodborne (CUSA03173, version 01.09)."
    Add-Type -AssemblyName System.Windows.Forms
    $dialog = New-Object System.Windows.Forms.OpenFileDialog
    $dialog.Title = "BBSC - elige eboot.bin"
    $dialog.Filter = "eboot.bin|eboot.bin|Todos los archivos|*.*"
    $owner = New-Object System.Windows.Forms.Form -Property @{ TopMost = $true }
    if ($dialog.ShowDialog($owner) -eq "OK") { $eboot = $dialog.FileName }
}
if ($eboot) {
    $json = [pscustomobject]@{ bbport = $bloodborne; eboot = $eboot } | ConvertTo-Json
    [IO.File]::WriteAllText($settings, $json, (New-Object Text.UTF8Encoding $false))
    Write-Host "Juego: $eboot"
} else {
    if (Test-Path -LiteralPath $settings) { Remove-Item -LiteralPath $settings -Force }
    Write-Host "No elegiste ninguno. El juego te lo va a pedir la primera vez que lo abras." -ForegroundColor Yellow
}

if (-not $testRun) {
    Step "Tu cuenta"
    if (Test-Path -LiteralPath (Join-Path $kit "tools\account.dat")) {
        Write-Host "Ya tienes una cuenta guardada."
    } else {
        & (Join-Path $kit "tools\create-account.ps1") -FromPlay
        if (-not (Test-Path -LiteralPath (Join-Path $kit "tools\account.dat"))) {
            Write-Host "La cuenta no quedo creada. El juego te la va a pedir la primera vez que lo abras." -ForegroundColor Yellow
        }
    }

    Step "Acceso directo"
    $desktop = [Environment]::GetFolderPath("Desktop")
    $link = (New-Object -ComObject WScript.Shell).CreateShortcut((Join-Path $desktop "BBSC Coop.lnk"))
    $link.TargetPath = Join-Path $kit "PLAY BBPORT + BBSC.cmd"
    $link.WorkingDirectory = $kit
    $link.IconLocation = "$bloodborne,0"
    $link.Save()
    Write-Host "Creado en el escritorio: BBSC Coop"
}

if (Test-Path -LiteralPath $downloads) { Remove-Item -LiteralPath $downloads -Recurse -Force }

Step "Listo"
Write-Host "1. Abre el acceso directo BBSC Coop. Si Windows pide permiso de firewall, aceptalo."
Write-Host "2. En el juego pon la misma clave de red que los demas (Opciones > Red)."
Write-Host "3. Anfitrion: Hunt Bell. Invitado: Kin Bell, y espera hasta 2 minutos."
Write-Host ""
Write-Host "Tus partidas de co-op quedan en:"
Write-Host "  $port\user\seamless-coop\savedata\1\"
Write-Host "Si ya tienes una partida de BBport, copia ahi tu carpeta CUSA00207 antes de jugar."
Write-Host "Para actualizar el mod mas adelante, ejecuta la version nueva de este archivo en la misma carpeta."
