#!/usr/bin/env bash
# =============================================================================
# preuve_ide_pass2.sh — 2e passe des captures J1.
#
# Pourquoi une 2e passe : au 1er lancement, PyCharm affiche une modale
# « Meet the Islands Theme » et deux ballons de notification qui CAPTURENT le
# focus. Les captures de la 1re passe montrent donc l'IDE, mais pas les
# panneaux vises. Cette passe les ferme d'abord (clic sur « Skip » et sur
# « Don't show again »), attend la fin de l'analyse, puis refait chaque piste.
#
# Les positions des clics sont mesurees sur les captures de la 1re passe
# (1920x1200, fenetre PyCharm de x=260 a x=1660).
# =============================================================================
set -u

PROOF="${1:-/work/preuves/cycle115/preuves}"
IDE="${IDE:-/work/ide/pycharm-2026.2.4}"

export PATH="/work/tools/x11/extracted/usr/bin:$PATH"
export LD_LIBRARY_PATH="/work/tools/x11/extracted/usr/bin:/work/tools/x11/extracted/usr/lib/x86_64-linux-gnu:${LD_LIBRARY_PATH:-}"
export DISPLAY=:99

mkdir -p "$PROOF"
LOG="$PROOF/preuve-ide-pass2.log"
exec > >(tee "$LOG") 2>&1

log() { echo "[$(date -u '+%H:%M:%S')] $*"; }
shot() {
    local name="$1"; sleep 2
    if import -window root "$PROOF/$name" 2>/dev/null && [ -s "$PROOF/$name" ]; then
        log "capture : $name ($(stat -c%s "$PROOF/$name") octets)"
    else
        log "ECHEC capture : $name"
    fi
}
click() { xdotool mousemove "$1" "$2" click 1; }
rclick() { xdotool mousemove "$1" "$2" click 3; }

log "=== PREUVE IDE — 2e PASSE — $(date -u '+%Y-%m-%dT%H:%M:%SZ') ==="

WID=$(xdotool search --name "PyCharm" 2>/dev/null | tail -1)
[ -z "$WID" ] && { log "ERREUR : l'IDE n'est pas lance"; exit 4; }
xdotool windowactivate "$WID" 2>/dev/null
log "fenetre active : $WID"

# --- 1. fermer la modale « Islands Theme » ------------------------------
log "--- fermeture de la modale et des ballons ---"
click 985 798       # bouton « Skip » de la modale « Meet the Islands Theme »
sleep 3
click 1508 913      # « Don't show again » (ballon 1)
sleep 2
click 1508 1035     # « Don't show again » (ballon 2)
sleep 2
xdotool key --clearmodifiers Escape; sleep 2
shot "J1-10-modale-fermee.png"

# --- 2. attendre la fin de l'analyse du projet ----------------------------
log "--- attente de la fin de l'analyse du projet (60 s) ---"
sleep 60
shot "J1-11-projet-pret.png"

# --- Piste A : le menu Git -> Log ---------------------------------------
log "--- Piste A : menu Git (le chemin de menus exact) ---"
click 688 115        # menu « Git » dans la barre de menus
sleep 4
shot "J1-12-menu-git-ouvert.png"
xdotool key --clearmodifiers Escape; sleep 3

log "--- Piste A : ouverture du panneau Git Log ---"
xdotool key --clearmodifiers ctrl+shift+a; sleep 4
xdotool type --delay 70 "Show Git Log"; sleep 5
shot "J1-13-find-action-show-git-log.png"
xdotool key --clearmodifiers Return; sleep 12
shot "J1-14-panneau-git-log.png"

# --- Piste A bis : le filtre du panneau Git Log --------------------------
log "--- Piste A bis : le filtre du Git Log avec la chaine distinctive ---"
xdotool key --clearmodifiers ctrl+f; sleep 3
xdotool type --delay 90 "pi3rre-magique-7749"; sleep 8
shot "J1-15-filtre-git-log-chaine-distinctive.png"

# --- Piste B : "Show History for Selection" ------------------------------
log "--- Piste B : menu contextuel de l'editeur ---"
# On ouvre le fichier qui contient la chaine, on selectionne tout, puis clic droit.
click 388 244        # src/config.py dans l'arborescence
sleep 6
xdotool key --clearmodifiers ctrl+a; sleep 3
rclick 900 200       # clic droit dans l'editeur
sleep 5
shot "J1-16-menu-contextuel-editeur.png"
xdotool key --clearmodifiers Escape; sleep 3

# --- Piste B bis : l'action existe-t-elle ? ------------------------------
log "--- Piste B bis : Find Action « Show History for Selection » ---"
xdotool key --clearmodifiers ctrl+shift+a; sleep 4
xdotool type --delay 70 "Show History for Selection"; sleep 5
shot "J1-17-find-action-show-history-for-selection.png"
xdotool key --clearmodifiers Escape; sleep 3

# --- Piste C : l'action du plugin ---------------------------------------
log "--- Piste C : l'action du plugin ---"
xdotool key --clearmodifiers ctrl+shift+a; sleep 4
xdotool type --delay 70 "Find in Commit History"; sleep 5
shot "J1-18-find-action-notre-plugin.png"
xdotool key --clearmodifiers Return; sleep 12
shot "J1-19-dialogue-find-in-commit-history.png"
xdotool type --delay 90 "pi3rre-magique-7749"; sleep 3
shot "J1-20-dialogue-chaine-saisiee.png"
xdotool key --clearmodifiers Return; sleep 15
shot "J1-21-resultats.png"

# --- Piste D : GitToolBox est-il installe ? ------------------------------
log "--- Piste D : GitToolBox ---"
xdotool key --clearmodifiers Escape; sleep 2
xdotool key --clearmodifiers ctrl+shift+a; sleep 4
xdotool type --delay 70 "GitToolBox"; sleep 5
shot "J1-22-find-action-gittoolbox.png"

log "=== FIN 2e passe ==="
ls -la "$PROOF"/J1-1*.png "$PROOF"/J1-2*.png 2>/dev/null | sed 's/^/    /'
exit 0
