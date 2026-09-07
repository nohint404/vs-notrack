#!/usr/bin/env bash
# VSCode Microsoft Tracker Obliterator — Linux + macOS (STRICT)
# Siamo noi a dominare su Microsoft, non il contrario.
#
# NORMAL (default): ammazza telemetria/crash/experiments/feedback/cloud-sync,
#   neutralizza product.json, blocca i domini telemetria, patcha il launcher.
#   Lo Store estensioni CONTINUA a funzionare.
# STRICT (STRICT=1): + blocca anche il Marketplace MS e punta a Open VSX.
#   Lo Store Microsoft smette di funzionare — zero contatti MS.
#
# Uso:
#   chmod +x vscode-obliterate-trackers.sh
#   ./vscode-obliterate-trackers.sh              # NORMAL
#   STRICT=1 ./vscode-obliterate-trackers.sh     # STRICT ☠️
#   sudo ./vscode-obliterate-trackers.sh         # + blocco /etc/hosts
#   STRICT=1 NO_HOSTS=1 NO_PRODUCT_PATCH=1 ./vscode-obliterate-trackers.sh
set -u
START_MS=$(date +%s%3N 2>/dev/null || echo 0)
STRICT="${STRICT:-0}"
NO_HOSTS="${NO_HOSTS:-0}"
NO_PRODUCT_PATCH="${NO_PRODUCT_PATCH:-0}"

if [ "$STRICT" = "1" ]; then MODE="STRICT ☠️  (zero Microsoft)"; else MODE="NORMAL (store attivo)"; fi
echo "=== VSCODE TRACKER OBLITERATOR — Linux/macOS [$MODE] ==="

# ---------------------------------------------------------------
# 0. Rileva OS e percorsi (Stable + Insiders + VSCodium residue)
# ---------------------------------------------------------------
OS="$(uname -s)"

pkill -f "Visual Studio Code" 2>/dev/null; pkill -x code 2>/dev/null; pkill -x codium 2>/dev/null; sleep 0.3

# ---------------------------------------------------------------
# 1+2. settings.json + argv.json per ogni installazione trovata
# ---------------------------------------------------------------
# Nota: i path contengono spazi ("Code - Insiders"), quindi niente word-splitting:
# ogni base viene passata come singolo argomento a process_base.
process_base() {
  BASE="$1"
  [ -d "$BASE" ] || return 0
  USER_DIR="$BASE/User"
  SETTINGS="$USER_DIR/settings.json"
  ARGV="$BASE/argv.json"
  mkdir -p "$USER_DIR"

  [ -f "$SETTINGS" ] && cp -f "$SETTINGS" "$SETTINGS.bak-$(date +%Y%m%d-%H%M%S)" && echo "[backup] $SETTINGS"
  STRICT_PY="$STRICT" python3 - "$SETTINGS" <<'EOF'
import json, os, sys
path = sys.argv[1]
strict = os.environ.get("STRICT_PY") == "1"
killer = {
  "telemetry.telemetryLevel": "off",
  "telemetry.enableTelemetry": False,
  "telemetry.enableCrashReporter": False,
  "telemetry.feedback.enabled": False,
  "workbench.enableExperiments": False,
  "workbench.settings.enableNaturalLanguageSearch": False,
  "workbench.commandPalette.experimental.suggestCommands": False,
  "workbench.startupEditor": "none",
  "workbench.tipOfTheDay.enabled": False,
  "update.mode": "manual",
  "update.showReleaseNotes": False,
  "extensions.ignoreRecommendations": True,
  "extensions.autoCheckUpdates": False,
  "extensions.autoUpdate": False,
  "workbench.editSessions.enabled": False,
  "core.editSessions.enabled": False,
  "workbench.cloudChanges.autoStore": "off",
  "workbench.experimental.editSessions.enabled": False,
  "npm.fetchOnlinePackageInfo": False,
  "typescript.surveys.enabled": False,
  "redhat.telemetry.enabled": False,
  "dotnetAcquisitionExtension.enableTelemetry": False,
  "powershell.telemetry.enabled": False,
  "github.copilot.enable": False,
  "chat.commandCenter.enabled": False,
  "inlineChat.holdToSpeak.enabled": False,
}
if strict:
    killer["extensionsGallery.serviceUrl"] = "https://open-vsx.org/vscode/gallery"
    killer["extensionsGallery.itemUrl"] = "https://open-vsx.org/vscode/item"
data = {}
if os.path.exists(path):
    try: data = json.load(open(path))
    except Exception: data = {}
data.update(killer)
json.dump(data, open(path, "w"), indent=4)
print(f"[ok] blindato: {path}")
EOF

  [ -f "$ARGV" ] && cp -f "$ARGV" "$ARGV.bak-$(date +%Y%m%d-%H%M%S)" && echo "[backup] $ARGV"
  python3 - "$ARGV" <<'EOF'
import json, os, sys
path = sys.argv[1]
data = {}
if os.path.exists(path):
    try: data = json.load(open(path))
    except Exception: data = {}
data.update({"enable-crash-reporter": False, "disable-telemetry": True, "disable-experiments": True})
json.dump(data, open(path, "w"), indent=4)
print(f"[ok] blindato: {path}")
EOF
}

