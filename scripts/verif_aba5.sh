#!/usr/bin/env bash
# =============================================================================
# verif_aba5.sh — verification NOMMEE des 5 corrections de la revue du jury
# `aba5` (05/11/2026 19:55, verdict A_CORRIGER) + des 2 « a corriger »
# restants, dans le ZIP REELLEMENT LIVRE.
#
# POURQUOI CE SCRIPT EXISTE
# -------------------------
# Le 06/11/2026 a 08:25, la mere a conclu que « le patch n'est PAS applique »
# en cherchant, dans le code du ZIP livre :
#   - la chaine  `runProcessWithProgressSynchronously` -> 0 occurrence ;
#   - le motif   `getParentCount() > 1`                 -> 0 occurrence ;
#   - et elle a vu que `getActionUpdateThread` etait deja en place.
# Les DEUX premieres recherches ne peuvent PAS aboutir sur du code Java :
#   1. le ZIP ne contient que des `.class` (du bytecode), pas du `.java` ;
#   2. `getParentCount() > 1` est une EXPRESSION JAVA : elle n'existe nulle
#      part dans un `.class` (le bytecode contient l'appel `getParentCount`
#      et une comparaison, pas la ligne source) ;
#   3. le code n'utilise PAS `runProcessWithProgressSynchronously` : il
#      utilise `ProgressManager.getInstance().run(new Task.Backgroundable(...))`,
#      qui fait le meme travail (la recherche sort de l'EDT) et VAUT MIEUX
#      pour l'annulation (l'indicateur de tache de fond porte le « Cancel »).
#
# Ce script fait la verification correctement, sur les DEUX supports :
#   (A) le SOURCE lisible  ;
#   (B) le BYTECODE du ZIP reellement livre (extrait a chaud).
# Chaque controle porte un NOM et affiche OK / ECHEC. Code de sortie : 0 si
# tous les controles sont OK, 1 sinon.
#
# Usage :
#   bash scripts/verif_aba5.sh [chemin_du_ZIP_livre]
#   ZIP par defaut : build/distributions/FindinCommitHistory-0.0.1.zip
# =============================================================================
set -u

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(cd "$HERE/.." && pwd)"
ZIP="${1:-$ROOT/build/distributions/FindinCommitHistory-0.0.1.zip}"
SRC="$ROOT/src/main/java/com/tgglabs/pickaxe"
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

FAIL=0
NAME=""

# ------------------------------------------------------------------ util ----
hdr() { NAME="$1"; printf '\n== %s ==\n' "$1"; }
ok()  { printf '   OK      %s\n' "$1"; }
ko()  { printf '   ECHEC   %s\n' "$1"; FAIL=1; }

# check <libelle> <0 si present>
check() {
    if [ "$2" -eq 0 ]; then ok "$1"; else ko "$1"; fi
}

# src_has <fichier> <motif>  -> 0 si le motif est present
src_has() { grep -qF -- "$2" "$SRC/$1"; }

# class_has <classe relative> <motif> -> 0 si le motif est dans le bytecode
class_has() { strings -a "$TMP/classes/$1" 2>/dev/null | grep -qF -- "$2"; }

echo "=========================================================="
echo " verification des corrections de la revue du jury aba5"
echo " ZIP livre : $ZIP"
echo " source    : $SRC"
echo "=========================================================="

# ------------------------------------------- extraction du ZIP livre -------
if [ ! -f "$ZIP" ]; then
    echo "ERREUR : ZIP introuvable : $ZIP" >&2
    exit 2
fi
mkdir -p "$TMP/x" "$TMP/classes"
unzip -q -o "$ZIP" -d "$TMP/x"
PLUGIN_JAR="$(find "$TMP/x" -name 'FindinCommitHistory-*.jar' | head -1)"
if [ -z "$PLUGIN_JAR" ]; then
    echo "ERREUR : jar du plugin introuvable dans le ZIP" >&2
    exit 2
fi
( cd "$TMP/classes" && unzip -q -o "$PLUGIN_JAR" )
echo " jar du plugin : $(basename "$PLUGIN_JAR") ($(stat -c%s "$PLUGIN_JAR") o)"
echo " md5 du ZIP    : $(md5sum "$ZIP" | cut -d' ' -f1)"

