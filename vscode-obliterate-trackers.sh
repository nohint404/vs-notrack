#!/usr/bin/env bash
# vs-notrack - Linux + macOS. Usage: curl -fsSL <url> | bash  (interactive menu) | STRICT=1 COPILOT=purge MENU=0 bash script.sh
set -u
START_MS=$(date +%s%3N 2>/dev/null || echo 0)
STRICT="${STRICT:-0}"
NO_HOSTS="${NO_HOSTS:-0}"
NO_PRODUCT_PATCH="${NO_PRODUCT_PATCH:-0}"
MENU="${MENU:-1}"
MODE_OPT="${MODE_OPT:-}"
COPILOT="${COPILOT:-purge}"

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

if [ -t 1 ] && [ -z "${NO_COLOR:-}" ]; then
  C_T=$'\033[1;36m'; C_G=$'\033[32m'; C_Y=$'\033[33m'; C_R=$'\033[31m'; C_D=$'\033[2m'; C_0=$'\033[0m'
else
  C_T=""; C_G=""; C_Y=""; C_R=""; C_D=""; C_0=""
fi
menu_head() {
  printf '%s\n' "${C_T}----------------------------------------${C_0}" "  $1" "${C_T}----------------------------------------${C_0}"
}

if [ "$MENU" = "1" ] && can_prompt; then
  echo ""
  menu_head "vs-notrack: choose lockdown level"
  printf '  %s[1] NORMAL%s  %s- telemetry off, Store works (default)%s\n' "$C_G" "$C_0" "$C_D" "$C_0"
  printf '  %s[2] STRICT%s  %s- zero Microsoft, MS Store dies%s\n' "$C_Y" "$C_0" "$C_D" "$C_0"
  printf "Choice [1/2]: "; m=""; tread m
  if [ "$m" = "2" ]; then STRICT=1; elif [ -n "$m" ]; then STRICT=0; fi
  echo ""
  menu_head "vs-notrack: copilot cleanup"
  printf '  %s[1] PURGE%s  %s- remove extensions + data (default)%s\n' "$C_R" "$C_0" "$C_D" "$C_0"
  printf '  %s[2] UNINSTALL%s  %s- remove extensions%s\n' "$C_Y" "$C_0" "$C_D" "$C_0"
  printf '  %s[3] KEEP%s  %s- disabled, stays installed%s\n' "$C_G" "$C_0" "$C_D" "$C_0"
  printf "Choice [1/2/3]: "; c=""; tread c
  case "$c" in 2) COPILOT=uninstall;; 3) COPILOT=keep;; *) COPILOT=purge;; esac
fi

if [ "$STRICT" = "1" ]; then MODE="STRICT (zero Microsoft)"; else MODE="NORMAL (store working)"; fi
echo "=== VSCODE TRACKER OBLITERATOR - Linux/macOS [$MODE] ==="

OS="$(uname -s)"

pkill -f "[V]isual Studio Code" 2>/dev/null; pkill -x code 2>/dev/null; pkill -x codium 2>/dev/null
_w=0
while pgrep -f "[V]isual Studio Code" >/dev/null 2>&1 || pgrep -x code >/dev/null 2>&1 || pgrep -x codium >/dev/null 2>&1; do
  _w=$((_w+1)); [ "$_w" -ge 10 ] && break
  sleep 1
done

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
  "workbench.settings.showAISearchToggle": False,
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
  "chat.disableAIFeatures": True,
  "chat.agent.enabled": False,
  "github.copilot.enable": {"*": False},
  "github.copilot.nextEditSuggestions.enabled": False,
  "github.copilot.editor.enableCodeActions": False,
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
ignored = {"github.copilot", "github.copilot-chat"}
cur = data.get("settingsSync.ignoredExtensions")
data["settingsSync.ignoredExtensions"] = sorted(set(cur) | ignored) if isinstance(cur, list) else sorted(ignored)
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
  _found_cli=0
  for _c in code code-insiders codium; do
    command -v "$_c" >/dev/null 2>&1 || continue
    _found_cli=1
    for ext in github.copilot github.copilot-chat; do
      _out=$("$_c" --uninstall-extension "$ext" --force 2>&1 | grep -vi "not installed" || true)
      [ -n "$_out" ] && echo "$_out"
      case "$_out" in
        *[Bb]uilt-in*) echo "[info] $ext is built-in (VSCode 1.116+): cannot be uninstalled, disabled via settings + auto-update blocked"; continue;;
      esac
      if "$_c" --list-extensions 2>/dev/null | grep -qxi "$ext"; then echo "[!] still present ($_c): $ext (close VSCode, re-run: $_c --uninstall-extension $ext --force)"; else echo "[ok] uninstalled ($_c): $ext"; fi
    done
  done
  if [ "$_found_cli" = "0" ]; then
    echo "[!] 'code' CLI not found: removing Copilot extension dirs directly"
  fi
  rm -rf "$HOME"/.vscode/extensions/github.copilot* "$HOME"/.vscode-insiders/extensions/github.copilot* "$HOME"/.vscode-oss/extensions/github.copilot* 2>/dev/null
  if ls -d "$HOME"/.vscode/extensions/github.copilot* "$HOME"/.vscode-insiders/extensions/github.copilot* "$HOME"/.vscode-oss/extensions/github.copilot* >/dev/null 2>&1; then
    echo "[!] Copilot extension dirs still present (close VSCode and re-run)"
  fi
