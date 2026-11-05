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
# Il y ajoute un controle que la consigne exige explicitement : les deux
# icones doivent se trouver DANS LE JAR du ZIP livre (`unzip -l`).
#
# Usage : bash scripts/preflight_local.sh [/chemin/vers/le/projet]
# Code de retour : 0 si et seulement si 0 ECHEC.
# =============================================================================
set -u

ROOT="${1:-/work/pickaxe}"
ECHECS=0
OKS=0

echec() { echo "ECHEC : $*"; ECHECS=$((ECHECS + 1)); }
ok()    { echo "OK    : $*"; OKS=$((OKS + 1)); }

echo "=== CONTROLE DE PRE-VOL (reconstitution locale) — $ROOT ==="
echo "date : $(date '+%Y-%m-%d %H:%M:%S %Z')"
echo

# ------------------------------------------------------- 1. plugin.xml ------
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
ok "plugin.xml trouve : $PLUGIN_XML"

XML_OUT="$(python3 -I - "$PLUGIN_XML" <<'PY'
import sys, xml.etree.ElementTree as ET
p = sys.argv[1]
r = ET.parse(p).getroot()
def txt(tag):
    e = r.find(tag)
    return (e.text or "").strip() if e is not None else ""
name = txt("name")
desc = txt("description")
cn = r.find("change-notes")
change = (cn.text or "").strip() if cn is not None else ""
deps = [ (d.text or "").strip() for d in r.findall("depends") ]
lic = r.find("license")
iv = r.find("idea-version")
until = ""
since = ""
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
PY
)"
getf() { echo "$XML_OUT" | sed -n "s/^$1=//p"; }

NAME="$(getf NAME)"; NAME_LEN="$(getf NAME_LEN)"; DEPENDS="$(getf DEPENDS)"
DESC_LEN="$(getf DESC_LEN)"; CHANGE_LEN="$(getf CHANGE_LEN)"
HAS_LICENSE="$(getf HAS_LICENSE)"; SINCE="$(getf SINCE)"; UNTIL="$(getf UNTIL)"

# ------------------------------------------------------- 2. depends --------
if [ -n "$DEPENDS" ]; then
    ok "<depends> present : $DEPENDS"
else
    echec "aucun <depends> dans plugin.xml"
fi

# ------------------------------------------------------- 3. description -----
if [ "${DESC_LEN:-0}" -gt 0 ] 2>/dev/null; then
    ok "<description> present (${DESC_LEN} caracteres)"
else
    echec "<description> manquant ou vide dans plugin.xml"
fi

# ------------------------------------------------------- 4. license racine --
if [ "$HAS_LICENSE" = "1" ]; then
    echec "<license> racine present dans plugin.xml (interdit : la licence se declare sur la fiche)"
else
    ok "pas de <license> racine"
fi

# ------------------------------------------------------- 5. until-build -----
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

# ------------------------------------------------------- 6. TODO/FIXME ------
if grep -rniE "TODO|FIXME|placeholder" "$ROOT/src" >/dev/null 2>&1; then
    echec "TODO / FIXME / placeholder present dans src"
    grep -rniE "TODO|FIXME|placeholder" "$ROOT/src" | head -5 | sed 's/^/       /'
else
    ok "aucun TODO / FIXME / placeholder dans src"
fi

# ------------------------------------------------------- 7. nom public ------
LOWER_NAME="$(echo "$NAME" | tr 'A-Z' 'a-z')"
if [ "${NAME_LEN:-999}" -gt 30 ] 2>/dev/null; then
    echec "nom public trop long : ${NAME_LEN} caracteres (max 30)"
else
    ok "nom public : \"$NAME\" (${NAME_LEN} caracteres <= 30)"
fi
for interdit in plugin intellij jetbrains; do
    case "$LOWER_NAME" in
        *"$interdit"*) echec "nom public contient le mot interdit : \"$interdit\"" ;;
    esac
done

# ------------------------------------------------------- 8. change-notes ----
if [ "${CHANGE_LEN:-0}" -gt 0 ] 2>/dev/null; then
    ok "<change-notes> non vide (${CHANGE_LEN} caracteres)"
else
    echec "change-notes manquantes ou vides dans plugin.xml (obligatoires a la revue)"
fi

# ------------------------------------------------------- 9. icones ---------
META="$ROOT/src/main/resources/META-INF"
for ico in pluginIcon.svg pluginIcon_dark.svg; do
    if [ ! -f "$META/$ico" ]; then
        echec "logo $ico manquant dans .../src/main/resources/META-INF"
        continue
    fi
    W="$(grep -o 'width="[0-9]*"' "$META/$ico" | head -1 | tr -dc '0-9')"
    H="$(grep -o 'height="[0-9]*"' "$META/$ico" | head -1 | tr -dc '0-9')"
    if [ "$W" = "40" ] && [ "$H" = "40" ]; then
        ok "logo $ico : 40x40 (width=\"40\" height=\"40\" ecrits dans le fichier)"
    else
        echec "logo $ico : dimensions ${W}x${H} au lieu de 40x40"
    fi
done

