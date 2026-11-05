#!/usr/bin/env bash
# =============================================================================
# contre_epreuve_preflight.sh — CONTROLE ROUGE du controle de PRE-VOL.
#
# « Un controle qui n'a jamais detecte de defaut n'est pas un controle. »
#
# Ce script prouve que le controle de pre-vol DETECTE chacun des deux defauts
# que la mere a demandes :
#   1. des <change-notes> VIDES dans plugin.xml ;
#   2. une icone ABSENTE (pluginIcon.svg renomme).
#
# Point important (05/11/2026, apres relecture hostile) : le controle de
# pre-vol verifie le DESC RIPTEUR LIVRE (extrait du jar du ZIP livre), pas le
# fichier source. On RECONSTRUIT donc le ZIP apres chaque mutation : c'est
# l'artefact livre qui doit etre casse, pas seulement le source.
#
# Pour chaque cas : on casse, on RECONSTRUIT, on lance le controle (qui doit
# ECHOUER et nommer le bon defaut), on restaure, on RECONSTRUIT (le sha256 du
# ZIP doit alors retrouver sa valeur exacte : le build est reproductible), on
# relance le controle (qui doit repasser a 0 ECHEC).
#
# Usage : bash scripts/contre_epreuve_preflight.sh [/chemin/vers/le/projet]
# Code de retour : 0 si et seulement si les deux controles rouges ont ete
# valides ET que l'etat final est 0 ECHEC.
# =============================================================================
set -u

RACINE_SCRIPT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="${1:-$(cd "$RACINE_SCRIPT/.." && pwd)}"
PREFLIGHT="$ROOT/scripts/preflight_local.sh"
META="$ROOT/src/main/resources/META-INF"
XML="$META/plugin.xml"
ICON="$META/pluginIcon.svg"
ZIP="$ROOT/build/distributions/FindinCommitHistory-0.0.1.zip"
LOG="$ROOT/build/preflight-rouge.log"
PLATFORM_LOCAL_PATH="${PLATFORM_LOCAL_PATH:-/work/ide/pycharm-2026.2.4}"

[ -x "$PREFLIGHT" ] || [ -f "$PREFLIGHT" ] || { echo "ERREUR : controle de pre-vol introuvable : $PREFLIGHT" >&2; exit 3; }
mkdir -p "$(dirname "$LOG")"
exec > >(tee "$LOG") 2>&1

# Reconstruction avec la recette Gradle officielle, hors ligne.
# On SUPPRIME le ZIP : sans cela Gradle considere la tache up-to-date et ne
# reecrit pas le fichier (l'horodatage du ZIP resterait anterieur a celui des
# sources restaurees, et le controle le refuserait a tort).
rebuild() {
    local attendu="$1"   # sha256 attendu (vide = on n'exige rien)
    if [ -x "$ROOT/gradlew" ]; then
        echo "--- reconstruction du ZIP (recette Gradle officielle, hors ligne) ---"
        rm -f "$ZIP"
        ( cd "$ROOT" && ./gradlew --offline buildPlugin \
            -PplatformLocalPath="$PLATFORM_LOCAL_PATH" \
            -Porg.gradle.java.installations.paths="$PLATFORM_LOCAL_PATH/jbr" ) \
            >/dev/null 2>&1
        local apres
        apres="$(sha256sum "$ZIP" | cut -d' ' -f1)"
        if [ -n "$attendu" ] && [ "$attendu" != "$apres" ]; then
            echo "ECHEC : ZIP reconstruit, sha256 different de l'attendu ($attendu -> $apres)"
            return 1
        fi
        echo "OK    : ZIP reconstruit, sha256 $apres"
        return 0
    fi
    echo "ERREUR : gradlew introuvable, impossible de reconstruire" >&2
    return 1
}

SHA_XML_AVANT="$(sha256sum "$XML" | cut -d' ' -f1)"
SHA_ICON_AVANT="$(sha256sum "$ICON" | cut -d' ' -f1)"
SHA_ZIP_AVANT="$(sha256sum "$ZIP" | cut -d' ' -f1)"
echo "=== CONTROLE ROUGE DU PRE-VOL — $(date '+%Y-%m-%d %H:%M:%S %Z') ==="
echo "projet       : $ROOT"
echo "sha256 XML   : $SHA_XML_AVANT"
echo "sha256 icone : $SHA_ICON_AVANT"
echo "sha256 ZIP   : $SHA_ZIP_AVANT"
echo

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
rebuild "" || RC1=1
echo "--- sortie du controle de pre-vol (change-notes vides) ---"
SORTIE1="$(bash "$PREFLIGHT" "$ROOT" 2>&1)"
CODE1=$?
printf '%s\n' "$SORTIE1" | grep -E "ECHEC|RESUME|FIN preflight"
echo "--- code de retour du controle : $CODE1 ---"
mv -f "$XML.bak-red" "$XML"
rebuild "$SHA_ZIP_AVANT" || RC1=1
echo "=== sortie du controle de pre-vol apres RESTAURATION ==="
SORTIE1B="$(bash "$PREFLIGHT" "$ROOT" 2>&1)"
CODE1B=$?
printf '%s\n' "$SORTIE1B" | grep -E "ECHEC|RESUME|FIN preflight"
echo "--- code de retour du controle : $CODE1B ---"
echo
if [ "$CODE1" -eq 0 ]; then
    echo "RESULTAT CAS 1 : ECHEC DU CONTROLE ROUGE (le controle n'a PAS detecte les change-notes vides)"
    RC1=1