if [ "$OS" = "Darwin" ]; then
  process_base "$HOME/Library/Application Support/Code"
  process_base "$HOME/Library/Application Support/Code - Insiders"
else
  process_base "$HOME/.config/Code"
  process_base "$HOME/.config/Code - Insiders"
fi

# ---------------------------------------------------------------
# 3. Env persistente anti-telemetria
# ---------------------------------------------------------------
for rc in "$HOME/.profile" "$HOME/.bashrc" "$HOME/.zshrc"; do
  [ -f "$rc" ] || continue
  grep -q "VSCODE_TELEMETRY_LEVEL=off" "$rc" 2>/dev/null || {
    printf '\n# vscode-obliterator\nexport VSCODE_TELEMETRY_LEVEL=off\nexport DOTNET_CLI_TELEMETRY_OPTOUT=1\nexport POWERSHELL_TELEMETRY_OPTOUT=1\nexport NEXT_TELEMETRY_DISABLED=1\n' >> "$rc"
    echo "[ok] env aggiunto in $rc"
  }
done
export VSCODE_TELEMETRY_LEVEL=off DOTNET_CLI_TELEMETRY_OPTOUT=1 POWERSHELL_TELEMETRY_OPTOUT=1 NEXT_TELEMETRY_DISABLED=1

# ---------------------------------------------------------------
# 4. product.json — neutralizza endpoint hardcoded
# ---------------------------------------------------------------
if [ "$NO_PRODUCT_PATCH" != "1" ]; then
  patch_product_json() {
    # $1 = percorso product.json
    [ -f "$1" ] || return 0
    STRICT_PY="$STRICT" python3 - "$1" <<'EOF'
import json, sys, os, shutil, datetime
path = sys.argv[1]
strict = os.environ.get("STRICT_PY") == "1"
try:
    data = json.load(open(path))
except Exception as e:
    print(f"[!] product.json illeggibile: {e}"); sys.exit(0)
changed = False
for k in ("enableTelemetry", "sendASmile", "aiConfig"):
    if k in data: data[k] = False; changed = True
if "telemetryEndpoint" in data: data["telemetryEndpoint"] = ""; changed = True
if "crashReporter" in data: data["crashReporter"] = {"companyName": "", "productName": ""}; changed = True
if strict and "extensionsGallery" in data:
    data["extensionsGallery"] = {"serviceUrl": "https://open-vsx.org/vscode/gallery",
                                 "itemUrl": "https://open-vsx.org/vscode/item"}
    changed = True
if not changed:
    print(f"[info] product.json gia' neutro: {path}"); sys.exit(0)
try:
    shutil.copy(path, path + ".bak-" + datetime.datetime.now().strftime("%Y%m%d-%H%M%S"))
    json.dump(data, open(path, "w"), indent=2)
    print(f"[ok] neutralizzato: {path}")
except PermissionError:
    print(f"[!] product.json non scrivibile (serve sudo): {path}")
EOF
  }
  if [ "$OS" = "Darwin" ]; then
    patch_product_json "/Applications/Visual Studio Code.app/Contents/Resources/app/product.json"
    patch_product_json "/Applications/Visual Studio Code - Insiders.app/Contents/Resources/app/product.json"
  else
    patch_product_json "/usr/share/code/resources/app/product.json"
    patch_product_json "/opt/visual-studio-code/resources/app/product.json"
    patch_product_json "/usr/lib/code/product.json"
  fi
fi

