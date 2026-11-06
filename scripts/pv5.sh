#!/usr/bin/env bash
# =============================================================================
# pv5.sh — pilote l'IDE (PyCharm 2026.2.4) pour produire des captures
# MARKETPLACE propres, prises sur le ZIP FIGÉ livré.
#
# Pourquoi v5 (et pas v4) : au cycle 122, la passe v4 a donné des captures
# techniquement bonnes (1400x1000, rognées sur la fenêtre de l'IDE, code
# visible en arrière-plan) mais porte deux défauts visibles :
#   1. une bande ROUGE « IDE error occurred / See details and submit report »
#      en bas à droite -> inacceptable sur une page de vente ;
#   2. une bande JAUNE « No Python interpreter configured » en haut.
# (Vérifié : le log de l'IDE ne contient AUCUNE ligne ERROR/SEVERE et 0
#  trace de com.tgglabs.pickaxe -> ce n'est pas une erreur du plugin.)
#
# v5 corrige en RÉUTILISANT la config+système déjà indexés de v4 (démarrage
# rapide, pas de gel de l'UI de 15 s) et en NETTOYANT l'écran avant les
# captures (notifications + bandeaux).
#
# Sous-commandes :
#   start            démarre l'IDE (copie la config v4) et attend qu'il soit prêt
#   shot <nom>       capture de tout l'écran -> <PROV>/<nom>.png
#   click X Y        clic souris
#   move X Y         déplacement de la souris (sans clic)
#   key <touches>    frappe clavier (ex. "Escape", "Return", "ctrl+a")
#   type <texte>     saisie de texte
#   geom             géométrie de la fenêtre de l'IDE
#   crop <nom>       rogne <PROV>/<nom>.png sur la fenêtre de l'IDE
#   stop             arrête l'IDE
# =============================================================================
set -u
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(cd "$HERE/.." && pwd)"
IDE="${IDE:-/work/ide/pycharm-2026.2.4}"
PROV="${PROV:-/work/preuves/cycle122/preuves-v5}"
SRC_CFG="${SRC_CFG:-/work/preuves/cycle122/preuves-v4/idecfg}"
PROJ="${PROJ:-/work/projets/demo-entree-5k}"
ZIP="${ZIP:-$ROOT/build/distributions/FindinCommitHistory-0.0.1.zip}"
MD5_ATTENDU="${MD5_ATTENDU:-b5e1d00b93eec4883699f9ea6eaed649}"

export PATH="/work/tools/x11/extracted/usr/bin:$PATH"
export LD_LIBRARY_PATH="/work/tools/x11/extracted/usr/bin:/work/tools/x11/extracted/usr/lib/x86_64-linux-gnu:${LD_LIBRARY_PATH:-}"
export DISPLAY=:99
export XDG_RUNTIME_DIR=/tmp/runtime-agent
mkdir -p "$XDG_RUNTIME_DIR" && chmod 700 "$XDG_RUNTIME_DIR"

CMD="${1:-}"
shift || true

log() { echo "[$(date -u '+%H:%M:%S')] $*"; }
mem() { awk '/^anon /{a=$2}/^slab /{s=$2}END{print a+s}' /sys/fs/cgroup/memory.stat; }
clic() { xdotool mousemove "$1" "$2"; sleep 1; xdotool click 1; sleep 1; }

ide_window() {
    for w in $(xdotool search --onlyvisible --name "." 2>/dev/null); do
        nm=$(xdotool getwindowname "$w" 2>/dev/null)
        case "$nm" in
            demo-*) echo "$w"; return 0;;
        esac
    done
    return 1
}

case "$CMD" in
start)
    MD5_ZIP=$(md5sum "$ZIP" 2>/dev/null | cut -d' ' -f1)
    if [ "$MD5_ZIP" != "$MD5_ATTENDU" ]; then
        log "ECHEC : le ZIP n'est pas le ZIP FIGE ($MD5_ZIP) -> on ne filme rien"; exit 2
    fi
    log "ZIP OK : $MD5_ZIP"
    mkdir -p "$PROV"
    CFG="$PROV/idecfg"
    rm -rf "$CFG"
    mkdir -p "$CFG"
    log "copie de la config indexee de v4 (systeme deja indexe -> demarrage rapide)"
    cp -a "$SRC_CFG/config" "$CFG/config"
    cp -a "$SRC_CFG/system" "$CFG/system"
    mkdir -p "$CFG/log" "$CFG/plugins"
    # Interpreteur Python du projet de demonstration : sans lui, PyCharm affiche
    # un bandeau jaune « No Python interpreter configured » dans l'editeur, qui
    # n'a rien a voir avec le plugin (doc officielle : « Include only relevant
    # information »). Fichier ecrit a la main, l'IDE etant arrete.
    if [ -f "${JDKTABLE:-/work/preuves/cycle122/jdk.table.xml}" ]; then
        cp "${JDKTABLE:-/work/preuves/cycle122/jdk.table.xml}" "$CFG/config/options/jdk.table.xml"
        log "jdk.table.xml (interpreteur Python 3.11) copie"
    fi
    cp -a "$SRC_CFG/plugins/." "$CFG/plugins/" 2>/dev/null
    # 05/11/2026 20:30 : le ZIP LIVRE a ete RECONSTRUIT apres la revue du jury
    # (descripteur change : balise <postStartupActivity> retiree). On installe
    # donc LE ZIP ANNONCE dans le repertoire de plugins de l'IDE (il ecrase
    # l'ancienne version copiee depuis la config de reference).
    rm -rf "$CFG/plugins/FindinCommitHistory"
    unzip -q -o "$ZIP" -d "$CFG/plugins"
    log "plugin installe depuis le ZIP : $(find "$CFG/plugins" -name '*.jar' | sort | tr '\n' ' ')"
    cat > "$CFG/idea.properties" <<EOF
