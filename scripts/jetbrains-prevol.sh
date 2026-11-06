# Pre-vol JetBrains : lance par « holding prevol N --dossier <produit> », dans le slot. $1 = dossier du produit.
# Chaque controle vient d'une erreur passee (date et origine en commentaire). Un echec bloque l'envoi a Tgg.
d="$1"; e=0
echec() { echo "ECHEC : $*"; e=1; }
px=$(find "$d" -path '*/src/main/resources/META-INF/plugin.xml' 2>/dev/null | head -1)
[ -n "$px" ] || echec "plugin.xml introuvable"
# 15/10/2026, revue du jury : sans <depends>, le plugin ne se charge pas dans PyCharm
[ -n "$px" ] && ! grep -q '<depends>' "$px" && echec "plugin.xml sans <depends> (au moins com.intellij.modules.platform)"
[ -n "$px" ] && ! grep -q '<description>' "$px" && echec "description manquante dans plugin.xml"
# 26/10/2026 (mere) : <license> n'est pas un element racine valide d'un plugin.xml pour IntelliJ 2024.3.
# Mesure : boot reel d'IntelliJ IDEA 2024.3 (IC-243.21565.193), jar installe dans cfg/plugins/<nom>/lib/ ->
# "ERROR: Unknown element: license" (XmlReader.readRootElementChild, XmlReader.kt:344) puis
# "contains invalid plugin descriptor" (PluginManagerCore.kt:328) : le plugin n'est JAMAIS charge.
# Origine : le ZIP 0.1.0 du slot 2 (XLSX Diff) portait <license>Apache-2.0</license> ; il etait joint a
# l'action de Tgg pour dimanche, je l'ai retire avant qu'il parte. La licence se declare dans
# META-INF/LICENSE.txt du jar ET dans le formulaire de publication Marketplace.
# 27/10/2026 (mere) : faux positif corrige. Le grep brut tombait sur un COMMENTAIRE XML qui expliquait
# l'absence de <license> (plugin.xml du slot 3, 27/10 02:10). Le parseur d'IntelliJ ignore les commentaires :
# le descripteur etait valide. On retire donc les commentaires avant de chercher la balise.
# 27/10/2026 02:18 (2e avis Gemini, gratuit) : le regex pouvait encore tomber sur un <license> ecrit dans
# une section CDATA (texte, pas element). On passe par un vrai parseur XML ; si le fichier ne se parse pas,
# on retombe sur le regex (commentaires et CDATA retires) et on ne bloque pas sur l'echec de parsing.
if [ -n "$px" ] && python3 -c 'import re,sys
import xml.etree.ElementTree as ET
p=sys.argv[1]
try:
    root=ET.parse(p).getroot()
    trouve=any(str(c.tag).lower()=="license" for c in root)
except Exception:
    s=open(p,encoding="utf-8",errors="replace").read()
    s=re.sub(r"<!--.*?-->","",s,flags=re.S)
    s=re.sub(r"<!\[CDATA\[.*?\]\]>","",s,flags=re.S)
    trouve=bool(re.search(r"<license[ >/]",s,re.I))
sys.exit(0 if trouve else 1)' "$px"; then
  echec "plugin.xml contient <license> : IntelliJ 2024.3 rejette le descripteur (Unknown element: license) -> le plugin ne se charge pas"
fi
# 15/10/2026, revue du jury : untilBuild=251.* excluait les IDE sortis depuis 2025.1
grep -Eqs 'untilBuild[^0-9]*(1[0-9]{2}|2[0-4][0-9]|25[01])' "$d/build.gradle.kts" "$d/gradle.properties" && echec "untilBuild exclut les IDE recents (laisse-le vide ou >= 252)"
# 15/10/2026, revue du jury : action « Deploy » factice avec une valeur placeholder
t=$(grep -rIniE 'v0\.0\.[0-9]+-placeholder|example\.invalid|lorem ipsum|\bTODO\b|\bFIXME\b' "$d/src" 2>/dev/null | head -5)
[ -n "$t" ] && { echec "texte provisoire dans src :"; echo "$t" | cut -c1-160 | sed 's/^/    /'; }
# 27/10/2026 (mere) : le produit peut avoir son projet gradle dans un sous-dossier (slot 3 : <produit>/source/).
# On cherche donc le ZIP de sortie du build dans n'importe quel build/distributions sous le produit.
# 27/10/2026 02:18 (2e avis Gemini) : on exclut les dossiers de sauvegarde (backup/bak/old/archive) qui
# pourraient contenir un ZIP d'un ancien build ; et on retient le ZIP LE PLUS RECENT (le slot 2 avait
# un 0.1.0 perime et un 0.2.0 dans le meme dossier : prendre le premier trouvait signalait a tort).
zip_trouve=$(find "$d" -path '*/build/distributions/*.zip' -printf '%T@ %p\n' 2>/dev/null | grep -viE '/(backup|bak|old|archive|archives)[^/]*/' | sort -rn | head -1 | cut -d' ' -f2-)
[ -n "$zip_trouve" ] || echec "aucun ZIP dans build/distributions (./gradlew buildPlugin)"
# 27/10/2026 02:18 (2e avis Gemini) : un ZIP d'un build anterieur ne prouve rien. On verifie que le ZIP
# n'est pas plus ancien que les sources : sinon le fichier joint a Tgg ne correspond pas au code relu.
if [ -n "$zip_trouve" ]; then
  python3 - "$d" "$zip_trouve" <<'PY' || e=1
