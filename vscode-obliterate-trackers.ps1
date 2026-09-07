#Requires -Version 5.1
<#
.SYNOPSIS
  VSCode Microsoft Tracker Obliterator — Windows (STRICT)
  Siamo noi a dominare su Microsoft, non il contrario.

.DESCRIPTION
  Livello NORMAL (default): ammazza telemetria, crash reporter, experiments,
  feedback, Edit Sessions cloud, update automatici e telemetria delle
  estensioni MS. Lo Store estensioni CONTINUA a funzionare.

  Livello STRICT (-Strict): tutto di NORMAL + blocca anche il Marketplace
  Microsoft e punta a Open VSX (store 100% no-MS). Lo Store Microsoft
  smette di funzionare — è il prezzo per zero contatti MS.

.PARAMETER Strict
  Attiva il blocco totale anche del Marketplace + redirect a Open VSX.
.PARAMETER NoHosts
  Salta la modifica del file hosts.
.PARAMETER NoFirewall
  Salta le regole firewall outbound.
.PARAMETER NoProductPatch
  Salta la neutralizzazione di product.json.

.EXAMPLE
  powershell -ExecutionPolicy Bypass -File vscode-obliterate-trackers.ps1
.EXAMPLE
  powershell -ExecutionPolicy Bypass -File vscode-obliterate-trackers.ps1 -Strict
#>
[CmdletBinding()]
param(
  [switch]$Strict,
  [switch]$NoHosts,
  [switch]$NoFirewall,
  [switch]$NoProductPatch
)

$ErrorActionPreference = 'SilentlyContinue'
$stopwatch = [System.Diagnostics.Stopwatch]::StartNew()
$mode = if ($Strict) { 'STRICT ☠️  (zero Microsoft)' } else { 'NORMAL (store attivo)' }
Write-Host "`n=== VSCODE TRACKER OBLITERATOR — Windows [$mode] ===" -ForegroundColor Red

# ---------------------------------------------------------------
# 0. Admin check (serve solo per hosts + firewall)
# ---------------------------------------------------------------
$isAdmin = ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()
  ).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
if (-not $isAdmin) {
  Write-Host "[!] Non sei Admin: settings+argv+env verranno blindati comunque." -ForegroundColor Yellow
  Write-Host "    Rilancia come Amministratore per hosts + firewall." -ForegroundColor Yellow
}

# ---------------------------------------------------------------
# 1. Chiudi VSCode per scrivere i file in sicurezza
# ---------------------------------------------------------------
Get-Process Code, 'Visual Studio Code' -ErrorAction SilentlyContinue | Stop-Process -Force
Start-Sleep -Milliseconds 300

# ---------------------------------------------------------------
# 2. Percorsi (Stable + Insiders, così copriamo tutto)
# ---------------------------------------------------------------
$codeDirs = @("$env:APPDATA\Code", "$env:APPDATA\Code - Insiders") | Where-Object { $_ }
foreach ($base in $codeDirs) {
  if (-not (Test-Path $base)) { continue }
  $UserDir = Join-Path $base 'User'
  $SettingsPath = Join-Path $UserDir 'settings.json'
  $ArgvPath = Join-Path $base 'argv.json'
  New-Item -ItemType Directory -Force -Path $UserDir | Out-Null

  function Backup-File($Path) {
    if (Test-Path $Path) {
      $bak = "$Path.bak-$(Get-Date -Format 'yyyyMMdd-HHmmss')"
      Copy-Item $Path $bak -Force
      Write-Host "[backup] $Path" -ForegroundColor DarkGray
    }
  }

  # -----------------------------------------------------------
  # 3. settings.json — merge, MAI sovrascrittura cieca
  # -----------------------------------------------------------
  $killer = [ordered]@{
    'telemetry.telemetryLevel'                              = 'off'
    'telemetry.enableTelemetry'                             = $false
    'telemetry.enableCrashReporter'                         = $false
    'telemetry.feedback.enabled'                            = $false
    'workbench.enableExperiments'                           = $false
    'workbench.settings.enableNaturalLanguageSearch'        = $false
    'workbench.commandPalette.experimental.suggestCommands' = $false
    'workbench.startupEditor'                               = 'none'
    'workbench.tipOfTheDay.enabled'                         = $false
    'update.mode'                                           = 'manual'
    'update.showReleaseNotes'                               = $false
    'extensions.ignoreRecommendations'                      = $true
    'extensions.autoCheckUpdates'                           = $false
    'extensions.autoUpdate'                                 = $false
    'workbench.editSessions.enabled'                        = $false
    'core.editSessions.enabled'                             = $false
    'workbench.cloudChanges.autoStore'                      = 'off'
    'npm.fetchOnlinePackageInfo'                            = $false
    'typescript.surveys.enabled'                            = $false
    'redhat.telemetry.enabled'                              = $false
    'dotnetAcquisitionExtension.enableTelemetry'            = $false
    'powershell.telemetry.enabled'                          = $false
    'github.copilot.enable'                                 = $false
    'chat.commandCenter.enabled'                            = $false
    'inlineChat.holdToSpeak.enabled'                        = $false
    'workbench.experimental.editSessions.enabled'           = $false
  }
  if ($Strict) {
    # In STRICT lo Store MS è morto: disattiviamo tutto ciò che lo chiama
    $killer['extensions.autoCheckUpdates'] = $false
    $killer['extensions.autoUpdate'] = $false
    # Gallery Open VSX (store libero, no account MS)
    $killer['extensionsGallery.serviceUrl'] = 'https://open-vsx.org/vscode/gallery'
    $killer['extensionsGallery.itemUrl'] = 'https://open-vsx.org/vscode/item'
  }

  Backup-File $SettingsPath
  $settings = @{}
  if (Test-Path $SettingsPath) {
    try { $settings = Get-Content $SettingsPath -Raw | ConvertFrom-Json -AsHashtable } catch { $settings = @{} }
  }
  foreach ($k in $killer.Keys) { $settings[$k] = $killer[$k] }
  $settings | ConvertTo-Json -Depth 10 | Set-Content $SettingsPath -Encoding UTF8
  Write-Host "[ok] blindato: $SettingsPath" -ForegroundColor Green

  # -----------------------------------------------------------
  # 4. argv.json — kill switch runtime
  # -----------------------------------------------------------
  Backup-File $ArgvPath
  $argv = @{}
  if (Test-Path $ArgvPath) {
    try { $argv = Get-Content $ArgvPath -Raw | ConvertFrom-Json -AsHashtable } catch { $argv = @{} }
  }
  $argv['enable-crash-reporter'] = $false
  $argv['disable-telemetry'] = $true
  $argv['disable-experiments'] = $true
  $argv | ConvertTo-Json -Depth 10 | Set-Content $ArgvPath -Encoding UTF8
  Write-Host "[ok] blindato: $ArgvPath" -ForegroundColor Green
}