idea.config.path=$CFG/config
idea.system.path=$CFG/system
idea.log.path=$CFG/log
idea.plugins.path=$CFG/plugins
EOF
    cat > "$CFG/pycharm64.vmoptions" <<'EOF'
-Xms128m
-Xmx448m
-XX:ReservedCodeCacheSize=240m
-XX:+UseSerialGC
-XX:MaxMetaspaceSize=400m
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
    pkill -f 'com[.]intellij[.]idea[.]Main' 2>/dev/null; sleep 3
    cd "$IDE/bin" || exit 3
    PYCHARM_VM_OPTIONS="$CFG/pycharm64.vmoptions" \
    PYCHARM_PROPERTIES="$CFG/idea.properties" \
      setsid ./pycharm.sh "$PROJ" "$PROJ/src/app.py" > "$PROV/ide_launch.log" 2>&1 &
    log "lanceur PID $!"
    for i in $(seq 1 60); do
        sleep 5
        if [ -f "$CFG/log/idea.log" ] && grep -q "Loaded custom plugins" "$CFG/log/idea.log" 2>/dev/null; then
            log "plugin charge a t+$((i*5))s"; break
        fi
        NS=$(mem); [ "$NS" -gt 1300000000 ] && { log "GARDE-FOU memoire $NS"; exit 5; }
    done
    W=$(ide_window) || { log "ERREUR : fenetre IDE introuvable"; exit 4; }
    xdotool windowactivate "$W" 2>/dev/null
    log "fenetre IDE $W -> geometrie :"
    xdotool getwindowgeometry --shell "$W" | tee "$PROV/ide-geom.txt"
    log "on laisse l'IDE se calmer (40 s)"
    sleep 40
    log "memoire : $(mem) / 1572864000"
    log "pret"
    ;;
shot)
    N="${1:?nom}"
    sleep 2
    import -window root "$PROV/$N.png" && log "capture : $N.png ($(stat -c%s "$PROV/$N.png") o, $(identify -format '%wx%h' "$PROV/$N.png"), md5 $(md5sum "$PROV/$N.png" | cut -c1-8))"
    ;;
click) clic "$1" "$2"; log "clic ($1,$2)";;
move)  xdotool mousemove "$1" "$2"; sleep 1; log "souris en ($1,$2)";;
key)   xdotool key --clearmodifiers "$@"; sleep 1; log "touche : $*";;
type)  xdotool type --delay 60 "$*"; sleep 1; log "texte saisi : $*";;
geom)
    W=$(ide_window) && xdotool getwindowgeometry --shell "$W" | tee "$PROV/ide-geom.txt"
    ;;
crop)
    N="${1:?nom}"
    if [ -f "$PROV/ide-geom.txt" ]; then
        IX=$(awk -F= '/^X=/{print $2}' "$PROV/ide-geom.txt")
        IY=$(awk -F= '/^Y=/{print $2}' "$PROV/ide-geom.txt")
        IW=$(awk -F= '/^WIDTH=/{print $2}' "$PROV/ide-geom.txt")
        IH=$(awk -F= '/^HEIGHT=/{print $2}' "$PROV/ide-geom.txt")
        convert "$PROV/$N.png" -crop "${IW}x${IH}+${IX}+${IY}" +repage "$PROV/rogn-$N.png" \
            && log "rogn-$N.png ($(identify -format '%wx%h' "$PROV/rogn-$N.png"))"
    fi
    ;;
stop)
    pkill -f 'com[.]intellij[.]idea[.]Main' 2>/dev/null; sleep 3
    pkill -9 -f 'com[.]intellij[.]idea[.]Main' 2>/dev/null; sleep 1
    log "IDE arrete ; memoire : $(mem)"
    ;;
*) echo "usage: pv5.sh {start|shot|click|move|key|type|geom|crop|stop}"; exit 2;;
esac
