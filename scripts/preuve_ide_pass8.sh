#!/usr/bin/env bash
# 8e passe : la palette « Find Action » est ouverte mais son champ contenait
# une chaine parasite (la liste etait donc vide). On vide le champ, on retype
# le nom de l'action, on CLIQUE l'entree, puis on saisit la chaine dans le
# dialogue.
set -u
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(cd "$HERE/.." && pwd)"
PROOF="${1:-$ROOT/../preuves/cycle115/preuves}"
export PATH="/work/tools/x11/extracted/usr/bin:$PATH"
export LD_LIBRARY_PATH="/work/tools/x11/extracted/usr/bin:/work/tools/x11/extracted/usr/lib/x86_64-linux-gnu:${LD_LIBRARY_PATH:-}"
export DISPLAY=:99
export XDG_RUNTIME_DIR=/tmp/runtime-agent
mkdir -p "$XDG_RUNTIME_DIR" && chmod 700 "$XDG_RUNTIME_DIR"
LOG="$PROOF/preuve-ide-pass8.log"
exec > >(tee "$LOG") 2>&1
log() { echo "[$(date -u '+%H:%M:%S')] $*"; }
shot() { local n="$1"; sleep 2; if import -window root "$PROOF/$n" 2>/dev/null && [ -s "$PROOF/$n" ]; then log "capture : $n ($(stat -c%s "$PROOF/$n") o)"; else log "ECHEC capture : $n"; fi; }
click() { xdotool mousemove "$1" "$2" click 1; sleep 1; }
log "=== 8e passe — $(date -u '+%Y-%m-%dT%H:%M:%SZ') ==="
click 950 368; sleep 1
xdotool key --clearmodifiers ctrl+a; sleep 1
xdotool key --clearmodifiers BackSpace; sleep 1
xdotool type --delay 70 "Find in Commit History"; sleep 5
shot "J1-28-find-action.png"
log "--- clic sur l'entree (709,405) ---"
click 709 405; sleep 14
shot "J1-29-dialogue-find-in-commit-history.png"
log "--- saisie de la chaine ---"
xdotool type --delay 90 "pi3rre-magique-7749"; sleep 3
shot "J1-30-dialogue-chaine-saisiee.png"
log "=== FIN 8e passe ==="
exit 0