# ---------------------------------------------------------------------------
# 1. GELE DE L'IDE : la recherche ne doit PAS tourner sur l'EDT
# ---------------------------------------------------------------------------
hdr "1. GELE DE L'IDE — la recherche sort de l'EDT (revue aba5 point 1)"
src_has ui/PickaxeDialog.java "ProgressManager.getInstance().run(";  check "SOURCE : ProgressManager.getInstance().run(...) dans le dialogue" $?
src_has ui/PickaxeDialog.java "new Task.Backgroundable(";            check "SOURCE : tache de fond Task.Backgroundable (le parcours part sur un thread de fond)" $?
src_has ui/PickaxeDialog.java "run(@NotNull ProgressIndicator indicator)"; check "SOURCE : la tache de fond recoit l'indicateur de progression" $?
class_has com/tgglabs/pickaxe/ui/PickaxeDialog.class "com/intellij/openapi/progress/ProgressManager"; check "BYTECODE : PickaxeDialog.class reference ProgressManager" $?
class_has com/tgglabs/pickaxe/ui/PickaxeDialog.class "com/intellij/openapi/progress/Task";           check "BYTECODE : PickaxeDialog.class reference la tache de fond" $?
# La forme EXACTE demandee par la revue (runProcessWithProgressSynchronously)
# n'est PAS utilisee : c'est une tache de fond non modale qui la remplace.
src_has ui/PickaxeDialog.java "runProcessWithProgressSynchronously"; [ $? -ne 0 ]
check "SOURCE : runProcessWithProgressSynchronously NON utilise (remplace par une tache de fond non modale, qui porte mieux le bouton Cancel)" $?

# ---------------------------------------------------------------------------
# 2. ANNULATION : le bouton Cancel doit arreter le parcours
# ---------------------------------------------------------------------------
hdr "2. ANNULATION — le parcours s'interrompt (revue aba5 point 2)"
src_has engine/PickaxeEngine.java "private final BooleanSupplier cancelled";     check "SOURCE : le moteur accepte un test d'annulation BooleanSupplier" $?
src_has engine/PickaxeEngine.java "cancelled.getAsBoolean()";                    check "SOURCE : le test d'annulation est appele dans la boucle" $?
src_has engine/PickaxeEngine.java "this(repository, () -> false);";              check "SOURCE : defaut = jamais annule (le moteur reste testable sans IDE)" $?
src_has ui/PickaxeDialog.java "indicator::isCanceled";                          check "SOURCE : le dialogue passe l'annulation de la tache de fond au moteur" $?
src_has ui/PickaxeDialog.java "new PickaxeEngine(repository, cancelled)";        check "SOURCE : le dialogue construit le moteur avec ce test d'annulation" $?
class_has com/tgglabs/pickaxe/engine/PickaxeEngine.class "getAsBoolean";         check "BYTECODE : PickaxeEngine.class appelle BooleanSupplier.getAsBoolean" $?
[ -f "$ROOT/src/test/java/com/tgglabs/pickaxe/engine/CancellationTest.java" ]
check "TEST : CancellationTest.java existe" $?

# ---------------------------------------------------------------------------
# 3. FUSIONS : un commit de fusion ne doit pas doubler les resultats
# ---------------------------------------------------------------------------
hdr "3. FUSIONS — un seul resultat par modification (revue aba5 point 3)"
src_has engine/PickaxeEngine.java "if (commit.getParentCount() > 1) {"; check "SOURCE : les commits a plus d'un parent ne sont pas diffes" $?
class_has com/tgglabs/pickaxe/engine/PickaxeEngine.class "getParentCount"; check "BYTECODE : PickaxeEngine.class appelle getParentCount" $?
[ -f "$ROOT/src/test/java/com/tgglabs/pickaxe/engine/MergeSearchTest.java" ]
check "TEST : MergeSearchTest.java existe" $?
grep -q "UN SEUL resultat" "$ROOT/src/test/java/com/tgglabs/pickaxe/engine/MergeSearchTest.java"
check "TEST : MergeSearchTest contient le cas « une branche ajoute la chaine puis fusionnee => UN SEUL resultat »" $?

# ---------------------------------------------------------------------------
# 4. FUITE DE RESSOURCE : l'ObjectReader doit etre ferme
# ---------------------------------------------------------------------------
hdr "4. FUITE DE RESSOURCE — l'ObjectReader est ferme (revue aba5 point 4)"
src_has engine/PickaxeEngine.java "try (ObjectReader reader = repository.newObjectReader()) {"; check "SOURCE : try-with-resources autour de l'ObjectReader" $?

