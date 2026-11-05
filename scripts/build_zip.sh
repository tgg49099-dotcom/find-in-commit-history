#!/usr/bin/env bash
# =============================================================================
# build_zip.sh — construit le ZIP du plugin pickaxe SANS reseau.
#
# Pourquoi pas Gradle ? Le build Gradle (IntelliJ Platform Plugin 2.7.2)
# telecharge et extrait PyCharm Professional 2024.3 (6 Go dans
# ~/.gradle/caches/8.10.2/transforms) : c'est plus de 6 Go pour un artefact
# de 4 Mo, et le conteneur n'a que 7,9 Go libres (mesure du 05/11 08:22).
#
# Ce script fait la meme chose, en compilant CONTRE L'IDE EXACT
# (l IDE de compilation = build 262.11879.98) :
#   - le jar du plugin   : classes + META-INF/plugin.xml ;
#   - le ZIP             : <Nom du plugin>/lib/{plugin.jar, jgit.jar, javaewah.jar}
# exactement comme le fait Gradle.
#
# Contrainte de la consigne du 05/11 08:35 : slf4j-api NE DOIT PAS etre
# embarque (la plateforme le fournit : lib/util-8.jar). Ce script ne le copie
# donc jamais ; le controle est fait a la fin, sur le contenu du ZIP.
#
# Code de sortie : 0 si le ZIP est conforme, 1 sinon.
# =============================================================================
set -u

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(cd "$HERE/.." && pwd)"
IDE="${IDE:-$ROOT/../ide/pycharm-2026.2.4}"
OUT="${1:-$ROOT/build/distributions}"
VERSION="$(grep -E '^pluginVersion' "$ROOT/gradle.properties" | cut -d= -f2 | tr -d ' ')"
NAME="$(grep -E '^pluginName' "$ROOT/gradle.properties" | cut -d= -f2 | tr -d ' ')"
BUILD="$ROOT/build/zip"

mkdir -p "$OUT" "$BUILD"

# ---------------------------------------------------------------- Java ------
# Le JBR embarque dans l'IDE (JDK 25.0.4.1) est UTILISE par defaut : les
# jars de la plateforme 2026.2 sont en version de class file 69 (Java 25),
# que seul un javac 25 sait lire. Le bytecode PRODUIT reste en Java 17
# (--release 17), comme l'exige la plateforme pour since-build 243.
if [ -x "$IDE/jbr/bin/javac" ]; then
    JAVAC="$IDE/jbr/bin/javac"; JAVA="$IDE/jbr/bin/java"
elif [ -n "${JAVA_HOME:-}" ] && [ -x "${JAVA_HOME}/bin/javac" ]; then
    JAVAC="$JAVA_HOME/bin/javac"; JAVA="$JAVA_HOME/bin/java"
elif command -v javac >/dev/null 2>&1; then
    JAVAC="$(command -v javac)"; JAVA="$(command -v java)"
