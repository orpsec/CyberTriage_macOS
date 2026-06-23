#!/bin/bash
# MacHarvest — macOS Data Collection Suite
# Çift tıkla: Terminal açılır, sudo şifresi istenir, toplama başlar.

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd -P)"
MAIN="$SCRIPT_DIR/macos_triage.sh"

if [[ ! -f "$MAIN" ]]; then
  printf '\n  \033[0;31m[!]\033[0m macos_triage.sh bulunamadı.\n'
  printf '      Bu dosyayı macos_triage.sh ile AYNI klasörde tut.\n\n'
  read -r -p "  Çıkmak için Enter..." _
  exit 1
fi

/usr/bin/xattr -dr com.apple.quarantine "$MAIN" 2>/dev/null || true
/usr/bin/xattr -dr com.apple.quarantine "$0"    2>/dev/null || true
chmod +x "$MAIN"

sudo /bin/bash "$MAIN"
EC=$?

if [[ $EC -ne 0 ]]; then
  printf '\n  \033[1;33m[!]\033[0m Hata kodu: %d — _collection.log dosyasını incele.\n\n' "$EC"
  read -r -p "  Kapatmak için Enter..." _
fi