import os, sys, time
d, zip_p = sys.argv[1], sys.argv[2]
SKIP = {"build", ".gradle", ".git", "out", "dist", "node_modules", "ide", "tools", "capture"}
EXT = (".kt", ".java", ".xml", ".kts", ".properties")
mt_zip = os.path.getmtime(zip_p)
plus_recent = 0.0; qui = ""
for root, dirs, files in os.walk(d):
    dirs[:] = [x for x in dirs if x not in SKIP and not x.startswith(".")]
    for f in files:
        if not f.endswith(EXT):
            continue
        p = os.path.join(root, f)
        try:
            m = os.path.getmtime(p)
        except OSError:
            continue
        if m > plus_recent:
            plus_recent, qui = m, p
if plus_recent > mt_zip + 5:
    print("ECHEC : le ZIP (%s, %s) est plus ancien que les sources (%s, %s) : rebuild puis re-zip"
          % (os.path.basename(zip_p), time.strftime('%d/%m %H:%M', time.localtime(mt_zip)),
             os.path.basename(qui), time.strftime('%d/%m %H:%M', time.localtime(plus_recent))))
    sys.exit(1)
PY
fi
# 26/10/2026 (mere), doc officielle « jetbrains-marketplace-approval-guidelines.html » (relue le 23/10/2026, copie dans /consignes/SAVOIR/jetbrains.md) :
# nom <= 30 caracteres, sans « Plugin » / « IntelliJ » / « JetBrains » ; logo SVG 40x40 (leger + sombre) ; change notes obligatoires et non vides.
if [ -n "$px" ]; then
  dossier=$(dirname "$px")
  python3 - "$px" "$dossier" <<'PY' || e=1
import re, sys
px, dossier = sys.argv[1], sys.argv[2]
s = open(px, encoding="utf-8", errors="replace").read()
def texte(balise):
    m = re.search(r"<%s[^>]*>(.*?)</%s>" % (balise, balise), s, re.S)
    if not m:
        return None
    t = m.group(1)
    t = re.sub(r"<!\[CDATA\[(.*?)\]\]>", r"\1", t, flags=re.S)
    t = re.sub(r"<[^>]+>", " ", t)
    return re.sub(r"\s+", " ", t).strip()
err = []
n = texte("name")
if not n:
    err.append("plugin.xml sans <name>")
else:
    if len(n) > 30:
        err.append("nom du plugin trop long (%d caracteres, maximum 30) : %s" % (len(n), n))
    if re.search(r"plugin|intellij|jetbrains", n, re.I):
        err.append("nom du plugin interdit par JetBrains (Plugin / IntelliJ / JetBrains) : %s" % n)
c = texte("change-notes")
if not c:
    err.append("change-notes manquantes ou vides dans plugin.xml (obligatoires a la revue)")
for x in err:
    print("ECHEC : " + x)
if n and c:
    print("nom OK (%d car.) : %s | change-notes : %d car." % (len(n), n, len(c)))
sys.exit(1 if err else 0)
PY
  for ic in pluginIcon.svg pluginIcon_dark.svg; do
    i="$dossier/$ic"
    [ -f "$i" ] || { echec "logo $ic manquant dans $dossier"; continue; }
    grep -qiE 'width="40"' "$i" && grep -qiE 'height="40"' "$i" || echec "$ic n'est pas un SVG 40x40 (largeur/hauteur dans le fichier)"
  done
fi
# 26/10/2026 (mere), doc officielle « best-practices-for-listing.html » (relue le 23/10/2026) : la section Media est le premier element vu par l'utilisateur ; images au moins 1200x760.
for md in "$d/media" "$d/MEDIA" "$d/captures"; do
  [ -d "$md" ] || continue
  python3 - "$md" <<'PY' || e=1
