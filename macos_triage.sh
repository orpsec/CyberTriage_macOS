#!/bin/bash
# =============================================================
# MacHarvest — macOS Data Collection Suite  (v1.0)
# Desteklenen: macOS 13 Ventura → 26 Tahoe  |  Intel + Apple Silicon
# Kullanım: sudo bash macos_triage.sh
# =============================================================
set -uo pipefail

# ── Renkler ──────────────────────────────────────────────────
C_GRN='\033[0;92m'   # Yeşil  — başarı
C_YLW='\033[1;33m'   # Sarı   — uyarı
C_RED='\033[0;31m'   # Kırmızı — hata
C_CYN='\033[0;96m'   # Cyan   — vurgu
C_DIM='\033[2m'      # Soluk  — meta
C_BLD='\033[1m'      # Kalın
C_RST='\033[0m'      # Sıfırla

# ── Yardımcı çıktı fonksiyonları ─────────────────────────────
ok()  { printf "  ${C_GRN}✓${C_RST}  %s\n"  "$*"; }
warn(){ printf "  ${C_YLW}⚠${C_RST}  %s\n"  "$*"; }
info(){ printf "  ${C_DIM}·${C_RST}  %s\n"  "$*"; }
err() { printf "  ${C_RED}✗${C_RST}  %s\n"  "$*"; }
sep() { printf "  ${C_DIM}%s${C_RST}\n" "──────────────────────────────────────────────────"; }

# ── Sabit binary yolları ──────────────────────────────────────
LOG_BIN="/usr/bin/log"
LS_BIN="/bin/ls"
LAST_BIN="/usr/bin/last"
PRAUDIT_BIN="/usr/sbin/praudit"
STAT_BIN="/usr/bin/stat"
FIND_BIN="/usr/bin/find"
DITTO_BIN="/usr/bin/ditto"

# ── macOS sürüm ve mimari ─────────────────────────────────────
OS_VER="$(sw_vers -productVersion 2>/dev/null || echo "13.0")"
OS_MAJOR="$(echo "$OS_VER" | cut -d. -f1)"
ARCH="$(uname -m 2>/dev/null || echo "x86_64")"
case "$OS_MAJOR" in
  13) OS_NAME="Ventura"  ;; 14) OS_NAME="Sonoma"  ;;
  15) OS_NAME="Sequoia"  ;; 26) OS_NAME="Tahoe"   ;;
  *)  OS_NAME="macOS $OS_MAJOR" ;;
esac
[[ "$ARCH" == "arm64" ]] && CHIP="Apple Silicon" || CHIP="Intel"

[[ "$OS_MAJOR" -lt 13 ]] && {
  warn "macOS $OS_VER tam desteklenmiyor (min: 13 Ventura)."
  read -r -p "  Devam? [e/H]: " _c
  [[ "$_c" =~ ^[Ee]$ ]] || exit 1
}

HAS_PRIVACY_REPORT=0; HAS_INTEL_REPORT=0
[[ "$OS_MAJOR" -ge 26 ]] && HAS_PRIVACY_REPORT=1
[[ "$OS_MAJOR" -ge 26 ]] && HAS_INTEL_REPORT=1

# ── Varsayılanlar ─────────────────────────────────────────────
DEF_USER="${TARGET_USER:-${SUDO_USER:-$("$STAT_BIN" -f%Su /dev/console 2>/dev/null || echo "$USER")}}"
[[ -z "$DEF_USER" || "$DEF_USER" == "root" ]] && \
  DEF_USER="$("$STAT_BIN" -f%Su /dev/console 2>/dev/null || echo "$USER")"
MAX_DAYS=30
DEF_DAYS="${DAYS:-15}"
DEF_CASE="${CASE_ID:-MH-$(date +%Y%m%d)-001}"

# ── BANNER ───────────────────────────────────────────────────
clear
printf "\n"
printf "${C_GRN}${C_BLD}"
printf '  ███╗   ███╗ █████╗  ██████╗\n'
printf '  ████╗ ████║██╔══██╗██╔════╝    ██╗  ██╗ █████╗ ██████╗ ██╗   ██╗███████╗███████╗████████╗\n'
printf '  ██╔████╔██║███████║██║         ███████║███████║██╔══██╗██║   ██║██╔════╝██╔════╝╚══██╔══╝\n'
printf '  ██║╚██╔╝██║██╔══██║██║         ██╔══██║██╔══██║██████╔╝██║   ██║█████╗  ███████╗   ██║\n'
printf '  ██║ ╚═╝ ██║██║  ██║╚██████╗    ██║  ██║██║  ██║██╔══██╗╚██╗ ██╔╝██╔══╝  ╚════██║   ██║\n'
printf '  ╚═╝     ╚═╝╚═╝  ╚═╝ ╚═════╝    ██║  ██║██║  ██║██║  ██║ ╚████╔╝ ███████╗███████║   ██║\n'
printf '                                  ╚═╝  ╚═╝╚═╝  ╚═╝╚═╝  ╚═╝  ╚═══╝  ╚══════╝╚══════╝   ╚═╝\n'
printf "${C_RST}"
printf "\n"
printf "  ${C_DIM}macOS Data Collection Suite  ·  v1.0  ·  %s %s (%s)${C_RST}\n" "$OS_NAME" "$OS_VER" "$CHIP"
sep
printf "\n"

