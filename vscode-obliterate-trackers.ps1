#Requires -Version 5.1
# vs-notrack — Windows. Usage: powershell -ExecutionPolicy Bypass -File vscode-obliterate-trackers.ps1 [-Strict] [-NoHosts] [-NoFirewall] [-NoProductPatch]
[CmdletBinding()]
param(
  [switch]$Strict,
  [switch]$NoHosts,
  [switch]$NoFirewall,
  [switch]$NoProductPatch
)
if ($env:VSCODE_OBLITERATOR_STRICT -eq '1') { $Strict = $true }

$ErrorActionPreference = 'SilentlyContinue'
$stopwatch = [System.Diagnostics.Stopwatch]::StartNew()
$mode = if ($Strict) { 'STRICT ☠️  (zero Microsoft)' } else { 'NORMAL (store working)' }
Write-Host "`n=== VSCODE TRACKER OBLITERATOR — Windows [$mode] ===" -ForegroundColor Red

$isAdmin = ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()
  ).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
if (-not $isAdmin) {
  Write-Host "[!] Not Admin: settings+argv+env will still be locked down." -ForegroundColor Yellow
  Write-Host "    Re-run as Administrator for hosts + firewall." -ForegroundColor Yellow
}

Get-Process Code, 'Visual Studio Code' -ErrorAction SilentlyContinue | Stop-Process -Force
Start-Sleep -Milliseconds 300

$codeDirs = @("$env:APPDATA\Code", "$env:APPDATA\Code - Insiders")
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
  Write-Host "[ok] hardened: $SettingsPath" -ForegroundColor Green

  Backup-File $ArgvPath
  $argv = @{}
  if (Test-Path $ArgvPath) {
    try { $argv = Get-Content $ArgvPath -Raw | ConvertFrom-Json -AsHashtable } catch { $argv = @{} }
  }
  $argv['enable-crash-reporter'] = $false
  $argv['disable-telemetry'] = $true
  $argv['disable-experiments'] = $true
  $argv | ConvertTo-Json -Depth 10 | Set-Content $ArgvPath -Encoding UTF8
  Write-Host "[ok] hardened: $ArgvPath" -ForegroundColor Green
}

[Environment]::SetEnvironmentVariable('VSCODE_TELEMETRY_LEVEL', 'off', 'User')
[Environment]::SetEnvironmentVariable('DOTNET_CLI_TELEMETRY_OPTOUT', '1', 'User')
[Environment]::SetEnvironmentVariable('POWERSHELL_TELEMETRY_OPTOUT', '1', 'User')
[Environment]::SetEnvironmentVariable('NEXT_TELEMETRY_DISABLED', '1', 'User')
$env:VSCODE_TELEMETRY_LEVEL = 'off'
Write-Host '[ok] env VSCODE_TELEMETRY_LEVEL=off (+ DOTNET/POWERSHELL/NEXT opt-out)' -ForegroundColor Green

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
        Write-Host "[ok] neutralized: $pp" -ForegroundColor Green
      }
    } catch {
      Write-Host "[!] product.json not patched (overwritten on updates, normal): $pp" -ForegroundColor Yellow
    }
  }
}

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
    Write-Host "[ok] hosts: $added domains blocked" -ForegroundColor Green
    ipconfig /flushdns | Out-Null
  } catch {
    Write-Host '[!] hosts not modified: re-run as Administrator.' -ForegroundColor Yellow
  }
}

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
    Write-Host '[ok] outbound firewall rules created' -ForegroundColor Green
  }
} elseif (-not $NoFirewall) {
  Write-Host '[!] firewall skipped (needs Admin).' -ForegroundColor Yellow
}

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
    Write-Host "[cleaned] $p" -ForegroundColor DarkGray
  }
}
Get-ChildItem "$env:APPDATA\Code*" -Recurse -Include '*telemetry*', '*crash*' -ErrorAction SilentlyContinue |
  Remove-Item -Recurse -Force -ErrorAction SilentlyContinue
Get-ScheduledTask -TaskName '*VSCode*Update*' -ErrorAction SilentlyContinue |
  Disable-ScheduledTask -ErrorAction SilentlyContinue | Out-Null

$flags = ' --disable-telemetry --disable-experiments --disable-crash-reporter'
$links = Get-ChildItem "$env:APPDATA\Microsoft\Windows\Start Menu\Programs\Visual Studio Code*.lnk" -ErrorAction SilentlyContinue
foreach ($l in $links) {
  try {
    $sh = New-Object -ComObject WScript.Shell
    $sc = $sh.CreateShortcut($l.FullName)
    if ($sc.Arguments -notmatch 'disable-telemetry') {
      $sc.Arguments += $flags
      $sc.Save()
      Write-Host "[ok] patched shortcut: $($l.Name)" -ForegroundColor Green
    }
  } catch { }
}

$stopwatch.Stop()
Write-Host "`n☠️  OBLITERATED [$mode] in $($stopwatch.ElapsedMilliseconds) ms. Restart VSCode." -ForegroundColor Red
Write-Host 'Verify: Settings -> search telemetry -> OFF | Help -> Toggle Developer Tools -> Network: zero vortex/dc calls.' -ForegroundColor Cyan
if (-not $Strict) {
  Write-Host 'Want ZERO MS contacts (Store dies)? Re-run with -Strict.' -ForegroundColor DarkYellow
} else {
  Write-Host 'STRICT active: install extensions from https://open-vsx.org (run: code --install-extension file.vsix).' -ForegroundColor DarkYellow
}