import os, struct, sys
def dim(p):
    with open(p, 'rb') as f:
        b = f.read(32)
    if b[:8] == b'\x89PNG\r\n\x1a\n':
        return struct.unpack('>II', b[16:24])
    if b[:2] == b'\xff\xd8':
        with open(p, 'rb') as f:
            f.read(2)
            while True:
                m = f.read(2)
                if len(m) < 2: return None
                L = struct.unpack('>H', m)[0]
                if m[0] == 0xFF and 0xC0 <= m[1] <= 0xCF and m[1] not in (0xC4, 0xC8, 0xCC):
                    d = f.read(5); h, w = struct.unpack('>HH', d[1:5]); return (w, h)
                f.read(L - 2)
    return None
bad = []
for root, _, files in os.walk(sys.argv[1]):
    for n in files:
        if n.lower().endswith(('.png', '.jpg', '.jpeg')):
            p = os.path.join(root, n); dd = dim(p)
            if dd is None: bad.append("%s : dimensions illisibles" % p)
            elif dd[0] < 1200 or dd[1] < 760: bad.append("%s : %dx%d, minimum 1200x760" % (p, dd[0], dd[1]))
for b in bad: print("ECHEC : media : " + b)
sys.exit(1 if bad else 0)
PY
done
# 27/10/2026 09:40 (mere) : <vendor> doit porter l'ADRESSE DE CONTACT DEDIEE, jamais l'adresse personnelle.
# Origine : les 4 versions publiees de 35416 (0.0.13/0.0.15/0.0.16/0.0.17) portent toutes exactement
#   <vendor email="tgg.apps.support@gmail.com" url="https://plugins.jetbrains.com/vendor/tgg-labs">Tgg Labs</vendor>
# et sont approuvees ; l'API publique renvoie email = tgg.apps.support@gmail.com pour le plugin, alors que
# vendor.email = tgg49099@gmail.com pour le compte editeur. La Marketplace accepte donc un email de contact
# different de l'email du compte. L'inference contraire (ecrite le 26/10, « supprimer l'attribut ») etait
# FAUSSE et a fait retirer l'attribut au slot 2 le 27/10 au matin ; voir /srv/iamere/savoir/jetbrains.md,
# section du 27/10 09:36. Ce controle est la contre-epreuve.
# Ce qui reste interdit : l'adresse personnelle de Tgg (donnee personnelle ; c'est aussi elle que le filtre
# anti-secret de /opt/iamere/bin/jules refuse d'envoyer).
# 04/11/2026 12:05 (mere) : FAUX POSITIF corrige. Le <vendor> se controle sur le plugin.xml CONSTRUIT
# (celui du jar dans le ZIP livre), pas sur le fichier SOURCE.
# Origine : le 04/11 11:55, le pre-vol du slot 5 (/work/ml-experiment-plugin) a repondu
#   « ECHEC : <vendor> sans attribut email » alors que le ZIP livre 0.0.21 porte bien
#   <vendor email="tgg.apps.support@gmail.com" url="https://plugins.jetbrains.com/vendor/tgg-labs">Tgg Labs</vendor>
# Le SOURCE src/main/resources/META-INF/plugin.xml a un <vendor> NU : c'est le build Gradle qui injecte
# les attributs (gradle.properties : pluginVendorName / pluginVendorEmail / pluginVendorUrl ->
# build.gradle.kts : pluginXml { vendor { url = ... } }). Le descripteur REELLEMENT publie est le
# construit ; controler la source produisait un blocage injustifie.
# Regle : on controle le construit ; si on ne peut pas le lire, on accepte la source nue SEULEMENT si
# gradle.properties porte pluginVendorEmail=tgg.apps.support@gmail.com (le build injectera alors l'adresse).
# Contre-epreuve : les deux ZIP du slot 5 (frozen 553362ce... / reconstruit 4d21db8d...) ont un CONTENU
# strictement identique (4 archives, 93+1038+45+3 entrees, 0 difference, hash de contenu identique) :
# seul l'horodatage des archives differe. Le md5 du ZIP n'est pas reproductible, le contenu l'est.
if [ -n "$px" ]; then
  python3 - "$px" "$zip_trouve" "$d" <<'PYV' || e=1
import io, os, re, sys, zipfile
px, zip_p, d = sys.argv[1], sys.argv[2], sys.argv[3]
ATTENDU = "tgg.apps.support@gmail.com"
def sans_commentaires(s):
    return re.sub(r"<!--.*?-->", "", s, flags=re.S)
def tag_vendor(s):
    m = re.search(r"<vendor\b[^>]*>", sans_commentaires(s), re.I)
    return m.group(0) if m else None
def plugin_xml_construit():
    if not zip_p:
        return None
    try:
        z = zipfile.ZipFile(zip_p)
    except Exception:
        return None
    for n in z.namelist():
        if not n.endswith(".jar"):
            continue
        try:
            zz = zipfile.ZipFile(io.BytesIO(z.read(n)))
        except Exception:
            continue
        for m2 in zz.namelist():
            if m2.endswith("plugin.xml"):
                return zz.read(m2).decode("utf-8", "replace")
    return None
