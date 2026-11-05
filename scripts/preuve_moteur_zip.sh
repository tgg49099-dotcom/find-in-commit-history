#!/usr/bin/env bash
# =============================================================================
# preuve_moteur_zip.sh — PREUVE FONCTIONNELLE avec le moteur CONTENU DANS LE
# ZIP LIVRE.
#
# Les tests unitaires ne suffisent pas (consigne du 05/11/2026, §4) : ce
# script prend les JARS DU ZIP DE DISTRIBUTION (pas le code source), les
# charge dans une JVM, et cherche une chaine dans un depot Git reel. Le
# resultat est compare au VRAI `git log -S`.
#
# AUCUN reseau, 0 $, aucune publication.
#
# Usage :
#   bash scripts/preuve_moteur_zip.sh [chemin/vers/le.zip] [depot] [chaine]
#
# Code de sortie : 0 si le moteur du ZIP trouve EXACTEMENT les memes commits
# que `git log -S`, 1 sinon, 3 si l'environnement est incomplet.
# =============================================================================
set -u

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(cd "$HERE/.." && pwd)"
BUILD="$ROOT/build"

ZIP="${1:-$ROOT/build/distributions/FindinCommitHistory-0.0.1.zip}"
REPO="${2:-$BUILD/demo-project}"
NEEDLE="${3:-pi3rre-magique-7749}"

# ---------------------------------------------------------------- Java ------
JAVAC=""; JAVA=""
if [ -n "${JAVA_HOME:-}" ] && [ -x "${JAVA_HOME}/bin/javac" ]; then
    JAVAC="$JAVA_HOME/bin/javac"; JAVA="$JAVA_HOME/bin/java"
elif command -v javac >/dev/null 2>&1; then
    JAVAC="$(command -v javac)"; JAVA="$(command -v java)"
elif [ -x /work/tools/jdk-21.0.12.1+1/bin/javac ]; then
    JAVAC=/work/tools/jdk-21.0.12.1+1/bin/javac
    JAVA=/work/tools/jdk-21.0.12.1+1/bin/java
fi
[ -z "$JAVAC" ] && { echo "ERREUR : aucun JDK. Renseignez JAVA_HOME." >&2; exit 3; }

[ -f "$ZIP" ] || { echo "ERREUR : ZIP introuvable : $ZIP" >&2; exit 3; }

echo "=== PREUVE FONCTIONNELLE DU MOTEUR CONTENU DANS LE ZIP LIVRE ==="
echo "Date        : $(date -u '+%Y-%m-%dT%H:%M:%SZ')"
echo "ZIP         : $ZIP ($(stat -c%s "$ZIP") octets)"
echo "sha256      : $(sha256sum "$ZIP" | cut -d' ' -f1)"
echo "Depot       : $REPO"
echo "Chaine      : $NEEDLE"

# --------------------------------------------------- depot de demonstration --
if [ ! -d "$REPO/.git" ]; then
    echo "--- creation du depot de demonstration ---"
    rm -rf "$REPO"; mkdir -p "$REPO/src"
    (
        cd "$REPO" || exit 3
        git init -q -b main .
        git config user.email "demo@example.org"; git config user.name "Demo"
        printf 'def main():\n    print("hello")\n' > src/app.py
        printf 'TOKEN = "pi3rre-magique-7749"\nTIMEOUT = 30\n' > src/config.py
        git add -A && git commit -q -m "feat: add the configuration file"
        printf 'TOKEN = "pi3rre-magique-7749"  # noqa\nTIMEOUT = 30\n' > src/config.py
        git add -A && git commit -q -m "style: annotate the token line"
        printf 'TIMEOUT = 30\n' > src/config.py
        git add -A && git commit -q -m "fix: remove the token line"
    ) || exit 3
fi