# ── İnteraktif giriş ─────────────────────────────────────────
printf "  ${C_BLD}Koleksiyon Parametreleri${C_RST}\n\n"
read -r -p "  Case ID      [${DEF_CASE}]: " IN_CASE
CASE_ID="${IN_CASE:-$DEF_CASE}"
CASE_ID="$(echo "$CASE_ID" | tr ' /:\\' '____')"

printf "  Kullanıcılar : ${C_CYN}%s${C_RST}\n" \
  "$(ls /Users 2>/dev/null | grep -vE '^(Shared|\.localized)$' | tr '\n' ' ')"
read -r -p "  Kullanıcı    [${DEF_USER}]: " IN_USER
TARGET_USER="${IN_USER:-$DEF_USER}"

printf "  ${C_DIM}Sistem kapasitesine bağlı olarak log süresi sınırlı olabilir (maks %d gün).${C_RST}\n" "$MAX_DAYS"
read -r -p "  Gün sayısı   [${DEF_DAYS}]: " IN_DAYS
DAYS="${IN_DAYS:-$DEF_DAYS}"
case "$DAYS" in *[!0-9]*|'') DAYS="$DEF_DAYS"; warn "Geçersiz değer, ${DEF_DAYS} gün kullanılacak.";; esac
[ "$DAYS" -gt "$MAX_DAYS" ] && { DAYS=$MAX_DAYS; warn "En fazla ${MAX_DAYS} güne sınırlandı."; }
[ "$DAYS" -lt 1 ] && DAYS=1

printf "\n"
sep
printf "  Kullanıcı  : ${C_BLD}%s${C_RST}   Süre: ${C_BLD}%s gün${C_RST}   Case: ${C_BLD}%s${C_RST}\n" \
  "$TARGET_USER" "$DAYS" "$CASE_ID"
sep
printf "\n"

# ── Çıktı konumu ──────────────────────────────────────────────
UH="/Users/$TARGET_USER"
ASUP="$UH/Library/Application Support"
ESF_SECONDS="${ESF_SECONDS:-45}"

OPERATOR="$("$STAT_BIN" -f%Su /dev/console 2>/dev/null)"
[[ -z "$OPERATOR" || "$OPERATOR" == "root" ]] && OPERATOR="${SUDO_USER:-$TARGET_USER}"
OUTBASE="/Users/$OPERATOR/Desktop"
[[ -d "$OUTBASE" ]] || OUTBASE="/Users/Shared"
mkdir -p "$OUTBASE" 2>/dev/null

HOSTS="$(hostname -s 2>/dev/null || hostname)"
STAMP="$(date +%Y%m%d-%H%M%S)"
CASE_FOLDER="${CASE_ID}_${HOSTS}_${STAMP}"
OUT="${OUT_DIR:-$OUTBASE/$CASE_FOLDER}"
ZIP="$OUTBASE/${CASE_FOLDER}.zip"
LOGFILE="$OUT/_collection.log"
START_TS=$(date +%s)

TUID="$(id -u "$TARGET_USER" 2>/dev/null || echo "")"
asuser(){
  if [[ -n "${TUID:-}" ]]; then
    launchctl asuser "$TUID" sudo -u "$TARGET_USER" "$@" 2>/dev/null \
      || sudo -u "$TARGET_USER" "$@" 2>/dev/null || "$@"
  else
    "$@"
  fi
}

safe_run(){
  local t=$1; shift
  "$@" &
  local pid=$! n=0
  while kill -0 "$pid" 2>/dev/null && [[ $n -lt $t ]]; do sleep 1; ((n++)); done
  kill "$pid" 2>/dev/null; wait "$pid" 2>/dev/null; return 0
}

mkdir -p "$OUT"/{unified,network,esf,audit,artifacts,downloads,downloads/browsers,system}
note(){ echo "[$(date -u +%FT%TZ)] $*" >> "$LOGFILE"; }
note "MacHarvest v1.0 başladı. macOS $OS_VER ($OS_NAME) $ARCH Host:$HOSTS Kullanıcı:$TARGET_USER ${DAYS}g EUID:$EUID"
[[ -d "$UH" ]] || note "UYARI: $UH yok"