else
    for candidate in /usr/lib/jvm/*/bin/javac; do
        if [ -x "$candidate" ]; then JAVAC="$candidate"; JAVA="$(dirname "$candidate")/java"; break; fi
    done
fi
if [ -z "${JAVAC:-}" ]; then echo "ERREUR : aucun JDK trouve" >&2; exit 1; fi

echo "=== 1. environnement ==="
echo "javac  : $($JAVAC -version 2>&1)"
echo "IDE    : $IDE"
if [ -f "$IDE/build.txt" ]; then echo "build  : $(tr '\n' ' ' < "$IDE/build.txt")"; fi
echo "version: $VERSION"

# ------------------------------------------- classpath de la PLATEFORME ------
# ATTENTION (revue du jury, 05/11) : le classpath de compilation ne doit
# contenir QUE lib/*.jar du IDE + les deux jars embarques (JGit, JavaEWAH).
# Les plugins/*/lib/*.jar du IDE ne sont PAS dans le classpath runtime d'un
# plugin tiers : y mettre une classe d'un plugin tiers ferait compiler le
# code, puis planter a l'execution (NoClassDefFoundError).
PLAT=""
for j in "$IDE"/lib/*.jar; do
    [ -f "$j" ] && PLAT="$PLAT:$j"
done
PLAT="${PLAT#:}"
if [ -z "$PLAT" ]; then echo "ERREUR : aucun jar de plateforme dans $IDE/lib" >&2; exit 1; fi
echo "jars de plateforme : $(echo "$PLAT" | tr ':' '\n' | wc -l)"

# ------------------------------------------- JGit + JavaEWAH ---------------
JGIT="$ROOT/libs/org.eclipse.jgit-6.10.1.202505221210-r.jar"
EWAH="$ROOT/libs/JavaEWAH-1.1.12.jar"
for j in "$JGIT" "$EWAH"; do
    [ -f "$j" ] || { echo "ERREUR : jar manquant : $j" >&2; exit 1; }
done
# slf4j n'est PAS dans le classpath de compilation : le code ne doit pas
# l'utiliser (la plateforme le fournit au runtime).
CP="$PLAT:$JGIT:$EWAH"

# ------------------------------------------- compilation --------------------
echo
echo "=== 2. compilation du plugin contre l'IDE exact ==="
rm -rf "$BUILD/classes" "$BUILD/jar"
mkdir -p "$BUILD/classes" "$BUILD/jar/META-INF"
find "$ROOT/src/main/java" -name "*.java" > "$BUILD/sources.txt"
echo "sources : $(wc -l < "$BUILD/sources.txt")"
"$JAVAC" -encoding UTF-8 --release 17 -nowarn -cp "$CP" -d "$BUILD/classes" @"$BUILD/sources.txt" \
    || { echo "ECHEC : compilation" >&2; exit 1; }
echo "OK : compilation reussie"

# ------------------------------------------- jar ---------------------------
cp "$ROOT/src/main/resources/META-INF/plugin.xml" "$BUILD/jar/META-INF/plugin.xml"
JAR_TOOL=""
for candidate in "$IDE/jbr/bin/jar" "$(dirname "$JAVAC")/jar" \
                 "$ROOT"/../tools/jdk-*/bin/jar "$(command -v jar 2>/dev/null || true)"; do
    if [ -n "$candidate" ] && [ -x "$candidate" ]; then JAR_TOOL="$candidate"; break; fi
done
if [ -z "$JAR_TOOL" ]; then echo "ERREUR : outil 'jar' introuvable" >&2; exit 1; fi
echo "jar tool : $JAR_TOOL"
# Horodatage FIXE dans le jar (option --date du JDK 17+) : deux constructions
# du meme code donnent le meme jar, donc le meme ZIP. C'est ce que fait la
# recette Gradle officielle (isPreserveFileTimestamps = false).
JAR_DATE_OPT=""
if "$JAR_TOOL" --help 2>&1 | grep -q -- '--date'; then
    JAR_DATE_OPT="--date 1980-02-01T00:00:00Z"
    echo "jar : horodatage fixe (--date 1980-02-01T00:00:00Z)"
else
    echo "jar : ATTENTION, option --date absente -> le jar ne sera pas reproductible"
fi
PLUGIN_JAR="$BUILD/$NAME-$VERSION.jar"
rm -f "$PLUGIN_JAR"
( cd "$BUILD/classes" && "$JAR_TOOL" --create $JAR_DATE_OPT --file "$PLUGIN_JAR" . ) \
    || { echo "ECHEC : creation du jar" >&2; exit 1; }
"$JAR_TOOL" --update $JAR_DATE_OPT --file "$PLUGIN_JAR" -C "$ROOT/src/main/resources" META-INF/plugin.xml \
    || { echo "ECHEC : ajout du plugin.xml dans le jar" >&2; exit 1; }
echo "jar du plugin : $PLUGIN_JAR ($(stat -c%s "$PLUGIN_JAR") octets)"
echo "--- contenu du jar ---"
"$JAR_TOOL" --list --file "$PLUGIN_JAR" | sed 's/^/    /'