elif ! printf '%s' "$SORTIE1" | grep -q "change-notes"; then
    echo "RESULTAT CAS 1 : ECHEC DU CONTROLE ROUGE (le controle a echoue, mais sans nommer les change-notes)"
    RC1=1
elif [ "$CODE1B" -ne 0 ]; then
    echo "RESULTAT CAS 1 : ECHEC DU CONTROLE ROUGE (la restauration n'a pas rendu le controle vert)"
    RC1=1
else
    echo "RESULTAT CAS 1 : OK — le controle detecte bien les change-notes vides, et redevient vert apres restauration"
fi
echo

echo "############ CAS 2 : ICONE ABSENTE (pluginIcon.svg renomme) ############"
mv "$ICON" "$ICON.hidden-red"
rebuild "" || RC2=1
echo "--- sortie du controle de pre-vol (icone absente) ---"
SORTIE2="$(bash "$PREFLIGHT" "$ROOT" 2>&1)"
CODE2=$?
printf '%s\n' "$SORTIE2" | grep -E "ECHEC|RESUME|FIN preflight"
echo "--- code de retour du controle : $CODE2 ---"
mv "$ICON.hidden-red" "$ICON"
rebuild "$SHA_ZIP_AVANT" || RC2=1
echo "=== sortie du controle de pre-vol apres RESTAURATION ==="
SORTIE2B="$(bash "$PREFLIGHT" "$ROOT" 2>&1)"
CODE2B=$?
printf '%s\n' "$SORTIE2B" | grep -E "ECHEC|RESUME|FIN preflight"
echo "--- code de retour du controle : $CODE2B ---"
echo
if [ "$CODE2" -eq 0 ]; then
    echo "RESULTAT CAS 2 : ECHEC DU CONTROLE ROUGE (le controle n'a PAS detecte l'icone absente)"
    RC2=1
elif ! printf '%s' "$SORTIE2" | grep -q "pluginIcon.svg"; then
    echo "RESULTAT CAS 2 : ECHEC DU CONTROLE ROUGE (le controle a echoue, mais sans nommer l'icone)"
    RC2=1
elif [ "$CODE2B" -ne 0 ]; then
    echo "RESULTAT CAS 2 : ECHEC DU CONTROLE ROUGE (la restauration n'a pas rendu le controle vert)"
    RC2=1
else
    echo "RESULTAT CAS 2 : OK — le controle detecte bien l'icone absente, et redevient vert apres restauration"
fi
echo

echo "=== ETAT FINAL ==="
SHA_XML_APRES="$(sha256sum "$XML" | cut -d' ' -f1)"
SHA_ICON_APRES="$(sha256sum "$ICON" | cut -d' ' -f1)"
SHA_ZIP_APRES="$(sha256sum "$ZIP" | cut -d' ' -f1)"
[ "$SHA_XML_AVANT" = "$SHA_XML_APRES" ] && echo "OK    : plugin.xml restaure (sha256 identique)" || { echo "ECHEC : plugin.xml NON restaure"; RC1=1; }
[ "$SHA_ICON_AVANT" = "$SHA_ICON_APRES" ] && echo "OK    : pluginIcon.svg restaure (sha256 identique)" || { echo "ECHEC : pluginIcon.svg NON restaure"; RC2=1; }
[ "$SHA_ZIP_AVANT" = "$SHA_ZIP_APRES" ] && echo "OK    : ZIP restitue a l'octet pres (sha256 identique : build reproductible)" || { echo "ECHEC : ZIP different de l'initial"; RC1=1; RC2=1; }
echo
if [ "$RC1" -eq 0 ] && [ "$RC2" -eq 0 ]; then
    echo "FIN contre_epreuve_preflight : les DEUX controles rouges sont valides"
    exit 0
fi
echo "FIN contre_epreuve_preflight : ECHEC" >&2
exit 1
