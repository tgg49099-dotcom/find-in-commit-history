#!/usr/bin/env bash
# =============================================================================
# preflight_local.sh — RECONSTITUTION LOCALE du controle de PRE-VOL JetBrains.
#
# AVERTISSEMENT HONNETE : le script OFFICIEL du serveur
# (`/consignes/SAVOIR/preflight/jetbrains.sh`) n'est PAS present dans ce
# conteneur au 05/11/2026 13:45 (controle : `ls /consignes/SAVOIR/preflight/`
# -> « No such file or directory »). Ce fichier est donc une RECONSTITUTION,
# ecrite critere par critere d'apres les criteres annonces par la mere dans
# `/consignes/INSTRUCTIONS.md` du 05/11/2026 12:59 (section 2) :
#
#   - `plugin.xml` trouve ;
#   - `<depends>` present ;
#   - `<description>` present ;
#   - PAS de `<license>` racine ;
#   - pas d'`until-build` excluant les IDE recents ;
#   - aucun `TODO` / `FIXME` / `placeholder` dans `src` ;
#   - un ZIP dans `build/distributions` plus RECENT que les sources ;
#   - nom public <= 30 caracteres, sans « plugin » / « intellij » / « jetbrains » ;
#   - `<change-notes>` non vide ;
#   - `pluginIcon.svg` ET `pluginIcon_dark.svg`, 40x40 ;
#   - images >= 1200x760 si un dossier `media/` existe ;
#   - md5 du ZIP coherent avec la documentation ;
#   - aucune mutation « contre » dans les sources.
#
# REGLE FONDAMENTALE (corrigee le 05/11/2026 14:2x apres relecture hostile) :
# les verifications de contenu portent sur le DESCIPTEUR LIVRE
# (`META-INF/plugin.xml` extrait du JAR contenu dans le ZIP livre), et non
# sur le fichier source. C'est le descripteur livre que le Marketplace lit ;
# `patchPluginXml` le reecrit (version, vendor, idea-version...) et c'est
# donc lui qui doit etre valide.
#
# Usage : bash scripts/preflight_local.sh [/chemin/vers/le/projet]
# Code de retour : 0 si et seulement si 0 ECHEC.
# =============================================================================
set -u

RACINE_SCRIPT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="${1:-$(cd "$RACINE_SCRIPT/.." && pwd)}"
ECHECS=0
OKS=0
TMP="$(mktemp -d /tmp/preflight.XXXXXX)"
trap 'rm -rf "$TMP"' EXIT

echec() { echo "ECHEC : $*"; ECHECS=$((ECHECS + 1)); }
ok()    { echo "OK    : $*"; OKS=$((OKS + 1)); }
info()  { echo "NOTE   : $*"; }

echo "=== CONTROLE DE PRE-VOL (reconstitution locale) — $ROOT ==="
echo "date : $(date '+%Y-%m-%d %H:%M:%S %Z')"
echo

# ------------------------------------------------------- 1. projet ----------
if [ ! -d "$ROOT" ]; then
    echec "projet introuvable : $ROOT"
    echo
    echo "FIN preflight : $ECHECS ECHEC"
    exit 1
fi
ok "projet : $ROOT"

PLUGIN_XML=""
for c in "$ROOT/src/main/resources/META-INF/plugin.xml" "$ROOT/src/main/resources/plugin.xml"; do
    [ -f "$c" ] && PLUGIN_XML="$c" && break
done
if [ -z "$PLUGIN_XML" ]; then
    echec "plugin.xml introuvable dans src/main/resources"
    echo
    echo "FIN preflight : $ECHECS ECHEC"
    exit 1
fi
ok "plugin.xml source trouve : $PLUGIN_XML"

# version et nom attendus (gradle.properties)
GRADLE_PROPS="$ROOT/gradle.properties"
PLUGIN_VERSION=""; PLUGIN_NAME_GRADLE=""
if [ -f "$GRADLE_PROPS" ]; then
    PLUGIN_VERSION="$(sed -n 's/^pluginVersion[[:space:]]*=[[:space:]]*//p' "$GRADLE_PROPS" | head -1 | tr -d '[:space:]')"
    PLUGIN_NAME_GRADLE="$(sed -n 's/^pluginName[[:space:]]*=[[:space:]]*//p' "$GRADLE_PROPS" | head -1 | tr -d '[:space:]')"