err = []
source = open(px, encoding="utf-8", errors="replace").read()
construit = plugin_xml_construit()
cible = "plugin.xml CONSTRUIT (dans le ZIP livre)" if construit else "plugin.xml source"
texte = construit if construit else source
tag = tag_vendor(texte)
if not tag:
    err.append("%s sans balise <vendor> (le contact editeur est obligatoire)" % cible)
else:
    em = re.search(r'email="([^"]*)"', tag)
    if not em:
        gp = ""
        for f in ("gradle.properties", "build.gradle.kts", "gradle/libs.versions.toml"):
            p = os.path.join(d, f)
            if os.path.exists(p):
                gp += open(p, encoding="utf-8", errors="replace").read().replace(" ", "")
        if construit:
            err.append('%s sans attribut email : mettre email="%s"' % (cible, ATTENDU))
        elif ("pluginVendorEmail=" + ATTENDU) in gp:
            print("OK : <vendor> nu dans la source, le build injecte email=\"%s\"" % ATTENDU)
        else:
            err.append('<vendor> sans attribut email : mettre email="%s" (dans la source ou dans gradle.properties)' % ATTENDU)
    elif em.group(1).strip() != ATTENDU:
        err.append("%s : <vendor email=\"%s\"> : utiliser l'adresse de contact dediee %s" % (cible, em.group(1), ATTENDU))
if "tgg49099@gmail.com" in source:
    err.append("<vendor> porte l'adresse personnelle de Tgg : interdite dans un produit public")
for x in err:
    print("ECHEC : " + x)
sys.exit(1 if err else 0)
PYV
  # 27/10/2026 09:40 (mere) : aucune adresse personnelle dans le CODE qui part dans le JAR.
  sr=$(dirname "$px"); sr=$(dirname "$(dirname "$(dirname "$sr")")")
  perso=$(grep -rIl 'tgg49099@gmail\.com' "$sr" 2>/dev/null | head -5)
  [ -n "$perso" ] && { echec "adresse personnelle de Tgg (tgg49099@gmail.com) dans le code du produit : retire-la"; echo "$perso" | cut -c1-160 | sed 's/^/    /'; }
fi
# 27/10/2026 10:45 (mere) : le md5 cite dans la documentation de publication doit etre celui du ZIP
# livre, et il ne doit y en avoir qu'UN seul par document.
# Origine : le 27/10 a 09:32 le slot 2 a reconstruit son ZIP (md5 706fac9e...), mais
# xlsx-diff-plugin/PUBLISH_TGG.md citait encore 83e53b8c... et /rapports/demandes.md citait
# 19b9a35e... -> TROIS md5 differents en circulation le meme jour. Tgg lit la doc pour verifier le
# fichier qu'il telecharge : il aurait compare le ZIP livre a une empreinte perimee, ou conclu que le
# fichier etait corrompu. Regle : un document de publication ne peut citer que le md5 du ZIP livre
# (ou aucun). Contre-epreuve : 4 cas de synthese testes le 27/10 (bon md5 = OK ; 2 md5 = ECHEC ;
# md5 obsolete = ECHEC ; aucun md5 = OK).
# 04/11/2026 05:48 (mere) : le md5 d'un ZIP JetBrains N'EST PAS REPRODUCTIBLE -> ne jamais l'exiger
# d'un rebuild. Origine : le slot 5 a rejoue le build de la 0.0.21 le 04/11 (BUILD SUCCESSFUL,
# 5 min 09) : le CONTENU est reproduit octet pour octet (hash des noms+octets, horodatages exclus
# = a94430a87550723188e26123ece99a9499059f2825fdc8413bdfb8e7dd4d1c09 pour les deux archives, 84/84
# .class identiques), mais le md5 differe (fige 553362cea452dc937188fbe29b7efb92 / 1 801 729 o
# vs reconstruit 4d21db8d5e4672873328fe89fdb92c1c / 1 801 725 o). Cause mesuree : Gradle horodate
# les entrees d'archive a l'heure du build (jar interne 31/10 22:09 -> 04/11 05:48:38 ; ZIP
# 31/10 22:10 -> 04/11 05:48:48). Consequence : le controle de md5 ci-dessous ne vaut QUE contre le
# ZIP LIVRE (c'est le bon controle : on retelecharge depuis la Marketplace et on compare) ; le
# critere de reproductibilite est le HASH DE CONTENU (noms + octets, horodatages exclus), pas le md5.
if [ -n "$zip_trouve" ]; then
  python3 - "$d" "$zip_trouve" <<'PYM' || e=1
