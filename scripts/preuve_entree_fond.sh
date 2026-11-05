#!/usr/bin/env bash
# =============================================================================
# preuve_entree_fond.sh — PREUVE DANS LE VRAI IDE (PyCharm 2026.2.4) que
#
#   D2 : la touche ENTREE lance la recherche (et n'est plus un no-op) ;
#   D1 : la recherche ne BLOQUE PAS l'IDE (elle est faite sur un thread de
#        fond, avec une progression visible).
#
# Le script pilote l'IDE par X11 (xdotool + import) :
#   1. il construit un depot de test avec un historique LONG (la recherche
#      dure plusieurs secondes : c'est ce qui rend la preuve D1 possible) ;
#   2. il installe le ZIP LIVRE dans une config NEUVE ;
#   3. il ouvre l'action par le MENU Tools (pas par la palette « Find
#      Action », qui a planté le 05/11 15:44 dans l'IDE lui-meme) ;
#   4. il saisit la chaine, puis il appuie sur ENTREE (pas de clic sur le
#      bouton « Search ») ;
#   5. pendant la recherche, il clique dans un autre champ du dialogue et il
#      y ecrit : si l'EDT etait bloque par la recherche, cette saisie
#      n'apparaitrait qu'a la fin. Elle apparait -> l'EDT etait libre ;
#   6. il capture le resultat affiche par le plugin.
#
# AUCUNE publication, AUCUN jeton, 0 $.
# Code de sortie : 0 si le resultat est affiche ET que le dialogue a bien ete
# ouvert, 1 sinon.
# =============================================================================
set -u

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(cd "$HERE/.." && pwd)"
IDE="${IDE:-/work/ide/pycharm-2026.2.4}"
ZIP="${1:-$ROOT/build/distributions/FindinCommitHistory-0.0.1.zip}"
PROOF="${2:-/work/preuves/cycle119/preuves}"
# Le projet de demonstration est HORS de /work/pickaxe : le pre-vol officiel
# scanne ce dossier et ne doit y trouver qu'UN plugin.xml.
PROJ="${PROJ:-/work/projets/demo-entree}"
NCOMMITS="${NCOMMITS:-1200}"

export PATH="/work/tools/x11/extracted/usr/bin:$PATH"
export LD_LIBRARY_PATH="/work/tools/x11/extracted/usr/bin:/work/tools/x11/extracted/usr/lib/x86_64-linux-gnu:${LD_LIBRARY_PATH:-}"
export DISPLAY=:99
export XDG_RUNTIME_DIR=/tmp/runtime-agent
mkdir -p "$XDG_RUNTIME_DIR" && chmod 700 "$XDG_RUNTIME_DIR"

mkdir -p "$PROOF"
LOG="$PROOF/preuve-entree-fond.log"
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
click() { xdotool mousemove "$1" "$2" click 1; sleep 1; }
mem() { awk '/^anon /{a=$2}/^slab /{s=$2}END{print a+s}' /sys/fs/cgroup/memory.stat; }

log "=== PREUVE ENTREE + FOND — $(date -u '+%Y-%m-%dT%H:%M:%SZ') ==="
log "IDE        : $IDE"
log "ZIP plugin : $ZIP ($(stat -c%s "$ZIP" 2>/dev/null) octets, md5 $(md5sum "$ZIP" 2>/dev/null | cut -d' ' -f1))"
log "memoire    : anon+slab = $(mem) / 1572864000"

# ---------------------------------------------------------------- projet ----
log "=== 1. depot de test (historique long : la recherche doit durer) ==="
if [ -d "$PROJ/.git" ] && [ "${RECREATE_REPO:-0}" != "1" ]; then
    log "depot de test deja present : $(git -C "$PROJ" log --oneline | wc -l) commits (on ne le recree pas)"
else
rm -rf "$PROJ"; mkdir -p "$PROJ"
python3 - "$NCOMMITS" <<'PY' > "$PROJ/stream.fi"
import sys
n = int(sys.argv[1])
out = []
mark = 0