fi
[ -n "$PLUGIN_VERSION" ] && ok "pluginVersion (gradle.properties) : $PLUGIN_VERSION" \
    || info "pluginVersion absente de gradle.properties"
[ -n "$PLUGIN_NAME_GRADLE" ] && ok "pluginName (gradle.properties) : $PLUGIN_NAME_GRADLE" \
    || info "pluginName absent de gradle.properties"

# ------------------------------------------------------- 2. ZIP ------------
# On ne prend pas « le plus recent » : on prend celui qui correspond au
# nom et a la version annonces, sinon on echoue explicitement.
ZIP=""
LISTE_ZIPS="$(ls -1 "$ROOT"/build/distributions/*.zip 2>/dev/null || true)"
if [ -z "$LISTE_ZIPS" ]; then
    echec "aucun ZIP dans build/distributions"
else
    if [ -n "$PLUGIN_NAME_GRADLE" ] && [ -n "$PLUGIN_VERSION" ]; then
        ATTENDU="$(echo "$PLUGIN_NAME_GRADLE" | tr -d '[:space:]')-$PLUGIN_VERSION.zip"
        for z in $LISTE_ZIPS; do
            [ "$(basename "$z")" = "$ATTENDU" ] && ZIP="$z" && break
        done
    fi
    if [ -z "$ZIP" ] && [ "$(printf '%s\n' $LISTE_ZIPS | wc -l)" -eq 1 ]; then
        ZIP="$(printf '%s\n' $LISTE_ZIPS | head -1)"
    fi
    if [ -z "$ZIP" ]; then
        echec "aucun ZIP ne correspond au nom et a la version annonces (fichiers : $(echo "$LISTE_ZIPS" | tr '\n' ' '))"
    else
        ok "ZIP retenu : $(basename "$ZIP") ($(stat -c%s "$ZIP") octets)"
    fi
fi

# ------------------------------------------------------- 3. jar du plugin ---
# Le jar a inspecter est celui qui CONTIENT `META-INF/plugin.xml` : pas
# « le premier lib/*.jar », qui pourrait etre une dependance.
JAR_DANS_ZIP=""; TMPJAR=""
if [ -n "$ZIP" ]; then
    for j in $(unzip -Z1 "$ZIP" 2>/dev/null | grep -E "lib/[^/]+\.jar$" | grep -v searchableOptions); do
        TMPJAR="$TMP/plugin.jar"
        unzip -p "$ZIP" "$j" > "$TMPJAR" 2>/dev/null || continue
        if unzip -Z1 "$TMPJAR" 2>/dev/null | grep -q "^META-INF/plugin.xml$"; then
            JAR_DANS_ZIP="$j"
            break
        fi
    done
    if [ -z "$JAR_DANS_ZIP" ]; then
        echec "aucun jar du plugin (contenant META-INF/plugin.xml) dans le ZIP livre"
    else
        ok "jar du plugin : $JAR_DANS_ZIP"
    fi
fi

# ------------------------------- 4. descripteur LIVRE (le vrai) ----------
XML_OUT=""
XML_DELIVRE=""
if [ -n "$JAR_DANS_ZIP" ]; then
    unzip -p "$TMPJAR" META-INF/plugin.xml > "$TMP/plugin.xml" 2>/dev/null || true
    XML_DELIVRE="$TMP/plugin.xml"
fi

if [ -z "$XML_DELIVRE" ] || [ ! -s "$XML_DELIVRE" ]; then
    echec "plugin.xml absent du jar du ZIP livre"
    echo
    echo "FIN preflight : $ECHECS ECHEC"
    exit 1
fi
ok "descripteur livré extrait : META-INF/plugin.xml du jar du ZIP ($(stat -c%s "$XML_DELIVRE") octets)"