import hashlib, os, re, sys, zipfile, io
d, zip_p = sys.argv[1], sys.argv[2]
def md5(p):
    h = hashlib.md5()
    with open(p, "rb") as f:
        for b in iter(lambda: f.read(1 << 20), b""):
            h.update(b)
    return h.hexdigest()
def hash_contenu(p):
    # 04/11/2026 12:05 (mere) : critere de reproductibilite = HASH DE CONTENU (noms + octets,
    # horodatages exclus). Le md5 d'un ZIP JetBrains n'est PAS reproductible (mesure du 04/11 :
    # le ZIP livre 553362ce... et le ZIP reconstruit 4d21db8d... ont le MEME hash de contenu).
    parties = []
    try:
        z = zipfile.ZipFile(p)
    except Exception:
        return ""
    for n in sorted(z.namelist()):
        if n.endswith("/"):
            continue
        try:
            data = z.read(n)
        except Exception:
            continue
        if n.endswith(".jar"):
            try:
                zz = zipfile.ZipFile(io.BytesIO(data))
                for m in sorted(zz.namelist()):
                    if m.endswith("/"):
                        continue
                    parties.append("%s!%s=%s" % (n, m, hashlib.md5(zz.read(m)).hexdigest()))
            except Exception:
                parties.append("%s=%s" % (n, hashlib.md5(data).hexdigest()))
        else:
            parties.append("%s=%s" % (n, hashlib.md5(data).hexdigest()))
    return hashlib.md5("\n".join(parties).encode()).hexdigest()
base = os.path.basename(zip_p)
# 04/11/2026 12:05 (mere) : le PAYLOAD est le ZIP LIVRE (dossier A_ENVOYER) quand il existe.
# Origine : le 04/11 11:55, le pre-vol du slot 5 a refuse le md5 553362ce... (le ZIP livre, cite dans
# /rapports/rapport.md, /rapports/etat.json, /rapports/demandes.md et dans le dossier de livraison)
# parce que la reference prise etait le ZIP reconstruit du 04/11 04:48 (4d21db8d...). Mesure de la mere
# (04/11 11:58) : les deux ZIP ont un CONTENU strictement identique (4 archives, 93+1038+45+3 entrees,
# 0 difference, hash de contenu edb785e5... identique pour le jar du plugin) ; ils ne different que
# par les horodatages des archives. Le md5 n'est pas reproductible, le contenu l'est.
# Regle : la reference est le ZIP LIVRE ; le ZIP du build doit avoir le MEME CONTENU que lui.
parent = os.path.dirname(d.rstrip("/"))
zip_livre = None
dossier_livraison = None
racine = os.path.join(parent, "A_ENVOYER")
if os.path.isdir(racine):
    candidats = []
    for root, dirs, files in os.walk(racine):
        for f in files:
            if f == base:
                try:
                    candidats.append((os.path.getmtime(os.path.join(root, f)), os.path.join(root, f), root))
                except OSError:
                    pass
    if candidats:
        candidats.sort(reverse=True)
        zip_livre = candidats[0][1]
        dossier_livraison = candidats[0][2]
reel = md5(zip_livre or zip_p)
if zip_livre:
    h1, h2 = hash_contenu(zip_livre), hash_contenu(zip_p)
    if h1 != h2:
        print("ECHEC : le ZIP livre (%s) et le ZIP du build (%s) n'ont pas le MEME CONTENU "
              "(hash de contenu %s / %s) : le fichier verifie n'est pas celui qui sera envoye a Tgg"
              % (zip_livre, zip_p, h1[:12], h2[:12]))
        sys.exit(1)
    print("ZIP livre = %s (md5 %s) | contenu identique au ZIP du build (hash de contenu %s)" % (zip_livre, reel, h1[:12]))
# empreintes legitimement citables : le ZIP livre + les fichiers A L'INTERIEUR du ZIP
# (le md5 du jar interne est cite legitement dans la doc de publication du slot 2).
legitimes = {reel}
# 04/11/2026 12:05 (mere) : les fichiers LIVRES AVEC le ZIP (RELEASE-*.md, SHA256-ET-FICHIERS.txt,
# jar_interne_*.jar, pousser_source_*.sh) font partie du dossier que Tgg recoit : leurs md5 sont
# citables. Origine : le 04/11 11:55, /rapports/etat.json citait bb739349... = RELEASE-0.0.21.md,
# refuse a tort parce que ce fichier est a COTE du ZIP et pas dedans.
if dossier_livraison:
    for f in sorted(os.listdir(dossier_livraison)):
        p = os.path.join(dossier_livraison, f)
        if os.path.isfile(p):
            try:
                legitimes.add(md5(p))
            except OSError:
                pass
