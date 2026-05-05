$UserPath = $env:USERPROFILE
$DownloadsPath = Join-Path $UserPath "Downloads"
$ProgressPreference = 'SilentlyContinue'

# --- FASE 1: INSTALACIÓN DE APLICACIONES ---
Write-Host "[+] Instalando herramientas de apoyo..." -ForegroundColor Cyan

$Apps = @(
    @{ Name = "Adobe Reader"; Url = "https://ardownload2.adobe.com/pub/adobe/reader/win/AcrobatDC/2100720091/AcroRdrDC2100720091_en_US.exe"; Args = "/sAll /rs /msi EULA_ACCEPT=YES" },
    @{ Name = "Thunderbird"; Url = "https://download.mozilla.org/?product=thunderbird-latest-ssl&os=win64&lang=es-ES"; Args = "-ms" },
    @{ Name = "AnyDesk"; Url = "https://download.anydesk.com/AnyDesk.exe"; Args = "--install --start-with-win --silent" },
    @{ Name = "Firefox"; Url = "https://download.mozilla.org/?product=firefox-latest-ssl&os=win64&lang=es-ES"; Args = "/S" },
    @{ Name = "7Zip"; Url = "https://www.7-zip.org/a/7z2408-x64.exe"; Args = "/S" },
    @{ Name = "ZeroTierOne"; Url = "https://download.zerotier.com/dist/ZeroTier%20One.msi"; Args = "/quiet /norestart" }
)

foreach ($App in $Apps) {
    # CORRECCIÓN: Envolver el if en $() para compatibilidad
    $Extension = $(if ($App.Url -match "\.msi") { ".msi" } else { ".exe" })
    $FilePath = Join-Path $DownloadsPath "$($App.Name)$Extension"
    
    Write-Host "    [>] Procesando $($App.Name)... " -NoNewline -ForegroundColor Yellow
    
    try {
        Invoke-WebRequest -Uri $App.Url -OutFile $FilePath -ErrorAction Stop
        
        $Process = Start-Process -FilePath $FilePath -ArgumentList $App.Args -Wait -PassThru
        
        if ($Process.ExitCode -eq 0 -or $Process.ExitCode -eq 3010) {
            Write-Host "HECHO" -ForegroundColor Green
        } else {
            Write-Host "ERROR (Código: $($Process.ExitCode))" -ForegroundColor Red
        }
    } catch { 
        Write-Host "FALLÓ LA DESCARGA O INSTALACIÓN" -ForegroundColor Red 
    }
}

# --- FASE 2: INSTALACIÓN DE MICROSOFT OFFICE 2021 (ODT METHOD) ---
Write-Host "`n[+] Iniciando instalación de Microsoft Office 2021 Developer/Pro..." -ForegroundColor Cyan
Write-Host "    [!] Este proceso puede tardar 10-15 min. No cierres la ventana." -ForegroundColor DarkYellow

$OdtUrl = "https://download.microsoft.com/download/2/7/A/27AF1BE6-DD20-4CB4-B154-EBAB8A7D4A7E/officedeploymenttool_17328-20162.exe"
$OdtPath = Join-Path $DownloadsPath "ODT_Setup.exe"
$OdtExtractPath = Join-Path $DownloadsPath "OfficeSetup"

if (!(Test-Path $OdtExtractPath)) { New-Item -ItemType Directory -Path $OdtExtractPath | Out-Null }

try {
    Write-Host "    [>] Descargando Office Deployment Tool... " -NoNewline -ForegroundColor Yellow
    # CORRECCIÓN: Añadir -ErrorAction Stop para que el 'catch' realmente funcione
    Invoke-WebRequest -Uri $OdtUrl -OutFile $OdtPath -ErrorAction Stop
    
    Start-Process $OdtPath -ArgumentList "/extract:`"$OdtExtractPath`" /quiet" -Wait
    Write-Host "HECHO" -ForegroundColor Green

    $ConfigXml = @"
<Configuration>
  <Add OfficeClientEdition="64" Channel="PerpetualVL2021">
    <Product ID="ProPlus2021Volume">
      <Language ID="es-es" />
    </Product>
  </Add>
  <Display Level="None" AcceptEULA="TRUE" />
</Configuration>
"@
    $ConfigPath = Join-Path $OdtExtractPath "installConfig.xml"
    
    # CORRECCIÓN: Usar escritura nativa para evitar que PowerShell corrompa el XML para Office
    [System.IO.File]::WriteAllText($ConfigPath, $ConfigXml)

    Write-Host "    [>] Descargando e instalando componentes de Office 2021... " -NoNewline -ForegroundColor Yellow
    $SetupExe = Join-Path $OdtExtractPath "setup.exe"
    
    Start-Process $SetupExe -ArgumentList "/configure `"$ConfigPath`"" -Wait
    Write-Host "INSTALADO" -ForegroundColor Green
} catch {
    # CORRECCIÓN: Imprimir el mensaje exacto de la excepción para depurar si algo falla
    Write-Host "FALLO: $($_.Exception.Message)" -ForegroundColor Red
}

# --- FASE 3: LIMPIEZA AUTOMÁTICA ---
Write-Host "`n[+] Eliminando instaladores residuales..." -ForegroundColor Cyan

foreach ($App in $Apps) {
    # CORRECCIÓN: Misma corrección del $() para el if
    $Extension = $(if ($App.Url -match "\.msi") { ".msi" } else { ".exe" })
    $FilePath = Join-Path $DownloadsPath "$($App.Name)$Extension"
    
    if (Test-Path $FilePath) {
        Remove-Item -Path $FilePath -Force
        Write-Host "    [-] Borrado: $($App.Name)$Extension" -ForegroundColor Gray
    }
}

Write-Host "`n[!] Script completado." -ForegroundColor Green