# ── Progress bar ──────────────────────────────────────────────
TOTAL=10; BAR_W=36
progress(){
  local s=$1; shift; local label="$*"
  local filled=$(( s * BAR_W / TOTAL ))
  local bar="" i
  for ((i=0;i<filled;i++));      do bar+="█"; done
  for ((i=filled;i<BAR_W;i++));  do bar+="░"; done
  local pct=$(( s * 100 / TOTAL ))
  local el=$(( $(date +%s) - START_TS ))
  local color
  if   [[ $pct -ge 80 ]]; then color="$C_GRN"
  elif [[ $pct -ge 40 ]]; then color="$C_CYN"
  else color="$C_DIM"; fi
  printf "  ${color}[%s]${C_RST} ${C_BLD}%3d%%${C_RST}  ${C_DIM}%2d/%-2d${C_RST}  %-32s  ${C_DIM}%ds${C_RST}\n" \
    "$bar" "$pct" "$s" "$TOTAL" "$label" "$el"
}

# ── TCC / Tam Disk Erişimi kontrolü ──────────────────────────
TCC_OK=1
if [[ -f "$UH/Library/Safari/History.db" ]] && ! cat "$UH/Library/Safari/History.db" >/dev/null 2>&1; then
  TCC_OK=0
fi
[[ "$TCC_OK" -eq 0 ]] && {
  warn "Tam Disk Erişimi (FDA) izni eksik — korumalı veriler toplanamayabilir."
  info "Sistem Ayarları › Gizlilik ve Güvenlik › Tam Disk Erişimi › Terminal"
  note "UYARI: Full Disk Access yok"
}
printf "\n"

# ============================================================
# ADIM 1 — Sistem Günlükleri
# ============================================================
progress 1 "Sistem günlükleri"
safe_run 300 "$LOG_BIN" collect --last "${DAYS}d" --output "$OUT/unified/system.logarchive" 2>>"$LOGFILE" \
  && note "log collect OK" || note "log collect timeout"
safe_run 120 "$LOG_BIN" show --last "${DAYS}d" --info \
  > "$OUT/unified/system_show.log" 2>>"$LOGFILE" \
  && note "log show OK" || {
    note "log show timeout; kısa deneniyor..."
    local_days=$(( DAYS > 3 ? 3 : DAYS ))
    safe_run 60 "$LOG_BIN" show --last "${local_days}d" --info \
      > "$OUT/unified/system_show.log" 2>>"$LOGFILE"
  }
[[ "$OS_MAJOR" -ge 26 ]] && safe_run 60 "$LOG_BIN" show --last "${DAYS}d" \
  --predicate 'subsystem == "com.apple.privacy" OR subsystem == "com.apple.intelligence" OR subsystem == "com.apple.tcc"' \
  > "$OUT/unified/tahoe_privacy_intelligence.log" 2>>"$LOGFILE" || true

# ============================================================
# ADIM 2 — Ağ Aktivitesi
# ============================================================
progress 2 "Ağ aktivitesi"
lsof -i -n -P                       > "$OUT/network/connections.txt"  2>>"$LOGFILE" || true
netstat -anv                        > "$OUT/network/netstat.txt"      2>>"$LOGFILE" || true
safe_run 30 nettop -P -L 1          > "$OUT/network/nettop.txt"       2>>"$LOGFILE" || true
arp -a                              > "$OUT/network/arp.txt"          2>>"$LOGFILE" || true
scutil --dns                        > "$OUT/network/dns.txt"          2>>"$LOGFILE" || true
networksetup -listallhardwareports  > "$OUT/network/interfaces.txt"   2>>"$LOGFILE" || true
[[ -f /var/log/appfirewall.log ]] && cp -p /var/log/appfirewall.log "$OUT/network/" 2>>"$LOGFILE" || true

NU=""
for c in /private/var/networkd/netusage.sqlite /var/networkd/netusage.sqlite; do
  [[ -f "$c" ]] && NU="$c" && break
done
if [[ -n "$NU" ]]; then
  cp -p "$NU" "$OUT/network/netusage.sqlite" 2>>"$LOGFILE"
  sqlite3 "$OUT/network/netusage.sqlite" \
    "SELECT p.ZPROCNAME, datetime(MIN(l.ZTIMESTAMP)+978307200,'unixepoch','localtime'), datetime(MAX(l.ZTIMESTAMP)+978307200,'unixepoch','localtime'), SUM(l.ZWIFIIN+l.ZWWANIN), SUM(l.ZWIFIOUT+l.ZWWANOUT) FROM ZLIVEUSAGE l JOIN ZPROCESS p ON l.ZHASPROCESS=p.Z_PK GROUP BY p.ZPROCNAME ORDER BY 5 DESC;" \
    > "$OUT/network/netusage_process.txt" 2>>"$LOGFILE" || true
  note "netusage OK"
else note "netusage.sqlite yok"; fi

safe_run 60 "$LOG_BIN" show --last "${DAYS}d" \
  --predicate 'process == "mDNSResponder" OR process == "networkd" OR process == "nehelper" OR subsystem == "com.apple.network"' \
  > "$OUT/network/unified_network.log" 2>>"$LOGFILE" || true
safe_run 60 "$LOG_BIN" show --last "${DAYS}d" \
  --predicate 'process == "airportd" OR subsystem == "com.apple.wifi"' \
  > "$OUT/network/wifi_history.log" 2>>"$LOGFILE" || true