XML_OUT="$(python3 -I - "$XML_DELIVRE" <<'PY'
import sys, xml.etree.ElementTree as ET
p = sys.argv[1]
try:
    r = ET.parse(p).getroot()
except Exception as e:
    print("PARSE_ERROR=" + str(e))
    sys.exit(2)
def txt(tag):
    e = r.find(tag)
    return (e.text or "").strip() if e is not None else ""
name = txt("name")
desc = txt("description")
cn = r.find("change-notes")
change = (cn.text or "").strip() if cn is not None else ""
# <depends> peut etre vide en texte mais contenir des <module>/<config-file>
deps = []
for d in r.findall("depends"):
    children = [c for c in d if c.tag]
    label = (d.text or "").strip()
    if not label:
        label = ",".join("%s:%s" % (c.tag, (c.get("name") or c.get("file") or "")) for c in children)
    deps.append(label if label else "(vide)")
lic = r.find("license")
iv = r.find("idea-version")
until = since = ""
if iv is not None:
    until = (iv.get("until-build") or "").strip()
    since = (iv.get("since-build") or "").strip()
print("NAME=" + name)
print("NAME_LEN=" + str(len(name)))
print("DEPENDS=" + ";".join(deps))
print("DESC_LEN=" + str(len(desc)))
print("CHANGE_LEN=" + str(len(change)))
print("HAS_LICENSE=" + ("1" if lic is not None else "0"))
print("SINCE=" + since)
print("UNTIL=" + until)
print("ID=" + txt("id"))
print("VERSION=" + txt("version"))
PY
)" || XML_OUT=""
if [ -z "$XML_OUT" ] || printf '%s' "$XML_OUT" | grep -q "^PARSE_ERROR="; then
    echec "plugin.xml livre illisible ou mal forme : $XML_OUT"
    echo
    echo "FIN preflight : $ECHECS ECHEC"
    exit 1
fi
getf() { echo "$XML_OUT" | sed -n "s/^$1=//p"; }

NAME="$(getf NAME)"; NAME_LEN="$(getf NAME_LEN)"; DEPENDS="$(getf DEPENDS)"
DESC_LEN="$(getf DESC_LEN)"; CHANGE_LEN="$(getf CHANGE_LEN)"
HAS_LICENSE="$(getf HAS_LICENSE)"; SINCE="$(getf SINCE)"; UNTIL="$(getf UNTIL)"
PLUGIN_ID="$(getf ID)"; VERSION_LIVREE="$(getf VERSION)"

# ------------------------------------------------------- 5. depends --------
if [ -n "$DEPENDS" ]; then
    ok "<depends> présent (descripteur livré) : $DEPENDS"
else
    echec "aucun <depends> dans le plugin.xml livré"
fi

# ------------------------------------------------------- 6. description -----
if [ "${DESC_LEN:-0}" -gt 0 ] 2>/dev/null; then
    ok "<description> présent (${DESC_LEN} caractères, descripteur livré)"
else
    echec "<description> manquant ou vide dans le plugin.xml livré"
fi

# ------------------------------------------------------- 7. license racine --
if [ "$HAS_LICENSE" = "1" ]; then
    echec "<license> racine présent dans le plugin.xml livré (interdit : la licence se déclare sur la fiche)"
else
    ok "pas de <license> racine dans le descripteur livré"
fi

# ------------------------------------------------------- 8. id / version ----
if [ -n "$PLUGIN_ID" ]; then
    ok "id livré : $PLUGIN_ID"
else
    echec "pas de <id> dans le plugin.xml livré"
fi
if [ -n "$PLUGIN_VERSION" ] && [ "$VERSION_LIVREE" != "$PLUGIN_VERSION" ]; then
    echec "version livrée ($VERSION_LIVREE) différente de pluginVersion ($PLUGIN_VERSION)"
elif [ -n "$VERSION_LIVREE" ]; then
    ok "version livrée : $VERSION_LIVREE"
fi

# ------------------------------------------------------- 9. since/until -----
if [ -z "$SINCE" ]; then
    echec "pas de since-build dans le plugin.xml livré"
