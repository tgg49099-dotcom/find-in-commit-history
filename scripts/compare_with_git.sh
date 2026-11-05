#!/usr/bin/env bash
# =============================================================================
# compare_with_git.sh — compare le moteur pickaxe avec le VRAI `git log`.
#
# Le depot de test est construit par le code des tests (JGit), puis on
# interroge le meme depot avec :
#   - `git log -S<chaine>` et `git log -G<regex>` (implementation de reference)
#   - le moteur pickaxe (PickaxeCli)
# et on compare les listes de messages de commit.
#
# Usage : bash scripts/compare_with_git.sh [repertoire_de_travail]
# Code de sortie : 0 si les deux implementations concordent.
# =============================================================================
set -u

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(cd "$HERE/.." && pwd)"
WORK="${1:-$ROOT/build/git-compare/repo}"
LIB="$ROOT/libs"

NEEDLE='s3cret-needle'
UNICODE='wörld'
REGEX='noqa'

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

CP="$LIB/org.eclipse.jgit-6.10.1.202505221210-r.jar"
for extra in "$LIB"/JavaEWAH-*.jar "$LIB"/slf4j-api-*.jar "$LIB"/junit-platform-console-standalone-*.jar; do
    [ -f "$extra" ] && CP="$CP:$extra"
done

# ------------------------------------------------- compilation du moteur ---
BUILD="$ROOT/build/git-compare/classes"
mkdir -p "$BUILD"
find "$ROOT/src/main/java/com/tgglabs/pickaxe/engine" -name '*.java' > "$BUILD/sources.txt"
# GitRepositoryLocator est hors du paquet 'engine' mais PickaxeRepository
# l'utilise (correction worktree du 05/11) : sans lui, la compilation echoue.
echo "$ROOT/src/main/java/com/tgglabs/pickaxe/GitRepositoryLocator.java" >> "$BUILD/sources.txt"
"$JAVAC" -encoding UTF-8 --release 17 -nowarn -cp "$CP" -d "$BUILD" @"$BUILD/sources.txt" || exit 1
find "$ROOT/src/test/java" -name '*.java' > "$BUILD/test-sources.txt"
"$JAVAC" -encoding UTF-8 --release 17 -nowarn -cp "$CP:$BUILD" -d "$BUILD" @"$BUILD/test-sources.txt" || exit 1

# ------------------------------------------------------ depot de test -------
rm -rf "$WORK"
mkdir -p "$WORK"
"$JAVA" -cp "$CP:$BUILD" com.tgglabs.pickaxe.engine.BuildTestRepo "$WORK" | sed 's/^/commit /'
if [ ! -d "$WORK/.git" ]; then
    echo "ERREUR : le depot de test n'a pas ete construit" >&2
    exit 3
fi

STATUS=0
# compare "libelle" "commande_git" "commande_pickaxe"
compare() {
    local label="$1" git_cmd="$2" engine_cmd="$3"
    local g e
    g="$(eval "$git_cmd" 2>/dev/null | sort)"
    e="$(eval "$engine_cmd" 2>/dev/null | grep -v '^# ' | cut -f2 | sort)"
    if [ -z "$g" ]; then
        # Comparaison vide = comparaison sans valeur : on la refuse.
        echo "VIDE $label (git ne renvoie rien : la comparaison serait vide)"
        STATUS=1
        return
    fi
    if [ "$g" = "$e" ]; then
        echo "OK   $label"
        echo "$g" | sed 's/^/       /'
    else
        echo "DIFF $label"
        echo "--- git ---";     echo "$g" | sed 's/^/       /'
        echo "--- pickaxe ---"; echo "$e" | sed 's/^/       /'
        STATUS=1
    fi
}

CLI="$JAVA -cp $CP:$BUILD com.tgglabs.pickaxe.engine.PickaxeCli"

compare "git log -S '$NEEDLE'" \
    "git -C '$WORK' log --all --format=%s -S'$NEEDLE'" \
    "$CLI '$WORK' STRING '$NEEDLE'"

compare "git log -S '$UNICODE'" \
    "git -C '$WORK' log --all --format=%s -S'$UNICODE'" \
    "$CLI '$WORK' STRING '$UNICODE'"

compare "git log -G '$REGEX'" \
    "git -C '$WORK' log --all --format=%s -G'$REGEX'" \
    "$CLI '$WORK' REGEX '$REGEX'"

compare "git log -S '$NEEDLE' --text (binaires inclus)" \
    "git -C '$WORK' log --all --format=%s --text -S'$NEEDLE'" \
    "$CLI '$WORK' STRING '$NEEDLE' '' true"

compare "git log -S '$NEEDLE' -- src/config.py" \
    "git -C '$WORK' log --all --format=%s -S'$NEEDLE' -- src/config.py" \
    "$CLI '$WORK' STRING '$NEEDLE' 'config\.py'"

compare "git log -G '$NEEDLE'" \
    "git -C '$WORK' log --all --format=%s -G'$NEEDLE'" \
    "$CLI '$WORK' REGEX '$NEEDLE'"

if [ $STATUS -eq 0 ]; then
    echo "=== RESULTAT : le moteur concorde avec git sur les 6 requetes ==="
else
    echo "=== RESULTAT : DIFFERENCES ===" >&2
fi
exit $STATUS
