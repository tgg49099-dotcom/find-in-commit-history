#!/usr/bin/env bash
# =============================================================================
# preuve_ide_pass9.sh — 9e passe : OUVRIR le dialogue, SAISIR la chaine,
# puis CLIQUER le bouton « Search » (la touche Entree ne declenche pas la
# recherche : c'est un defaut connu, non corrige) et capturer le RESULTAT.
#
# But : une capture qui montre les commits trouves PAR LE PLUGIN, avec le ZIP
# officiel installe — pas seulement un dialogue vide.
#
# Usage : bash scripts/preuve_ide_pass9.sh <dossier_preuves>
# =============================================================================
set -u
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(cd "$HERE/.." && pwd)"
PROOF="${1:-$ROOT/../preuves/cycle117/preuves}"

export PATH="/work/tools/x11/extracted/usr/bin:$PATH"
export LD_LIBRARY_PATH="/work/tools/x11/extracted/usr/bin:/work/tools/x11/extracted/usr/lib/x86_64-linux-gnu:${LD_LIBRARY_PATH:-}"
export DISPLAY=:99
export XDG_RUNTIME_DIR=/tmp/runtime-agent
mkdir -p "$XDG_RUNTIME_DIR" && chmod 700 "$XDG_RUNTIME_DIR"

LOG="$PROOF/preuve-ide-pass9.log"
exec > >(tee "$LOG") 2>&1
log() { echo "[$(date -u '+%H:%M:%S')] $*"; }
shot() { local n="$1"; sleep 2; if import -window root "$PROOF/$n" 2>/dev/null && [ -s "$PROOF/$n" ]; then log "capture : $n ($(stat -c%s "$PROOF/$n") o, $(identify -format '%wx%h' "$PROOF/$n" 2>/dev/null))"; else log "ECHEC capture : $n"; fi; }
click() { xdotool mousemove "$1" "$2" click 1; sleep 1; }

log "=== 9e passe — resultats avec le ZIP officiel — $(date -u '+%Y-%m-%dT%H:%M:%SZ') ==="

WID=$(xdotool search --name "PyCharm" 2>/dev/null | tail -1)
[ -n "$WID" ] && { xdotool windowactivate "$WID" 2>/dev/null; log "fenetre PyCharm active ($WID)"; }
sleep 3

log "--- 1. palette « Find Action » ---"
xdotool key --clearmodifiers ctrl+shift+a 2>/dev/null; sleep 5
xdotool key --clearmodifiers ctrl+a 2>/dev/null; sleep 1
xdotool key --clearmodifiers BackSpace 2>/dev/null; sleep 1
xdotool type --delay 70 "Find in Commit History" 2>/dev/null; sleep 5
shot "J1-40-find-action.png"

log "--- 2. clic sur l'entree de l'action ---"
click 709 405; sleep 16
shot "J1-41-dialogue.png"

log "--- 3. saisie de la chaine distinctive ---"
xdotool type --delay 90 "pi3rre-magique-7749" 2>/dev/null; sleep 3
shot "J1-42-dialogue-chaine-saisiee.png"

log "--- 4. CLIC sur le bouton « Search » (1096,777) ---"
click 1096 777; sleep 14
shot "J1-43-resultats.png"

log "=== FIN 9e passe ==="
exit 0