else
    MAJ_SINCE="$(echo "$SINCE" | sed 's/[^0-9].*//')"
    if [ -z "$MAJ_SINCE" ] || [ "$MAJ_SINCE" -gt 262 ] 2>/dev/null; then
        echec "since-build=$SINCE exclut l'IDE de référence (build 262, PyCharm 2026.2.4)"
    else
        ok "since-build=$SINCE (n'exclut pas l'IDE de référence 262)"
    fi
fi
if [ -n "$UNTIL" ]; then
    MAJ="$(echo "$UNTIL" | sed 's/[^0-9].*//')"
    if [ -n "$MAJ" ] && [ "$MAJ" -lt 262 ] 2>/dev/null; then
        echec "until-build=$UNTIL exclut les IDE recents (2026.2 = 262 et suivants)"
    else
        ok "until-build=$UNTIL n'exclut pas les IDE recents"
    fi
else
    ok "pas d'until-build (aucune borne haute exclue)"
fi

# ------------------------------------------------------- 10. nom public -----
LOWER_NAME="$(echo "$NAME" | tr 'A-Z' 'a-z')"
if [ "${NAME_LEN:-999}" -gt 30 ] 2>/dev/null; then
    echec "nom public trop long : ${NAME_LEN} caracteres (max 30)"
else
    ok "nom public livré : \"$NAME\" (${NAME_LEN} caracteres <= 30)"
fi
for interdit in plugin intellij jetbrains; do
    case "$LOWER_NAME" in
        *"$interdit"*) echec "nom public contient le mot interdit : \"$interdit\"" ;;
    esac
done

# ------------------------------------------------------- 11. change-notes ---
if [ "${CHANGE_LEN:-0}" -gt 0 ] 2>/dev/null; then
    ok "<change-notes> non vide (${CHANGE_LEN} caractères, descripteur livré)"
else
    echec "change-notes manquantes ou vides dans plugin.xml (obligatoires a la revue)"
fi

# ------------------------------------------------------- 12. TODO/FIXME -----
OUT_GREP="$(grep -rniE "TODO|FIXME|placeholder" "$ROOT/src" 2>/dev/null)"
CODE_GREP=$?
if [ "$CODE_GREP" -eq 0 ]; then
    echec "TODO / FIXME / placeholder present dans src"
    printf '%s\n' "$OUT_GREP" | head -5 | sed 's/^/       /'
elif [ "$CODE_GREP" -eq 1 ]; then
    ok "aucun TODO / FIXME / placeholder dans src"
else
    echec "la recherche de TODO / FIXME / placeholder a echoue (grep code $CODE_GREP) : le controle n'est pas fiable"
fi

# ------------------------------------------------------- 13. icones ---------
# Les icones sont verifiees par scripts/controle_icones.py (controle hostile :
# XML strict, 40x40 ecrits dans le fichier, aucune reference externe, traits
# connectes, contraste WCAG, rasterisation). On le lance sur les sources ET
# sur les icones extraites du jar LIVRE.
META="$ROOT/src/main/resources/META-INF"
if [ -f "$ROOT/scripts/controle_icones.py" ]; then
    SORTIE_ICO="$(python3 "$ROOT/scripts/controle_icones.py" "$META" 2>&1)"
    CODE_ICO=$?
    if [ "$CODE_ICO" -eq 0 ]; then
        ok "icones sources : controle hostile vert ($(printf '%s' "$SORTIE_ICO" | grep -c '^OK') contrôles OK)"
    else
        echec "icones sources : controle hostile en échec"
        printf '%s\n' "$SORTIE_ICO" | grep -E "^(ECHEC|NOTE)" | sed 's/^/       /'
    fi
    if [ -n "$JAR_DANS_ZIP" ]; then
        TMPICO="$TMP/icones"
        mkdir -p "$TMPICO"
        for ico in pluginIcon.svg pluginIcon_dark.svg; do
            if unzip -p "$TMPJAR" "META-INF/$ico" > "$TMPICO/$ico" 2>/dev/null && [ -s "$TMPICO/$ico" ]; then
                ok "$ico présent dans le jar du ZIP livré ($JAR_DANS_ZIP)"
            else
                echec "$ico absent du jar du ZIP livré ($JAR_DANS_ZIP)"
            fi
        done
        if [ -s "$TMPICO/pluginIcon.svg" ] && [ -s "$TMPICO/pluginIcon_dark.svg" ]; then
            SORTIE_ICO_ZIP="$(python3 "$ROOT/scripts/controle_icones.py" "$TMPICO" 2>&1)"
            CODE_ICO_ZIP=$?
            if [ "$CODE_ICO_ZIP" -eq 0 ]; then
                ok "icones du jar livré : contrôle hostile vert"
            else
                echec "icones du jar livré : contrôle hostile en échec"
                printf '%s\n' "$SORTIE_ICO_ZIP" | grep -E "^(ECHEC|NOTE)" | sed 's/^/       /'
            fi
        fi
    fi
