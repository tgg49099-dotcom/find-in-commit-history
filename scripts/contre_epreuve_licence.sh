#!/usr/bin/env bash
# =============================================================================
# contre_epreuve_licence.sh — preuve que le test « sans licence » teste
# vraiment la licence.
#
# PRINCIPE : on change l'etat de licence, on rejoue la suite, et le test (a)
# doit devenir ROUGE. Si le test (a) reste VERT apres le changement, il ne
# testait rien : il est inutile.
#
# Deux mutations sont faites, l'une apres l'autre, puis chaque fichier est
# restaure BIT A BIT (verifie par sha256) :
#
#   1. le test injecte une licence ACTIVE au lieu d'une licence absente
#      (`licenceFausse()` : FALSE -> TRUE) ;
#   2. la garde de licence du produit est forcee a true
#      (`LicenceEtat.estPro()` : return true).
#
# Dans les deux cas, le test vise est :
#   com.tgglabs.pickaxe.pro.FonctionsProTest#sansLicenceLes4FonctionsProSontRefusees
#
# Code de sortie : 0 si la contre-epreuve est concluante (rouge apres
# mutation, vert apres restauration), 1 sinon.
# =============================================================================
set -u

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(cd "$HERE/.." && pwd)"
cd "$ROOT" || exit 3

WORK="$ROOT/build/contre-epreuve"
rm -rf "$WORK"
mkdir -p "$WORK"

FICHIER_PRODUIT="$ROOT/src/main/java/com/tgglabs/pickaxe/pro/LicenceEtat.java"
FICHIER_TEST="$ROOT/src/test/java/com/tgglabs/pickaxe/pro/FonctionsProTest.java"

cp "$FICHIER_PRODUIT" "$WORK/LicenceEtat.java.orig"
cp "$FICHIER_TEST" "$WORK/FonctionsProTest.java.orig"

SHA_PRODUIT_AVANT="$(sha256sum "$FICHIER_PRODUIT" | cut -d' ' -f1)"
SHA_TEST_AVANT="$(sha256sum "$FICHIER_TEST" | cut -d' ' -f1)"

restore() {
    cp "$WORK/LicenceEtat.java.orig" "$FICHIER_PRODUIT"
    cp "$WORK/FonctionsProTest.java.orig" "$FICHIER_TEST"
}
trap 'restore' EXIT

# --- helpers ---------------------------------------------------------------

# Lance la suite et affiche : succes, echecs, et les tests en echec.
lancer_suite() {
    local etiquette="$1"
    local log="$WORK/$etiquette.log"
    bash scripts/run_tests.sh > "$log" 2>&1
    local code=$?
    local succes echecs
    succes="$(grep -oE '[0-9]+ tests successful' "$log" | tail -1 | grep -oE '[0-9]+')"
    echecs="$(grep -oE '[0-9]+ tests failed' "$log" | tail -1 | grep -oE '[0-9]+')"
    echo "  suite [$etiquette] : code=$code  tests successful=${succes:-?}  tests failed=${echecs:-?}"
    if [ "${echecs:-0}" != "0" ]; then
        echo "  tests en echec :"
        grep -oE "methodName = '[^']+'" "$log" | sed "s/methodName = '//; s/'//" | sort -u | sed 's/^/    - /'
    fi
    return $code
}

conclusion=0

echo "==================================================================="
echo "CONTRE-EPREUVE 1 : l'etat de licence injecte passe de FALSE a TRUE"
echo "==================================================================="
echo " fichier muté : src/test/java/com/tgglabs/pickaxe/pro/FonctionsProTest.java"
lancer_suite "avant"
AVANT_CODE=$?

sed -i 's/return new LicenceEtat(() -> Boolean.FALSE);/return new LicenceEtat(() -> Boolean.TRUE);/' "$FICHIER_TEST"
if cmp -s "$FICHIER_TEST" "$WORK/FonctionsProTest.java.orig"; then
    echo "  ERREUR : la mutation n'a rien changé." >&2
    conclusion=1
else
    echo "  mutation appliquée : licenceFausse() rend maintenant TRUE"
    lancer_suite "apres"
    if [ $? -eq 0 ]; then
        echo "  ECHEC DE LA CONTRE-EPREUVE : le test (a) est resté VERT." >&2
        conclusion=1
    else
        echo "  OK : le test (a) est devenu ROUGE (le test teste bien la licence)."
    fi
fi
restore
echo "  restauration du fichier de test"
lancer_suite "restaure"
if [ $? -ne 0 ]; then
    echo "  ECHEC : la suite n'est pas revenue au vert." >&2
    conclusion=1
fi

echo
echo "==================================================================="
echo "CONTRE-EPREUVE 2 : la garde de licence du produit est forcee a true"
echo "==================================================================="
echo " fichier muté : src/main/java/com/tgglabs/pickaxe/pro/LicenceEtat.java"
sed -i 's/return Boolean.TRUE.equals(lire());/return true; \/\/ MUTATION CONTRE-EPREUVE/' "$FICHIER_PRODUIT"
if cmp -s "$FICHIER_PRODUIT" "$WORK/LicenceEtat.java.orig"; then
    echo "  ERREUR : la mutation n'a rien changé." >&2
    conclusion=1
else
    echo "  mutation appliquée : LicenceEtat.estPro() rend toujours true"
    lancer_suite "apres2"
    if [ $? -eq 0 ]; then
        echo "  ECHEC DE LA CONTRE-EPREUVE : le test (a) est resté VERT." >&2
        conclusion=1
    else
        echo "  OK : le test (a) est devenu ROUGE (le test teste bien la licence)."
    fi
fi
restore
echo "  restauration du fichier produit"
lancer_suite "restaure2"
if [ $? -ne 0 ]; then
    echo "  ECHEC : la suite n'est pas revenue au vert." >&2
    conclusion=1
fi

# --- verification finale : les fichiers sont intacts ------------------------
echo
echo "=== verification des fichiers restaures ==="
SHA_PRODUIT_APRES="$(sha256sum "$FICHIER_PRODUIT" | cut -d' ' -f1)"
SHA_TEST_APRES="$(sha256sum "$FICHIER_TEST" | cut -d' ' -f1)"
echo "  LicenceEtat.java   avant=$SHA_PRODUIT_AVANT"
echo "  LicenceEtat.java   apres=$SHA_PRODUIT_APRES"
echo "  FonctionsProTest.java avant=$SHA_TEST_AVANT"
echo "  FonctionsProTest.java apres=$SHA_TEST_APRES"
if [ "$SHA_PRODUIT_AVANT" != "$SHA_PRODUIT_APRES" ] || [ "$SHA_TEST_AVANT" != "$SHA_TEST_APRES" ]; then
    echo "  ECHEC : les fichiers n'ont pas ete restaures a l'identique." >&2
    conclusion=1
else
    echo "  OK : les deux fichiers sont restaures a l'identique (sha256)."
fi

echo
if [ "$conclusion" -eq 0 ]; then
    echo "=== RESULTAT : CONTRE-EPREUVE CONCLUANTE ==="
else
    echo "=== RESULTAT : CONTRE-EPREUVE NON CONCLUANTE ===" >&2
fi
exit "$conclusion"
