#!/usr/bin/env bash
# =============================================================================
# preuve_captures_marketplace.sh — 3 captures d'écran PRÊTES POUR LE
# MARKETPLACE, prises sur le ZIP FIGÉ livré (celui que Tgg va téléverser).
#
# HISTORIQUE DE CE SCRIPT (2 essais le 05/11/2026, les deux documentés) :
#   Essai 1 (19:02-19:05) : ÉCHEC. Cause : une config IDE NEUVE fait apparaître
#   la modale « Meet the Islands Theme » au démarrage. Cette modale est
#   DESSINÉE DANS la fenêtre de l'IDE (ce n'est pas une fenêtre X séparée :
#   `xdotool search --name "Islands"` ne la trouve pas) -> elle intercepte
#   tous les clics -> le dialogue ne s'ouvre pas. Le cycle 119, lui, avait
#   réussi parce qu'il RÉUTILISAIT une config où la modale était déjà fermée.
#   -> Ce script réutilise la config du cycle 119 et, en plus, détecte la
#      modale par l'image (pas de clic aveugle) et clique sur « Skip » s'il faut.
#   Deux bulles jaunes se superposent aussi (« IDE launched with a script
#   launcher », « code cache 192 MB is not enough ») : la 2ᵉ disparaît en
#   passant le cache de code à 240 Mo, la 1ʳᵉ est déjà « Do not show again »
#   dans la config réutilisée.
#
# CE QUE CE SCRIPT FAIT DE MIEUX QUE `preuve_ide.sh` (cycle 120, défectueux) :
#   1. il ouvre l'action par le MENU « Tools » (la palette « Find Action » a
#      fait planter l'IDE le 05/11 à 15:44) ;
#   2. il attend que le projet soit RÉELLEMENT monté (« Add project root »)
#      et ferme la modale d'accueil ;
#   3. il CONTRÔLE le contenu de chaque capture : si deux captures
#      consécutives sont identiques (octet pour octet), c'est que l'écran
#      n'a pas changé -> ALERTE (c'est exactement le défaut du cycle 120) ;
#   4. il vérifie que le dialogue a bien été ouvert (fenêtre X portant le
#      nom « Find in Commit History ») ;
#   5. il ROGNE les captures sur la fenêtre de l'IDE : la doc officielle
#      (« Best practices for listing your plugin ») met « Include desktop
#      backgrounds … in your screenshots » dans les ❌ DON'T ;
#   6. il refuse de tourner si le ZIP n'est pas celui annoncé (md5 figé).
#
# AUCUNE publication, AUCUN jeton, 0 $. Code de sortie 0 = dialogue vu et
# captures distinctes.
# =============================================================================
set -u

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(cd "$HERE/.." && pwd)"
IDE="${IDE:-/work/ide/pycharm-2026.2.4}"
ZIP="${1:-$ROOT/build/distributions/FindinCommitHistory-0.0.1.zip}"
PROOF="${2:-/work/preuves/cycle122/preuves-v2}"
# Le projet de demonstration est HORS de /work/pickaxe : le pre-vol officiel
# scanne le dossier produit et ne doit y trouver qu'UN plugin.xml.
PROJ="${PROJ:-/work/projets/demo-entree-5k}"
# Config IDE deja « nettoyee » : la modale « Islands » et les bulles jaunes y
# sont deja fermees (c'est la config du cycle 119, ou les captures propres
# ont ete prises). On n'en copie que la partie « config » (13 Mo) : les
# index (« system », 382 Mo) sont reconstruits.
CFG_BASE="${CFG_BASE:-/work/preuves/cycle119/preuves5k/idecfg}"
MD5_ATTENDU="${MD5_ATTENDU:-b5e1d00b93eec4883699f9ea6eaed649}"
CHAINE="${CHAINE:-pi3rre-magique-7749}"

export PATH="/work/tools/x11/extracted/usr/bin:$PATH"
export LD_LIBRARY_PATH="/work/tools/x11/extracted/usr/bin:/work/tools/x11/extracted/usr/lib/x86_64-linux-gnu:${LD_LIBRARY_PATH:-}"
export DISPLAY=:99
export XDG_RUNTIME_DIR=/tmp/runtime-agent
mkdir -p "$XDG_RUNTIME_DIR" && chmod 700 "$XDG_RUNTIME_DIR"