zip_ref = zip_livre or zip_p
try:
    with zipfile.ZipFile(zip_ref) as z:
        for n in z.namelist():
            if n.endswith("/"):
                continue
            try:
                with z.open(n) as f:
                    h = hashlib.md5()
                    for b in iter(lambda: f.read(1 << 20), b""):
                        h.update(b)
                legitimes.add(h.hexdigest())
            except Exception:
                pass
            # 29/10/2026 22:30 (mere) : les fichiers A L'INTERIEUR du jar interne sont citables
            # eux aussi (ex. META-INF/LICENSE.txt du jar du plugin).
            # Origine : le 29/10 le slot 3 a cite dans son rapport le md5 du LICENSE.txt DANS le jar
            # (3b83ef96387f14655fc854ddc3c6bd57) -> le controle le rejetait ("ni le ZIP livre ni un
            # fichier qu'il contient") et le pre-vol sortait ROUGE sur un ZIP parfaitement correct.
            # Le md5 du LICENSE.txt publie (META-INF/LICENSE.txt) est bien celui du ZIP livre.
            # Contre-epreuve : le controle des md5 perimes (27/10) reste actif : un md5 qui n'est ni
            # le ZIP, ni un fichier du ZIP, ni un fichier d'un jar du ZIP, est toujours refuse.
            if n.endswith(".jar"):
                try:
                    import io
                    with z.open(n) as f:
                        data = f.read()
                    with zipfile.ZipFile(io.BytesIO(data)) as zj:
                        for m in zj.namelist():
                            if m.endswith("/"):
                                continue
                            try:
                                legitimes.add(hashlib.md5(zj.read(m)).hexdigest())
                            except Exception:
                                pass
                except Exception:
                    pass
except Exception:
    pass
copies = []
for root, dirs, files in os.walk(d):
    dirs[:] = [x for x in dirs if x not in {"build", ".gradle", ".git", "node_modules", "tools", "ide", "capture"} and not x.startswith(".")]
    for f in files:
        if f == base:
            p = os.path.join(root, f)
            try:
                # 04/11/2026 12:05 (mere) : on compare le CONTENU, pas le md5 (le md5 d'un ZIP
                # n'est pas reproductible : deux ZIP de meme contenu ont des md5 differents).
                if hash_contenu(p) != hash_contenu(zip_ref):
                    copies.append(p)
            except OSError:
                pass
SAUT = {"build", ".gradle", ".git", "node_modules", "tools", "ide", "capture",
        "preuves", "backup", "bak", "old", "archives", "archive", "rapports"}
docs = []
for root, dirs, files in os.walk(d):
    dirs[:] = [x for x in dirs if x not in SAUT and not x.startswith(".")]
    for f in files:
        if f.lower().endswith(".md"):
            docs.append(os.path.join(root, f))
parent = os.path.dirname(d.rstrip("/"))
# 04/11/2026 12:05 (mere) : les JOURNAUX du slot ne sont pas des documents de publication.
# Origine : le 04/11 11:55, le pre-vol du slot 5 a refuse 48 md5 de /work/NOTES.md (le journal du
# slot, 664 Ko, qui garde l'historique des versions) + NOTES_CYCLE43/45/48/51.md + rapports/
# R97-PROVISOIRE.md + R98-PROVISOIRE.md + rapports/savoir.md. Un journal DOIT pouvoir citer les md5
# passes : c'est son role. Ce qui doit etre exempt de md5 perime, c'est ce que TGG LIT : la fiche de
# publication, le rapport du cycle, le readme du produit.
# Le controle reste actif sur : les .md du produit, FICHE*.md, LISEZMOI*.md, README*.md,
# /rapports/rapport.md, /rapports/etat.json, /rapports/demandes.md.
JOURNAL_MD = re.compile(r"^(notes|cycle|compris|chronologie|debt|savoir|journal)", re.I)
PROVISOIRE_MD = re.compile(r"provisoire", re.I)
def est_journal(f):
    return bool(JOURNAL_MD.match(f)) or bool(PROVISOIRE_MD.search(f))
for racine in (parent, os.path.join(parent, "rapports")):
    if not racine or not os.path.isdir(racine):
        continue
    for f in sorted(os.listdir(racine)):
        if f.lower().endswith(".md") and not est_journal(f):
            docs.append(os.path.join(racine, f))
if os.path.exists("/rapports/demandes.md"):
    docs.append("/rapports/demandes.md")
