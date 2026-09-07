# ☠️ VSCode Microsoft Tracker Obliterator

![CI](https://github.com/nohint404/vs-notrack/actions/workflows/ci.yml/badge.svg)
![platform](https://img.shields.io/badge/OS-Windows%20%7C%20Linux%20%7C%20macOS-blue)
![license](https://img.shields.io/badge/license-MIT-green)

**Your PC. Your editor. Your rules.**
`vs-notrack` kills VSCode telemetry, crash reporter, experiments, feedback and cloud sync — in under 2 seconds, with automatic backups.

> ⚠️ Honesty first: the **Microsoft extension Marketplace tracks by design** (IP + downloads, like any server). `NORMAL` mode keeps the Store working while VSCode stops spying on you. Only `STRICT` mode brings Microsoft contacts to **zero** — at the cost of switching to the free [Open VSX](https://open-vsx.org) store.

---

## 🚀 One-liner install (curl)

### Linux / macOS

```bash
# NORMAL — anti-tracking, Store keeps working (recommended)
curl -fsSL https://raw.githubusercontent.com/nohint404/vs-notrack/main/vscode-obliterate-trackers.sh | bash

# STRICT ☠️ — zero Microsoft, MS Store dies, Open VSX is used instead
curl -fsSL https://raw.githubusercontent.com/nohint404/vs-notrack/main/vscode-obliterate-trackers.sh | STRICT=1 bash

# With /etc/hosts DNS blocking (needs sudo — sudo goes on bash, NOT on curl)
curl -fsSL https://raw.githubusercontent.com/nohint404/vs-notrack/main/vscode-obliterate-trackers.sh | sudo bash

# Mirror (if raw.githubusercontent.com doesn't resolve on your network)
curl -fsSL https://cdn.jsdelivr.net/gh/nohint404/vs-notrack@main/vscode-obliterate-trackers.sh | bash
```

Running it from a terminal opens an interactive menu: pick NORMAL vs STRICT lockdown, then choose what to do with Copilot (keep disabled / uninstall / uninstall + purge data). Non-interactive shells (CI, no TTY) automatically use safe defaults; every choice is also scriptable via env vars (see table below).

Or the classic way:

```bash
chmod +x vscode-obliterate-trackers.sh
./vscode-obliterate-trackers.sh              # NORMAL
STRICT=1 ./vscode-obliterate-trackers.sh     # STRICT ☠️
sudo ./vscode-obliterate-trackers.sh         # + /etc/hosts blocking
```

| Env var | Effect |
|---------|--------|
| `STRICT=1` | Also blocks the MS Marketplace + points the gallery to Open VSX |
| `COPILOT=uninstall` | Uninstalls Copilot extensions (`github.copilot`, `github.copilot-chat`) |
| `COPILOT=purge` | Uninstalls Copilot extensions + deletes their leftover data |
| `MODE_OPT=strict` / `normal` | Scriptable alternative to `STRICT=1` / unset |
| `MENU=0` | Skips the interactive menu (uses env/defaults) |
| `NO_HOSTS=1` | Skips `/etc/hosts` modification |
| `NO_PRODUCT_PATCH=1` | Skips `product.json` neutralization |

### Windows (PowerShell)

```powershell
# NORMAL — anti-tracking, Store keeps working (recommended)
irm https://raw.githubusercontent.com/nohint404/vs-notrack/main/vscode-obliterate-trackers.ps1 | iex

# STRICT ☠️ — zero Microsoft, MS Store dies, Open VSX is used instead
$env:VSCODE_OBLITERATOR_STRICT=1; irm https://raw.githubusercontent.com/nohint404/vs-notrack/main/vscode-obliterate-trackers.ps1 | iex
```

Or from a local copy:

```powershell
powershell -ExecutionPolicy Bypass -File vscode-obliterate-trackers.ps1          # NORMAL
powershell -ExecutionPolicy Bypass -File vscode-obliterate-trackers.ps1 -Strict  # STRICT ☠️
```

> 💡 Run as **Administrator** to also enable `hosts` + firewall blocking. Without admin, settings/argv/env are still locked down.

| Flag | Effect |
|------|--------|
| `-Strict` | Also blocks the MS Marketplace + points the gallery to Open VSX |
| `-PurgeCopilot` | Uninstalls Copilot extensions + deletes their leftover data |
| `-NoHosts` | Skips `hosts` file modification |
| `-NoFirewall` | Skips outbound firewall rules |
| `-NoProductPatch` | Skips `product.json` neutralization |

---

## ⚔️ NORMAL vs STRICT

| What | NORMAL | STRICT ☠️ |
|------|:------:|:---------:|
| VSCode telemetry (`telemetryLevel: off`) | ✅ | ✅ |
| Crash reporter / experiments / feedback | ✅ | ✅ |
| Cloud Edit Sessions / cloudChanges | ✅ | ✅ |
| MS extension telemetry (Python, C#, PowerShell…) | ✅ | ✅ |
| `product.json` neutralization | ✅ | ✅ |
| Telemetry domain DNS blocking | ✅ | ✅ |
| Outbound firewall rules (Win, admin) | ✅ | ✅ |
| `--disable-telemetry` launcher/shortcut flags | ✅ | ✅ |
| **Microsoft extension Store working** | ✅ | ❌ (on purpose) |
| Marketplace DNS blocking | ❌ | ✅ |
| Gallery redirected to **Open VSX** | ❌ | ✅ |

---

## 🛡️ What it does, layer by layer

1. **`settings.json` (merged, never blindly overwritten)** — ~25 killer keys: `telemetry.telemetryLevel: off`, `workbench.enableExperiments: false`, `telemetry.feedback.enabled: false`, `workbench.cloudChanges.autoStore: off`, manual updates, no recommendations, `redhat/dotnet/powershell/copilot/chat` opt-outs. Your settings stay intact.
2. **`argv.json` (runtime kill switch)** — `disable-telemetry`, `disable-experiments`, `enable-crash-reporter: false`. Kicks in before settings are even loaded.
3. **Persistent env vars** — `VSCODE_TELEMETRY_LEVEL=off`, `DOTNET_CLI_TELEMETRY_OPTOUT=1`, `POWERSHELL_TELEMETRY_OPTOUT=1`, `NEXT_TELEMETRY_DISABLED=1`.
4. **`product.json`** — neutralizes hardcoded endpoints (`telemetryEndpoint`, `crashReporter`, `sendASmile`). Note: VSCode restores it on update → re-run the script after every update.
5. **DNS blocking (`hosts`)** — 13 telemetry domains. Never the Marketplace in NORMAL.
6. **Outbound firewall (Windows, admin)** — second wall for `Code.exe`.
7. **Cleanup** — wipes `Crash Reports`, `CachedData`, logs and `*telemetry*/*crash*` leftovers + disables auto-update scheduled tasks (Win).

### Blocked domains (always)

```
vortex.data.microsoft.com · vortex-win.data.microsoft.com
v10.vortex-win.data.microsoft.com · settings-win.data.microsoft.com
telecommand.telemetry.microsoft.com · telemetry.microsoft.com
dc.services.visualstudio.com · dc.applicationinsights.azure.com
dc.applicationinsights.microsoft.com · mobile.events.data.microsoft.com
events.data.microsoft.com · crl.microsoft.com · functionschina.azurecomm.net
```

STRICT adds: `marketplace.visualstudio.com`, `vscode.blob.core.windows.net`, `vscode-update.azurewebsites.net`, `update.code.visualstudio.com`.

---

## ✅ Verify (30 seconds)

1. Reopen VSCode → Settings → search `telemetry` → must say **OFF**.
2. `Help → Toggle Developer Tools → Network` → reload: zero calls to `vortex` / `applicationinsights` / `events.data`.
3. Check the backup: next to every modified file you'll find `settings.json.bak-<date>` — rollback = rename the `.bak` back.

---

## ↩️ Rollback

Every touched file gets a timestamped backup in the same folder:

- Windows: `%APPDATA%\Code\User\settings.json.bak-*`, `%APPDATA%\Code\argv.json.bak-*`
- Linux: `~/.config/Code/User/settings.json.bak-*`, `~/.config/Code/argv.json.bak-*`
- macOS: `~/Library/Application Support/Code/User/settings.json.bak-*`

To revert: close VSCode, delete the modified file, rename the newest `.bak` back. For the `hosts` file, remove the lines tagged `# vscode-obliterator`.

---

## ❓ FAQ

**Does the extension Store keep working?**
Yes in NORMAL. No in STRICT (on purpose — use [open-vsx.org](https://open-vsx.org) or `code --install-extension file.vsix`).

**Must I re-run it after VSCode updates?**
Yes, updates can restore `product.json` and scheduled tasks. Your `settings.json`/`argv.json` survive updates.

**Does it cover VSCode Insiders?**
Yes, both scripts lock down Stable + Insiders.

**What about closed-source third-party extensions?**
No script can guarantee what a closed binary does. Rule of thumb: few extensions, open-source whenever possible, in STRICT only from Open VSX.

**I want zero Microsoft, period.**
`STRICT=1` + consider [VSCodium](https://vscodium.com) (telemetry-free build by design) with Open VSX. This script is still useful there as a safety belt.

**Is piping curl to bash safe here?**
The shell script reads nothing from stdin (no heredocs, no prompts), so `curl | bash` is safe by construction. Pin to a commit for extra paranoia: replace `/main/` in the URL with `/<commit-sha>/`.

---

## 🤝 Contributing

PRs welcome! The CI workflow (`.github/workflows/ci.yml`) tests everything automatically: shellcheck + functional test on a fake HOME + PowerShell parsing on a Windows runner. If you add domains or keys, update the README + both scripts.

## 📄 License

MIT — see [LICENSE](LICENSE). Use it, fork it, share it. Your PC, your rules. ☠️