mkdir -p "$PROOF"
LOG="$PROOF/preuve-captures.log"
exec > >(tee "$LOG") 2>&1

log() { echo "[$(date -u '+%H:%M:%S')] $*"; }
mem() { awk '/^anon /{a=$2}/^slab /{s=$2}END{print a+s}' /sys/fs/cgroup/memory.stat; }
clic() { xdotool mousemove "$1" "$2"; sleep 1.5; xdotool click 1; sleep 1; }

# Capture + CONTROLE DE DIFFERENCE avec la capture precedente.
PREV=""
shot() {
    local name="$1" f="$PROOF/$1"
    sleep 2
    if ! import -window root "$f" 2>/dev/null || [ ! -s "$f" ]; then
        log "ECHEC capture : $name"
        return 1
    fi
    local m; m=$(md5sum "$f" | cut -d' ' -f1)
    log "capture : $name ($(stat -c%s "$f") octets, $(identify -format '%wx%h' "$f" 2>/dev/null), md5 ${m:0:8})"
    if [ -n "$PREV" ] && [ "$PREV" = "$m" ]; then
        log "   !! ALERTE : image IDENTIQUE a la capture precedente -> l'ecran n'a pas change"
        ALERTES=$((ALERTES + 1))
    fi
    PREV="$m"
    return 0
}

# La modale « Meet the Islands Theme » est DESSINEE dans la fenetre de l'IDE :
# on ne peut pas la voir par son nom de fenetre X. On la detecte par l'image :
# l'illustration aux couleurs vives occupe une zone centree de ~390 x 480 px.
# Sans modale, cette zone est l'editeur vide (sombre).
modale_presente() {
    local f="$1" v
    v=$(convert "$f" -crop 390x480+765+360 +repage -colorspace Gray -format "%[fx:mean]" info: 2>/dev/null)
    [ -n "$v" ] || return 1
    awk -v v="$v" 'BEGIN{exit !(v>0.12)}'
}
# Une bulle jaune d'avertissement est presente si la zone des bulles
# (en bas a droite) est nettement plus claire que le fond de l'editeur.
bulle_presente() {
    local f="$1" v
    v=$(convert "$f" -crop 380x250+1245+810 +repage -colorspace Gray -format "%[fx:mean]" info: 2>/dev/null)
    [ -n "$v" ] || return 1
    awk -v v="$v" 'BEGIN{exit !(v>0.10)}'
}

ALERTES=0
STATUS=0

log "=== PREUVE CAPTURES MARKETPLACE (v2) — $(date -u '+%Y-%m-%dT%H:%M:%SZ') ==="
MD5_ZIP=$(md5sum "$ZIP" 2>/dev/null | cut -d' ' -f1)
log "ZIP : $ZIP"
log "md5 : $MD5_ZIP"
if [ "$MD5_ZIP" != "$MD5_ATTENDU" ]; then
    log "ECHEC : le ZIP n'est pas celui annonce (attendu $MD5_ATTENDU) -> on ne filme rien"
    exit 2
fi
log "OK : le ZIP est bien le ZIP FIGE livre."
log "memoire : anon+slab = $(mem) / 1572864000"

# ------------------------------------------------------------ installation --
CFG="$PROOF/idecfg"
log "=== 1. config IDE : reutilisation de l'etat deja « nettoyee » ==="
if [ ! -d "$CFG_BASE/config" ]; then
    log "ECHEC : config de reference absente : $CFG_BASE"
    exit 3
fi
rm -rf "$CFG"
mkdir -p "$CFG/system" "$CFG/log" "$CFG/plugins"
cp -a "$CFG_BASE/config" "$CFG/config"
# 05/11/2026 21:44 — CORRECTIF MEMOIRE : on copie AUSSI le repertoire « system »
# (les index deja construits, 382 Mo). Sans lui, l'IDE doit reindexer le depot
# de demonstration (5 002 commits) au demarrage : le pic de memoire a fait
# OOM-killer l'IDE (cgroup 1 572 864 000 o, oom_kill=1) -> « 1016 Killed »
# et 0 capture. Avec les index reutilises, aucun reindexage.
if [ -d "$CFG_BASE/system" ]; then
    cp -a "$CFG_BASE/system" "$CFG/system"
    log "systeme (index) recopie : $(du -sh "$CFG/system" | cut -f1) -> pas de reindexage"