else
    echec "scripts/controle_icones.py absent : les icones ne sont pas vérifiées en profondeur"
    for ico in pluginIcon.svg pluginIcon_dark.svg; do
        [ -f "$META/$ico" ] && ok "$ico présent dans src/main/resources/META-INF" \
            || echec "logo $ico manquant dans .../src/main/resources/META-INF"
    done
fi

# ------------------------------------------------------- 14. media ---------
if [ -d "$ROOT/media" ]; then
    if python3 -I - "$ROOT/media" <<'PY'
import sys, struct
from pathlib import Path
d = Path(sys.argv[1])
bad = []
for f in sorted(d.rglob("*")):
    if f.suffix.lower() not in (".png", ".jpg", ".jpeg"): continue
    data = f.read_bytes()
    w = h = 0
    if data[:8] == b"\x89PNG\r\n\x1a\n":
        w, h = struct.unpack(">II", data[16:24])
    elif data[:2] == b"\xff\xd8":
        i = 2
        while i < len(data) - 9:
            if data[i] != 0xFF: i += 1; continue
            m = data[i+1]
            if m in (0xC0,0xC1,0xC2,0xC3,0xC5,0xC6,0xC7,0xC9,0xCA,0xCB,0xCD,0xCE,0xCF):
                h, w = struct.unpack(">HH", data[i+5:i+9]); break
            if m in (0xD8,0xD9) or 0xD0 <= m <= 0xD7: i += 2; continue
            ln = struct.unpack(">H", data[i+2:i+4])[0]; i += 2 + ln
    if w and h and (w < 1200 or h < 760): bad.append("%s %dx%d" % (f.name, w, h))
print("\n".join(bad))
sys.exit(1 if bad else 0)
PY
    then
        ok "media/ : images >= 1200x760"
    else
        echec "image(s) de media/ < 1200x760 (ou illisible)"
    fi
else
    info "media/ absent du projet : critère des captures NON APPLICABLE (pas de média à vérifier)"
fi

# ------------------------------------------------------- 15. lib/ du ZIP ----
if [ -n "$ZIP" ]; then
    CONTENU_LIB="$(unzip -Z1 "$ZIP" 2>/dev/null | grep -E "lib/[^/]+\.jar$")"
    if printf '%s\n' "$CONTENU_LIB" | grep -qiE "slf4j|commons-codec"; then
        echec "le ZIP embarque slf4j-api ou commons-codec (fournis par la plateforme) : refus attendu par le Marketplace"
        printf '%s\n' "$CONTENU_LIB" | grep -iE "slf4j|commons-codec" | sed 's/^/       /'
    else
        ok "lib/ du ZIP : ni slf4j-api ni commons-codec embarqués"
    fi
    NB_PLUGIN_JAR=0
    for j in $(printf '%s\n' "$CONTENU_LIB" | grep -v searchableOptions); do
        unzip -p "$ZIP" "$j" > "$TMP/candidat.jar" 2>/dev/null || continue
        unzip -Z1 "$TMP/candidat.jar" 2>/dev/null | grep -q "^META-INF/plugin.xml$" && NB_PLUGIN_JAR=$((NB_PLUGIN_JAR+1))
    done
    if [ "$NB_PLUGIN_JAR" -eq 1 ]; then
        ok "lib/ du ZIP : exactement un jar de plugin (les autres jars sont des dépendances déclarées)"
    else
        echec "lib/ du ZIP : $NB_PLUGIN_JAR jar(s) contenant META-INF/plugin.xml (1 attendu)"
    fi
