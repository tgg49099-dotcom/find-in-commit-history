#!/usr/bin/env bash
# =============================================================================
# preuve_ide_pass4.sh — 4e passe, avec le plugin.xml CORRIGE.
#
# Correction : les <action> doivent etre dans un bloc <actions> de premier
# niveau, pas dans <extensions>. Dans <extensions>, elles sont ignoreees
# silencieusement : le plugin se chargeait, mais l'action n'apparait dans
# AUCUN menu (constate sur la capture du menu Tools du 05/11 11:00).
#
# Cette passe : redemarre l'IDE avec le ZIP corrige, puis
#   1. ouvre Git > Show Git Log et saisit la chaine distinctive dans le
#      champ « Text or hash » -> le filtre natif ne doit rien remonter ;
#   2. ouvre le menu Tools et montre que l'action du plugin y est ;
#   3. lance l'action, saisit la chaine, clique Search -> le moteur doit
#      rendre les commits qui ajoutent / suppriment la chaine.
# =============================================================================
set -u
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(cd "$HERE/.." && pwd)"
PROOF="${1:-$ROOT/../preuves/cycle115/preuves}"
ZIP="$ROOT/build/distributions/FindinCommitHistory-0.0.1.zip"
IDE="${IDE:-$ROOT/../ide/pycharm-2026.2.4}"
CFG="$PROOF/idecfg"

export PATH="/work/tools/x11/extracted/usr/bin:$PATH"
export LD_LIBRARY_PATH="/work/tools/x11/extracted/usr/bin:/work/tools/x11/extracted/usr/lib/x86_64-linux-gnu:${LD_LIBRARY_PATH:-}"
export DISPLAY=:99
export XDG_RUNTIME_DIR=/tmp/runtime-agent
mkdir -p "$XDG_RUNTIME_DIR" && chmod 700 "$XDG_RUNTIME_DIR"

mkdir -p "$PROOF"
LOG="$PROOF/preuve-ide-pass4.log"
exec > >(tee "$LOG") 2>&1
log() { echo "[$(date -u '+%H:%M:%S')] $*"; }
shot() { local n="$1"; sleep 2; if import -window root "$PROOF/$n" 2>/dev/null && [ -s "$PROOF/$n" ]; then log "capture : $n"; else log "ECHEC capture : $n"; fi; }
click() { xdotool mousemove "$1" "$2" click 1; sleep 1; }

log "=== 4e passe — plugin.xml corrige — $(date -u '+%Y-%m-%dT%H:%M:%SZ') ==="

# --- redemarrage de l'IDE avec le ZIP corrige ---------------------------
log "--- arret de l'IDE ---"
pkill -f 'com[.]intellij[.]idea[.]Main' 2>/dev/null; sleep 4
pkill -9 -f 'com[.]intellij[.]idea[.]Main' 2>/dev/null; sleep 2
log "--- reinstallation du ZIP corrige ---"
rm -rf "$CFG/plugins"; mkdir -p "$CFG/plugins"
unzip -q -o "$ZIP" -d "$CFG/plugins"
log "plugin(s) : $(ls "$CFG/plugins")"
rm -f "$CFG/log/idea.log"

log "--- lancement ---"
cd "$IDE/bin" || exit 3
PYCHARM_VM_OPTIONS="$CFG/pycharm64.vmoptions" \
PYCHARM_PROPERTIES="$CFG/idea.properties" \
  setsid ./pycharm.sh "$ROOT/build/demo-project" > "$PROOF/ide_launch_pass4.log" 2>&1 &
for i in $(seq 1 60); do
    sleep 5
    if [ -f "$CFG/log/idea.log" ] && grep -q "Loaded custom plugins" "$CFG/log/idea.log" 2>/dev/null; then
        log "ligne 'Loaded custom plugins' trouvee a t+$((i*5))s"
        break
    fi
done
grep -h "Loaded custom plugins" "$CFG/log/idea.log" 2>/dev/null | tee -a "$LOG"
grep -h "Loaded custom plugins" "$CFG/log/idea.log" 2>/dev/null | head -1 > "$PROOF/ligne-chargement.txt"
sleep 50

WID=$(xdotool search --name "PyCharm" 2>/dev/null | tail -1)
[ -z "$WID" ] && { log "ERREUR : fenetre introuvable"; exit 4; }
xdotool windowactivate "$WID" 2>/dev/null
log "fenetre $WID"

# --- 1. le filtre natif « Text or hash » ---------------------------------
log "--- 1. Git > Show Git Log, puis le champ « Text or hash » ---"
click 688 115; sleep 4
click 747 474; sleep 20
shot "J1-25-panneau-git-log-avant-filtre.png"
click 790 796; sleep 3          # champ « Text or hash »
xdotool type --delay 90 "pi3rre-magique-7749"; sleep 8
shot "J1-26-filtre-git-log-chaine-distinctive.png"

# --- 2. le menu Tools doit contenir notre action ------------------------
log "--- 2. menu Tools ---"
click 645 115; sleep 4
shot "J1-27-menu-tools-avec-l-action.png"
xdotool key --clearmodifiers End; sleep 2
shot "J1-28-menu-tools-dernier-item-surligne.png"
xdotool key --clearmodifiers Return; sleep 12
shot "J1-29-dialogue-find-in-commit-history.png"

# --- 3. le moteur dans l'IDE --------------------------------------------
log "--- 3. saisie de la chaine et recherche ---"
xdotool type --delay 90 "pi3rre-magique-7749"; sleep 3
shot "J1-30-dialogue-chaine-saisiee.png"
xdotool key --clearmodifiers Return; sleep 18
shot "J1-31-resultats.png"

log "=== FIN 4e passe ==="
ls -la "$PROOF"/J1-2*.png "$PROOF"/J1-3*.png 2>/dev/null | sed 's/^/    /'
exit 0