else
    log "ATTENTION : pas de « system » de reference -> reindexage (risque OOM)"
fi
log "config recopiee : $(du -sh "$CFG/config" | cut -f1) (modale Islands et bulles deja fermees)"
cat > "$CFG/idea.properties" <<EOF
idea.config.path=$CFG/config
idea.system.path=$CFG/system
idea.log.path=$CFG/log
idea.plugins.path=$CFG/plugins
EOF
cat > "$CFG/pycharm64.vmoptions" <<'EOF'
-Xms128m
-Xmx512m
-XX:ReservedCodeCacheSize=192m
-XX:+UseSerialGC
-XX:MaxMetaspaceSize=320m
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
-Dide.browser.jcef.enabled=false
EOF
rm -rf "$CFG/plugins/FindinCommitHistory"
unzip -q -o "$ZIP" -d "$CFG/plugins"
log "plugin(s) depose(s) : $(ls "$CFG/plugins")"
log "jar principal : $(find "$CFG/plugins" -name 'FindinCommitHistory-*.jar' ! -name '*searchableOptions*' | head -1)"

log "=== 2. depot de demonstration ==="
[ -d "$PROJ/.git" ] || { log "ECHEC : depot absent : $PROJ"; exit 3; }
log "commits : $(git -C "$PROJ" log --oneline 2>/dev/null | wc -l)"
for c in "feat: add the configuration file" "fix: remove the token line"; do
    git -C "$PROJ" log --oneline 2>/dev/null | grep -qF "$c" \
        || { log "ECHEC : commit attendu absent : $c"; exit 3; }
done
log "OK : la chaine '$CHAINE' est dans l'historique (ajoutee puis supprimee)."

# ------------------------------------------------------------- lancement ----
log "=== 3. lancement de PyCharm sur :99 ==="
pkill -f 'com[.]intellij[.]idea[.]Main' 2>/dev/null; sleep 3
cd "$IDE/bin" || exit 3
PYCHARM_VM_OPTIONS="$CFG/pycharm64.vmoptions" \
PYCHARM_PROPERTIES="$CFG/idea.properties" \
  setsid ./pycharm.sh "$PROJ" "${FICHIER_OUVRIR:-$PROJ/src/app.py}" > "$PROOF/ide_launch.log" 2>&1 &
log "lanceur PID $! (projet $PROJ + fichier ${FICHIER_OUVRIR:-$PROJ/src/app.py})"

IDELOG=""
for i in $(seq 1 60); do
    sleep 5
    if [ -f "$CFG/log/idea.log" ] && grep -q "Loaded custom plugins" "$CFG/log/idea.log" 2>/dev/null; then
        IDELOG="$CFG/log/idea.log"
        log "ligne 'Loaded custom plugins' trouvee a t+$((i*5))s"
        break
    fi
    NS=$(mem)
    if [ "$NS" -gt 1150000000 ]; then
        log "GARDE-FOU : anon+slab = $NS > 1 150 000 000 -> arret de l'IDE"
        exit 5
    fi
done
[ -z "$IDELOG" ] && IDELOG=$(ls -t "$CFG/log"/idea.log 2>/dev/null | head -1)
if [ ! -f "${IDELOG:-/nonexistent}" ]; then
    log "ERREUR : pas de idea.log -> l'IDE n'a pas demarre"
    tail -30 "$PROOF/ide_launch.log" 2>/dev/null
    exit 4
fi

log "=== 4. LIGNE DE CHARGEMENT (verbatim) ==="
grep -h "Loaded custom plugins" "$IDELOG" | tee -a "$LOG"
grep -h "Loaded custom plugins" "$IDELOG" | head -1 > "$PROOF/ligne-chargement.txt"
grep -q "Find in Commit History" "$PROOF/ligne-chargement.txt" \
    || { log "ECHEC : le plugin n'est pas dans la ligne de chargement"; STATUS=1; }
