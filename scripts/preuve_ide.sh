#!/usr/bin/env bash
# =============================================================================
# preuve_ide.sh — PREUVE DANS LE VRAI IDE (PyCharm 2026.2.4).
#
# Deux objectifs (consigne du 05/11 08:35, §3 et §4) :
#   A. la ligne "Loaded custom plugins: ..." qui prouve que le plugin se
#      charge (et 0 erreur de ce plugin dans le log) ;
#   B. les captures J1 : la preuve qu'aucune fonction NATIVE de l'IDE ne
#      fait deja `git log -S` / `git log -G`.
#
# Le projet de test est un depot Git reel, avec une chaine distinctive
# ("pi3rre-magique-7749") ajoutee puis supprimee : le plugin doit la
# retrouver ; le panneau Git Log, lui, ne sait pas la chercher.
#
# AUCUNE publication, AUCUN jeton, 0 $.
# Code de sortie : 0 si la ligne de chargement est trouvee ET au moins une
# capture est prise, 1 sinon.
# =============================================================================
set -u

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(cd "$HERE/.." && pwd)"
IDE="${IDE:-/work/ide/pycharm-2026.2.4}"
ZIP="${1:-$ROOT/build/distributions/FindinCommitHistory-0.0.1.zip}"
PROOF="${2:-/work/preuves/cycle115/preuves}"
PROJ="$ROOT/build/demo-project"

export PATH="/work/tools/x11/extracted/usr/bin:$PATH"
export LD_LIBRARY_PATH="/work/tools/x11/extracted/usr/bin:/work/tools/x11/extracted/usr/lib/x86_64-linux-gnu:${LD_LIBRARY_PATH:-}"
export DISPLAY=:99
export XDG_RUNTIME_DIR=/tmp/runtime-agent
mkdir -p "$XDG_RUNTIME_DIR" && chmod 700 "$XDG_RUNTIME_DIR"

mkdir -p "$PROOF"
LOG="$PROOF/preuve-ide.log"
exec > >(tee "$LOG") 2>&1

log() { echo "[$(date -u '+%H:%M:%S')] $*"; }
shot() {
    local name="$1"
    sleep 2
    if import -window root "$PROOF/$name" 2>/dev/null && [ -s "$PROOF/$name" ]; then
        log "capture : $name ($(stat -c%s "$PROOF/$name") octets, $(identify -format '%wx%h' "$PROOF/$name" 2>/dev/null))"
    else
        log "ECHEC capture : $name"
    fi
}
mem() { awk '/^anon /{a=$2}/^slab /{s=$2}END{print a+s}' /sys/fs/cgroup/memory.stat; }

log "=== PREUVE IDE — $(date -u '+%Y-%m-%dT%H:%M:%SZ') ==="
log "IDE        : $IDE"
log "build IDE  : $(tr '\n' ' ' < "$IDE/build.txt" 2>/dev/null)"
log "ZIP plugin : $ZIP ($(stat -c%s "$ZIP" 2>/dev/null) octets)"
log "memoire    : anon+slab = $(mem) / 1572864000"

# ---------------------------------------------------------------- projet ----
log "=== 1. projet de test (depot Git reel) ==="
rm -rf "$PROJ"; mkdir -p "$PROJ"
cd "$PROJ" || exit 3
git init -q -b main .
git config user.email "demo@example.org"; git config user.name "Demo"
mkdir -p src
printf 'def main():\n    print("hello")\n' > src/app.py
printf 'TOKEN = "pi3rre-magique-7749"\nTIMEOUT = 30\n' > src/config.py
git add -A && git commit -q -m "feat: add the configuration file"
printf 'TOKEN = "pi3rre-magique-7749"  # noqa\nTIMEOUT = 30\n' > src/config.py
git add -A && git commit -q -m "style: annotate the token line"
printf 'TIMEOUT = 30\n' > src/config.py
git add -A && git commit -q -m "fix: remove the token line"
log "commits du projet de test : $(git log --oneline | wc -l)"
log "chaine distinctive : pi3rre-magique-7749"
cd "$ROOT" || exit 3