# ---------------------------------------------------------------
# 5. Env anti-telemetria persistenti (utente)
# ---------------------------------------------------------------
[Environment]::SetEnvironmentVariable('VSCODE_TELEMETRY_LEVEL', 'off', 'User')
[Environment]::SetEnvironmentVariable('DOTNET_CLI_TELEMETRY_OPTOUT', '1', 'User')
[Environment]::SetEnvironmentVariable('POWERSHELL_TELEMETRY_OPTOUT', '1', 'User')
[Environment]::SetEnvironmentVariable('NEXT_TELEMETRY_DISABLED', '1', 'User')
$env:VSCODE_TELEMETRY_LEVEL = 'off'
Write-Host '[ok] env VSCODE_TELEMETRY_LEVEL=off (+ DOTNET/POWERSHELL/NEXT opt-out)' -ForegroundColor Green

# ---------------------------------------------------------------
# 6. product.json — neutralizza gli endpoint hardcoded
# ---------------------------------------------------------------
if (-not $NoProductPatch) {
  $productPaths = @(
    "$env:LOCALAPPDATA\Programs\Microsoft VS Code\resources\app\product.json",
    "$env:LOCALAPPDATA\Programs\Microsoft VS Code Insiders\resources\app\product.json"
  )
  foreach ($pp in $productPaths) {
    if (-not (Test-Path $pp)) { continue }
    try {
      $pj = Get-Content $pp -Raw | ConvertFrom-Json -AsHashtable
      $changed = $false
      foreach ($key in @('enableTelemetry', 'sendASmile', 'aiConfig')) {
        if ($pj.ContainsKey($key)) { $pj[$key] = $false; $changed = $true }
      }
      if ($pj.ContainsKey('telemetryEndpoint')) { $pj['telemetryEndpoint'] = ''; $changed = $true }
      if ($pj.ContainsKey('crashReporter')) {
        $pj['crashReporter'] = @{ companyName = ''; productName = '' }; $changed = $true
      }
      if ($Strict -and $pj.ContainsKey('extensionsGallery')) {
        $pj['extensionsGallery'] = @{
          serviceUrl = 'https://open-vsx.org/vscode/gallery'
          itemUrl    = 'https://open-vsx.org/vscode/item'
        }
        $changed = $true
      }
      if ($changed) {
        Copy-Item $pp "$pp.bak-$(Get-Date -Format 'yyyyMMdd-HHmmss')" -Force
        $pj | ConvertTo-Json -Depth 20 | Set-Content $pp -Encoding UTF8
        Write-Host "[ok] neutralizzato: $pp" -ForegroundColor Green
      }
    } catch {
      Write-Host "[!] product.json non patchato (si sovrascrive agli update, normale): $pp" -ForegroundColor Yellow
    }
  }
}