def blob(content):
    global mark
    mark += 1
    out.append(b"blob\nmark :%d\ndata %d\n" % (mark, len(content)))
    out.append(content)
    out.append(b"\n")
    return mark

def commit(content, message):
    global mark
    b = blob(content)
    mark += 1
    m = message.encode()
    out.append(b"commit refs/heads/main\nmark :%d\n" % mark)
    out.append(b"committer Test <test@example.org> 1700000000 +0000\n")
    out.append(b"data %d\n" % len(m))
    out.append(m)
    out.append(b"\n")
    out.append(b"M 100644 :%d src/app.py\n" % b)

# 1. la chaine distinctive est introduite
commit(b'TOKEN = "pi3rre-magique-7749"\nTIMEOUT = 30\n', "feat: add the configuration file")
# 2. elle est supprimee
commit(b'TIMEOUT = 30\n', "fix: remove the token line")
# 3. un historique long : la recherche met plusieurs secondes
for i in range(n):
    commit(("TIMEOUT = 30\nligne %d\n" % i).encode(), "chore: filler commit %d" % i)
sys.stdout.buffer.write(b"".join(out))
PY
cd "$PROJ" || exit 3
git init -q -b main .
git config user.email "demo@example.org"; git config user.name "Demo"
git fast-import --quiet < "$PROJ/stream.fi" 2>&1 | tail -3
rm -f "$PROJ/stream.fi"
git reset -q --hard main
log "commits du projet de test : $(git log --oneline | wc -l)"
log "chaine distinctive : pi3rre-magique-7749"
cd "$ROOT" || exit 3
fi

# ------------------------------------------------------------ installation --
CFG="$PROOF/idecfg"
log "=== 2. installation du plugin dans la config de l'IDE ==="
# La config est CONSERVEE entre les essais : c'est elle qui memorise que les
# fenetres d'accueil de l'IDE (« Meet the Islands Theme », « Tool Window
# Names ») ont ete fermees. Les rafraichir a chaque essai ferait apparaitre
# une fenetre MODALE au milieu de l'IDE, qui intercepterait les clics.
if [ -f "$CFG/log/idea.log" ]; then
    mv -f "$CFG/log/idea.log" "$CFG/log/idea.log.prev" 2>/dev/null
fi
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

# ------------------------------------------------------------- lancement ----
log "=== 3. lancement de PyCharm sur :99 (projet ouvert) ==="
pkill -f 'com[.]intellij[.]idea[.]Main' 2>/dev/null; sleep 3
cd "$IDE/bin" || exit 3
PYCHARM_VM_OPTIONS="$CFG/pycharm64.vmoptions" \
PYCHARM_PROPERTIES="$CFG/idea.properties" \
  setsid ./pycharm.sh "$PROJ" > "$PROOF/ide_launch.log" 2>&1 &
log "lanceur PID $!"

IDELOG=""
for i in $(seq 1 60); do
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
    grep -h "Loaded custom plugins" "$IDELOG" | head -1 | grep -q "Find in Commit History" \
        || { log "ECHEC : le plugin n'est pas dans la ligne de chargement"; STATUS=1; }
    ERR=$(grep -i -E "error|exception|incompatible|not compatible|not found|cannot|Could not" "$IDELOG" 2>/dev/null \
          | grep -i -E "tgglabs|pickaxe|Find in Commit History" | head -15)
    if [ -n "$ERR" ]; then
        log "ATTENTION — lignes d'erreur :"; printf '%s\n' "$ERR" | tee -a "$LOG"; STATUS=1
    else
        log "OK : 0 erreur concernant com.tgglabs.pickaxe dans le log"
    fi
else
    log "ERREUR : pas de idea.log -> l'IDE n'a pas demarre"
    tail -30 "$PROOF/ide_launch.log" 2>/dev/null
    exit 4
fi