fi

# ------------------------------------------------------- 16. fraicheur ------
if [ -n "$ZIP" ]; then
    # Un ZIP reproductible se compare par CONTENU (sha256), pas par horodatage :
    # un `git clone` ou un `tar` rafraichit les mtimes des sources sans
    # changer une ligne de code. On fait donc les DEUX controles.
    SHA_ZIP="$(sha256sum "$ZIP" | cut -d' ' -f1)"
    if [ -f "$ROOT/SHA256.txt" ]; then
        SHA_DOC="$(grep -oE "\b[0-9a-f]{64}\b" "$ROOT/SHA256.txt" | head -1)"
        if [ -z "$SHA_DOC" ]; then
            echec "SHA256.txt ne contient aucune empreinte sha256"
        elif [ "$SHA_DOC" = "$SHA_ZIP" ]; then
            ok "sha256 du ZIP = sha256 documenté dans SHA256.txt (source de vérité unique)"
        else
            echec "sha256 du ZIP ($SHA_ZIP) différent du sha256 documenté dans SHA256.txt ($SHA_DOC)"
        fi
    else
        echec "SHA256.txt absent : pas de source de vérité unique pour le ZIP livré"
    fi
    NEWER_SRC="$(find "$ROOT/src/main" "$ROOT/build.gradle.kts" "$ROOT/settings.gradle.kts" \
        "$ROOT/gradle.properties" "$ROOT/libs" -newer "$ZIP" -type f 2>/dev/null | head -5)"
    if [ -n "$NEWER_SRC" ]; then
        echec "le ZIP n'est pas plus récent que les sources : $(echo "$NEWER_SRC" | tr '\n' ' ') (relancer le build : il est reproductible)"
    else
        ok "ZIP plus récent que les sources de production (src/main, fichiers Gradle, libs/)"
    fi
fi

# ------------------------------------------------------- 17. md5 / docs -----
if [ -n "$ZIP" ]; then
    MD5_ZIP="$(md5sum "$ZIP" | cut -d' ' -f1)"
    if [ -z "$MD5_ZIP" ]; then
        echec "md5sum indisponible ou vide : le contrôle du md5 ne peut pas être fiable"
    else
        DOCS_OK=0; DOCS_TOTAL=0; DOCS_BAD=""
        NOM_ZIP="$(basename "$ZIP")"
        while IFS= read -r f; do
            [ -z "$f" ] && continue
            DOCS_TOTAL=$((DOCS_TOTAL+1))
            if grep -q "$MD5_ZIP" "$f"; then
                DOCS_OK=$((DOCS_OK+1))
            else
                # on ne retient que les hashes attaches a CE ZIP (une ligne qui
                # parle du ZIP livre) : un autre hash dans la doc n'est pas un
                # conflit, c'est une autre version.
                while IFS= read -r ligne; do
                    [ -z "$ligne" ] && continue
                    for autre in $(printf '%s' "$ligne" | grep -oE "\b[0-9a-f]{32}\b" | sort -u); do
                        DOCS_BAD="$DOCS_BAD $f($autre)"
                    done
                done < <(grep -F "$NOM_ZIP" "$f" 2>/dev/null || true)
            fi
        done < <(find "$ROOT" -maxdepth 2 -type f \( -name "*.md" -o -name "*.txt" \) \
                -not -path "$ROOT/build/*" -not -path "$ROOT/.git/*" | sort)
        if [ "$DOCS_TOTAL" -eq 0 ]; then
            echec "aucune documentation (md/txt) pour vérifier le md5 du ZIP"
        elif [ "$DOCS_OK" -gt 0 ] && [ -z "$DOCS_BAD" ]; then
            ok "md5 OK $MD5_ZIP et cohérent avec la documentation ($DOCS_OK doc(s) vérifiée(s))"
        else
            echec "md5 du ZIP non cohérent avec la documentation (attendu $MD5_ZIP ; divergent :$DOCS_BAD)"
        fi
    fi
