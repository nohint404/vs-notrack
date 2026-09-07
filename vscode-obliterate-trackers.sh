#!/usr/bin/env bash
# vs-notrack — Linux + macOS. Usage: curl -fsSL <url> | bash  (interactive menu) | STRICT=1 COPILOT=purge MENU=0 bash script.sh
set -u
START_MS=$(date +%s%3N 2>/dev/null || echo 0)
STRICT="${STRICT:-0}"
NO_HOSTS="${NO_HOSTS:-0}"
NO_PRODUCT_PATCH="${NO_PRODUCT_PATCH:-0}"
MENU="${MENU:-1}"
MODE_OPT="${MODE_OPT:-}"
COPILOT="${COPILOT:-keep}"

if [ -n "${SUDO_USER:-}" ] && [ "$SUDO_USER" != "root" ]; then
  SUDO_HOME="$(getent passwd "$SUDO_USER" | cut -d: -f6)"
  [ -n "$SUDO_HOME" ] && [ -d "$SUDO_HOME" ] && HOME="$SUDO_HOME"
fi

case "$MODE_OPT" in strict) STRICT=1;; normal) STRICT=0;; esac

can_prompt() {
  [ -t 0 ] && return 0
  exec 9< /dev/tty 2>/dev/null && { exec 9<&-; return 0; }
  return 1
}
tread() {
  if [ -t 0 ]; then read -r "$1" || true; else read -r "$1" < /dev/tty || true; fi
}

if [ "$MENU" = "1" ] && can_prompt; then
  echo ""
  echo "What should I nuke?"
  echo "  [1] NORMAL lockdown (default) — Store keeps working"
  echo "  [2] STRICT lockdown — zero Microsoft, MS Store dies"
  printf "Mode [1/2]: "; m=""; tread m
  if [ "$m" = "2" ]; then STRICT=1; elif [ -n "$m" ]; then STRICT=0; fi
  echo ""
  echo "Copilot?"
  echo "  [1] keep, but disabled (default)"
  echo "  [2] uninstall Copilot extensions"
  echo "  [3] uninstall + purge Copilot data"
  printf "Copilot [1/2/3]: "; c=""; tread c
  case "$c" in 2) COPILOT=uninstall;; 3) COPILOT=purge;; *) COPILOT=keep;; esac
fi

if [ "$STRICT" = "1" ]; then MODE="STRICT ☠️  (zero Microsoft)"; else MODE="NORMAL (store working)"; fi
echo "=== VSCODE TRACKER OBLITERATOR — Linux/macOS [$MODE] ==="

OS="$(uname -s)"

pkill -f "Visual Studio Code" 2>/dev/null; pkill -x code 2>/dev/null; pkill -x codium 2>/dev/null; sleep 0.3

process_base() {
  BASE="$1"
  [ -d "$BASE" ] || return 0
  USER_DIR="$BASE/User"
  SETTINGS="$USER_DIR/settings.json"
  ARGV="$BASE/argv.json"
  mkdir -p "$USER_DIR"

  [ -f "$SETTINGS" ] && cp -f "$SETTINGS" "$SETTINGS.bak-$(date +%Y%m%d-%H%M%S)" && echo "[backup] $SETTINGS"
  STRICT_PY="$STRICT" python3 -c '
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
print(f"[ok] hardened: {path}")
' "$SETTINGS"

  [ -f "$ARGV" ] && cp -f "$ARGV" "$ARGV.bak-$(date +%Y%m%d-%H%M%S)" && echo "[backup] $ARGV"
  python3 -c '
import json, os, sys
path = sys.argv[1]
data = {}
if os.path.exists(path):
    try: data = json.load(open(path))
    except Exception: data = {}
data.update({"enable-crash-reporter": False, "disable-telemetry": True, "disable-experiments": True})
json.dump(data, open(path, "w"), indent=4)
print(f"[ok] hardened: {path}")
' "$ARGV"
}

list_bases() {
  if [ "$OS" = "Darwin" ]; then
    printf '%s\n' "$HOME/Library/Application Support/Code" "$HOME/Library/Application Support/Code - Insiders"
  else
    printf '%s\n' "$HOME/.config/Code" "$HOME/.config/Code - Insiders"
  fi
}

list_bases | while IFS= read -r b; do process_base "$b"; done

if [ "$COPILOT" = "uninstall" ] || [ "$COPILOT" = "purge" ]; then
  if command -v code >/dev/null 2>&1; then
    for ext in github.copilot github.copilot-chat; do
      code --uninstall-extension "$ext" --force >/dev/null 2>&1
      if code --list-extensions 2>/dev/null | grep -qxi "$ext"; then echo "[info] still present (built-in?): $ext"; else echo "[ok] uninstalled: $ext"; fi
    done
  else
    echo "[!] 'code' CLI not found: skipping extension uninstall"
  fi
fi

if [ "$COPILOT" = "purge" ]; then
  list_bases | while IFS= read -r b; do
    rm -rf "$b"/User/globalStorage/github.copilot* 2>/dev/null
  done
  echo "[ok] Copilot data purged"
fi

