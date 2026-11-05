#!/usr/bin/env bash
# =============================================================================
# preuve_ide_pass5.sh — 5e passe : la passe 4 a PROUVE que l'action est
# enregistree (elle apparait dans le menu Tools), mais la navigation au
# clavier (End puis Return) n'a pas declenche l'action : les captures
# J1-28 a J1-31 sont strictement identiques (124975 octets).
#
# Correction : on CLIQUE directement l'entree de menu « Find in Commit
# History... » (coordonnees mesurees sur la capture J1-27 : 714,417).
# L'IDE est deja lance et le plugin deja installe : cette passe ne
# redemarre rien.
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

LOG="$PROOF/preuve-ide-pass5.log"
exec > >(tee "$LOG") 2>&1
log() { echo "[$(date -u '+%H:%M:%S')] $*"; }
shot() { local n="$1"; sleep 2; if import -window root "$PROOF/$n" 2>/dev/null && [ -s "$PROOF/$n" ]; then log "capture : $n ($(stat -c%s "$PROOF/$n") o)"; else log "ECHEC capture : $n"; fi; }
click() { xdotool mousemove "$1" "$2" click 1; sleep 1; }

log "=== 5e passe — clic direct sur l'action — $(date -u '+%Y-%m-%dT%H:%M:%SZ') ==="

WID=$(xdotool search --name "PyCharm" 2>/dev/null | tail -1)
[ -z "$WID" ] && { log "ERREUR : fenetre PyCharm introuvable"; exit 4; }
xdotool windowactivate "$WID" 2>/dev/null; sleep 2
log "fenetre $WID"

log "--- 1. menu Tools ---"
click 645 115; sleep 4
shot "J1-27-menu-tools-avec-l-action.png"

log "--- 2. clic direct sur « Find in Commit History... » (714,417) ---"
click 714 417; sleep 12
shot "J1-29-dialogue-find-in-commit-history.png"

log "--- 3. saisie de la chaine distinctive ---"
xdotool type --delay 90 "pi3rre-magique-7749"; sleep 3
shot "J1-30-dialogue-chaine-saisiee.png"

log "--- 4. lancement de la recherche (touche Entree) ---"
xdotool key --clearmodifiers Return; sleep 20
shot "J1-31-resultats.png"

log "=== FIN 5e passe ==="
md5sum "$PROOF"/J1-27*.png "$PROOF"/J1-29*.png "$PROOF"/J1-30*.png "$PROOF"/J1-31*.png 2>/dev/null | sed 's/^/    /'
exit 0