[[ -f /var/log/wifi.log ]] && cp -p /var/log/wifi.log "$OUT/network/" 2>>"$LOGFILE" || true
pfctl -sa > "$OUT/network/pfctl_state.txt" 2>>"$LOGFILE" || true
[[ "$OS_MAJOR" -ge 26 ]] && safe_run 30 "$LOG_BIN" show --last "${DAYS}d" \
  --predicate 'subsystem == "com.apple.networkextension" OR subsystem == "com.apple.network.security"' \
  > "$OUT/network/tahoe_network_security.log" 2>>"$LOGFILE" || true
[[ -d "/Library/Objective-See/LuLu" ]] && cp -Rp "/Library/Objective-See/LuLu" "$OUT/network/LuLu_config" 2>>"$LOGFILE" || true
if [[ "${PCAP_SECONDS:-0}" -gt 0 ]] && command -v tcpdump >/dev/null 2>&1; then
  tcpdump -i any -w "$OUT/network/capture.pcap" 2>>"$LOGFILE" &
  TPID=$!; sleep "${PCAP_SECONDS}"; kill "$TPID" 2>/dev/null; wait "$TPID" 2>/dev/null
fi

# ============================================================
# ADIM 3 — Süreç İzleme (ESF)
# ============================================================
progress 3 "Süreç izleme (${ESF_SECONDS}sn)"
if command -v eslogger >/dev/null 2>&1; then
  if   [[ "$OS_MAJOR" -ge 26 ]]; then
    ( eslogger exec open create rename unlink clone > "$OUT/esf/events.ndjson" 2>>"$LOGFILE" ) &
  elif [[ "$OS_MAJOR" -ge 14 ]]; then
    ( eslogger exec open create rename unlink       > "$OUT/esf/events.ndjson" 2>>"$LOGFILE" ) &
  else
    ( eslogger exec open create                     > "$OUT/esf/events.ndjson" 2>>"$LOGFILE" ) &
  fi
  ESF_PID=$!; sleep "$ESF_SECONDS"; kill "$ESF_PID" 2>/dev/null; wait "$ESF_PID" 2>/dev/null
  note "ESF OK"
else note "eslogger bulunamadı"; fi

