#!/usr/bin/env bash
# =============================================================================
# contre_epreuve_rouge.sh — PREUVE ROUGE du moteur pickaxe.
#
# Principe : « un test qui n'a jamais ete rouge n'est pas un test ».
# On mutate une COPIE du moteur (le source canonique n'est JAMAIS touche),
# on rejoue la suite de tests, et on exige que la suite ECHOUE.
#
# La mutation simule l'implementation naive de `git log -S` : au lieu de
# comparer le NOMBRE d'occurrences avant / apres, on se contente de demander
# « la chaine est-elle presente d'un cote ou de l'autre ? ». C'est exactement
# le piege que le produit promet d'eviter : une chaine reecrite a l'identique
# ne doit PAS remonter.
#
# Sortie : 0 si la suite a bien echoue (preuve ROUGE validee),
#          1 si la suite est verte (la mutation ne mord pas : preuve INVALIDEE),
#          3 si l'environnement est incomplet.
# =============================================================================
set -u

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(cd "$HERE/.." && pwd)"
WORK="$ROOT/build/red-proof"
PROOF="${1:-$ROOT/../preuves/cycle115}"
LOG="$PROOF/contre-epreuve-rouge.log"
MUT="$WORK/src/main/java/com/tgglabs/pickaxe/engine/PickaxeEngine.java"

mkdir -p "$PROOF"

# ---------------------------------------------------------------- Java ------
if [ -n "${JAVA_HOME:-}" ] && [ -x "${JAVA_HOME}/bin/javac" ]; then
    JAVAC="$JAVA_HOME/bin/javac"; JAVA="$JAVA_HOME/bin/java"
elif command -v javac >/dev/null 2>&1; then
    JAVAC="$(command -v javac)"; JAVA="$(command -v java)"
else
    for candidate in /usr/lib/jvm/*/bin/javac; do
        if [ -x "$candidate" ]; then JAVAC="$candidate"; JAVA="$(dirname "$candidate")/java"; break; fi
    done
fi
if [ -z "${JAVAC:-}" ]; then echo "ERREUR : aucun JDK trouve" >&2; exit 3; fi

CP="$ROOT/libs/org.eclipse.jgit-6.10.1.202505221210-r.jar"
CP="$CP:$ROOT/libs/JavaEWAH-1.1.12.jar"
CP="$CP:$ROOT/libs/slf4j-api-2.0.13.jar"
CP="$CP:$ROOT/libs/junit-platform-console-standalone-1.10.2.jar"

exec > >(tee "$LOG") 2>&1

echo "=== CONTRE-EPREUVE ROUGE — moteur pickaxe ==="
echo "date            : $(date -u '+%Y-%m-%dT%H:%M:%SZ')"
echo "java            : $($JAVA -version 2>&1 | head -1)"
echo "source canonique: $ROOT/src/main/java/com/tgglabs/pickaxe/engine/PickaxeEngine.java"

CANON="$ROOT/src/main/java/com/tgglabs/pickaxe/engine/PickaxeEngine.java"
SHA_AVANT="$(sha256sum "$CANON" | cut -d' ' -f1)"
echo "sha256 AVANT    : $SHA_AVANT"

# ------------------------------------------------- copie + mutation ---------
rm -rf "$WORK"
mkdir -p "$WORK"
cp -r "$ROOT/src" "$WORK/src"
echo
echo "=== 1. mutation de la COPIE (le canonique n'est pas touche) ==="
echo "avant : $(grep -n 'hit = countOccurrences' "$MUT")"
python3 -I - "$MUT" <<'PY'
import sys
p = sys.argv[1]
s = open(p, encoding="utf-8").read()
avant = "hit = countOccurrences(oldBytes, needleBytes) != countOccurrences(newBytes, needleBytes);"
apres = "hit = countOccurrences(oldBytes, needleBytes) > 0 || countOccurrences(newBytes, needleBytes) > 0;"
if avant not in s:
    sys.exit("MUTATION IMPOSSIBLE : le motif attendu est absent du source")
open(p, "w", encoding="utf-8").write(s.replace(avant, apres, 1))
PY
if [ $? -ne 0 ]; then echo "ECHEC : mutation impossible" >&2; exit 3; fi
echo "apres : $(grep -n 'hit = countOccurrences' "$MUT")"
echo "sha256 de la copie mutee : $(sha256sum "$MUT" | cut -d' ' -f1)"

# ------------------------------------------------- compilation --------------
echo
echo "=== 2. compilation de la copie mutee ==="
rm -rf "$WORK/classes" "$WORK/test-classes"
mkdir -p "$WORK/classes" "$WORK/test-classes"
find "$WORK/src/main/java/com/tgglabs/pickaxe/engine" -name "*.java" > "$WORK/sources.txt"
"$JAVAC" -encoding UTF-8 --release 17 -nowarn -cp "$CP" -d "$WORK/classes" @"$WORK/sources.txt" || {
    echo "ECHEC : compilation" >&2; exit 3; }
find "$WORK/src/test/java" -name "*.java" > "$WORK/test-sources.txt"
"$JAVAC" -encoding UTF-8 --release 17 -nowarn -cp "$CP:$WORK/classes" -d "$WORK/test-classes" \
    @"$WORK/test-sources.txt" || { echo "ECHEC : compilation des tests" >&2; exit 3; }
echo "OK : compilation reussie"

# ------------------------------------------------- execution ----------------
echo
echo "=== 3. execution de la suite sur le moteur MUTE ==="
echo "commande : java -jar junit-platform-console-standalone-1.10.2.jar --class-path ... --scan-class-path ... --details=tree"
"$JAVA" -jar "$ROOT/libs/junit-platform-console-standalone-1.10.2.jar" \
    --class-path "$CP:$WORK/classes:$WORK/test-classes" \
    --scan-class-path "$WORK/test-classes" \
    --details=tree \
    --disable-ansi-colors \
    --disable-banner
CODE=$?
echo
echo "=== 4. CODE DE RETOUR de la suite mutée : $CODE ==="

# ------------------------------------------------- controle -----------------
SHA_APRES="$(sha256sum "$CANON" | cut -d' ' -f1)"
echo "sha256 APRES (canonique) : $SHA_APRES"
if [ "$SHA_AVANT" != "$SHA_APRES" ]; then
    echo "ALERTE : le source canonique a ete modifie pendant la contre-epreuve" >&2
    exit 1
fi
echo "OK : le source canonique est intact (sha256 identique avant / apres)."

echo
if [ "$CODE" -ne 0 ]; then
    echo "=== RESULTAT : PREUVE ROUGE VALIDEE ==="
    echo "La suite echoue (code $CODE) sur le moteur mute : les tests mordent."
    exit 0
else
    echo "=== RESULTAT : PREUVE ROUGE INVALIDEE ===" >&2
    echo "La suite est VERTE sur le moteur mute : la mutation ne mord pas." >&2
    exit 1
fi