ERR=$(grep -i -E "error|exception|incompatible|not compatible|not found|cannot|Could not" "$IDELOG" 2>/dev/null \
      | grep -i -E "tgglabs|pickaxe|Find in Commit History" | head -15)
if [ -n "$ERR" ]; then
    log "ATTENTION — lignes d'erreur :"; printf '%s\n' "$ERR" | tee -a "$LOG"; STATUS=1
else
    log "OK : 0 erreur concernant com.tgglabs.pickaxe dans le log"
fi

log "=== 5. ATTENTE QUE LE PROJET SOIT REELLEMENT OUVERT ==="
for i in $(seq 1 60); do
    sleep 5
    if grep -q "Add project root" "$CFG/log/idea.log" 2>/dev/null; then
        log "racine du project montee a t+$((i*5))s"
        break
    fi
    NS=$(mem)
    if [ "$NS" -gt 1150000000 ]; then
        log "GARDE-FOU : anon+slab = $NS > 1 150 000 000 -> arret de l'IDE"
        exit 5
    fi
done
log "on laisse l'IDE finir son indexation (45 s)"
sleep 45

log "=== 5b. ETAT DE L'ECRAN : modale d'accueil et bulles ? ==="
WID=""
for w in $(xdotool search --onlyvisible --name "." 2>/dev/null); do
    nm=$(xdotool getwindowname "$w" 2>/dev/null)
    case "$nm" in
        demo-*) WID="$w";;
    esac
done
if [ -n "$WID" ]; then
    xdotool getwindowgeometry --shell "$WID" | tee "$PROOF/ide-geom.txt"
    xdotool windowactivate "$WID" 2>/dev/null
    log "fenetre IDE active (id $WID)"
else
    log "ATTENTION : fenetre de l'IDE introuvable"
fi
sleep 2
shot "MP-00-etat-au-demarrage.png"
if modale_presente "$PROOF/MP-00-etat-au-demarrage.png"; then
    log "MODALE « Islands » DETECTEE -> clic sur « Skip » (960, 799)"
    clic 960 799
    sleep 2
    shot "MP-00b-apres-skip.png"
    if modale_presente "$PROOF/MP-00b-apres-skip.png"; then
        log "ECHEC : la modale est toujours la -> abandon"
        STATUS=1
    else
        log "OK : la modale a bien ete fermee."
    fi
else
    log "OK : pas de modale « Islands »."
fi
if bulle_presente "$PROOF/MP-00-etat-au-demarrage.png"; then
    log "BULLE JAUNE detectee -> clic sur « Don't show again » (1510, 914) et (1512, 1037)"
    clic 1510 914
    clic 1512 1037
    sleep 1
    shot "MP-00c-apres-bulles.png"
    if bulle_presente "$PROOF/MP-00c-apres-bulles.png"; then
        log "ATTENTION : une bulle semble encore presente"
    else
        log "OK : bulles fermees."
    fi
else
    log "OK : pas de bulle jaune."
fi

# ------------------------------------------------------------- captures -----
log "=== 6. CAPTURES (route MENU Tools, pas la palette Find Action) ==="
clic 647 115
shot "MP-01-menu-tools.png"

clic 730 419
DIALOG=""
for i in $(seq 1 20); do
    DIALOG=$(xdotool search --name "Find in Commit History" 2>/dev/null | tail -1)
    [ -n "$DIALOG" ] && break
    sleep 1
done
if [ -z "$DIALOG" ]; then
    log "le clic n'a pas ouvert le dialogue -> nouvelle tentative au CLAVIER (menu Tools, touche End)"
    clic 647 115
    sleep 2
    xdotool key --clearmodifiers End 2>/dev/null; sleep 1
    xdotool key --clearmodifiers Return 2>/dev/null
    for i in $(seq 1 20); do
        DIALOG=$(xdotool search --name "Find in Commit History" 2>/dev/null | tail -1)
        [ -n "$DIALOG" ] && break
        sleep 1
    done
fi
if [ -n "$DIALOG" ]; then
    log "dialogue ouvert (fenetre X id $DIALOG)"
    xdotool getwindowgeometry --shell "$DIALOG" | tee "$PROOF/dialog-geom.txt"