# ------------------------------------------------------------ installation --
CFG="$PROOF/idecfg"
log "=== 2. installation du plugin dans une config NEUVE ==="
rm -rf "$CFG"
mkdir -p "$CFG/config" "$CFG/system" "$CFG/log" "$CFG/plugins"
cat > "$CFG/idea.properties" <<EOF
idea.config.path=$CFG/config
idea.system.path=$CFG/system
idea.log.path=$CFG/log
idea.plugins.path=$CFG/plugins
EOF
cat > "$CFG/pycharm64.vmoptions" <<'EOF'
-Xms128m
-Xmx700m
-XX:ReservedCodeCacheSize=192m
-XX:+UseSerialGC
-XX:MaxMetaspaceSize=384m
-XX:MaxDirectMemorySize=64m
-XX:TieredStopAtLevel=1
-Djb.privacy.policy.text=<!--999.999-->
-Djb.consents.confirmation.enabled=false
-Dide.show.tips.on.startup=false
-Didea.trust.all.projects=true
-Didea.initially.ask.config=never
-Dide.newUi.tour.enabled=false
-Dide.newUi.first.time.experience=false
-Dide.is.internal=false
-Didea.suppress.statistics.report=true
EOF
unzip -q -o "$ZIP" -d "$CFG/plugins"
log "plugin(s) depose(s) : $(ls "$CFG/plugins")"
log "jar principal : $(find "$CFG/plugins" -name 'FindinCommitHistory-*.jar' | head -1)"

# ------------------------------------------------------------- lancement ----
log "=== 3. lancement de PyCharm sur :99 (projet ouvert) ==="
pkill -f 'com[.]intellij[.]idea[.]Main' 2>/dev/null; sleep 3
cd "$IDE/bin" || exit 3
PYCHARM_VM_OPTIONS="$CFG/pycharm64.vmoptions" \
PYCHARM_PROPERTIES="$CFG/idea.properties" \
  setsid ./pycharm.sh "$PROJ" > "$PROOF/ide_launch.log" 2>&1 &
log "lanceur PID $!"

IDELOG=""
for i in $(seq 1 48); do
    sleep 5
    if [ -f "$CFG/log/idea.log" ] && grep -q "Loaded custom plugins" "$CFG/log/idea.log" 2>/dev/null; then
        IDELOG="$CFG/log/idea.log"
        log "ligne 'Loaded custom plugins' trouvee a t+$((i*5))s"
        break
    fi
    NS=$(mem)
    if [ "$NS" -gt 1350000000 ]; then
        log "GARDE-FOU : anon+slab = $NS > 1 350 000 000 -> arret de l'IDE"
        break
    fi
done
[ -z "$IDELOG" ] && IDELOG=$(ls -t "$CFG/log"/idea.log 2>/dev/null | head -1)

STATUS=0
log "=== 4. LIGNE DE CHARGEMENT (verbatim) ==="
if [ -n "${IDELOG:-}" ] && [ -f "$IDELOG" ]; then
    grep -h "Loaded custom plugins" "$IDELOG" | tee -a "$LOG"
    grep -h "Loaded custom plugins" "$IDELOG" | head -1 > "$PROOF/ligne-chargement.txt"
    if grep -h "Loaded custom plugins" "$IDELOG" | head -1 | grep -q "Find in Commit History"; then
        log "OK : le plugin 'Find in Commit History' est dans la ligne de chargement"
    else
        log "ECHEC : le plugin n'est pas dans la ligne de chargement"
        STATUS=1
    fi
    log "--- erreurs concernant ce plugin ? ---"
    ERR=$(grep -i -E "error|exception|incompatible|not compatible|not found|cannot|Could not" "$IDELOG" 2>/dev/null \
          | grep -i -E "tgglabs|pickaxe|Find in Commit History" | head -15)
    if [ -n "$ERR" ]; then
        log "ATTENTION — lignes d'erreur :"; printf '%s\n' "$ERR" | tee -a "$LOG"; STATUS=1
    else
        log "OK : 0 erreur concernant com.tgglabs.pickaxe dans le log"
    fi
    grep -iE "plugin.*pickaxe|pickaxe.*plugin" "$IDELOG" | head -10 | sed 's/^/    /'
else
    log "ERREUR : pas de idea.log -> l'IDE n'a pas demarre"
    tail -30 "$PROOF/ide_launch.log" 2>/dev/null
    exit 4
fi