# ------------------------------------------- ZIP ---------------------------
echo
echo "=== 3. assemblage du ZIP ==="
STAGE="$BUILD/stage"
rm -rf "$STAGE"
mkdir -p "$STAGE/$NAME/lib"
cp "$PLUGIN_JAR" "$STAGE/$NAME/lib/"
cp "$JGIT" "$STAGE/$NAME/lib/"
cp "$EWAH" "$STAGE/$NAME/lib/"
# Horodatage FIXE de tous les fichiers de l'archive (le plus ancien horodatage
# DOS representable) : le ZIP ne depend plus de l'heure de la construction.
find "$STAGE" -exec touch -t 198002010000 {} +
ZIP="$OUT/$NAME-$VERSION.zip"
rm -f "$ZIP"
# Liste TRIEE des entrees (repertoires + fichiers) : l'ordre de `zip -r`
# depend du ordre de lecture du systeme de fichiers, donc il n'est pas
# reproductible. Ici, l'ordre est impose.
( cd "$STAGE" && { find "$NAME" -type d; find "$NAME" -type f; } | LC_ALL=C sort | zip -q -X "$ZIP" -@ ) \
    || { echo "ECHEC : creation du ZIP" >&2; exit 1; }
echo "ZIP : $ZIP"
echo "taille : $(stat -c%s "$ZIP") octets ($(du -h "$ZIP" | cut -f1))"

# ------------------------------------------- controles ---------------------
echo
echo "=== 4. CONTROLE du contenu du ZIP ==="
STATUS=0
echo "--- listing ---"
unzip -l "$ZIP" | sed 's/^/    /'

echo "--- slf4j ABSENT ? ---"
if unzip -l "$ZIP" | grep -qi "slf4j"; then
    echo "    ECHEC : slf4j est DANS le ZIP"
    STATUS=1
else
    echo "    OK : aucun jar slf4j dans le ZIP"
fi

echo "--- JGit EMBARQUE ? ---"
if unzip -l "$ZIP" | grep -q "org.eclipse.jgit-6.10.1.202505221210-r.jar"; then
    echo "    OK : JGit 6.10.1 est embarque"
else
    echo "    ECHEC : JGit n'est pas dans le ZIP"
    STATUS=1
fi

echo "--- JavaEWAH embarque ? ---"
if unzip -l "$ZIP" | grep -q "JavaEWAH-1.1.12.jar"; then
    echo "    OK : JavaEWAH 1.1.12 est embarque"
else
    echo "    ECHEC : JavaEWAH n'est pas dans le ZIP"
    STATUS=1
fi

echo "--- nombre de jars dans lib/ (attendu : 3) ---"
NB=$(unzip -l "$ZIP" | grep -c "\.jar$")
echo "    $NB jar(s)"
[ "$NB" -eq 3 ] || { echo "    ECHEC : attendu 3 jars"; STATUS=1; }

echo "--- dependance a un plugin DESACTIVABLE de l'IDE ? ---"
# Un plugin tiers ne voit pas le classpath de la plateforme : le seul moyen
# d'y acceder est de declarer une dependance a un plugin de l'IDE.
DEPS=$(grep -oE "<depends>[^<]*</depends>|<depends optional=\"[^\"]*\">[^<]*</depends>" \
       "$ROOT/src/main/resources/META-INF/plugin.xml" | tr '\n' ' ')
echo "    depends : ${DEPS:-<aucun declare>}"
if echo "$DEPS" | grep -qi "settingsSync"; then
    echo "    ECHEC : dependance a com.intellij.settingsSync"
    STATUS=1
else
    echo "    OK : aucune dependance a un plugin desactivable (settingsSync absent)"
fi

echo "--- sha256 de chaque fichier du ZIP ---"
rm -rf "$BUILD/verify"; mkdir -p "$BUILD/verify"
( cd "$BUILD/verify" && unzip -q -o "$ZIP" )
find "$BUILD/verify" -type f | sort | while read -r f; do
    printf "    %s  %10d  %s\n" "$(sha256sum "$f" | cut -d' ' -f1)" "$(stat -c%s "$f")" "${f#$BUILD/verify/}"
done

echo
if [ "$STATUS" -eq 0 ]; then
    echo "=== RESULTAT : ZIP CONFORME ==="
else
    echo "=== RESULTAT : ZIP NON CONFORME ===" >&2
fi
exit $STATUS