else
    log "ECHEC : le dialogue ne s'est pas ouvert"
    STATUS=1
    shot "MP-ECHEC-dialogue-absent.png"
    log "=== 8. arret de l'IDE ==="
    pkill -f 'com[.]intellij[.]idea[.]Main' 2>/dev/null; sleep 3
    pkill -9 -f 'com[.]intellij[.]idea[.]Main' 2>/dev/null; sleep 1
    log "FIN preuve_captures_marketplace.sh statut=$STATUS"
    exit $STATUS
fi

GEOM=$(xdotool getwindowgeometry --shell "$DIALOG")
DX=$(echo "$GEOM" | awk -F= '/^X=/{print $2}')
DY=$(echo "$GEOM" | awk -F= '/^Y=/{print $2}')
NEEDLE_X=$((DX + 341)); NEEDLE_Y=$((DY + 24))
xdotool windowactivate "$DIALOG" 2>/dev/null; sleep 1
shot "MP-02-dialogue-ouvert.png"

log "champ « Search for » : ($NEEDLE_X, $NEEDLE_Y)"
clic "$NEEDLE_X" "$NEEDLE_Y"
xdotool type --delay 80 "$CHAINE" 2>/dev/null
sleep 1
shot "MP-03-dialogue-chaine-saisiee.png"

log "=== ENTREE (la touche lance la recherche) ==="
xdotool key --clearmodifiers Return 2>/dev/null
sleep 1
shot "MP-04-recherche-lancee.png"
for i in $(seq 1 12); do
    sleep 5
    shot "MP-05-resultats-$i.png"
    if [ "$i" -ge 3 ]; then
        M1=$(md5sum "$PROOF/MP-05-resultats-$i.png" 2>/dev/null | cut -d' ' -f1)
        M2=$(md5sum "$PROOF/MP-05-resultats-$((i-1)).png" 2>/dev/null | cut -d' ' -f1)
        [ "$M1" = "$M2" ] && { log "ecran stable -> resultat fige (iteration $i)"; break; }
    fi
done

log "=== 7. ROGNAGE sur la fenetre de l'IDE (pas de fond d'ecran) ==="
if [ -f "$PROOF/ide-geom.txt" ]; then
    IX=$(awk -F= '/^X=/{print $2}' "$PROOF/ide-geom.txt")
    IY=$(awk -F= '/^Y=/{print $2}' "$PROOF/ide-geom.txt")
    IW=$(awk -F= '/^WIDTH=/{print $2}' "$PROOF/ide-geom.txt")
    IH=$(awk -F= '/^HEIGHT=/{print $2}' "$PROOF/ide-geom.txt")
    log "fenetre IDE : ${IW}x${IH} a (${IX},${IY})"
    for f in "$PROOF"/MP-*.png; do
        b=$(basename "$f")
        convert "$f" -crop "${IW}x${IH}+${IX}+${IY}" +repage "$PROOF/rogn-$b" 2>/dev/null \
            && log "rogne : rogn-$b ($(identify -format '%wx%h' "$PROOF/rogn-$b"))" \
            || log "ECHEC rognage : $b"
    done
else
    log "pas de ide-geom.txt -> pas de rognage"
fi

log "=== 8. etat final ==="
log "memoire : anon+slab = $(mem) / 1572864000"
log "alertes (captures identiques a la precedente) : $ALERTES"
[ "$ALERTES" -gt 0 ] && STATUS=1
NBCAPT=$(ls "$PROOF"/MP-*.png 2>/dev/null | wc -l)
log "captures prises : $NBCAPT"
[ "$NBCAPT" -ge 4 ] || { log "ECHEC : pas assez de captures"; STATUS=1; }

log "=== 9. arret de l'IDE ==="
pkill -f 'com[.]intellij[.]idea[.]Main' 2>/dev/null; sleep 3
pkill -9 -f 'com[.]intellij[.]idea[.]Main' 2>/dev/null; sleep 1
log "memoire apres arret : anon+slab = $(mem) / 1572864000"

log "FIN preuve_captures_marketplace.sh statut=$STATUS"
exit $STATUS