fi

if [ "$COPILOT" = "purge" ]; then
  list_bases | while IFS= read -r b; do
    rm -rf "$b"/User/globalStorage/github.copilot* "$b"/User/workspaceStorage/*/github.copilot* 2>/dev/null
  done
  echo "[ok] Copilot data purged"
fi

# user-level product.json override (no admin): stops VSCode 1.116+ force-reinstalling built-in copilot-chat
list_bases | while IFS= read -r b; do
  [ -d "$b" ] || continue
  python3 -c '
import json, os, sys, shutil, datetime
path = os.path.join(sys.argv[1], "product.json")
data = {}
try:
    data = json.load(open(path))
except Exception:
    data = {}
if data.get("builtInExtensionsEnabledWithAutoUpdates") != []:
    if os.path.exists(path):
        shutil.copy(path, path + ".bak-" + datetime.datetime.now().strftime("%Y%m%d-%H%M%S"))
        print(f"[backup] {path}")
    data["builtInExtensionsEnabledWithAutoUpdates"] = []
    json.dump(data, open(path, "w"), indent=2)
    print(f"[ok] blocked built-in copilot auto-update: {path}")
else:
    print(f"[info] auto-update already blocked: {path}")
' "$b"
done

# persistent extension disable (same as gear-menu Disable): flips Copilot off in state.vscdb, VSCode already stopped above
list_bases | while IFS= read -r b; do
  _db="$b/User/globalStorage/state.vscdb"
  [ -f "$_db" ] || continue
  cp -f "$_db" "$_db.bak-$(date +%Y%m%d-%H%M%S)" && echo "[backup] $_db"
  python3 -c '
import json, sqlite3, sys
db = sys.argv[1]
want = {"github.copilot", "github.copilot-chat"}
con = sqlite3.connect(db)
try:
    row = con.execute("SELECT value FROM ItemTable WHERE key = ?", ("extensionsIdentifiers/disabled",)).fetchone()
    cur = json.loads(row[0]) if row else []
    have = {e.get("id", "").lower() for e in cur if isinstance(e, dict)}
    for ext in sorted(want - have):
        cur.append({"id": ext})
    if want - have:
        con.execute("INSERT OR REPLACE INTO ItemTable(key, value) VALUES (?, ?)", ("extensionsIdentifiers/disabled", json.dumps(cur)))
        con.commit()
        print("[ok] Copilot disabled (extension state): " + ", ".join(sorted(want)))
    else:
        print("[info] Copilot already disabled (extension state)")
finally:
    con.close()
' "$_db"
done

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
if "builtInExtensionsEnabledWithAutoUpdates" in data: data["builtInExtensionsEnabledWithAutoUpdates"] = []; changed = True
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
    if ! grep -q "disable-extension github.copilot-chat" "$d" 2>/dev/null && [ -w "$d" ]; then
      sed -i 's|--disable-telemetry|--disable-extension github.copilot --disable-extension github.copilot-chat --disable-telemetry|g' "$d"
      grep -q "disable-extension github.copilot-chat" "$d" 2>/dev/null && echo "[ok] launcher Copilot disabled: $d"
    fi
  done
else
  if command -v code >/dev/null 2>&1 && [ -w /usr/local/bin/code ]; then
    echo "[info] macOS: add alias: alias code='code --disable-telemetry --disable-experiments --disable-crash-reporter --disable-extension github.copilot --disable-extension github.copilot-chat'"
  fi
fi

if [ "$OS" = "Darwin" ]; then
  rm -rf "$HOME/Library/Application Support/Code/Crash Reports" \
         "$HOME/Library/Application Support/Code/logs" \
         "$HOME/Library/Application Support/Code/CachedData" 2>/dev/null
  find "$HOME/Library/Application Support/Code" \( -iname "*telemetry*" -o -iname "*crash*" \) -exec rm -rf {} + 2>/dev/null
else
  rm -rf "$HOME/.config/Code/Crash Reports" "$HOME/.config/Code - Insiders/Crash Reports" \
         "$HOME/.config/Code/CachedData" "$HOME/.config/Code/logs" \
         "$HOME/.config/Code - Insiders/logs" "$HOME/.vscode-crash" /tmp/vscode-crashes 2>/dev/null
  find "$HOME/.config/Code"* \( -iname "*telemetry*" -o -iname "*crash*" \) -exec rm -rf {} + 2>/dev/null
fi
echo "[ok] telemetry/crash caches cleaned"

if [ "$START_MS" != "0" ]; then
  END_MS=$(date +%s%3N); echo ""; echo "OBLITERATED [$MODE] in $((END_MS-START_MS)) ms. Restart VSCode."
else
  echo ""; echo "OBLITERATED [$MODE]. Restart VSCode."
fi
echo "Verify: Settings -> search telemetry -> OFF."
if [ "$STRICT" = "1" ]; then
  echo "STRICT active: get extensions from https://open-vsx.org (code --install-extension file.vsix)."
else
  echo "Want ZERO MS contacts (Store dies)? Re-run with STRICT=1."
fi
