#!/usr/bin/env bash
# =============================================================================
# preuve_worktree_zip.sh — PREUVE « worktree » AVEC LE MOTEUR CONTENU DANS LE
# ZIP LIVRE.
#
# Un worktree (`git worktree add`) a un `.git` qui est un FICHIER, et ses
# references vivent dans le depot COMMUN. Un lecteur qui ouvre le repertoire
# du worktree ne voit ni HEAD ni aucune reference : la recherche rend alors
# ZERO resultat, silencieusement.
#
# Ce script monte un vrai worktree, puis interroge le moteur **des jars du ZIP
# de distribution** (donc le code livre) et compare avec le vrai
# `git log -S` sur le meme worktree.
#
# AUCUN reseau, 0 $, aucune publication.
#
# Usage :
#   bash scripts/preuve_worktree_zip.sh [chemin/vers/le.zip]
#
# Code de sortie : 0 si le moteur du ZIP trouve EXACTEMENT les memes commits
# que `git log -S` dans le worktree, 1 sinon, 3 si l'environnement est
# incomplet.
# =============================================================================
set -u

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(cd "$HERE/.." && pwd)"
BUILD="$ROOT/build"

ZIP="${1:-$ROOT/build/distributions/FindinCommitHistory-0.0.1.zip}"
WORK="$BUILD/preuve-worktree-zip"
DEMO="$BUILD/demo-worktree"
NEEDLE="pi3rre-magique-7749"

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
command -v git >/dev/null 2>&1 || { echo "ERREUR : le binaire git est necessaire." >&2; exit 3; }

echo "=== PREUVE « WORKTREE » AVEC LE MOTEUR CONTENU DANS LE ZIP LIVRE ==="
echo "Date        : $(date -u '+%Y-%m-%dT%H:%M:%SZ')"
echo "ZIP         : $ZIP ($(stat -c%s "$ZIP") octets)"
echo "sha256      : $(sha256sum "$ZIP" | cut -d' ' -f1)"

# --------------------------------------------------- le worktree de test ----
if [ ! -f "$DEMO/wt/.git" ]; then
    echo "--- creation du depot + du worktree ---"
    rm -rf "$DEMO"; mkdir -p "$DEMO/repo"
    (
        cd "$DEMO/repo" || exit 3
        git init -q -b main .
        git config user.email "demo@example.org"; git config user.name "Demo"
        printf 'def main():\n    print("hello")\n' > app.py
        git add -A && git commit -q -m "init: add app"
        git checkout -q -b feature
        printf 'TOKEN = "pi3rre-magique-7749"\nTIMEOUT = 30\n' > config.py
        git add -A && git commit -q -m "feat: add the configuration file"
        git checkout -q main
        git worktree add -q "$DEMO/wt" feature
    ) || exit 3
fi
echo "worktree    : $DEMO/wt"
echo "  .git      : $(cat "$DEMO/wt/.git")"
echo "  commondir : $(cat "$DEMO/repo/.git/worktrees/wt/commondir" 2>/dev/null)"
echo "  refs du depot commun : $(git -C "$DEMO/repo" for-each-ref --format='%(refname)' | tr '\n' ' ')"

# ------------------------------------------- les jars DU ZIP (pas les sources) --
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
SLF4J="$ROOT/libs/slf4j-api-2.0.13.jar"
[ -f "$SLF4J" ] && CP="$CP:$SLF4J"
CP="${CP#:}"
echo "Jars du ZIP : $(ls "$LIBDIR" | tr '\n' ' ')"

# ------------------------------------------------------------- le pilote ----
cat > "$WORK/Driver.java" <<'EOF'
import com.tgglabs.pickaxe.engine.*;
import org.eclipse.jgit.lib.Repository;
import java.nio.file.*;
import java.util.*;

/** Appelle EXACTEMENT le chemin du produit : PickaxeRepository.open(racine). */
public class Driver {
    public static void main(String[] args) throws Exception {
        Path root = Paths.get(args[0]);
        String needle = args[1];
        try (Repository repo = PickaxeRepository.open(root)) {
            System.out.println("# getDirectory() = " + repo.getDirectory());
            System.out.println("# getWorkTree()  = " + repo.getWorkTree());
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

echo "--- 1. moteur du ZIP livre, DANS LE WORKTREE ---"
"$JAVA" -cp "$CP:$WORK" Driver "$DEMO/wt" "$NEEDLE" 2>"$WORK/stderr-moteur.txt" \
    | tee "$WORK/resultat-moteur.txt"
echo "--- stderr du moteur (avertissements, hors resultat) ---"
sed 's/^/    /' "$WORK/stderr-moteur.txt"

echo "--- 2. controle : le vrai git log -S DANS LE WORKTREE ---"
git -C "$DEMO/wt" log --oneline --format='%h%x09%s' -S"$NEEDLE" > "$WORK/resultat-git.txt" 2>&1
cat "$WORK/resultat-git.txt"

echo "--- 3. comparaison ---"
MINE=$(grep -v '^#' "$WORK/resultat-moteur.txt" | cut -f1)
THEIRS=$(cut -f1 "$WORK/resultat-git.txt")
if [ "$MINE" = "$THEIRS" ] && [ -n "$MINE" ]; then
    echo "OK : le moteur du ZIP livre trouve EXACTEMENT les memes commits que"
    echo "     'git log -S' DANS LE WORKTREE ($(printf '%s' "$MINE" | grep -c . ) commit(s))"
    echo "FIN preuve_worktree_zip.sh statut=0"
    exit 0
fi
echo "ECHEC : listes differentes" >&2
echo "--- moteur ---" >&2; printf '%s\n' "$MINE" >&2
echo "--- git ---" >&2;    printf '%s\n' "$THEIRS" >&2
echo "FIN preuve_worktree_zip.sh statut=1" >&2
exit 1