# ============================================================
# ADIM 4 — Denetim Kayıtları
# ============================================================
progress 4 "Denetim kayıtları"
if [[ -d /var/audit ]] && ls /var/audit/* >/dev/null 2>&1; then
  for f in /var/audit/*; do
    [[ -f "$f" ]] || continue
    "$PRAUDIT_BIN" -l "$f" >> "$OUT/audit/audit.txt" 2>>"$LOGFILE" || true
  done
  [[ -f /etc/security/audit_control ]] && cp -p /etc/security/audit_control "$OUT/audit/" 2>>"$LOGFILE" || true
  note "audit OK"
else note "audit kapalı"; fi

# ============================================================
# ADIM 5 — Aktivite Geçmişi
# ============================================================
progress 5 "Aktivite geçmişi"
for h in .zsh_history .bash_history .sh_history .python_history .node_repl_history .lesshst .mysql_history .psql_history; do
  [[ -f "$UH/$h" ]] && cp -p "$UH/$h" "$OUT/artifacts/$h" 2>>"$LOGFILE" || true
done
[[ -d "$UH/.zsh_sessions" ]] && cp -Rp "$UH/.zsh_sessions" "$OUT/artifacts/zsh_sessions" 2>>"$LOGFILE" || true
[[ -f "$ASUP/Knowledge/knowledgeC.db" ]] && cp -p "$ASUP/Knowledge/knowledgeC.db" "$OUT/artifacts/knowledgeC.db" 2>>"$LOGFILE" || true
"$LS_BIN" -laT /.fseventsd 2>/dev/null > "$OUT/artifacts/fseventsd_listing.txt" || true
"$LAST_BIN" -50 > "$OUT/artifacts/last_logins.txt" 2>>"$LOGFILE" || true
who -a          > "$OUT/artifacts/who.txt"          2>>"$LOGFILE" || true
[[ "$HAS_INTEL_REPORT" -eq 1 ]] && safe_run 30 "$LOG_BIN" show --last "${DAYS}d" \
  --predicate 'subsystem == "com.apple.intelligence" OR process == "intelligenced"' \
  > "$OUT/artifacts/apple_intelligence.log" 2>>"$LOGFILE" || true

# ============================================================
# ADIM 6 — İndirme Geçmişi & Tarayıcılar
# ============================================================
progress 6 "İndirme geçmişi & tarayıcılar"
asuser mdfind "kMDItemWhereFroms == '*'" -onlyin "$UH" \
  > "$OUT/downloads/indirilen_dosyalar.txt" 2>>"$LOGFILE" || true

: > "$OUT/downloads/indirilen_DETAY.txt"
for d in Downloads Desktop Documents Movies Music Pictures Public "Library/Mobile Documents"; do
  [[ -d "$UH/$d" ]] || continue
  "$FIND_BIN" "$UH/$d" -type f 2>/dev/null | while IFS= read -r f; do
    hex="$(xattr -p -x com.apple.metadata:kMDItemWhereFroms "$f" 2>/dev/null)"
    [[ -z "$hex" ]] && continue
    url="$(printf '%s' "$hex" | xxd -r -p 2>/dev/null | strings 2>/dev/null | grep -Eo 'https?://[^[:space:]]+' | tr '\n' ' ')"
    [[ -z "$url" ]] && url="(xattr mevcut, URL çözülemedi)"
    { echo "=== $f ==="; echo "KAYNAK : $url"
      echo "MTIME  : $("$STAT_BIN" -f '%Sm' "$f" 2>/dev/null)"
      echo "BOYUT  : $("$STAT_BIN" -f '%z byte' "$f" 2>/dev/null)"; echo
    } >> "$OUT/downloads/indirilen_DETAY.txt"
  done
done
[[ ! -s "$OUT/downloads/indirilen_dosyalar.txt" ]] && \
  grep '^=== ' "$OUT/downloads/indirilen_DETAY.txt" 2>/dev/null | sed 's/^=== //; s/ ===$//' \
  > "$OUT/downloads/indirilen_dosyalar.txt" || true

QDB="$UH/Library/Preferences/com.apple.LaunchServices.QuarantineEventsV2"
if [[ -f "$QDB" ]]; then
  sqlite3 "$QDB" "SELECT datetime(LSQuarantineTimeStamp+978307200,'unixepoch','localtime'),LSQuarantineAgentName,LSQuarantineDataURLString FROM LSQuarantineEvent ORDER BY 1 DESC;" \
    > "$OUT/downloads/quarantine.txt" 2>>"$LOGFILE" || true
  cp -p "$QDB" "$OUT/downloads/QuarantineEventsV2.db" 2>>"$LOGFILE" || true
fi

asuser mdfind "kMDItemDateAdded >= \$time.today(-${DAYS})"    -onlyin "$UH" > "$OUT/downloads/son_eklenen.txt"  2>>"$LOGFILE" || true
asuser mdfind "kMDItemLastUsedDate >= \$time.today(-${DAYS})" -onlyin "$UH" > "$OUT/downloads/son_acilan.txt"   2>>"$LOGFILE" || true
"$FIND_BIN" "$UH" -type f -mtime -"${DAYS}" 2>/dev/null > "$OUT/downloads/son_degisen_dosyalar.txt" || true

bdir="$OUT/downloads/browsers"
for base in "Google/Chrome" "Google/Chrome Beta" "Google/Chrome Canary" \
            "BraveSoftware/Brave-Browser" "Microsoft Edge" "Vivaldi" "Chromium" \
            "Yandex/YandexBrowser" "com.operasoftware.Opera" "com.operasoftware.OperaGX" "Arc/User Data"; do
  [[ -d "$ASUP/$base" ]] || continue
  while IFS= read -r hist; do
    [[ -f "$hist" ]] || continue
    prof="$(basename "$(dirname "$hist")")"
    safe="$(echo "${base}_${prof}" | tr ' /' '__')"
    DBF="$bdir/${safe}_History.db"
    cp -p "$hist" "$DBF" 2>>"$LOGFILE" || continue
    sqlite3 "$DBF" "SELECT datetime(start_time/1000000-11644473600,'unixepoch','localtime'),target_path,tab_url FROM downloads ORDER BY 1 DESC;" > "$bdir/${safe}_INDIRMELER.txt" 2>>"$LOGFILE" || true
    sqlite3 "$DBF" "SELECT datetime(last_visit_time/1000000-11644473600,'unixepoch','localtime'),url,title FROM urls ORDER BY last_visit_time DESC LIMIT 1000;" > "$bdir/${safe}_GEZINTI.txt" 2>>"$LOGFILE" || true
    note "[chromium] $safe"
  done < <("$FIND_BIN" "$ASUP/$base" -maxdepth 2 -name History -type f 2>/dev/null)
done

if [[ -d "$ASUP/Firefox/Profiles" ]]; then
  while IFS= read -r places; do
    [[ -f "$places" ]] || continue
    prof="$(basename "$(dirname "$places")")"
    DBF="$bdir/firefox_${prof}_places.sqlite"
    cp -p "$places" "$DBF" 2>>"$LOGFILE" || continue
    sqlite3 "$DBF" "SELECT datetime(last_visit_date/1000000,'unixepoch','localtime'),url,title FROM moz_places WHERE last_visit_date IS NOT NULL ORDER BY last_visit_date DESC LIMIT 1000;" > "$bdir/firefox_${prof}_GEZINTI.txt" 2>>"$LOGFILE" || true
    sqlite3 "$DBF" "SELECT datetime(a.dateAdded/1000000,'unixepoch','localtime'),p.url,a.content FROM moz_annos a JOIN moz_places p ON a.place_id=p.id JOIN moz_anno_attributes t ON a.anno_attribute_id=t.id WHERE t.name='downloads/destinationFileURI' ORDER BY a.dateAdded DESC;" > "$bdir/firefox_${prof}_INDIRMELER.txt" 2>>"$LOGFILE" || true
    note "[firefox] $prof"
  done < <("$FIND_BIN" "$ASUP/Firefox/Profiles" -maxdepth 2 -name places.sqlite -type f 2>/dev/null)
fi

SAF="$UH/Library/Safari/History.db"
if [[ -f "$SAF" ]]; then
  cp -p "$SAF" "$bdir/safari_History.db" 2>>"$LOGFILE" || true
  sqlite3 "$bdir/safari_History.db" \
    "SELECT datetime(v.visit_time+978307200,'unixepoch','localtime'),i.url FROM history_visits v JOIN history_items i ON v.history_item=i.id ORDER BY 1 DESC LIMIT 1000;" \
    > "$bdir/safari_GEZINTI.txt" 2>>"$LOGFILE" || true
fi
[[ -f "$UH/Library/Safari/Downloads.plist" ]] && cp -p "$UH/Library/Safari/Downloads.plist" "$bdir/safari_Downloads.plist" 2>>"$LOGFILE" || true

safe_run 60 "$LOG_BIN" show --last "${DAYS}d" \
  --predicate 'eventMessage CONTAINS "USBMSC" OR eventMessage CONTAINS[c] "mount" OR eventMessage CONTAINS "DiskArbitration"' \
  > "$OUT/downloads/usb_disk.log" 2>>"$LOGFILE" || true
system_profiler SPUSBDataType > "$OUT/downloads/usb_aygitlar.txt" 2>>"$LOGFILE" || true
"$LS_BIN" -la /Volumes        > "$OUT/downloads/bagli_diskler.txt" 2>>"$LOGFILE" || true
grep -iE "git (clone|pull|fetch)" "$UH"/.zsh_history "$UH"/.bash_history 2>/dev/null > "$OUT/downloads/_git_komutlari.txt" || true
"$FIND_BIN" "$UH" -type d -name ".git" 2>/dev/null > "$OUT/downloads/_git_repolar.txt" || true

# ============================================================
# ADIM 7 — Veri Akış Noktaları & Sistem Yapılandırması
# ============================================================
progress 7 "Veri akış noktaları & yapılandırma"
EX="$OUT/exfil"; PS_="$OUT/persistence"; mkdir -p "$EX" "$PS_"

ICD="$ASUP/CloudDocs/session/db"
[[ -d "$ICD" ]] && { mkdir -p "$EX/icloud"; cp -p "$ICD"/*.db "$EX/icloud/" 2>>"$LOGFILE" || true; }
[[ "$OS_MAJOR" -ge 26 && -d "$UH/Library/CloudStorage" ]] && \
  "$LS_BIN" -laRT "$UH/Library/CloudStorage" > "$EX/icloud_cloudStorage_listing.txt" 2>>"$LOGFILE" || true
GDF="$ASUP/Google/DriveFS"
[[ -d "$GDF" ]] && { mkdir -p "$EX/googledrive"; "$FIND_BIN" "$GDF" -maxdepth 3 \( -name "*.log" -o -name "metadata_sqlite_db" -o -name "*.db" \) -exec cp -p {} "$EX/googledrive/" \; 2>>"$LOGFILE" || true; }
if [[ -d "$UH/.dropbox" ]]; then
  mkdir -p "$EX/dropbox"
  cp -p "$UH/.dropbox/info.json" "$UH/.dropbox/host.db" "$EX/dropbox/" 2>/dev/null || true
  [[ -d "$UH/Dropbox" ]] && "$LS_BIN" -laT "$UH/Dropbox" > "$EX/dropbox/_klasor_listesi.txt" 2>>"$LOGFILE" || true
fi
[[ -d "$ASUP/OneDrive" ]] && { mkdir -p "$EX/onedrive"; "$FIND_BIN" "$ASUP/OneDrive" -maxdepth 3 \( -name "*.log" -o -name "*.ini" -o -name "*.db" \) -exec cp -p {} "$EX/onedrive/" \; 2>>"$LOGFILE" || true; }
[[ -d "$ASUP/Box" ]] && { mkdir -p "$EX/box"; "$FIND_BIN" "$ASUP/Box" -maxdepth 3 \( -name "*.db" -o -name "*.log" \) -exec cp -p {} "$EX/box/" \; 2>>"$LOGFILE" || true; }

if [[ -f "$UH/Library/Messages/chat.db" ]]; then
  cp -p "$UH/Library/Messages/chat.db" "$EX/messages_chat.db" 2>>"$LOGFILE" || true
  sqlite3 "$EX/messages_chat.db" \
    "SELECT datetime(m.date/1000000000+978307200,'unixepoch','localtime'),h.id,a.filename,m.text FROM message m LEFT JOIN handle h ON m.handle_id=h.ROWID LEFT JOIN message_attachment_join maj ON m.ROWID=maj.message_id LEFT JOIN attachment a ON maj.attachment_id=a.ROWID WHERE a.filename IS NOT NULL ORDER BY 1 DESC;" \
    > "$EX/messages_ekler.txt" 2>>"$LOGFILE" || true
fi
for app in "Slack" "Telegram Desktop" "WhatsApp" "Signal" "Microsoft Teams" "discord"; do
  [[ -d "$ASUP/$app" ]] && { echo "### $app" >> "$EX/mesajlasma_uygulamalari.txt"; "$LS_BIN" -laT "$ASUP/$app" >> "$EX/mesajlasma_uygulamalari.txt" 2>>"$LOGFILE" || true; }
done
if [[ -d "$UH/Library/Mail" ]]; then
  mkdir -p "$EX/mail"
  "$FIND_BIN" "$UH/Library/Mail" -maxdepth 4 -name "Envelope Index" -exec cp -p {} "$EX/mail/" \; 2>>"$LOGFILE" || true
  "$FIND_BIN" "$UH/Library/Mail" -maxdepth 5 -type d -name "Attachments" > "$EX/mail/_ek_klasorleri.txt" 2>>"$LOGFILE" || true
fi
[[ -d "$UH/Library/Group Containers/UBF8T346G9.Office/Outlook" ]] && \
  "$LS_BIN" -laTR "$UH/Library/Group Containers/UBF8T346G9.Office/Outlook" > "$EX/outlook_listesi.txt" 2>>"$LOGFILE" || true
safe_run 30 "$LOG_BIN" show --last "${DAYS}d" --predicate 'process == "sharingd"' > "$EX/airdrop_sharingd.log" 2>>"$LOGFILE" || true
[[ -f /var/log/cups/page_log   ]] && cp -p /var/log/cups/page_log   "$EX/cups_page_log"   2>>"$LOGFILE" || true
[[ -f /var/log/cups/access_log ]] && cp -p /var/log/cups/access_log "$EX/cups_access_log" 2>>"$LOGFILE" || true
asuser mdfind "kMDItemIsScreenCapture == 1" -onlyin "$UH" > "$EX/ekran_goruntuleri.txt" 2>>"$LOGFILE" || true
"$FIND_BIN" "$UH/Desktop" "$UH/Downloads" "$UH/Pictures" -type f \
  \( -iname "Screen Shot*" -o -iname "Ekran *" -o -iname "CleanShot*" -o -iname "*screenshot*" \) \
  2>/dev/null >> "$EX/ekran_goruntuleri.txt" || true

for tcc in "/Library/Application Support/com.apple.TCC/TCC.db" "$UH/Library/Application Support/com.apple.TCC/TCC.db"; do
  [[ -f "$tcc" ]] || continue
  scope=$([[ "$tcc" == /Library/* ]] && echo SYSTEM || echo USER)
  cp -p "$tcc" "$PS_/TCC_${scope}.db" 2>>"$LOGFILE" || true
  { echo "### $scope ($tcc)"
    sqlite3 "$tcc" "SELECT service, client, auth_value, last_modified FROM access;" 2>/dev/null \
    || sqlite3 "$tcc" "SELECT service, client, auth_value FROM access;" 2>/dev/null \
    || sqlite3 "$tcc" "SELECT service, client, allowed FROM access;" 2>/dev/null \
    || echo "(TCC şeması okunamadı)"
    echo; } >> "$PS_/tcc_izinler.txt"
done
[[ "$HAS_PRIVACY_REPORT" -eq 1 ]] && {
  for pr_path in "$UH/Library/Application Support/com.apple.PrivacyReport/privacy_report.db" \
                 "/Library/Application Support/com.apple.PrivacyReport/privacy_report.db"; do
    [[ -f "$pr_path" ]] && cp -p "$pr_path" "$PS_/tahoe_privacy_report.db" 2>>"$LOGFILE" && \
      { sqlite3 "$PS_/tahoe_privacy_report.db" ".tables" > "$PS_/tahoe_privacy_report_tables.txt" 2>/dev/null || true; }
  done
}
for d in "$UH/Library/LaunchAgents" "/Library/LaunchAgents" "/Library/LaunchDaemons"; do
  [[ -d "$d" ]] || continue
  safe_dir=$(echo "$d" | tr ' /' '__')
  mkdir -p "$PS_/launch/$safe_dir"
  cp -p "$d"/*.plist "$PS_/launch/$safe_dir/" 2>/dev/null || true
done
for btm in "/private/var/db/com.apple.backgroundtaskmanagement" "/private/var/db/com.apple.btm"; do
  [[ -d "$btm" ]] && { cp -Rp "$btm" "$PS_/BTM" 2>>"$LOGFILE" || true; break; }
done
{ [[ "$OS_MAJOR" -ge 13 ]] && profiles list -all 2>/dev/null \
  || profiles -P 2>/dev/null || echo "(profiles komutu çalışmadı)"; } \
  > "$PS_/config_profilleri.txt" 2>>"$LOGFILE" || true
if [[ -d "$UH/.ssh" ]]; then
  mkdir -p "$PS_/ssh"
  for sf in config known_hosts authorized_keys; do
    [[ -f "$UH/.ssh/$sf" ]] && cp -p "$UH/.ssh/$sf" "$PS_/ssh/" 2>>"$LOGFILE" || true
  done
  cp -p "$UH/.ssh/"*.pub "$PS_/ssh/" 2>/dev/null || true
fi

# ============================================================
# ADIM 8 — Sistem Envanteri
# ============================================================
progress 8 "Sistem envanteri"
system_profiler SPSoftwareDataType SPHardwareDataType > "$OUT/system/os_info.txt" 2>>"$LOGFILE" || true
ps aux                             > "$OUT/system/processes.txt"     2>>"$LOGFILE" || true
launchctl list                     > "$OUT/system/launch_agents.txt" 2>>"$LOGFILE" || true
dscl . list /Users                 > "$OUT/system/local_users.txt"   2>>"$LOGFILE" || true
ioreg -p IOUSB -l                  > "$OUT/system/usb_devices.txt"   2>>"$LOGFILE" || true
[[ "$ARCH" == "arm64" ]] && sysctl -a | grep -E "hw\.(optional|features|perflevel)" > "$OUT/system/apple_silicon.txt" 2>/dev/null || true
[[ "$OS_MAJOR" -ge 26 ]] && sfltool dumpef 2>/dev/null | head -500 > "$OUT/system/tahoe_spotlight_ef.txt" || true

# ============================================================
# ADIM 9 — Bütünlük Doğrulaması
# ============================================================
progress 9 "Bütünlük doğrulaması"
( cd "$OUT" && "$FIND_BIN" . -type f ! -name "MANIFEST_SHA256.txt" \
    -exec shasum -a 256 {} \; ) | sort > "$OUT/MANIFEST_SHA256.txt"

# ============================================================
# ADIM 10 — Paketleniyor
# ============================================================
progress 10 "Paketleniyor"
rm -f "$ZIP"
if "$DITTO_BIN" -c -k --sequesterRsrc --keepParent "$OUT" "$ZIP" 2>>"$LOGFILE"; then
  note "ZIP OK (ditto)"
else
  note "ditto uyarı; zip ile deneniyor..."
  ( cd "$OUTBASE" && zip -r -q "${CASE_FOLDER}.zip" "$CASE_FOLDER" ) 2>>"$LOGFILE" || true
fi
chown -R "$OPERATOR":staff "$OUT" 2>/dev/null || true
chown    "$OPERATOR":staff "$ZIP" 2>/dev/null || true

# ── Özet ─────────────────────────────────────────────────────
EL=$(( $(date +%s) - START_TS ))
note "TAMAMLANDI ($EL sn). ZIP: $ZIP"

ZIP_SIZE="$( du -sh "$ZIP" 2>/dev/null | cut -f1 || echo "—" )"
FILE_COUNT="$( wc -l < "$OUT/MANIFEST_SHA256.txt" 2>/dev/null | tr -d ' ' || echo "—" )"

printf "\n"
sep
printf "\n"
printf "  ${C_GRN}${C_BLD}✓  Koleksiyon tamamlandı${C_RST}\n\n"
printf "  ${C_DIM}%-18s${C_RST}  %s\n"  "Sistem"      "$OS_NAME $OS_VER ($CHIP)"
printf "  ${C_DIM}%-18s${C_RST}  %s\n"  "Kullanıcı"   "$TARGET_USER"
printf "  ${C_DIM}%-18s${C_RST}  %s\n"  "Case ID"     "$CASE_ID"
printf "  ${C_DIM}%-18s${C_RST}  %s\n"  "Süre"        "${EL} saniye"
printf "  ${C_DIM}%-18s${C_RST}  %s\n"  "Dosya sayısı" "$FILE_COUNT"
printf "  ${C_DIM}%-18s${C_RST}  %s\n"  "Arşiv boyutu" "$ZIP_SIZE"
printf "\n"
printf "  ${C_BLD}Çıktı:${C_RST}\n"
printf "  ${C_CYN}%s${C_RST}\n" "$ZIP"
printf "\n"
sep
printf "\n"

su "$OPERATOR" -c "/usr/bin/open -R '$ZIP'" >/dev/null 2>&1 \
  || su "$OPERATOR" -c "/usr/bin/open '$OUTBASE'" >/dev/null 2>&1 || true
/usr/bin/osascript \
  -e "display dialog \"MacHarvest tamamlandı.\n\nCase: $CASE_ID\nSüre: ${EL}sn  ·  $FILE_COUNT dosya  ·  $ZIP_SIZE\n\nMasaüstünde:\n${CASE_FOLDER}.zip\" buttons {\"Tamam\"} default button 1 with title \"MacHarvest\" with icon note" \
  >/dev/null 2>&1 || true
