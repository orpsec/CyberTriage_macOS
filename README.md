# MacHarvest
### macOS Forensic Data Collection Suite

> **Version:** 1.0  
> **Platform:** macOS 13 Ventura · 14 Sonoma · 15 Sequoia · 26 Tahoe  
> **Architecture:** Intel (x86_64) · Apple Silicon (M1 / M2 / M3 / M4 / M5)  
> **Distribution:** No app bundle — Gatekeeper / XProtect safe

---

## File Structure

```
MacHarvest/
├── MacHarvest.command    ← Entry point — double-click this
├── macos_triage.sh       ← Core forensic engine — do not modify
└── README.md             ← This document
```

| File | Purpose |
|---|---|
| `MacHarvest.command` | Launcher. Strips quarantine flag, requests sudo, starts the engine. |
| `macos_triage.sh` | Core script. All collection logic lives here. Run via launcher, not directly. |

---

## Usage

**Step 1 — Copy to target Mac**

Copy `MacHarvest.command` and `macos_triage.sh` to the target machine.

**Step 2 — Launch**

Double-click `MacHarvest.command` → Terminal opens → enter sudo password → answer prompts:

```
Case ID       →  Leave blank for auto-generated (e.g. MH-20260616-092228)
Target user   →  macOS username of the subject account
Days of scope →  How many days back to collect (default: 30)
Operator name →  Your name / badge ID for the report
```

**Step 3 — Collect**

10 steps run automatically. When complete, two items appear on the Desktop:

```
30-operator_Hostname_20260616-092228/     ← Raw collection folder
30-operator_Hostname_20260616-092228.zip  ← Archived for transport
```

---

## Full Disk Access (FDA)

MacHarvest runs without FDA but certain high-value artifacts become inaccessible:

| Artifact | Path | Blocked Without FDA |
|---|---|---|
| Safari history & cookies | `~/Library/Safari/` | Yes |
| Messages (iMessage) database | `~/Library/Messages/chat.db` | Yes |
| Mail database | `~/Library/Mail/` | Yes |
| TCC permission history | `/Library/Application Support/com.apple.TCC/TCC.db` | Yes |
| ESF live events | Kernel entitlement | Yes |

**How to grant FDA:**

```
System Settings → Privacy & Security → Full Disk Access → Terminal → Enable
```

> FDA can be revoked after the script completes.

---

## What Gets Collected

| Step | Category | Contents |
|---|---|---|
| 1 | **Unified Log** | System logs via `log collect` + `log show`. Tahoe: network security subsystem, Apple Intelligence logs. |
| 2 | **Network Activity** | Active TCP/UDP connections with process names (`lsof`), DNS cache, Wi-Fi connection history, `netusage.sqlite`, ARP table, `pfctl` rules, `nettop` snapshot. |
| 3 | **ESF** | Endpoint Security Framework live events via `eslogger` (macOS 13+). Tahoe: rename / unlink / clone events. |
| 4 | **Audit** | BSD audit subsystem records (`praudit`). |
| 5 | **Activity History** | `zsh` / `bash` command history, `knowledgeC.db` (app usage timestamps), Apple Intelligence logs (Tahoe). |
| 6 | **Downloads & Browsers** | `QuarantineEventsV2` download history. Browser visit history and downloads: Chrome · Brave · Edge · Firefox · Safari · Opera · Vivaldi · Yandex · Arc. |
| 7 | **Cloud & Persistence** | Cloud storage listings: iCloud · Google Drive · Dropbox · OneDrive · Box. Messages DB, Mail, print queue, TCC history, LaunchAgents / LaunchDaemons, BTM, SSH key listing, Privacy Report (Tahoe). |
| 8 | **System Inventory** | OS version, hardware profile, running process list, local users, USB connection history, Apple Silicon power profile, SIP status. |
| 9 | **SHA-256 Manifest** | Cryptographic hash of every collected file. Establishes chain of custody for forensic integrity. |
| 10 | **ZIP Archive** | Full collection packaged to operator's Desktop. |

> **Read-only.** No files are deleted, modified, or encrypted. SSH private keys are never collected.

---

## Output Structure

```
30-operator_Hostname_20260616-092228/
├── _collection.log        ← Runtime log for troubleshooting
├── MANIFEST_SHA256.txt    ← SHA-256 hash of every collected file
├── artifacts/             ← Shell history, knowledgeC.db, AI logs
├── audit/                 ← BSD audit records
├── downloads/             ← QuarantineEventsV2, browser databases
├── esf/                   ← Endpoint Security events
├── exfil/                 ← Cloud listings, Messages, print queue
├── network/               ← Connections, DNS, Wi-Fi, pfctl
├── persistence/           ← TCC.db, LaunchAgents, BTM
├── system/                ← OS info, processes, users, USB
└── unified/               ← Unified Log output files
```

**Verify integrity:**

```bash
shasum -a 256 -c MANIFEST_SHA256.txt
```

---

## Troubleshooting

| Symptom | Cause | Fix |
|---|---|---|
| *"cannot be opened"* | Quarantine flag attached | Right-click → Open, or run `xattr -dr com.apple.quarantine` |
| *"move to trash"* warning | XProtect behavioral detection | Right-click → Open — `.command` is not an `.app` |
| ESF output empty | Missing FDA or ESF entitlement | Grant Full Disk Access to Terminal |
| Safari / Messages empty | TCC restriction | Grant Full Disk Access to Terminal |
| Step output says `[No data]` | App not installed or no data in scope | Normal — not an error |
| Need to see error detail | — | Open `_collection.log` |

---

## Legal

> This tool must only be used under **written corporate authorization** (Legal · HR · Management approval).  
> Unauthorized use may result in legal liability.