# ---------------------------------------------------------------
# 5. Blocco DNS via hosts
# ---------------------------------------------------------------
TELEMETRY_DOMAINS="vortex.data.microsoft.com vortex-win.data.microsoft.com v10.vortex-win.data.microsoft.com settings-win.data.microsoft.com telecommand.telemetry.microsoft.com telemetry.microsoft.com dc.services.visualstudio.com dc.applicationinsights.azure.com dc.applicationinsights.microsoft.com mobile.events.data.microsoft.com events.data.microsoft.com crl.microsoft.com functionschina.azurecomm.net"
MARKETPLACE_DOMAINS="marketplace.visualstudio.com vscode.blob.core.windows.net vscode-update.azurewebsites.net update.code.visualstudio.com"
DOMAINS="$TELEMETRY_DOMAINS"
[ "$STRICT" = "1" ] && DOMAINS="$DOMAINS $MARKETPLACE_DOMAINS"

if [ "$NO_HOSTS" = "1" ]; then
  echo "[skip] blocco hosts disattivato (NO_HOSTS=1)"
elif [ -w /etc/hosts ]; then
  for d in $DOMAINS; do
    grep -q "$d" /etc/hosts || echo "0.0.0.0 $d # vscode-obliterator" >> /etc/hosts
  done
  echo "[ok] hosts bloccato ($(echo "$DOMAINS" | wc -w | tr -d ' ') domini)"
  if [ "$OS" = "Darwin" ]; then dscacheutil -flushcache 2>/dev/null; elif command -v systemd-resolve >/dev/null 2>&1; then systemd-resolve --flush-caches 2>/dev/null; fi
else
  echo "[!] /etc/hosts non scrivibile: rilancia con sudo per il blocco DNS"
  echo "    sudo ./vscode-obliterate-trackers.sh"
fi

# ---------------------------------------------------------------
# 6. Patch launcher Linux (.desktop) con flag anti-telemetria
# ---------------------------------------------------------------
if [ "$OS" != "Darwin" ]; then
  for d in "$HOME/.local/share/applications/visual-studio-code.desktop" "/usr/share/applications/visual-studio-code.desktop" "/usr/share/applications/code.desktop"; do
    [ -f "$d" ] || continue
    if ! grep -q "disable-telemetry" "$d" 2>/dev/null; then
      if [ -w "$d" ]; then
        sed -i 's|Exec=/usr/share/code/code|Exec=/usr/share/code/code --disable-telemetry --disable-experiments --disable-crash-reporter|; s|Exec=/usr/bin/code|Exec=/usr/bin/code --disable-telemetry --disable-experiments --disable-crash-reporter|' "$d"
        echo "[ok] patchato launcher $d"
      else
        echo "[!] launcher $d non scrivibile (serve sudo), salto"
      fi
    fi
  done
else
  # macOS: wrapper `code` con flag (se code CLI installata)
  if command -v code >/dev/null 2>&1 && [ -w /usr/local/bin/code 2>/dev/null ]; then
    echo "[info] macOS: aggiungi alias: alias code='code --disable-telemetry --disable-experiments --disable-crash-reporter'"
  fi
fi

# ---------------------------------------------------------------
# 7. Pulizia cache telemetria / crash
# ---------------------------------------------------------------
if [ "$OS" = "Darwin" ]; then
  rm -rf "$HOME/Library/Application Support/Code/Crash Reports" \
         "$HOME/Library/Application Support/Code/logs" \
         "$HOME/Library/Application Support/Code/CachedData" 2>/dev/null
  find "$HOME/Library/Application Support/Code" -iname "*telemetry*" -o -iname "*crash*" 2>/dev/null | xargs rm -rf 2>/dev/null
else
  rm -rf "$HOME/.config/Code/Crash Reports" "$HOME/.config/Code - Insiders/Crash Reports" \
         "$HOME/.config/Code/CachedData" "$HOME/.config/Code/logs" \
         "$HOME/.config/Code - Insiders/logs" "$HOME/.vscode-crash" /tmp/vscode-crashes 2>/dev/null
  find "$HOME/.config/Code"* -iname "*telemetry*" -o -iname "*crash*" 2>/dev/null | xargs rm -rf 2>/dev/null
fi
echo "[ok] cache telemetria/crash pulite"

if [ "$START_MS" != "0" ]; then
  END_MS=$(date +%s%3N); echo ""; echo "☠️  OBLITERATO [$MODE] in $((END_MS-START_MS)) ms. Riavvia VSCode."
else
  echo ""; echo "☠️  OBLITERATO [$MODE]. Riavvia VSCode."
fi
echo "Verifica: Impostazioni -> cerca telemetry -> OFF."
if [ "$STRICT" = "1" ]; then
  echo "STRICT attivo: estensioni da https://open-vsx.org (code --install-extension file.vsix)."
else
  echo "Vuoi ZERO contatti MS (muore lo Store)? Rilancia con STRICT=1."
fi
