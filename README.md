# ☠️ vs-notrack — VSCode Microsoft Tracker Obliterator

![CI](https://github.com/nohint404/vs-notrack/actions/workflows/ci.yml/badge.svg)
![platform](https://img.shields.io/badge/OS-Windows%20%7C%20Linux%20%7C%20macOS-blue)
![license](https://img.shields.io/badge/license-MIT-green)

**Il tuo PC. Il tuo editor. Le tue regole.**
`vs-notrack` ammazza telemetria, crash reporter, experiments, feedback e cloud-sync di VSCode — in meno di 2 secondi, con backup automatico. Siamo noi a dominare su Microsoft, non il contrario.

> ⚠️ Onestà prima di tutto: lo **Store estensioni Microsoft traccia per natura** (IP + download, come qualsiasi server). In modalità `NORMAL` lo Store resta attivo ma VSCode smette di spiarti. Solo la modalità `STRICT` porta i contatti MS a **zero** — al prezzo di usare lo store libero [Open VSX](https://open-vsx.org).

---

## 🚀 Uso rapido

### Windows (PowerShell)

```powershell
# NORMAL — anti-tracciamento, Store attivo (consigliato)
powershell -ExecutionPolicy Bypass -File vscode-obliterate-trackers.ps1

# STRICT ☠️ — zero Microsoft, Store MS morto, si usa Open VSX
powershell -ExecutionPolicy Bypass -File vscode-obliterate-trackers.ps1 -Strict
```

> 💡 Esegui come **Amministratore** per attivare anche blocco `hosts` + firewall. Senza admin, settings/argv/env vengono blindati comunque.

| Flag | Effetto |
|------|---------|
| `-Strict` | Blocca anche il Marketplace MS + punta la gallery a Open VSX |
| `-NoHosts` | Salta la modifica del file `hosts` |
| `-NoFirewall` | Salta le regole firewall outbound |
| `-NoProductPatch` | Salta la neutralizzazione di `product.json` |

### Linux / macOS (bash)

```bash
chmod +x vscode-obliterate-trackers.sh

# NORMAL — anti-tracciamento, Store attivo (consigliato)
./vscode-obliterate-trackers.sh

# STRICT ☠️ — zero Microsoft, Store MS morto, si usa Open VSX
STRICT=1 ./vscode-obliterate-trackers.sh

# Con blocco /etc/hosts (serve sudo)
sudo ./vscode-obliterate-trackers.sh
# oppure STRICT + sudo:
sudo STRICT=1 ./vscode-obliterate-trackers.sh
```

| Variabile | Effetto |
|-----------|---------|
| `STRICT=1` | Blocca anche il Marketplace MS + gallery su Open VSX |
| `NO_HOSTS=1` | Salta la modifica di `/etc/hosts` |
| `NO_PRODUCT_PATCH=1` | Salta la neutralizzazione di `product.json` |

---

## ⚔️ NORMAL vs STRICT

| Cosa | NORMAL | STRICT ☠️ |
|------|:------:|:---------:|
| Telemetria VSCode (`telemetryLevel: off`) | ✅ | ✅ |
| Crash reporter / experiments / feedback | ✅ | ✅ |
| Edit Sessions cloud / cloudChanges | ✅ | ✅ |
| Telemetria estensioni MS (Python, C#, PowerShell…) | ✅ | ✅ |
| Neutralizzazione `product.json` | ✅ | ✅ |
| Blocco DNS domini telemetria | ✅ | ✅ |
| Regole firewall outbound (Win, admin) | ✅ | ✅ |
| Flag `--disable-telemetry` su launcher/scorciatoie | ✅ | ✅ |
| **Store estensioni Microsoft funzionante** | ✅ | ❌ (voluto) |
| Blocco DNS anche del Marketplace | ❌ | ✅ |
| Gallery reindirizzata su **Open VSX** | ❌ | ✅ |

---

## 🛡️ Cosa fa, livello per livello

1. **`settings.json` (merge, mai sovrascritto)** — ~25 chiavi killer: `telemetry.telemetryLevel: off`, `workbench.enableExperiments: false`, `telemetry.feedback.enabled: false`, `workbench.cloudChanges.autoStore: off`, update manuali, niente recommendations, opt-out `redhat/dotnet/powershell/copilot/chat`. Le tue impostazioni restano intatte.
2. **`argv.json` (kill switch runtime)** — `disable-telemetry`, `disable-experiments`, `enable-crash-reporter: false`. Agisce prima ancora che le impostazioni vengano caricate.
3. **Variabili d'ambiente persistenti** — `VSCODE_TELEMETRY_LEVEL=off`, `DOTNET_CLI_TELEMETRY_OPTOUT=1`, `POWERSHELL_TELEMETRY_OPTOUT=1`, `NEXT_TELEMETRY_DISABLED=1`.
4. **`product.json`** — neutralizza endpoint hardcoded (`telemetryEndpoint`, `crashReporter`, `sendASmile`). Nota: VSCode lo sovrascrive agli update → rilancia lo script dopo ogni aggiornamento.
5. **Blocco DNS (`hosts`)** — 13 domini telemetria. Mai il Marketplace in NORMAL.
6. **Firewall outbound (Windows, admin)** — seconda muraglia per `Code.exe`.
7. **Pulizia** — spazza via `Crash Reports`, `CachedData`, log e file `*telemetry*/*crash*` esistenti + disattiva i task schedulati di auto-update (Win).

### Domini bloccati (sempre)

```
vortex.data.microsoft.com · vortex-win.data.microsoft.com
v10.vortex-win.data.microsoft.com · settings-win.data.microsoft.com
telecommand.telemetry.microsoft.com · telemetry.microsoft.com
dc.services.visualstudio.com · dc.applicationinsights.azure.com
dc.applicationinsights.microsoft.com · mobile.events.data.microsoft.com
events.data.microsoft.com · crl.microsoft.com · functionschina.azurecomm.net
```

Solo in STRICT si aggiungono: `marketplace.visualstudio.com`, `vscode.blob.core.windows.net`, `vscode-update.azurewebsites.net`, `update.code.visualstudio.com`.

---

## ✅ Verifica (30 secondi)

1. Riapri VSCode → Impostazioni → cerca `telemetry` → deve dire **OFF**.
2. `Help → Toggle Developer Tools → Network` → ricarica: zero chiamate a `vortex` / `applicationinsights` / `events.data`.
3. Controlla il backup: accanto a ogni file modificato trovi `settings.json.bak-<data>` — rollback = rinomina il `.bak`.

---

## ↩️ Rollback

Ogni file toccato ha un backup timestampato nella stessa cartella:

- Windows: `%APPDATA%\Code\User\settings.json.bak-*`, `%APPDATA%\Code\argv.json.bak-*`
- Linux: `~/.config/Code/User/settings.json.bak-*`, `~/.config/Code/argv.json.bak-*`
- macOS: `~/Library/Application Support/Code/User/settings.json.bak-*`

Per tornare indietro: chiudi VSCode, cancella il file modificato, rinomina il `.bak` più recente. Per il file `hosts`, rimuovi le righe marcate `# vscode-obliterator`.

---

## ❓ FAQ

**Lo Store estensioni continua a funzionare?**
Sì in NORMAL. No in STRICT (di proposito — usa [open-vsx.org](https://open-vsx.org) o `code --install-extension file.vsix`).

**Devo rilanciarlo dopo gli update di VSCode?**
Sì, gli update possono ripristinare `product.json` e i task schedulati. Le tue `settings.json`/`argv.json` invece sopravvivono.

**Copre anche VSCode Insiders?**
Sì, entrambi gli script blindano Stable + Insiders.

**E le estensioni di terze parti closed-source?**
Nessuno script può garantire cosa fa un binario chiuso. Regola d'oro: poche estensioni, solo open-source quando possibile, in STRICT solo da Open VSX.

**Voglio proprio zero Microsoft, punto.**
`STRICT=1` + valuta [VSCodium](https://vscodium.com) (build senza telemetria by-design) con Open VSX. Questo script resta utile anche lì come cintura di sicurezza.

---

## 🤝 Contribuire

PR benvenute! Il workflow CI (`.github/workflows/ci.yml`) testa tutto in automatico: shellcheck + test funzionale su HOME finta + parsing PowerShell su runner Windows. Se aggiungi domini o chiavi, aggiorna README + entrambi gli script.

## 📄 Licenza

MIT — vedi [LICENSE](LICENSE). Usalo, forcalo, condividilo. Il tuo PC, le tue regole. ☠️
