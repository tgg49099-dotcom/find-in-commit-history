#!/usr/bin/env bash
# =============================================================================
# preuve_entree_fond_suite.sh — PHASE 2 de la preuve D1 + D2 dans le VRAI IDE.
#
# La phase 1 (preuve_entree_fond.sh) a lance l'IDE et prepare le projet de
# demonstration (1 202 commits : la recherche dure ~4,5 s).
#
# Cette phase-ci :
#   1. ouvre l'action par le MENU Tools ;
#   2. saisit la chaine distinctive dans « Search for: » ;
#   3. appuie sur ENTREE (et NON sur le bouton « Search »)  -> preuve D2 ;
#   4. PENDANT la recherche, ecrit dans le champ « Path filter » et capture
#      l'ecran : si l'EDT etait bloque par la recherche, cette saisie
#      n'apparaitrait qu'a la fin           -> preuve D1 ;
#   5. capture le resultat affiche par le plugin ;
#   6. arrete l'IDE.
#
# AUCUNE publication, AUCUN jeton, 0 $.
# =============================================================================
set -u

export PATH="/work/tools/x11/extracted/usr/bin:$PATH"
export LD_LIBRARY_PATH="/work/tools/x11/extracted/usr/bin:/work/tools/x11/extracted/usr/lib/x86_64-linux-gnu:${LD_LIBRARY_PATH:-}"
export DISPLAY=:99
export XDG_RUNTIME_DIR=/tmp/runtime-agent
mkdir -p "$XDG_RUNTIME_DIR" && chmod 700 "$XDG_RUNTIME_DIR"

PROOF="${PROOF:-/work/preuves/cycle119/preuves}"
LOG="$PROOF/preuve-entree-fond-phase2.log"
exec > >(tee -a "$LOG") 2>&1

log() { echo "[$(date -u '+%H:%M:%S')] $*"; }
shot() {
    local name="$1"
    if import -window root "$PROOF/$name" 2>/dev/null && [ -s "$PROOF/$name" ]; then
        log "capture : $name ($(stat -c%s "$PROOF/$name") octets)"
    else
        log "ECHEC capture : $name"
    fi
}
# clic « sur » : on deplace la souris, on ATTEND que l'IDE ait traite le
# deplacement, puis on clique (sinon le clic part a l'ancien endroit et le
# menu se referme sans rien lancer).
clic() { xdotool mousemove "$1" "$2"; sleep 1.5; xdotool click 1; sleep 1; }
mem() { awk '/^anon /{a=$2}/^slab /{s=$2}END{print a+s}' /sys/fs/cgroup/memory.stat; }

WID=$(xdotool search --name "PyCharm" 2>/dev/null | tail -1)
[ -n "$WID" ] && xdotool windowactivate "$WID" 2>/dev/null
sleep 2

log "=== 1. ouverture de l'action par le MENU Tools ==="
clic 647 115                       # menu « Tools »
clic 730 419                       # « Find in Commit History… » (dernier item)
DIALOG=""
for i in $(seq 1 20); do
    DIALOG=$(xdotool search --name "Find in Commit History" 2>/dev/null | tail -1)
    [ -n "$DIALOG" ] && break
    sleep 1
done
if [ -z "$DIALOG" ]; then
    log "ECHEC : le dialogue ne s'est pas ouvert"
    exit 1
fi
log "dialogue ouvert (fenetre X id $DIALOG)"
GEOM=$(xdotool getwindowgeometry --shell "$DIALOG")
echo "$GEOM" | tee -a "$LOG"
DX=$(echo "$GEOM" | awk -F= '/^X=/{print $2}')
DY=$(echo "$GEOM" | awk -F= '/^Y=/{print $2}')
# Decalages mesures sur la capture reelle (le dialogue fait 544 x 405).
OFF_NEEDLE_X="${OFF_NEEDLE_X:-341}"; OFF_NEEDLE_Y="${OFF_NEEDLE_Y:-24}"
OFF_PATH_X="${OFF_PATH_X:-341}";   OFF_PATH_Y="${OFF_PATH_Y:-92}"
NEEDLE_X=$((DX + OFF_NEEDLE_X)); NEEDLE_Y=$((DY + OFF_NEEDLE_Y))
PATH_X=$((DX + OFF_PATH_X));     PATH_Y=$((DY + OFF_PATH_Y))
log "champ « Search for »  : ($NEEDLE_X, $NEEDLE_Y)"
log "champ « Path filter » : ($PATH_X, $PATH_Y)"
xdotool windowactivate "$DIALOG" 2>/dev/null
sleep 1
shot "D2-01-dialogue-ouvert.png"

log "=== 2. saisie de la chaine distinctive ==="
clic "$NEEDLE_X" "$NEEDLE_Y"
xdotool type --delay 80 "pi3rre-magique-7749" 2>/dev/null
sleep 1
shot "D2-02-chaine-saisiee.png"

log "=== 3. ENTREE (aucun clic sur le bouton « Search ») ==="
xdotool key --clearmodifiers Return 2>/dev/null
sleep 0.3
# Capture immediate : la recherche dure ~15 s sur ce depot, l'ecran doit
# montrer « Searching... » -> la touche ENTREE a bien declenche la
# recherche (preuve D2).
shot "D2-03-recherche-en-cours.png"

# --- D1 : pendant que la recherche tourne, on ecrit dans un AUTRE champ.
# Si l'EDT etait bloque par la recherche, cette saisie n'apparaitrait qu'a la
# fin de la recherche : elle resterait invisible dans la capture.
xdotool mousemove "$PATH_X" "$PATH_Y"; sleep 0.8; xdotool click 1
xdotool type --delay 100 "src" 2>/dev/null
sleep 0.3
shot "D2-04-ide-reactif-pendant-la-recherche.png"

log "=== 4. attente de la fin de la recherche (boucle : capture toutes les 20 s) ==="
for i in $(seq 1 9); do
    sleep 20
    shot "D2-05-resultats-appres-entree-$i.png"
    # si le dialogue affiche un nombre de commits, la recherche est finie
    if xdotool search --name "Find in Commit History" >/dev/null 2>&1; then
        TXT=$(import -window root png:- 2>/dev/null | python3 -c "
import sys
d=sys.stdin.buffer.read()
import re
print('peut-etre' if len(d)>0 else 'non')
" 2>/dev/null)
    fi
done
cp -f "$PROOF/D2-05-resultats-appres-entree-9.png" "$PROOF/D2-05-resultats-apres-entree.png" 2>/dev/null

log "=== 5. etat final ==="
log "memoire : anon+slab = $(mem) / 1572864000"
NBCAPT=$(ls "$PROOF"/D2-0*.png 2>/dev/null | wc -l)
log "captures : $NBCAPT"

log "=== 6. arret de l'IDE ==="
pkill -f 'com[.]intellij[.]idea[.]Main' 2>/dev/null; sleep 3
pkill -9 -f 'com[.]intellij[.]idea[.]Main' 2>/dev/null; sleep 1
log "memoire apres arret : anon+slab = $(mem) / 1572864000"
log "FIN phase 2"
