#!/usr/bin/env bash
# =============================================================================
# contre_epreuve_preflight.sh — CONTROLE ROUGE du controle de PRE-VOL.
#
# « Un controle qui n'a jamais detecte de defaut n'est pas un controle. »
#
# Ce script prouve que le controle de pre-vol DETECTE chacun des deux defauts
# que la mere a demandes :
#   1. des <change-notes> VIDES dans plugin.xml ;
#   2. une icone ABSENTE (pluginIcon.svg renomme pendant 2 secondes).
#
# Pour chaque cas : on casse, on lance le controle (qui doit ECHOUER), on
# restaure, on relance (qui doit repasser a 0 ECHEC). Les sha256 des fichiers
# touches sont compares avant / apres : la restauration doit etre EXACTE.
#
# Usage : bash scripts/contre_epreuve_preflight.sh [/chemin/vers/le/projet]
# Code de retour : 0 si et seulement si les deux controles rouges ont ete
# valides ET que l'etat final est 0 ECHEC.
# =============================================================================
set -u

ROOT="${1:-/work/pickaxe}"
PREFLIGHT="$ROOT/scripts/preflight_local.sh"
META="$ROOT/src/main/resources/META-INF"
XML="$META/plugin.xml"
ICON="$META/pluginIcon.svg"
LOG="$(dirname "$0")/../build/preflight-rouge.log"

[ -x "$PREFLIGHT" ] || { echo "ERREUR : controle de pre-vol introuvable : $PREFLIGHT" >&2; exit 3; }
mkdir -p "$(dirname "$LOG")"
exec > >(tee "$LOG") 2>&1

# Apres restauration, le ZIP doit etre PLUS RECENT que les sources (c'est un
# des criteres du pre-vol). On le RECONSTRUIT avec la recette Gradle
# officielle : le build etant REPRODUCTIBLE, le ZIP reconstruit est
# identique octet pour octet (le sha256 du ZIP est verifie : il doit etre
# INCHANGE). Si Gradle n'est pas disponible, on se contente de mettre le
# ZIP a l'heure (son contenu, lui, n'est pas touche).
rebuild() {
    local zip="$ROOT/build/distributions/FindinCommitHistory-0.0.1.zip"
    local avant="$1"
    if [ -x "$ROOT/gradlew" ] && [ -n "${JAVA_HOME:-}" ] && [ -x "$JAVA_HOME/bin/java" ]; then
        echo "--- reconstruction du ZIP (recette Gradle officielle, hors ligne) ---"
        # On SUPPRIME le ZIP : sans cela Gradle considere la tache up-to-date
        # (les sources sont identiques au contenu) et ne reecrit PAS le
        # fichier -> l'horodatage du ZIP resterait anterieur a celui des
        # sources restaurees, et le controle le refuserait a tort.
        rm -f "$zip"
        ( cd "$ROOT" && ./gradlew --offline buildPlugin \
            -PplatformLocalPath="${PLATFORM_LOCAL_PATH:-/work/ide/pycharm-2026.2.4}" \
            -Porg.gradle.java.installations.paths="${PLATFORM_LOCAL_PATH:-/work/ide/pycharm-2026.2.4}/jbr" ) \
            >/dev/null 2>&1
        local apres
        apres="$(sha256sum "$zip" | cut -d' ' -f1)"
        if [ "$avant" = "$apres" ]; then
            echo "OK    : ZIP reconstruit, sha256 INCHANGE ($apres) — build reproductible"
        else
            echo "ECHEC : ZIP reconstruit mais sha256 different ($avant -> $apres)"
            return 1
        fi
    else
        touch "$zip"
        echo "OK    : ZIP remis a l'heure (contenu non modifie)"
    fi
}

SHA_XML_AVANT="$(sha256sum "$XML" | cut -d' ' -f1)"
SHA_ICON_AVANT="$(sha256sum "$ICON" | cut -d' ' -f1)"
SHA_ZIP_AVANT="$(sha256sum "$ROOT/build/distributions/FindinCommitHistory-0.0.1.zip" | cut -d' ' -f1)"
echo "=== CONTROLE ROUGE DU PRE-VOL — $(date '+%Y-%m-%d %H:%M:%S %Z') ==="
echo "projet       : $ROOT"
echo "sha256 XML   : $SHA_XML_AVANT"
echo "sha256 icone : $SHA_ICON_AVANT"
echo "sha256 ZIP   : $SHA_ZIP_AVANT"
echo