# ------------------------------------------------------- 10. media ---------
if [ -d "$ROOT/media" ]; then
    python3 -I - "$ROOT/media" <<'PY' || echec "image(s) de media/ < 1200x760"
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
    if w and h and (w < 1200 or h < 760): bad.append(f"{f.name} {w}x{h}")
print("\n".join(bad))
sys.exit(1 if bad else 0)
PY
    ok "media/ : images >= 1200x760"
fi

# ------------------------------------------------------- 11. ZIP ------------
ZIP="$(ls -t "$ROOT"/build/distributions/*.zip 2>/dev/null | head -1)"
if [ -z "$ZIP" ]; then
    echec "aucun ZIP dans build/distributions"
else
    ZIP_MTIME="$(stat -c %Y "$ZIP")"
    NEWER_SRC="$(find "$ROOT/src" "$ROOT/build.gradle.kts" "$ROOT/settings.gradle.kts" "$ROOT/gradle.properties" -newer "$ZIP" -type f 2>/dev/null | head -5)"
    if [ -n "$NEWER_SRC" ]; then
        echec "le ZIP n'est pas plus recent que les sources : $(echo "$NEWER_SRC" | tr '\n' ' ')"
    else
        ok "ZIP present et plus recent que les sources : $(basename "$ZIP") ($(stat -c%s "$ZIP") octets)"
    fi

    # les deux icones doivent etre DANS LE JAR du ZIP livre
    JAR="$(unzip -Z1 "$ZIP" | grep -E "lib/[^/]+\.jar$" | grep -v searchableOptions | head -1)"
    if [ -n "$JAR" ]; then
        TMPJAR="$(mktemp -d)/plugin.jar"
        unzip -p "$ZIP" "$JAR" > "$TMPJAR"
        LISTE="$(unzip -l "$TMPJAR" | awk '{print $4}')"
        for ico in pluginIcon.svg pluginIcon_dark.svg; do
            if echo "$LISTE" | grep -q "META-INF/$ico"; then
                ok "$ico present dans le jar du ZIP livre ($JAR)"
            else
                echec "$ico absent du jar du ZIP livre ($JAR)"
            fi
        done
    else
        echec "jar du plugin introuvable dans le ZIP livre"
    fi

    # md5 coherent avec la documentation
    MD5_ZIP="$(md5sum "$ZIP" | cut -d' ' -f1)"
    DOCS_OK=0; DOCS_TOTAL=0; DOCS_BAD=""
    while IFS= read -r f; do
        DOCS_TOTAL=$((DOCS_TOTAL+1))
        if grep -q "$MD5_ZIP" "$f"; then
            DOCS_OK=$((DOCS_OK+1))
        else
            for autre in $(grep -oE "\b[0-9a-f]{32}\b" "$f" | sort -u); do
                DOCS_BAD="$DOCS_BAD $f($autre)"
            done
        fi
    done < <(find "$ROOT" -maxdepth 2 -type f \( -name "*.md" -o -name "*.txt" \) \
                -not -path "$ROOT/build/*" -not -path "$ROOT/.git/*" | sort)
    if [ "$DOCS_TOTAL" -eq 0 ]; then
        echec "aucune documentation (md/txt) pour verifier le md5 du ZIP"
    elif [ "$DOCS_OK" -gt 0 ] && [ -z "$DOCS_BAD" ]; then
        echo "md5 OK $MD5_ZIP et coherent avec la documentation ($DOCS_OK doc(s) verifiee(s))"
    else
        echec "md5 du ZIP non coherent avec la documentation (attendu $MD5_ZIP ; divergent :$DOCS_BAD)"
    fi
fi

# ------------------------------------------------------- 12. mutations ------
PY_CONTRE="$(find "$ROOT/scripts" -maxdepth 1 -type f -name "*contre*.py" | head -1)"
if [ -z "$PY_CONTRE" ]; then
    echo "rien a controler : aucun fichier .py dont le nom contient « contre »"
else
    OUT="$(python3 -I - "$PY_CONTRE" "$ROOT/src" <<'PY'
import importlib.util, sys
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
    for f in sorted(Path(srcdir).rglob("*")):
        if f.is_file() and v in f.read_text(encoding="utf-8", errors="replace"):
            faux.append(f"{nom} present dans {f}")
print("\n".join(faux))
sys.exit(1 if faux else 0)
PY
)"
    CODE=$?
    if [ $CODE -eq 0 ] && [ "$OUT" != "AUCUNE_MUTATION_DECLAREE" ]; then
        ok "contre-epreuve : $(basename "$PY_CONTRE") arme, aucune mutation dans les sources"
    elif [ "$OUT" = "AUCUNE_MUTATION_DECLAREE" ]; then
        echec "contre-epreuve : $(basename "$PY_CONTRE") ne declare aucune mutation (controle arme sur du vide)"
    else
        echec "contre-epreuve : mutation presente dans les sources -> $OUT"
    fi
fi

echo
echo "=== RESUME : $ECHECS ECHEC, $OKS controle(s) OK ==="
echo "FIN preflight : $ECHECS ECHEC"
[ "$ECHECS" -eq 0 ] && exit 0
exit 1
