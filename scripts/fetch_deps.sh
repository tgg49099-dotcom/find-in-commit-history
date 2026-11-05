#!/usr/bin/env bash
# =============================================================================
# fetch_deps.sh — telecharge les dependances de TEST dans `libs/`.
#
# Ces jarots ne sont PAS livres dans le plugin : ils servent uniquement a
# compiler et executer les tests hors IDE.
#
#   - org.eclipse.jgit 6.10.1.202505221210-r : la version de JGit utilisee
#     par l'IDE 2026.2.4 (mesure : 1 594 classes communes sur 1 597) ;
#   - JavaEWAH 1.1.12 : dependance de JGit pour l'ecriture des packs ;
#   - junit-platform-console-standalone 1.10.2 : la console de test.
#
# Code de sortie : 0 si tout est present (telecharge ou deja la).
# =============================================================================
set -u

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(cd "$HERE/.." && pwd)"
LIBS="$ROOT/libs"
mkdir -p "$LIBS"

download() {
    local url="$1"
    local target="$2"
    if [ -f "$target" ]; then
        echo "deja present : $(basename "$target")"
        return 0
    fi
    echo "telechargement : $(basename "$target")"
    if command -v curl >/dev/null 2>&1; then
        curl -sSfL -o "$target" "$url"
    else
        wget -q -O "$target" "$url"
    fi
}

download "https://repo1.maven.org/maven2/org/eclipse/jgit/org.eclipse.jgit/6.10.1.202505221210-r/org.eclipse.jgit-6.10.1.202505221210-r.jar" \
         "$LIBS/org.eclipse.jgit-6.10.1.202505221210-r.jar"
download "https://repo1.maven.org/maven2/com/googlecode/javaewah/JavaEWAH/1.1.12/JavaEWAH-1.1.12.jar" \
         "$LIBS/JavaEWAH-1.1.12.jar"
# slf4j-api : JGit en a besoin. Dans l'IDE, c'est la plateforme qui la
# fournit (lib/util-8.jar, 49 classes org/slf4j) ; ici on la prend a part
# pour que les tests tournent hors IDE.
download "https://repo1.maven.org/maven2/org/slf4j/slf4j-api/2.0.13/slf4j-api-2.0.13.jar" \
         "$LIBS/slf4j-api-2.0.13.jar"
download "https://repo1.maven.org/maven2/org/junit/platform/junit-platform-console-standalone/1.10.2/junit-platform-console-standalone-1.10.2.jar" \
         "$LIBS/junit-platform-console-standalone-1.10.2.jar"

echo "=== contenu de libs/ ==="
ls -la "$LIBS"