# --------------------------------------------------------------------------
RC1=0
RC2=0
echo "############ CAS 1 : <change-notes> VIDES ############"
cp "$XML" "$XML.bak-red"
python3 -I - "$XML.bak-red" "$XML" <<'PY'
import re, sys
src, dst = sys.argv[1], sys.argv[2]
s = open(src, encoding="utf-8").read()
new, n = re.subn(r"<change-notes>.*?</change-notes>", "<change-notes></change-notes>", s, count=1, flags=re.S)
if n != 1:
    sys.exit("MUTATION IMPOSSIBLE : <change-notes> non trouve")
open(dst, "w", encoding="utf-8").write(new)
PY
echo "--- sortie du controle de pre-vol (change-notes vides) ---"
bash "$PREFLIGHT" "$ROOT" | grep -E "ECHEC|RESUME|FIN preflight"
CODE1="${PIPESTATUS[0]}"
echo "--- code de retour du controle : $CODE1 ---"
mv -f "$XML.bak-red" "$XML"
rebuild "$SHA_ZIP_AVANT" || RC1=1
echo "=== sortie du controle de pre-vol apres RESTAURATION ==="
bash "$PREFLIGHT" "$ROOT" | grep -E "ECHEC|RESUME|FIN preflight"
CODE1B="${PIPESTATUS[0]}"
echo
if [ "$CODE1" -eq 0 ]; then
    echo "RESULTAT CAS 1 : ECHEC DU CONTROLE ROUGE (le controle n'a PAS detecte les change-notes vides)"
    RC1=1
elif [ "$CODE1B" -ne 0 ]; then
    echo "RESULTAT CAS 1 : ECHEC DU CONTROLE ROUGE (la restauration n'a pas rendu le controle vert)"
    RC1=1
else
    echo "RESULTAT CAS 1 : OK — le controle detecte bien les change-notes vides, et redevient vert apres restauration"
fi
echo

# --------------------------------------------------------------------------
echo "############ CAS 2 : ICONE ABSENTE (pluginIcon.svg renomme) ############"
mv "$ICON" "$ICON.hidden-red"
echo "--- sortie du controle de pre-vol (icone absente) ---"
bash "$PREFLIGHT" "$ROOT" | grep -E "ECHEC|RESUME|FIN preflight"
CODE2="${PIPESTATUS[0]}"
echo "--- code de retour du controle : $CODE2 ---"
mv "$ICON.hidden-red" "$ICON"
rebuild "$SHA_ZIP_AVANT" || RC2=1
echo "=== sortie du controle de pre-vol apres RESTAURATION ==="
bash "$PREFLIGHT" "$ROOT" | grep -E "ECHEC|RESUME|FIN preflight"
CODE2B="${PIPESTATUS[0]}"
echo
if [ "$CODE2" -eq 0 ]; then
    echo "RESULTAT CAS 2 : ECHEC DU CONTROLE ROUGE (le controle n'a PAS detecte l'icone absente)"
    RC2=1
elif [ "$CODE2B" -ne 0 ]; then
    echo "RESULTAT CAS 2 : ECHEC DU CONTROLE ROUGE (la restauration n'a pas rendu le controle vert)"
    RC2=1
else
    echo "RESULTAT CAS 2 : OK — le controle detecte bien l'icone absente, et redevient vert apres restauration"
fi
echo

# --------------------------------------------------------------------------
echo "=== ETAT FINAL ==="
SHA_XML_APRES="$(sha256sum "$XML" | cut -d' ' -f1)"
SHA_ICON_APRES="$(sha256sum "$ICON" | cut -d' ' -f1)"
[ "$SHA_XML_AVANT" = "$SHA_XML_APRES" ] && echo "OK    : plugin.xml restaure (sha256 identique)" || { echo "ECHEC : plugin.xml NON restaure"; RC1=1; }
[ "$SHA_ICON_AVANT" = "$SHA_ICON_APRES" ] && echo "OK    : pluginIcon.svg restaure (sha256 identique)" || { echo "ECHEC : pluginIcon.svg NON restaure"; RC2=1; }
ls -la "$META" | sed 's/^/    /'
echo
if [ "$RC1" -eq 0 ] && [ "$RC2" -eq 0 ]; then
    echo "FIN contre_epreuve_preflight : les DEUX controles rouges sont valides"
    exit 0
fi
echo "FIN contre_epreuve_preflight : ECHEC" >&2
exit 1
