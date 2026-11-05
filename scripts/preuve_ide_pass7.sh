#!/usr/bin/env bash
# =============================================================================
# preuve_ide_pass7.sh — 7e passe : ouvrir le dialogue en CLIQUANT l'action
# dans la palette « Find Action » (la touche Entree ne l'activait pas),
# saisir la chaine, puis s'arreter : le bouton « Search » sera clique avec
# les coordonnees relevees sur la capture du dialogue.
# =============================================================================
set -u
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(cd "$HERE/.." && pwd)"
PROOF="${1:-$ROOT/../preuves/cycle115/preuves}"

export PATH="/work/tools/x11/extracted/usr/bin:$PATH"
export LD_LIBRARY_PATH="/work/tools/x11/extracted/usr/bin:/work/tools/x11/extracted/usr/lib/x86_64-linux-gnu:${LD_LIBRARY_PATH:-}"
export DISPLAY=:99
export XDG_RUNTIME_DIR=/tmp/runtime-agent
mkdir -p "$XDG_RUNTIME_DIR" && chmod 700 "$XDG_RUNTIME_DIR"

LOG="$PROOF/preuve-ide-pass7.log"
exec > >(tee "$LOG") 2>&1
log() { echo "[$(date -u '+%H:%M:%S')] $*"; }
shot() { local n="$1"; sleep 2; if import -window root "$PROOF/$n" 2>/dev/null && [ -s "$PROOF/$n" ]; then log "capture : $n ($(stat -c%s "$PROOF/$n") o)"; else log "ECHEC capture : $n"; fi; }
click() { xdotool mousemove "$1" "$2" click 1; sleep 1; }

log "=== 7e passe — clic sur l'action dans Find Action — $(date -u '+%Y-%m-%dT%H:%M:%SZ') ==="

log "--- 1. clic sur l'entree « Find in Commit History... » (709,405) ---"
click 709 405; sleep 14
shot "J1-29-dialogue-find-in-commit-history.png"

log "--- 2. saisie de la chaine distinctive ---"
xdotool type --delay 90 "pi3rre-magique-7749"; sleep 3
shot "J1-30-dialogue-chaine-saisiee.png"

log "=== FIN 7e passe ==="
exit 0