# ---------------------------------------------------------------
# 7. Blocco DNS via hosts — SOLO telemetria in NORMAL, tutto in STRICT
# ---------------------------------------------------------------
$telemetryHosts = @(
  'vortex.data.microsoft.com',
  'vortex-win.data.microsoft.com',
  'v10.vortex-win.data.microsoft.com',
  'settings-win.data.microsoft.com',
  'telecommand.telemetry.microsoft.com',
  'telemetry.microsoft.com',
  'dc.services.visualstudio.com',
  'dc.applicationinsights.azure.com',
  'dc.applicationinsights.microsoft.com',
  'mobile.events.data.microsoft.com',
  'events.data.microsoft.com',
  'crl.microsoft.com',
  'functionschina.azurecomm.net'
)
$marketplaceHosts = @(
  'marketplace.visualstudio.com',
  'vscode.blob.core.windows.net',
  'vscode-update.azurewebsites.net',
  'update.code.visualstudio.com'
)
$blockList = $telemetryHosts
if ($Strict) { $blockList += $marketplaceHosts }

if (-not $NoHosts) {
  $hostsPath = "$env:SystemRoot\System32\drivers\etc\hosts"
  try {
    $hosts = Get-Content $hostsPath -Raw
    $added = 0
    foreach ($h in $blockList) {
      if ($hosts -notmatch [regex]::Escape($h)) {
        Add-Content $hostsPath "`n0.0.0.0 $h # vscode-obliterator"
        $added++
      }
    }
    Write-Host "[ok] hosts: $added domini bloccati" -ForegroundColor Green
    ipconfig /flushdns | Out-Null
  } catch {
    Write-Host '[!] hosts non modificato: rilancia come Amministratore.' -ForegroundColor Yellow
  }
}

# ---------------------------------------------------------------
# 8. Firewall outbound — seconda muraglia (solo Admin)
# ---------------------------------------------------------------
if (-not $NoFirewall -and $isAdmin) {
  $codeExe = "$env:LOCALAPPDATA\Programs\Microsoft VS Code\Code.exe"
  if (Test-Path $codeExe) {
    foreach ($d in $blockList) {
      $rule = "VSCode-Obliterator-$d"
      if (-not (Get-NetFirewallRule -DisplayName $rule -ErrorAction SilentlyContinue)) {
        New-NetFirewallRule -DisplayName $rule -Direction Outbound -Action Block `
          -Program $codeExe -RemoteAddress $d -ErrorAction SilentlyContinue | Out-Null
      }
    }
    Write-Host '[ok] regole firewall outbound create' -ForegroundColor Green
  }
} elseif (-not $NoFirewall) {
  Write-Host '[!] firewall saltato (serve Admin).' -ForegroundColor Yellow
}

# ---------------------------------------------------------------
# 9. Pulizia cache telemetria / crash / update task
# ---------------------------------------------------------------
$toWipe = @(
  "$env:APPDATA\Code\Crash Reports",
  "$env:APPDATA\Code - Insiders\Crash Reports",
  "$env:APPDATA\Code\CachedData",
  "$env:APPDATA\Code\logs",
  "$env:APPDATA\Code - Insiders\logs",
  "$env:TEMP\vscode-crashes"
)
foreach ($p in $toWipe) {
  if (Test-Path $p) {
    Remove-Item $p -Recurse -Force -ErrorAction SilentlyContinue
    Write-Host "[pulito] $p" -ForegroundColor DarkGray
  }
}
Get-ChildItem "$env:APPDATA\Code*" -Recurse -Include '*telemetry*', '*crash*' -ErrorAction SilentlyContinue |
  Remove-Item -Recurse -Force -ErrorAction SilentlyContinue
Get-ScheduledTask -TaskName '*VSCode*Update*' -ErrorAction SilentlyContinue |
  Disable-ScheduledTask -ErrorAction SilentlyContinue | Out-Null

# ---------------------------------------------------------------
# 10. Patch scorciatoie menu Start con flag anti-telemetria
# ---------------------------------------------------------------
$flags = ' --disable-telemetry --disable-experiments --disable-crash-reporter'
$links = Get-ChildItem "$env:APPDATA\Microsoft\Windows\Start Menu\Programs\Visual Studio Code*.lnk" -ErrorAction SilentlyContinue
foreach ($l in $links) {
  try {
    $sh = New-Object -ComObject WScript.Shell
    $sc = $sh.CreateShortcut($l.FullName)
    if ($sc.Arguments -notmatch 'disable-telemetry') {
      $sc.Arguments += $flags
      $sc.Save()
      Write-Host "[ok] patchata scorciatoia: $($l.Name)" -ForegroundColor Green
    }
  } catch { }
}

$stopwatch.Stop()
Write-Host "`n☠️  OBLITERATO [$mode] in $($stopwatch.ElapsedMilliseconds) ms. Riavvia VSCode." -ForegroundColor Red
Write-Host 'Verifica: Impostazioni -> cerca telemetry -> OFF | Help -> Toggle Developer Tools -> Network: zero chiamate vortex/dc.' -ForegroundColor Cyan
if (-not $Strict) {
  Write-Host 'Vuoi ZERO contatti MS (muore lo Store)? Rilancia con -Strict.' -ForegroundColor DarkYellow
} else {
  Write-Host 'STRICT attivo: installa estensioni da https://open-vsx.org (comando: code --install-extension file.vsix).' -ForegroundColor DarkYellow
}
