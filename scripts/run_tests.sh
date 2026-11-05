#!/usr/bin/env bash
# =============================================================================
# run_tests.sh — compile et execute les tests du moteur pickaxe.
#
# AUCUNE dependance a Gradle, AUCUN reseau : le script compile les sources
# avec `javac` et lance la console JUnit. Il est donc utilisable dans un
# conteneur sans IDE, et reproductible a l'identique.
#
# Usage :
#   bash scripts/run_tests.sh [jar_jgit]
#
# Le jar de JGit est cherche dans `libs/`. On peut en passer un autre en
# argument : c'est ce qui permet de faire tourner la meme suite de tests
# contre le jar EXACT de l'IDE (preuve de compatibilite).
#
# Code de sortie : 0 si tous les tests passent, 1 sinon, 3 si l'environnement
# est incomplet (pas de JDK, jar manquant).
# =============================================================================
set -u

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(cd "$HERE/.." && pwd)"
BUILD="$ROOT/build"

# ---------------------------------------------------------------- Java ------
JAVAC=""
JAVA=""
if [ -n "${JAVA_HOME:-}" ] && [ -x "${JAVA_HOME}/bin/javac" ]; then
    JAVAC="$JAVA_HOME/bin/javac"
    JAVA="$JAVA_HOME/bin/java"
elif command -v javac >/dev/null 2>&1; then
    JAVAC="$(command -v javac)"
    JAVA="$(command -v java)"
else
    for candidate in /usr/lib/jvm/*/bin/javac; do
        if [ -x "$candidate" ]; then
            JAVAC="$candidate"
            JAVA="$(dirname "$candidate")/java"
            break
        fi
    done
fi
if [ -z "$JAVAC" ]; then
    echo "ERREUR : aucun JDK trouve. Renseignez JAVA_HOME." >&2
    exit 3
fi

# ---------------------------------------------------------------- Jars ------
JGIT_JAR="${1:-}"
if [ -z "$JGIT_JAR" ]; then
    for candidate in "$ROOT"/libs/org.eclipse.jgit-*.jar; do
        if [ -f "$candidate" ]; then
            JGIT_JAR="$candidate"
            break
        fi
    done
fi
if [ -z "$JGIT_JAR" ] || [ ! -f "$JGIT_JAR" ]; then
    echo "ERREUR : jar JGit introuvable. Lancez scripts/fetch_deps.sh" >&2
    exit 3
fi

JUNIT_JAR=""
for candidate in "$ROOT"/libs/junit-platform-console-standalone-*.jar; do
    if [ -f "$candidate" ]; then
        JUNIT_JAR="$candidate"
        break
    fi
done
if [ -z "$JUNIT_JAR" ]; then
    echo "ERREUR : console JUnit introuvable. Lancez scripts/fetch_deps.sh" >&2
    exit 3
fi

CP="$JGIT_JAR:$JUNIT_JAR"
for extra in "$ROOT"/libs/JavaEWAH-*.jar "$ROOT"/libs/slf4j-api-*.jar; do
    if [ -f "$extra" ]; then
        CP="$CP:$extra"
    fi
done

echo "=== 1. compilation des sources du moteur ==="
# On ne compile ici que LE MOTEUR (src/main/java/.../engine) : il ne depend
# que de JGit. La partie interface (src/main/java/.../ui) depend de la
# plateforme IntelliJ : elle est compilee par le build Gradle, qui a la
# plateforme sur son classpath.
# GitRepositoryLocator est compile avec le moteur : il ne depend que de
# java.nio (aucune dependance a la plateforme), et ses tests — le cas du
# WORKTREE, ou .git est un fichier — doivent tourner dans cette suite.
rm -rf "$BUILD/classes" "$BUILD/test-classes"
mkdir -p "$BUILD/classes" "$BUILD/test-classes" "$BUILD/tmp"
find "$ROOT/src/main/java/com/tgglabs/pickaxe/engine" -name "*.java" > "$BUILD/main-sources.txt"
echo "$ROOT/src/main/java/com/tgglabs/pickaxe/GitRepositoryLocator.java" >> "$BUILD/main-sources.txt"
"$JAVAC" -encoding UTF-8 --release 17 -nowarn -cp "$CP" -d "$BUILD/classes" \
    @"$BUILD/main-sources.txt"
if [ $? -ne 0 ]; then
    echo "ECHEC : compilation du moteur" >&2
    exit 1
fi
echo "OK : $(wc -l < "$BUILD/main-sources.txt") fichiers sources compiles"

echo "=== 2. compilation des tests ==="
find "$ROOT/src/test/java" -name "*.java" > "$BUILD/test-sources.txt"
"$JAVAC" -encoding UTF-8 --release 17 -nowarn -cp "$CP:$BUILD/classes" -d "$BUILD/test-classes" \
    @"$BUILD/test-sources.txt"
if [ $? -ne 0 ]; then
    echo "ECHEC : compilation des tests" >&2
    exit 1
fi
echo "OK : $(wc -l < "$BUILD/test-sources.txt") fichiers de tests compiles"

echo "=== 3. execution des tests ==="
echo "JGit utilise : $(basename "$JGIT_JAR")"
# Les repertoires temporaires des tests sont forces dans `build/tmp` :
# le test « blob de plus de 64 Mo » ecrit ~130 Mo, et /tmp est un tmpfs
# de 256 Mo souvent plein dans ce conteneur.
"$JAVA" -Djava.io.tmpdir="$BUILD/tmp" -jar "$JUNIT_JAR" \
    --class-path "$CP:$BUILD/classes:$BUILD/test-classes" \
    --scan-class-path "$BUILD/test-classes" \
    --details=tree \
    --disable-ansi-colors \
    --disable-banner
STATUS=$?

if [ $STATUS -eq 0 ]; then
    echo "=== RESULTAT : TOUT VERT ==="
else
    echo "=== RESULTAT : ECHEC (code $STATUS) ===" >&2
fi
exit $STATUS