for rc in "$HOME/.profile" "$HOME/.bashrc" "$HOME/.zshrc"; do
  [ -f "$rc" ] || continue
  grep -q "VSCODE_TELEMETRY_LEVEL=off" "$rc" 2>/dev/null || {
    printf '\n# vscode-obliterator\nexport VSCODE_TELEMETRY_LEVEL=off\nexport DOTNET_CLI_TELEMETRY_OPTOUT=1\nexport POWERSHELL_TELEMETRY_OPTOUT=1\nexport NEXT_TELEMETRY_DISABLED=1\n' >> "$rc"
    echo "[ok] env added to $rc"
  }
done
export VSCODE_TELEMETRY_LEVEL=off DOTNET_CLI_TELEMETRY_OPTOUT=1 POWERSHELL_TELEMETRY_OPTOUT=1 NEXT_TELEMETRY_DISABLED=1

if [ "$NO_PRODUCT_PATCH" != "1" ]; then
  patch_product_json() {
    [ -f "$1" ] || return 0
    STRICT_PY="$STRICT" python3 -c '
import json, sys, os, shutil, datetime
path = sys.argv[1]
strict = os.environ.get("STRICT_PY") == "1"
try:
    data = json.load(open(path))
except Exception as e:
    print(f"[!] product.json unreadable: {e}"); sys.exit(0)
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
    print(f"[info] product.json already neutral: {path}"); sys.exit(0)
try:
    shutil.copy(path, path + ".bak-" + datetime.datetime.now().strftime("%Y%m%d-%H%M%S"))
    json.dump(data, open(path, "w"), indent=2)
    print(f"[ok] neutralized: {path}")
except PermissionError:
    print(f"[!] product.json not writable (needs sudo): {path}")
' "$1"
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

TELEMETRY_DOMAINS="vortex.data.microsoft.com vortex-win.data.microsoft.com v10.vortex-win.data.microsoft.com settings-win.data.microsoft.com telecommand.telemetry.microsoft.com telemetry.microsoft.com dc.services.visualstudio.com dc.applicationinsights.azure.com dc.applicationinsights.microsoft.com mobile.events.data.microsoft.com events.data.microsoft.com crl.microsoft.com functionschina.azurecomm.net"
MARKETPLACE_DOMAINS="marketplace.visualstudio.com vscode.blob.core.windows.net vscode-update.azurewebsites.net update.code.visualstudio.com"
DOMAINS="$TELEMETRY_DOMAINS"
[ "$STRICT" = "1" ] && DOMAINS="$DOMAINS $MARKETPLACE_DOMAINS"

if [ "$NO_HOSTS" = "1" ]; then
  echo "[skip] hosts blocking disabled (NO_HOSTS=1)"
elif [ -w /etc/hosts ]; then
  for d in $DOMAINS; do
    grep -q "$d" /etc/hosts || echo "0.0.0.0 $d # vscode-obliterator" >> /etc/hosts
  done
  echo "[ok] hosts blocked ($(echo "$DOMAINS" | wc -w | tr -d ' ') domains)"
  if [ "$OS" = "Darwin" ]; then dscacheutil -flushcache 2>/dev/null; elif command -v systemd-resolve >/dev/null 2>&1; then systemd-resolve --flush-caches 2>/dev/null; fi
else
  if [ "$(id -u)" -eq 0 ]; then
    echo "[!] /etc/hosts not writable (read-only filesystem or immutable file?)"
  else
    echo "[!] /etc/hosts not writable: sudo goes on bash, not on curl:"
    echo "    curl -fsSL <url> | sudo bash"
  fi
fi

if [ "$OS" != "Darwin" ]; then
  for d in "$HOME/.local/share/applications/visual-studio-code.desktop" "/usr/share/applications/visual-studio-code.desktop" "/usr/share/applications/code.desktop"; do
    [ -f "$d" ] || continue
    if ! grep -q "disable-telemetry" "$d" 2>/dev/null; then
      if [ -w "$d" ]; then
        sed -i 's|Exec=/usr/share/code/code|Exec=/usr/share/code/code --disable-telemetry --disable-experiments --disable-crash-reporter|; s|Exec=/usr/bin/code|Exec=/usr/bin/code --disable-telemetry --disable-experiments --disable-crash-reporter|' "$d"
        echo "[ok] patched launcher $d"
      else
        echo "[!] launcher $d not writable (needs sudo), skipping"
      fi
    fi
  done
else
  if command -v code >/dev/null 2>&1 && [ -w /usr/local/bin/code 2>/dev/null ]; then
    echo "[info] macOS: add alias: alias code='code --disable-telemetry --disable-experiments --disable-crash-reporter'"
  fi
fi

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
echo "[ok] telemetry/crash caches cleaned"

if [ "$START_MS" != "0" ]; then
  END_MS=$(date +%s%3N); echo ""; echo "☠️  OBLITERATED [$MODE] in $((END_MS-START_MS)) ms. Restart VSCode."
else
  echo ""; echo "☠️  OBLITERATED [$MODE]. Restart VSCode."
fi
echo "Verify: Settings -> search telemetry -> OFF."
if [ "$STRICT" = "1" ]; then
  echo "STRICT active: get extensions from https://open-vsx.org (code --install-extension file.vsix)."
else
  echo "Want ZERO MS contacts (Store dies)? Re-run with STRICT=1."
fi
