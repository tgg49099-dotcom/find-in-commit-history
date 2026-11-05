#!/usr/bin/env bash
# =============================================================================
# preuve_ide_pass3.sh — 3e passe : on pilote l'IDE par CLICS, plus par le
# champ « Find Action » (qui n'a pas focalise la saisie).
#
# Coordonnees mesurees sur les captures de la 2e passe (1920x1200) :
#   menu « Git » de la barre de menus      : (688, 115)
#   entrée « Show Git Log » du menu Git    : (747, 474)
#   menu « Tools »                         : (645, 115)
#   fichier src/config.py dans l'arborescence : (388, 244)
# =============================================================================
set -u
PROOF="${1:-/work/preuves/cycle115/preuves}"
export PATH="/work/tools/x11/extracted/usr/bin:$PATH"
export LD_LIBRARY_PATH="/work/tools/x11/extracted/usr/bin:/work/tools/x11/extracted/usr/lib/x86_64-linux-gnu:${LD_LIBRARY_PATH:-}"
export DISPLAY=:99
mkdir -p "$PROOF"
LOG="$PROOF/preuve-ide-pass3.log"
exec > >(tee "$LOG") 2>&1
log() { echo "[$(date -u '+%H:%M:%S')] $*"; }
shot() { local n="$1"; sleep 2; if import -window root "$PROOF/$n" 2>/dev/null && [ -s "$PROOF/$n" ]; then log "capture : $n"; else log "ECHEC capture : $n"; fi; }
click() { xdotool mousemove "$1" "$2" click 1; sleep 1; }
rclick() { xdotool mousemove "$1" "$2" click 3; sleep 1; }

WID=$(xdotool search --name "PyCharm" 2>/dev/null | tail -1)
[ -z "$WID" ] && { log "ERREUR : l'IDE n'est pas lance"; exit 4; }
xdotool windowactivate "$WID" 2>/dev/null
log "=== 3e passe — fenetre $WID ==="

# --- refermer la boite de dialogue « Open » restee ouverte ---------------
log "--- fermeture de la boite de dialogue residuelle ---"
click 1401 901          # bouton « Cancel »
sleep 3
xdotool key --clearmodifiers Escape; sleep 2
xdotool key --clearmodifiers Escape; sleep 2
click 1100 800          # clic dans la zone editor : l'IDE reprend le focus
sleep 3
shot "J1-20-etat-retabli.png"

# --- Piste B : menu contextuel de l'editeur ------------------------------
log "--- Piste B : menu contextuel de l'editeur (src/config.py) ---"
click 388 244           # src/config.py
sleep 6
xdotool key --clearmodifiers ctrl+a; sleep 3
rclick 900 200          # clic droit dans le texte selectionne
sleep 5
shot "J1-21-menu-contextuel-editeur.png"
xdotool key --clearmodifiers Escape; sleep 3

# --- Piste A : Git > Show Git Log ----------------------------------------
log "--- Piste A : Git > Show Git Log ---"
click 688 115           # menu « Git »
sleep 4
shot "J1-22-menu-git-ouvert.png"
click 747 474           # « Show Git Log »
sleep 18
shot "J1-23-panneau-git-log.png"

# --- Piste C : menu Tools (notre action est en dernier) ------------------
log "--- Piste C : menu Tools ---"
click 645 115           # menu « Tools »
sleep 4
shot "J1-24-menu-tools-ouvert.png"
xdotool key --clearmodifiers Escape; sleep 2

log "=== FIN 3e passe ==="
exit 0