# ------------------------------------------------------------- la preuve ----
log "=== 5. ATTENTE QUE LE PROJET SOIT REELLEMENT OUVERT ==="
# Au cycle 118 la manipulation a ete tentee alors que l'IDE finissait
# seulement d'importer le projet : le clic est tombe dans le vide. On attend
# donc que la racine du projet soit montee dans le modele, puis que
# l'indexation se calme.
for i in $(seq 1 60); do
    sleep 5
    if grep -q "Add project root" "$CFG/log/idea.log" 2>/dev/null; then
        log "racine du project montee a t+$((i*5))s"
        break
    fi
    NS=$(mem)
    if [ "$NS" -gt 1350000000 ]; then
        log "GARDE-FOU : anon+slab = $NS > 1 350 000 000 -> arret de l'IDE"
        exit 5
    fi
done
log "on laisse l'IDE finir son indexation (45 s)"
sleep 45

# Filet de securite : si une fenetre d'accueil de l'IDE est encore ouverte
# (elle est MODALE et intercepte tous les clics), on la ferme.
log "=== 5b. verification : aucune fenetre d'accueil ne doit rester ouverte ==="
for i in $(seq 1 12); do
    for w in $(xdotool search --name "Islands" 2>/dev/null); do
        G=$(xdotool getwindowgeometry --shell "$w")
        WX=$(echo "$G" | awk -F= '/^X=/{print $2}'); WY=$(echo "$G" | awk -F= '/^Y=/{print $2}')
        WW=$(echo "$G" | awk -F= '/^WIDTH=/{print $2}'); WH=$(echo "$G" | awk -F= '/^HEIGHT=/{print $2}')
        SX=$((WX + WW*57/100)); SY=$((WY + WH*91/100))
        log "fenetre modale 'Islands' (id $w) : clic sur « Skip » en ($SX, $SY)"
        xdotool mousemove "$SX" "$SY"; sleep 1.5; xdotool click 1; sleep 2
    done
    sleep 2
done

log "=== 6. OUVERTURE DE L'ACTION PAR LE MENU Tools ==="
WID=$(xdotool search --name "PyCharm" 2>/dev/null | tail -1)
if [ -n "$WID" ]; then
    xdotool windowactivate "$WID" 2>/dev/null
    log "fenetre PyCharm active (id $WID)"
else
    log "ATTENTION : fenetre PyCharm introuvable pour xdotool"
fi
sleep 3
click 647 115          # menu « Tools »
shot "D2-00-menu-tools.png"
click 716 419          # item « Find in Commit History… » (dernier item du menu)
sleep 3

# Si le clic n'a pas ouvert le dialogue (IDE pas encore pret), on recommence
# au clavier : le menu Tools se termine par « Find in Commit History… ».
DIALOG=""
for i in $(seq 1 15); do
    DIALOG=$(xdotool search --name "Find in Commit History" 2>/dev/null | tail -1)
    [ -n "$DIALOG" ] && break
    sleep 2
done
if [ -z "$DIALOG" ]; then
    log "le clic n'a pas ouvert le dialogue -> nouvelle tentative au CLAVIER"
    click 647 115
    sleep 2
    xdotool key --clearmodifiers End 2>/dev/null; sleep 1
    shot "D2-00b-menu-tools-clavier.png"
    xdotool key --clearmodifiers Return 2>/dev/null
    for i in $(seq 1 15); do
        DIALOG=$(xdotool search --name "Find in Commit History" 2>/dev/null | tail -1)
        [ -n "$DIALOG" ] && break
        sleep 2
    done
fi
if [ -n "$DIALOG" ]; then
    log "dialogue ouvert (fenetre X id $DIALOG)"
    xdotool getwindowgeometry --shell "$DIALOG" | tee "$PROOF/dialog-geom.txt"
else
    log "ECHEC : le dialogue ne s'est pas ouvert"
    STATUS=1
fi
shot "D2-01-dialogue-ouvert.png"

log "=== 7. PHASE 1 TERMINEE — l'IDE reste vivant pour la phase 2 ==="
cat > "$PROOF/phase1.env" <<EOF
CFG=$CFG
PROJ=$PROJ
DIALOG=$DIALOG
PROOF=$PROOF
EOF
log "memoire : anon+slab = $(mem) / 1572864000"
log "FIN phase 1 (preuve_entree_fond.sh) statut=$STATUS"
exit $STATUS
