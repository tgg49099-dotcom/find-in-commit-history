#!/usr/bin/env bash
# =============================================================================
# preuve_ide_pass6.sh — 6e passe : ouvrir le DIALOGUE du plugin et saisir
# la chaine distinctive.
#
# Ce que les passes precedentes ont etabli :
#  - J1-27 : le menu Tools contient bien « Find in Commit History... »
#            (l'action est enregistree : la correction du plugin.xml marche) ;
#  - J1-23 : le panneau Git Log natif liste 3 commits et son filtre s'appelle
#            « Text or hash » ;
#  - dans le depot de demonstration, la chaine « pi3rre-magique-7749 » a ete
#    AJOUTEE puis SUPPRIMEE : `git log -S` renvoie 2 commits sur 3
#    (« feat: add the configuration file » et « fix: remove the token line »),
#    le commit du milieu « style: annotate the token line » ne matche PAS (controle
#    negatif). La chaine est absente des fichiers actuels (grep : 0 resultat).
#
# Cette passe ouvre le dialogue via « Find Action » (Ctrl+Shift+A), plus
# robuste qu'un clic de menu, saisit la chaine et s'arrete avant la
# recherche : le bouton « Search » sera clique ensuite (coordonnees relevees
# sur la capture du dialogue), car le dialogue ne declara pas de bouton par
# defaut (pas de setDefaultButton) et la touche Entree ne declenche donc
# rien.
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

LOG="$PROOF/preuve-ide-pass6.log"
exec > >(tee "$LOG") 2>&1
log() { echo "[$(date -u '+%H:%M:%S')] $*"; }
shot() { local n="$1"; sleep 2; if import -window root "$PROOF/$n" 2>/dev/null && [ -s "$PROOF/$n" ]; then log "capture : $n ($(stat -c%s "$PROOF/$n") o)"; else log "ECHEC capture : $n"; fi; }
click() { xdotool mousemove "$1" "$2" click 1; sleep 1; }

log "=== 6e passe — dialogue du plugin — $(date -u '+%Y-%m-%dT%H:%M:%SZ') ==="

# La fenetre REELLE porte le nom du projet (« demo-project ») et pas
# « PyCharm » : on prend donc la plus grande fenetre visible.
WID=$(for w in $(xdotool search --onlyvisible --name '.*' 2>/dev/null); do
        wd=$(xdotool getwindowgeometry "$w" 2>/dev/null | grep Geometry | sed 's/.*: //;s/x.*//')
        [ -n "${wd:-}" ] && [ "$wd" -gt 1000 ] && echo "$w"
      done | head -1)
[ -z "$WID" ] && { log "ERREUR : fenetre PyCharm introuvable"; exit 4; }
xdotool windowactivate "$WID" 2>/dev/null; sleep 2
log "fenetre $WID"

log "--- 1. focus sur la fenetre, fermeture de tout menu ---"
click 1200 300
xdotool key --clearmodifiers Escape; sleep 2

log "--- 2. Find Action (Ctrl+Shift+A) ---"
xdotool key --clearmodifiers ctrl+shift+a; sleep 5
xdotool type --delay 70 "Find in Commit History"; sleep 4
shot "J1-28-find-action.png"
xdotool key --clearmodifiers Return; sleep 14
shot "J1-29-dialogue-find-in-commit-history.png"

log "--- 3. saisie de la chaine distinctive ---"
xdotool type --delay 90 "pi3rre-magique-7749"; sleep 3
shot "J1-30-dialogue-chaine-saisiee.png"

log "=== FIN 6e passe (clic sur Search a faire ensuite) ==="
md5sum "$PROOF"/J1-28-find-action.png "$PROOF"/J1-29-dialogue-find-in-commit-history.png "$PROOF"/J1-30-dialogue-chaine-saisiee.png 2>/dev/null | sed 's/^/    /'
exit 0