# ------------------------------------------- les jars DU ZIP (pas les sources) --
WORK="$BUILD/preuve-moteur-zip"
rm -rf "$WORK"; mkdir -p "$WORK"
unzip -q "$ZIP" -d "$WORK" || exit 3
LIBDIR="$(find "$WORK" -type d -name lib | head -1)"
CP=""
for j in "$LIBDIR"/*.jar; do
    case "$(basename "$j")" in
        *searchableOptions*) continue ;;
    esac
    CP="$CP:$j"
done
# slf4j-api : fourni par la PLATEFORME dans l'IDE (lib/util-8.jar) ; hors IDE
# on l'ajoute pour que JGit trouve LoggerFactory. Il n'est PAS dans le ZIP.
SLF4J="$ROOT/libs/slf4j-api-2.0.13.jar"
[ -f "$SLF4J" ] && CP="$CP:$SLF4J"
CP="${CP#:}"
echo "Jars du ZIP : $(ls "$LIBDIR" | tr '\n' ' ')"
echo "Classpath   : $CP"

# ------------------------------------------------------------- le pilote ----
cat > "$WORK/Driver.java" <<'EOF'
import com.tgglabs.pickaxe.engine.*;
import org.eclipse.jgit.lib.Repository;
import org.eclipse.jgit.storage.file.FileRepositoryBuilder;
import java.nio.file.*;
import java.util.*;

public class Driver {
    public static void main(String[] args) throws Exception {
        Path root = Paths.get(args[0]);
        String needle = args[1];
        try (Repository repo = new FileRepositoryBuilder()
                .setGitDir(root.resolve(".git").toFile())
                .readEnvironment().findGitDir().build()) {
            PickaxeEngine engine = new PickaxeEngine(repo);
            PickaxeQuery query = PickaxeQuery.builder(PickaxeMode.STRING, needle).build();
            List<PickaxeHit> hits = engine.search(query);
            for (PickaxeHit h : hits) {
                System.out.println(h.getShortId() + "\t" + h.getSubject() + "\t"
                        + String.join(",", h.getPaths()));
            }
            System.out.println("# " + hits.size() + " commit(s)");
        }
    }
}
EOF

echo "--- compilation du pilote CONTRE LES JARS DU ZIP ---"
"$JAVAC" -encoding UTF-8 --release 17 -nowarn -cp "$CP" -d "$WORK" "$WORK/Driver.java" || {
    echo "ECHEC : compilation du pilote" >&2; exit 1; }

echo "--- 1. moteur du ZIP livre ---"
# stderr a part : l'avertissement SLF4J hors IDE ("No SLF4J providers were
# found") ne doit pas polluer la comparaison des listes de commits.
"$JAVA" -cp "$CP:$WORK" Driver "$REPO" "$NEEDLE" 2>"$WORK/stderr-moteur.txt" \
    | tee "$WORK/resultat-moteur.txt"
echo "--- stderr du moteur (avertissements, hors resultat) ---"
sed 's/^/    /' "$WORK/stderr-moteur.txt"

echo "--- 2. controle : le vrai git log -S ---"
git -C "$REPO" log --oneline --format='%h%x09%s' -S"$NEEDLE" > "$WORK/resultat-git.txt" 2>&1
cat "$WORK/resultat-git.txt"

echo "--- 3. comparaison ---"
# On compare les identifiants de commit, dans l'ordre.
MINE=$(grep -v '^#' "$WORK/resultat-moteur.txt" | cut -f1)
THEIRS=$(cut -f1 "$WORK/resultat-git.txt")
if [ "$MINE" = "$THEIRS" ] && [ -n "$MINE" ]; then
    echo "OK : le moteur du ZIP livre trouve EXACTEMENT les memes commits que 'git log -S'"
    echo "     ($(printf '%s' "$MINE" | grep -c . ) commit(s))"
    echo "FIN preuve_moteur_zip.sh statut=0"
    exit 0
fi
echo "ECHEC : listes differentes" >&2
echo "--- moteur ---" >&2; printf '%s\n' "$MINE" >&2
echo "--- git ---" >&2;    printf '%s\n' "$THEIRS" >&2
echo "FIN preuve_moteur_zip.sh statut=1" >&2
exit 1
