#!/usr/bin/env bash
# Contre-epreuve du controle des icones (scripts/controle_icones.py).
#
# Principe : on ne prouve un controle qu'en le mettant en defaut.
# On travaille sur des COPIES dans un dossier temporaire ; les icones livrees
# ne sont JAMAIS touchees (le sha256 est verifie avant et apres).
#
# Sortie : un verdict par cas. Code de retour 0 si le controle a bien
# detecte chaque defaut et si les sources sont intactes au final.

set -u

RACINE="$(cd "$(dirname "$0")/.." && pwd)"
SRC="$RACINE/src/main/resources/META-INF"
CONTROLE="$RACINE/scripts/controle_icones.py"
TMP="$(mktemp -d /tmp/contre_icones.XXXXXX)"
trap 'rm -rf "$TMP"' EXIT

rc_global=0
declare -a CAS

sha_avant="$(sha256sum "$SRC/pluginIcon.svg" "$SRC/pluginIcon_dark.svg")"

# $1 = nom du cas, $2 = description, $3 = sed/py sur le fichier, $4 = motif attendu dans la sortie
cas() {
  local nom="$1" desc="$2" mutation="$3" attendu="$4"
  local dossier="$TMP/$nom"
  mkdir -p "$dossier"
  cp "$SRC/pluginIcon.svg" "$SRC/pluginIcon_dark.svg" "$dossier/"
  python3 - "$dossier" "$mutation" <<'PY'
import sys, os
dossier, mutation = sys.argv[1], sys.argv[2]
def mut(f):
    p = os.path.join(dossier, f)
    s = open(p, encoding="utf-8").read()
    if mutation == "taille":
        s = s.replace('width="40"', 'width="39"').replace('height="40"', 'height="39"')
    elif mutation == "deconnecte":
        s = s.replace('M10 7 L19 23', 'M10 5 L13 14')
    elif mutation == "externe":
        s = s.replace('xmlns="http://www.w3.org/2000/svg"',
                      'xmlns="http://www.w3.org/2000/svg" xmlns:xlink="http://www.w3.org/1999/xlink"')
        s = s.replace('<path d="M8 29', '<path xlink:href="https://exemple.test/x.svg" d="M8 29')
    elif mutation == "vide":
        s = '<svg xmlns="http://www.w3.org/2000/svg" width="40" height="40" viewBox="0 0 40 40" fill="none">\n</svg>\n'
    elif mutation == "horsboite":
        s = s.replace('M8 29 Q20 19 32 29', 'M8 29 Q20 19 52 29')
    elif mutation == "transforme":
        s = s.replace('viewBox="0 0 40 40"', 'viewBox="0 0 40 40" transform="translate(6 6)"')
    open(p, "w", encoding="utf-8").write(s)
mut("pluginIcon.svg")
PY
  local sortie rc
  sortie="$(python3 "$CONTROLE" "$dossier" 2>&1)"
  rc=$?
  if [ "$rc" -ne 0 ] && printf '%s' "$sortie" | grep -q "$attendu"; then
    printf 'OK    : cas %-12s : le controle a bien detecte (%s)\n' "$nom" "$attendu"
    printf '%s\n' "$sortie" | grep -E "^ECHEC" | sed 's/^/        /'
  else
    printf "ECHEC : cas %-12s : le controle n'a PAS detecte (rc=%s, motif attendu : %s)\n" "$nom" "$rc" "$attendu"
    rc_global=1
  fi
}

echo "Contre-epreuve du controle des icones"
echo "Les copies sont dans $TMP ; les sources livrees ne sont pas touchees."
echo

cas "taille"      "width/height different de 40"        "taille"      "40"
cas "deconnecte"  "les 2 traits ne se touchent plus"     "deconnecte"  "ne se touchent pas"
cas "externe"     "reference externe (xlink:href)"       "externe"     "interdit"
cas "vide"        "icone vide"                           "vide"        "VIDE"
cas "horsboite"   "dessin sorti de la boite 40x40"       "horsboite"   "debord"
cas "transforme"  "transform (geometrie non mesurable)"  "transforme"  "transform"

echo
sha_apres="$(sha256sum "$SRC/pluginIcon.svg" "$SRC/pluginIcon_dark.svg")"
if [ "$sha_avant" = "$sha_apres" ]; then
  echo "OK    : les icones livrees sont intactes (sha256 identique avant / apres)"
else
  echo "ECHEC : les icones livrees ont ete modifiees !"
  rc_global=1
fi

echo
if [ "$rc_global" -eq 0 ]; then
  echo "FIN contre_epreuve_icones : OK (le controle detecte chaque defaut, sources intactes)"
else
  echo "FIN contre_epreuve_icones : ECHEC"
fi
exit "$rc_global"