# 27/10/2026 11:45 (mere) : les RAPPORTS du slot comptent aussi comme documents de publication.
# Origine : le 27/10, le cycle du slot 2 a ete tue a 150 tours AVANT de reecrire ses rapports :
# /rapports/rapport.md (07:50) et /rapports/etat.json (07:51) citaient encore l'ancien md5
# (19b9a35e..., taille 17 258 637) alors que le ZIP livre fait 706fac9e... / 17 258 505 octets.
# C'est ce que je lis (ctl etat, ctl rapport) : un rapport perime me fait croire a un produit perime.
# On controle donc ces trois fichiers precis (le reste du .json peut contenir des hachages sans
# rapport avec le md5 du livrable).
for _f in ("rapport.md", "etat.json", "demandes.md"):
    _p = os.path.join("/rapports", _f)
    if os.path.exists(_p):
        docs.append(_p)
pat = re.compile(r"\b([0-9a-fA-F]{32})\b")
err = []
for c in copies:
    err.append("copie du ZIP avec un CONTENU different : %s" % c)
# 04/11/2026 12:05 (mere) : un md5 cite dans un document de publication doit designer un fichier
# QUI EXISTE : le ZIP livre, un fichier dedans, un fichier livre avec, ou un fichier du depot.
# Origine : le 04/11 11:55, le pre-vol du slot 5 a refuse 3 md5 LEGITIMES : 3b83ef96... = le texte
# Apache-2.0 du depot public, 56b7e707... = SUPPORT.md du depot public, 297c4c56... = la capture
# /work/MEDIA/ml-experiment-cockpit-mlflow-tree-1200x760.png (citee dans la fiche de publication).
# Ces trois fichiers existent (mesure de la mere, 04/11 12:00) : le controle les refusait parce
# qu'ils ne sont ni le ZIP ni dans le ZIP. Regle : on refuse seulement ce qui ne correspond a AUCUN
# fichier du depot : la c'est une empreinte perimee ou une faute de frappe, et Tgg ne peut pas la
# verifier. Mesure : 2 115 fichiers / 80 Mo a hacher = ~1 s.
SAUT_EXIST = {"build", ".gradle", ".git", "node_modules", "tools", "ide", "capture", ".pylocal",
               ".cctmp", "caches", "tmp"}
existants = set()
# 04/11/2026 12:10 (mere) : seul le ZIP LIVRE est citable ; les autres ZIP du depot ne le sont pas.
# C'est exactement le risque du controle : un document de publication qui cite le md5 d'un 0.0.19
# (ou d'une reconstruction du 0.0.21 rangée dans preuves/) alors que Tgg recoit le 0.0.21 -> il ne
# peut pas verifier. Contre-epreuve du 04/11 12:20 : avec cette regle, un doc citant le md5 du
# 0.0.19 est REFUSE, un doc citant le md5 du ZIP reconstruit du 04/11 est REFUSE, un doc citant le
# md5 du ZIP livre ou celui d'un fichier du depot (LICENSE, capture) est ACCEPTE.
for root, dirs, files in os.walk(parent or "/work"):
    dirs[:] = [x for x in dirs if x not in SAUT_EXIST and not x.startswith(".")]
    for f in files:
        p = os.path.join(root, f)
        try:
            if os.path.getsize(p) > 64 * 1024 * 1024:
                continue
            if f.lower().endswith(".zip"):
                continue
            with open(p, "rb") as fh:
                h = hashlib.md5()
                for b in iter(lambda: fh.read(1 << 20), b""):
                    h.update(b)
            existants.add(h.hexdigest())
        except OSError:
            pass
# 06/11/2026 13:45 (cycle 134) : le PAQUET de livraison est citable.
# Origine : le cycle 133 a reconstruit /work/pickaxe-soumission/dossier-pickaxe.zip (le paquet que
# Tgg recoit : ZIP du plugin + LISEZMOI + MISE-VENTE + captures) et a cite son md5 dans
# /rapports/rapport.md et /rapports/etat.json. Le controle des md5 le REFUSAIT : le scan des
# fichiers existants saute les .zip (regle du 04/11 12:10 : "seul le ZIP livre est citable, pas
# les autres ZIP du depot"), et le paquet n'est ni le ZIP livre ni un fichier a l'interieur de
# celui-ci. Resultat : le pre-vol sortait ROUGE sur un paquet parfaitement correct.
# REGLE : un fichier ZIP est citable SI ET SEULEMENT SI il CONTIENT le ZIP livre (md5 reel).
# C'est verifiable tout seul, sans liste de fichiers a maintenir : le paquet porte le fichier
# que Tgg va telecharger ; un ZIP perime (0.0.19, 0.0.21) ne le contient pas et reste refuse.
# Contre-epreuve : scripts/contre_epreuve_prevol_md5.sh (paquet accepte ; ZIP ancien refuse ;
# md5 inconnu refuse).
taille_zip_livre = os.path.getsize(zip_ref)
for root, dirs, files in os.walk(parent or "/work"):
    dirs[:] = [x for x in dirs if x not in SAUT_EXIST and not x.startswith(".")]
    for f in files:
        if not f.lower().endswith(".zip"):
            continue
        p = os.path.join(root, f)
        try:
            if os.path.getsize(p) > 64 * 1024 * 1024:
                continue
            porte_le_livre = False
            with zipfile.ZipFile(p) as zp:
                for n in zp.namelist():
                    if n.endswith("/"):
                        continue
                    try:
                        info = zp.getinfo(n)
                    except Exception:
                        continue
                    if info.file_size != taille_zip_livre:
                        continue
                    try:
                        h = hashlib.md5()
                        with zp.open(n) as fh:
                            for b in iter(lambda: fh.read(1 << 20), b""):
                                h.update(b)
                        if h.hexdigest() == reel:
                            porte_le_livre = True
                            break
                    except Exception:
                        continue
            if porte_le_livre:
                legitimes.add(md5(p))
        except Exception:
            continue