fi

# ------------------------------------------------------- 18. contre-epreuve -
PY_CONTRE="$(find "$ROOT/scripts" -maxdepth 1 -type f -name "*contre*.py" 2>/dev/null | head -1)"
if [ -z "$PY_CONTRE" ]; then
    echec "contre-epreuve : aucun fichier .py dont le nom contient « contre » — le critère ne peut pas être vérifié"
else
    # (a) aucune mutation declares ne doit se trouver telle quelle dans src/
    OUT="$(python3 -I - "$PY_CONTRE" "$ROOT/src" <<'PY'
import importlib.util, sys, re
from pathlib import Path
script, srcdir = Path(sys.argv[1]), Path(sys.argv[2])
spec = importlib.util.spec_from_file_location("contre_mod", script)
mod = importlib.util.module_from_spec(spec)
spec.loader.exec_module(mod)          # le module ne fait rien a l'import
muts = []
for nom in dir(mod):
    if nom.startswith("MUTATION"):
        v = getattr(mod, nom)
        if isinstance(v, str) and v:
            muts.append((nom, v))
if not muts:
    print("AUCUNE_MUTATION_DECLAREE")
    sys.exit(0)
faux = []
for nom, v in muts:
    # REGLE : c'est le TEXTE LITERAL de la mutation qui ne doit pas se trouver
    # dans les sources. La forme « avant » est ecrite sous forme de REGEX
    # justement pour que son texte litteral ne soit pas findable ; on ne doit
    # donc PAS l'interpreter comme un motif (il correspond, par construction,
    # au code legitime d'origine).
    for f in sorted(Path(srcdir).rglob("*")):
        if not f.is_file():
            continue
        if v in f.read_text(encoding="utf-8", errors="replace"):
            faux.append("%s present dans %s" % (nom, f))
print("\n".join(sorted(set(faux))))
sys.exit(1 if faux else 0)
PY
)"
    CODE=$?
    if [ $CODE -eq 0 ] && [ "$OUT" != "AUCUNE_MUTATION_DECLAREE" ]; then
        ok "contre-épreuve : aucune mutation déclarée ne se trouve dans les sources"
    elif [ "$OUT" = "AUCUNE_MUTATION_DECLAREE" ]; then
        echec "contre-épreuve : $(basename "$PY_CONTRE") ne déclare aucune mutation (contrôle armé sur du vide)"
    else
        echec "contre-épreuve : mutation présente dans les sources -> $OUT"
    fi
    # (b) la contre-epreuve est reellement executee : elle doit rester VALIDE
    JDK_HOME=""
    if [ -n "${JAVA_HOME:-}" ] && [ -x "${JAVA_HOME}/bin/javac" ]; then
        JDK_HOME="$JAVA_HOME"
    else
        for c in /work/tools/jdk-*/bin/javac /usr/lib/jvm/*/bin/javac; do
            [ -x "$c" ] && JDK_HOME="$(dirname "$(dirname "$c")")" && break
        done
    fi
    if [ -n "$JDK_HOME" ]; then
        if JAVA_HOME="$JDK_HOME" python3 "$PY_CONTRE" > "$TMP/contre.log" 2>&1; then
            ok "contre-épreuve exécutée et VALIDÉE ($(basename "$PY_CONTRE") : la suite échoue bien sur le moteur muté)"
        else
            echec "contre-épreuve exécutée mais NON validée : $(basename "$PY_CONTRE") — voir la sortie"
            tail -5 "$TMP/contre.log" | sed 's/^/       /'
        fi
    else
        info "contre-épreuve non exécutée (aucun JDK trouvé) : le critère des mutations reste vérifié"
    fi
fi

echo
echo "=== RESUME : $ECHECS ECHEC, $OKS controle(s) OK ==="
echo "FIN preflight : $ECHECS ECHEC"
[ "$ECHECS" -eq 0 ] && exit 0
exit 1