# ----------------------------------------------------------- captures J1 ----
log "=== 5. CAPTURES J1 ==="
# On laisse l'IDE finir de s'ouvrir (indexation, projet ouvert).
sleep 45
WID=$(xdotool search --name "PyCharm" 2>/dev/null | tail -1)
if [ -n "$WID" ]; then
    xdotool windowactivate "$WID" 2>/dev/null
    log "fenetre PyCharm active (id $WID)"
else
    log "ATTENTION : fenetre PyCharm introuvable pour xdotool"
fi
shot "J1-00-ide-au-demarrage.png"

# --- Piste A : le filtre du panneau Git Log -------------------------------
# Ouverture par le menu Git (clic), puis capture du champ de filtre.
log "--- Piste A : panneau Git Log + champ de filtre ---"
xdotool key --clearmodifiers ctrl+shift+a 2>/dev/null; sleep 4
xdotool type --delay 60 "Show Git Log" 2>/dev/null; sleep 4
shot "J1-01-find-action-show-git-log.png"
xdotool key --clearmodifiers Return 2>/dev/null; sleep 8
shot "J1-02-panneau-git-log.png"

# --- Piste B : "Show History for Selection" --------------------------------
log "--- Piste B : Show History for Selection ---"
xdotool key --clearmodifiers ctrl+shift+a 2>/dev/null; sleep 4
xdotool type --delay 60 "Show History for Selection" 2>/dev/null; sleep 4
shot "J1-03-find-action-show-history-for-selection.png"
xdotool key --clearmodifiers Escape 2>/dev/null; sleep 3

# --- Piste C : notre action ----------------------------------------------
log "--- Piste C : l'action du plugin ---"
xdotool key --clearmodifiers ctrl+shift+a 2>/dev/null; sleep 4
xdotool type --delay 60 "Find in Commit History" 2>/dev/null; sleep 4
shot "J1-04-find-action-notre-plugin.png"
xdotool key --clearmodifiers Return 2>/dev/null; sleep 10
shot "J1-05-dialogue-find-in-commit-history.png"
# On saisit la chaine distinctive et on lance la recherche.
xdotool type --delay 80 "pi3rre-magique-7749" 2>/dev/null; sleep 2
shot "J1-06-dialogue-chaine-saisiee.png"
xdotool key --clearmodifiers Return 2>/dev/null; sleep 12
shot "J1-07-resultats.png"

# --- Piste D : le filtre du Git Log, texte de recherche -------------------
log "--- Piste D : le filtre du Git Log ne sait pas chercher une chaine ---"
xdotool key --clearmodifiers Escape 2>/dev/null; sleep 2
xdotool key --clearmodifiers ctrl+shift+a 2>/dev/null; sleep 4
xdotool type --delay 60 "Show Git Log" 2>/dev/null; sleep 3
xdotool key --clearmodifiers Return 2>/dev/null; sleep 8
xdotool key --clearmodifiers ctrl+f 2>/dev/null; sleep 2
xdotool type --delay 80 "pi3rre-magique-7749" 2>/dev/null; sleep 5
shot "J1-08-filtre-git-log-avec-la-chaine.png"

# --- Piste E : GitToolBox -------------------------------------------------
log "--- Piste E : GitToolBox est-il installe ? ---"
xdotool key --clearmodifiers ctrl+shift+a 2>/dev/null; sleep 4
xdotool type --delay 60 "GitToolBox" 2>/dev/null; sleep 4
shot "J1-09-find-action-gittoolbox.png"

log "=== 6. etat final ==="
log "memoire : anon+slab = $(mem) / 1572864000"
ls -la "$PROOF"/*.png 2>/dev/null | sed 's/^/    /'
NBCAPT=$(ls "$PROOF"/*.png 2>/dev/null | wc -l)
log "captures prises : $NBCAPT"
[ "$NBCAPT" -ge 3 ] || { log "ECHEC : pas assez de captures"; STATUS=1; }

log "=== 7. arret de l'IDE ==="
pkill -f 'com[.]intellij[.]idea[.]Main' 2>/dev/null; sleep 3
pkill -9 -f 'com[.]intellij[.]idea[.]Main' 2>/dev/null; sleep 1
log "memoire apres arret : anon+slab = $(mem) / 1572864000"

log "FIN preuve_ide.sh statut=$STATUS"
exit $STATUS