vus = set()
for p in sorted(set(docs)):
    try:
        s = open(p, encoding="utf-8", errors="replace").read()
    except OSError:
        continue
    if "md5" not in s.lower() and base not in s:
        continue
    md5s = {x.lower() for x in pat.findall(s)}
    if not md5s:
        continue
    vus.add(p)
    etrangers = md5s - legitimes - existants
    if etrangers:
        err.append("%s cite %d md5 qui ne correspondent a aucun fichier du depot ni du dossier livre (%s) : "
                   "ce sont des empreintes perimees ou des fautes de frappe ; le md5 du ZIP livre est %s"
                   % (p, len(etrangers), ", ".join(sorted(etrangers)), reel))
for x in err:
    print("ECHEC : " + x)
if not err:
    print("md5 OK (%s = %s) et coherent avec la documentation (%d doc(s) verifiee(s))" % (base, reel, len(vus)))
sys.exit(1 if err else 0)
PYM
fi
# 27/10/2026 11:25 (mere) : MUTATION DE CONTRE-EPREUVE.
# Origine : revue du jury 20261027-0337 du produit du slot 3 (BLOQUANT n°1) : le code livre
# contenait « args.add("--grep=$query") » au lieu de « args.add(pickaxe) » — exactement la mutation
# que le script scripts/contre_epreuve.py DU PROPRE PRODUIT injecte pour tester. La copie envoyee
# au jury avait ete prise pendant que la mutation etait active (le fichier source a ete reecrit a
# 04:17, apres la lecture du jury de 03:37).
# Regle : si le produit contient un script de contre-epreuve, aucune de ses mutations (« new »)
# ne doit etre presente dans les sources du produit.
if [ -n "$d" ]; then
  python3 - "$d" <<'PYC' || e=1
import os, re, sys
d = sys.argv[1]
SAUT = {"build", ".gradle", ".git", "node_modules", "tools", "ide", "capture", "rapports", "preuves"}
scripts, srcs = [], []
for root, dirs, files in os.walk(d):
    dirs[:] = [x for x in dirs if x not in SAUT and not x.startswith(".")]
    for f in files:
        p = os.path.join(root, f)
        if f.lower().endswith(".py") and "contre" in f.lower():
            scripts.append(p)
        elif f.lower().endswith((".kt", ".java", ".xml", ".kts", ".js", ".ts", ".py")):
            srcs.append(p)
if not scripts:
    print("pas de script de contre-epreuve dans le produit : rien a controler")
    sys.exit(0)
pat = re.compile(r"""["']new["']\s*:\s*(['"])(.+?)\1""", re.S)
mut = []
for p in scripts:
    try:
        s = open(p, encoding="utf-8", errors="replace").read()
    except OSError:
        continue
    for _, val in pat.findall(s):
        v = val.strip()
        if len(v) >= 12 and any(k in v for k in ("(", "=", "def ", "return", "import ")):
            mut.append((p, v))
if not mut:
    print("script(s) de contre-epreuve sans mutation « new » lisible : rien a controler")
    sys.exit(0)
contenus = {}
for p in srcs:
    try:
        contenus[p] = open(p, encoding="utf-8", errors="replace").read()
    except OSError:
        pass
err = []
for sp, v in mut:
    for p, s in contenus.items():
        if p == sp:
            continue
        if v in s:
            err.append("%s contient la mutation de contre-epreuve de %s : %s"
                       % (p, os.path.basename(sp), v[:90]))
            break
for x in sorted(set(err)):
    print("ECHEC : " + x)
if not err:
    print("contre-epreuve : %d mutation(s) testee(s), aucune presente dans les sources" % len(mut))
sys.exit(1 if err else 0)
PYC
fi
[ "$e" = 0 ] && echo "pre-vol JetBrains OK"
exit $e