# ---------------------------------------------------------------------------
# 5. getActionUpdateThread
# ---------------------------------------------------------------------------
hdr "5. getActionUpdateThread — avertissement plateforme 243+ (revue aba5 point 5)"
src_has ui/FindInHistoryAction.java "getActionUpdateThread";            check "SOURCE : FindInHistoryAction renvoie le fil de mise a jour" $?
src_has ui/FindInHistoryAction.java "ActionUpdateThread.BGT";            check "SOURCE : le fil de mise a jour est BGT" $?
class_has com/tgglabs/pickaxe/ui/FindInHistoryAction.class "getActionUpdateThread"; check "BYTECODE : FindInHistoryAction.class declare getActionUpdateThread" $?

# ---------------------------------------------------------------------------
# A. Clean-up : les 2 « a corriger » restants
# ---------------------------------------------------------------------------
hdr "A. CLEAN-UP — les 2 points « a corriger » restants de la revue"
if [ -f "$SRC/com/tgglabs/pickaxe/PickaxeStartupActivity.java" ] || \
   find "$SRC" -name "*StartupActivity*" | grep -q .; then
    ko "PickaxeStartupActivity : le FICHIER existe encore"
else
    ok "PickaxeStartupActivity : le fichier n'existe plus"
fi
grep -q "postStartupActivity" "$ROOT/src/main/resources/META-INF/plugin.xml"
if [ $? -ne 0 ]; then ok "plugin.xml : plus aucune balise <postStartupActivity>"; else ko "plugin.xml : <postStartupActivity> encore present"; fi

hdr "B. TEXTE PUBLIC — l'absolu « No false positives » a disparu"
if grep -rqF "No false positives" "$ROOT/src/main/resources/META-INF/plugin.xml" "$ROOT"/*.md 2>/dev/null; then
    grep -rlF "No false positives" "$ROOT/src/main/resources/META-INF/plugin.xml" "$ROOT"/*.md 2>/dev/null | while read -r f; do ko "« No false positives » encore present dans $f"; done
else
    ok "« No false positives » absent du descripteur ET de tous les .md du dossier"
fi
grep -qF "A line rewritten identically is not reported" "$ROOT/src/main/resources/META-INF/plugin.xml"
check "plugin.xml : la phrase vraie « A line rewritten identically is not reported » est presente" $?
unzip -p "$PLUGIN_JAR" META-INF/plugin.xml > "$TMP/plugin.xml"
grep -qF "A line rewritten identically is not reported" "$TMP/plugin.xml"
check "plugin.xml du jar livre : la phrase vraie est bien celle qui part en ligne" $?

# ---------------------------------------------------------------------------
# C. COHERENCE DE L'ARCHIVE
# ---------------------------------------------------------------------------
hdr "C. COHERENCE DE L'ARCHIVE"
grep -qF 'since-build="243"' "$TMP/plugin.xml"; check "plugin.xml du jar : since-build=\"243\" (IntelliJ 2024.3)" $?
grep -qF 'until-build' "$TMP/plugin.xml"; if [ $? -ne 0 ]; then ok "plugin.xml du jar : aucune borne haute (until-build absent)"; else ko "plugin.xml du jar : until-build present"; fi
grep -qF '<version>0.0.1</version>' "$TMP/plugin.xml"; check "plugin.xml du jar : version 0.0.1 (inchangee)" $?
grep -qF '<id>com.tgglabs.pickaxe</id>' "$TMP/plugin.xml"; check "plugin.xml du jar : id com.tgglabs.pickaxe (inchange)" $?
NB=$(find "$TMP/x" -name '*.jar' | wc -l); [ "$NB" -eq 3 ] && ok "3 jars dans lib/ (plugin + JGit + JavaEWAH)" || ko "$NB jars dans lib/ (attendu 3)"
find "$TMP/x" -name '*.jar' | grep -qi slf4j && ko "slf4j est dans le ZIP" || ok "aucun jar slf4j dans le ZIP"

echo
echo "=========================================================="
if [ "$FAIL" -eq 0 ]; then
    echo " VERDICT : TOUS LES CONTROLES SONT OK"
else
    echo " VERDICT : AU MOINS UN CONTROLE EST EN ECHEC"
fi
echo "=========================================================="
exit $FAIL
