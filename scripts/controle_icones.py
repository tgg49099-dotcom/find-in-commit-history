#!/usr/bin/env python3
"""Controle hostile des deux icones livrees (SVG) du plugin.

Ce controle est plus severe que le simple "le fichier existe" :
il analyse chaque SVG comme un hostile le ferait (XML strict, pas de
DOCTYPE ni d'entites, pas de reference externe, pas de script, pas de
police, dessin dans la boite 40x40, traits connectes, contraste WCAG).

Sortie : un verdict par icone, puis "FIN controle_icones : N ECHEC".
Code de retour : 0 si aucun echec, 1 sinon.

Limite assumee : aucun rasteriseur SVG n'existe dans l'environnement
(le script le verifie et le dit) -> la lisibilite visuelle n'est pas
verifiee, seulement la structure et la geometrie.
"""

import math
import os
import re
import sys
import xml.etree.ElementTree as ET

SVG_NS = "http://www.w3.org/2000/svg"
RACINE = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
# Un dossier peut etre passe en argument : c'est ainsi que la contre-epreuve
# (scripts/contre_epreuve_icones.sh) teste le controle sur des COPIES
# volontairement cassees, sans jamais toucher les sources livrees.
DOSSIER = sys.argv[1] if len(sys.argv) > 1 else os.path.join(
    RACINE, "src", "main", "resources", "META-INF")
FICHIERS = ("pluginIcon.svg", "pluginIcon_dark.svg")
TAILLE = 40.0

echecs = []


def echec(qui, message):
    echecs.append("[%s] %s" % (qui, message))
    print("ECHEC : %s : %s" % (qui, message))


def ok(qui, message):
    print("OK    : %s : %s" % (qui, message))


# ---------------------------------------------------------------- couleurs

def luminance(r, g, b):
    def canal(c):
        c = c / 255.0
        return c / 12.92 if c <= 0.03928 else ((c + 0.055) / 1.055) ** 2.4
    return 0.2126 * canal(r) + 0.7152 * canal(g) + 0.0722 * canal(b)


def contraste(c1, c2):
    l1, l2 = luminance(*c1), luminance(*c2)
    if l1 < l2:
        l1, l2 = l2, l1
    return (l1 + 0.05) / (l2 + 0.05)


def parse_couleur(valeur):
    v = (valeur or "").strip()
    m = re.fullmatch(r"#([0-9a-fA-F]{6})", v)
    if m:
        h = m.group(1)
        return tuple(int(h[i:i + 2], 16) for i in (0, 2, 4))
    m = re.fullmatch(r"#([0-9a-fA-F]{3})", v)
    if m:
        h = m.group(1)
        return tuple(int(c * 2, 16) for c in h)
    return None


FOND_CLAIR = (255, 255, 255)
FOND_SOMBRE = (0x1E, 0x1E, 0x1E)


# -------------------------------------------------------------- geometrie

def parse_chemin(d):
    """Retourne la liste des points de controle (x, y) d'un chemin SVG.

    Commandes gérées : M, L, Q, C (absolues). Les variantes relatives et
    les arcs (A) ne sont pas gérées : le script s'arrete dessus au lieu de
    deviner une geometrie.
    """
    jetons = re.findall(r"[A-Za-z]|-?\d+(?:\.\d+)?", d)
    points = []
    cmd = None
    i = 0
    while i < len(jetons):
        t = jetons[i]
        if t.isalpha():
            cmd = t
            i += 1
            if cmd not in ("M", "L", "Q", "C"):
                break
            continue
        if cmd is None:
            break
        try:
            if cmd in ("M", "L"):
                x, y = float(jetons[i]), float(jetons[i + 1])
                points.append((x, y))
                i += 2
            elif cmd == "Q":
                points.append((float(jetons[i]), float(jetons[i + 1])))
                points.append((float(jetons[i + 2]), float(jetons[i + 3])))
                i += 4
            else:  # C
                points.append((float(jetons[i]), float(jetons[i + 1])))
                points.append((float(jetons[i + 2]), float(jetons[i + 3])))
                points.append((float(jetons[i + 4]), float(jetons[i + 5])))
                i += 6
        except (IndexError, ValueError):
            break
    return points


def bbox(points):
    xs = [p[0] for p in points]
    ys = [p[1] for p in points]
    return min(xs), min(ys), max(xs), max(ys)


def distance(a, b):
    return math.hypot(a[0] - b[0], a[1] - b[1])


def milieu_quadratique(p0, p1, p2, t=0.5):
    mt = 1 - t
    x = mt * mt * p0[0] + 2 * mt * t * p1[0] + t * t * p2[0]
    y = mt * mt * p0[1] + 2 * mt * t * p1[1] + t * t * p2[1]
    return (x, y)


def echantillonner(d, n=400):
    """Points reellement traces sur la courbe (et pas les points de controle).

    Necessaire pour mesurer la distance entre deux traits : la distance
    entre points de controle n'est pas la distance entre les courbes.
    """
    jetons = re.findall(r"[A-Za-z]|-?\d+(?:\.\d+)?", d)
    pts = []
    cmd = None
    i = 0
    courant = None
    while i < len(jetons):
        t = jetons[i]
        if t.isalpha():
            cmd = t
            i += 1
            if cmd not in ("M", "L", "Q", "C"):
                break
            continue
        try:
            if cmd in ("M", "L"):
                x, y = float(jetons[i]), float(jetons[i + 1])
                i += 2
                if cmd == "L" and courant is not None:
                    for k in range(1, n + 1):
                        u = k / n
                        pts.append((courant[0] + (x - courant[0]) * u,
                                    courant[1] + (y - courant[1]) * u))
                pts.append((x, y))
                courant = (x, y)
            elif cmd == "Q":
                c = (float(jetons[i]), float(jetons[i + 1]))
                p2 = (float(jetons[i + 2]), float(jetons[i + 3]))
                i += 4
                if courant is not None:
                    for k in range(1, n + 1):
                        u = k / n
                        pts.append(milieu_quadratique(courant, c, p2, u))
                courant = p2
            else:  # C
                c1 = (float(jetons[i]), float(jetons[i + 1]))
                c2 = (float(jetons[i + 2]), float(jetons[i + 3]))
                p3 = (float(jetons[i + 4]), float(jetons[i + 5]))
                i += 6
                if courant is not None:
                    for k in range(1, n + 1):
                        u = k / n
                        mt = 1 - u
                        x = (mt ** 3 * courant[0] + 3 * mt * mt * u * c1[0]
                             + 3 * mt * u * u * c2[0] + u ** 3 * p3[0])
                        y = (mt ** 3 * courant[1] + 3 * mt * mt * u * c1[1]
                             + 3 * mt * u * u * c2[1] + u ** 3 * p3[1])
                        pts.append((x, y))
                courant = p3
        except (IndexError, ValueError):
            break
    return pts


# ------------------------------------------------------------------ audit

def auditer(nom):
    chemin = os.path.join(DOSSIER, nom)
    if not os.path.isfile(chemin):
        echec(nom, "fichier absent de %s" % DOSSIER)
        return
    brut = open(chemin, "rb").read()
    texte = brut.decode("utf-8")

    # 1. XML strict
    if "<!DOCTYPE" in texte or "<!ENTITY" in texte:
        echec(nom, "DOCTYPE ou ENTITY present (interdit)")
    try:
        racine = ET.fromstring(texte)
    except ET.ParseError as e:
        echec(nom, "XML mal forme : %s" % e)
        return
    if racine.tag != "{%s}svg" % SVG_NS:
        echec(nom, "element racine %r au lieu de svg dans le namespace SVG" % racine.tag)
        return
    ok(nom, "XML bien forme, racine svg (namespace SVG correct)")

    # 2. taille ecrite DANS le fichier
    for attribut, attendu in (("width", "40"), ("height", "40")):
        valeur = racine.get(attribut)
        if valeur is None:
            echec(nom, "attribut %s absent de la racine" % attribut)
        elif valeur.strip() != attendu:
            echec(nom, "%s=%r au lieu de %r" % (attribut, valeur, attendu))
        elif ('%s="%s"' % (attribut, attendu)) not in texte:
            echec(nom, "%s=\"%s\" absent du texte brut" % (attribut, attendu))
        else:
            ok(nom, "%s=\"%s\" present dans l'attribut ET dans le texte du fichier" % (attribut, attendu))
    if racine.get("viewBox") != "0 0 40 40":
        echec(nom, "viewBox=%r au lieu de '0 0 40 40'" % racine.get("viewBox"))
    else:
        ok(nom, "viewBox=\"0 0 40 40\"")

    # 3. aucune reference externe, aucun script, aucune police
    interdits = {
        "xlink:href": "reference xlink",
        "href=": "reference href",
        "<script": "balise script",
        "<foreignObject": "balise foreignObject",
        "<image": "balise image",
        "<use": "balise use",
        "<style": "balise style",
        "@import": "import CSS",
        "url(": "url() CSS",
        "font-family": "police",
        "<text": "balise text",
        "transform": "transform (le controle ne mesure pas la geometrie transformee)",
    }
    trouves = [v for k, v in interdits.items() if k in texte]
    if trouves:
        echec(nom, "interdit(s) present(s) : %s" % ", ".join(sorted(trouves)))
    else:
        ok(nom, "aucune reference externe, aucun script, aucune police, aucun texte")
    # http(s) : seul le xmlns du namespace SVG est tolere
    for m in re.finditer(r"https?://[^\s\"'<>]+", texte):
        if m.group(0).rstrip("/") != SVG_NS:
            echec(nom, "URL externe : %s" % m.group(0))
    ok(nom, "seule URL presente : le namespace SVG (obligatoire, non telecharge)")

    # 4. elements de dessin
    chemins = racine.findall(".//{%s}path" % SVG_NS)
    if len(chemins) < 2:
        echec(nom, "%d path(s) : au moins 2 traits attendus (manche + tete)" % len(chemins))
        return
    epaisseurs, couleurs = [], []
    for p in chemins:
        d = p.get("d")
        if not d:
            echec(nom, "un path n'a pas d'attribut d")
            return
        epaisseur = float(p.get("stroke-width", "1"))
        epaisseurs.append(epaisseur)
        couleurs.append(parse_couleur(p.get("stroke")))
        if p.get("stroke") is None:
            echec(nom, "un path n'a pas de couleur de trait")
        if p.get("fill") not in (None, "none"):
            echec(nom, "remplissage %r inattendu (l'icone doit etre en trait)" % p.get("fill"))
    ok(nom, "%d paths, remplissage none, traits de %s" % (len(chemins), "/".join("%g" % e for e in epaisseurs)))

    # 5. le dessin tient dans la boite 40x40 (marge = demi-epaisseur du trait)
    echantillons = []
    for i, p in enumerate(chemins):
        pts = echantillonner(p.get("d"))
        echantillons.append(pts)
        if not pts:
            echec(nom, "path %d : aucun point exploitable" % i)
            continue
        x0, y0, x1, y1 = bbox(pts)
        marge = epaisseurs[i] / 2.0
        if x0 - marge < 0 or y0 - marge < 0 or x1 + marge > TAILLE or y1 + marge > TAILLE:
            echec(nom, "path %d deborde de la boite 40x40 (bbox %.2f,%.2f -> %.2f,%.2f, marge %g)"
                  % (i, x0, y0, x1, y1, marge))
        else:
            ok(nom, "path %d dans la boite : bbox %.2f,%.2f -> %.2f,%.2f (+/-%g)"
               % (i, x0, y0, x1, y1, marge))

    # 6. les traits se touchent-ils ? (distance reelle entre les courbes)
    best = None
    for i in range(len(chemins)):
        for j in range(i + 1, len(chemins)):
            for a in echantillons[i]:
                for b in echantillons[j]:
                    d = distance(a, b)
                    if best is None or d < best[0]:
                        best = (d, i, j)
    seuil = (epaisseurs[best[1]] + epaisseurs[best[2]]) / 2.0
    if best[0] > seuil:
        echec(nom, "les 2 traits ne se touchent pas : ecart %.2f > seuil %.2f" % (best[0], seuil))
    else:
        ok(nom, "traits connectes : ecart reel %.2f <= seuil %.2f (rayons %g + %g)"
           % (best[0], seuil, epaisseurs[best[1]] / 2, epaisseurs[best[2]] / 2))

    # 7. contraste WCAG des couleurs de trait sur les 2 fonds
    for c in couleurs:
        if c is None:
            continue
        cl = contraste(c, FOND_CLAIR)
        cs = contraste(c, FOND_SOMBRE)
        # 3:1 = seuil WCAG 1.4.11 pour les elements graphiques significatifs
        if cl < 3.0 and cs < 3.0:
            echec(nom, "contraste insuffisant : %.2f:1 sur blanc, %.2f:1 sur #1E1E1E" % (cl, cs))
        else:
            ok(nom, "contraste #%02X%02X%02X : %.2f:1 sur blanc, %.2f:1 sur #1E1E1E"
               % (c[0], c[1], c[2], cl, cs))


# ------------------------------------------------------------- rasterisation

def _png_masque(chemin_png):
    """Masque des pixels 'encres' d'un PNG RGBA 8 bits (alpha > 8).

    Decodeur PNG minimal (IHDR + IDAT, zlib, filtres 0 a 4) : evite une
    dependance a PIL, absente de l'environnement.
    """
    import struct
    import zlib

    data = open(chemin_png, "rb").read()
    if data[:8] != b"\x89PNG\r\n\x1a\n":
        raise ValueError("pas un PNG")
    i = 8
    largeur = hauteur = 0
    idat = b""
    while i < len(data):
        longueur, typ = struct.unpack(">I4s", data[i:i + 8])
        corps = data[i + 8:i + 8 + longueur]
        if typ == b"IHDR":
            largeur, hauteur, prof, ctype, comp, filt, inter = struct.unpack(">IIBBBBB", corps)
            if prof != 8 or ctype != 6 or inter != 0:
                raise ValueError("PNG non attendu (prof=%d type=%d interlace=%d)" % (prof, ctype, inter))
        elif typ == b"IDAT":
            idat += corps
        elif typ == b"IEND":
            break
        i += 12 + longueur
    brut = zlib.decompress(idat)
    octets = largeur * 4
    lignes = []
    pos = 0
    precedent = bytearray(octets)
    for _ in range(hauteur):
        f = brut[pos]
        pos += 1
        ligne = bytearray(brut[pos:pos + octets])
        pos += octets
        for x in range(octets):
            a = ligne[x - 4] if x >= 4 else 0
            b = precedent[x]
            c = precedent[x - 4] if x >= 4 else 0
            if f == 1:
                ligne[x] = (ligne[x] + a) & 0xFF
            elif f == 2:
                ligne[x] = (ligne[x] + b) & 0xFF
            elif f == 3:
                ligne[x] = (ligne[x] + ((a + b) >> 1)) & 0xFF
            elif f == 4:
                p = a + b - c
                pa, pb, pc = abs(p - a), abs(p - b), abs(p - c)
                pr = a if (pa <= pb and pa <= pc) else (b if pb <= pc else c)
                ligne[x] = (ligne[x] + pr) & 0xFF
        lignes.append(ligne)
        precedent = ligne
    return {(x, y) for y, ligne in enumerate(lignes)
            for x in range(largeur) if ligne[x * 4 + 3] > 8}, largeur, hauteur


def rasteriser():
    """Rasterise les icones et verifie qu'elles ne sont pas vides.

    Le rendu se fait sur fond TRANSPARENT : le masque alpha donne exactement
    les pixels encres. On verifie que l'icone n'est pas vide et que les deux
    variantes ont la MEME forme (seules les couleurs changent).
    """
    try:
        import cairosvg
    except ImportError:
        for extra in ("/work/.pylocal", os.path.expanduser("~/.pylocal")):
            if os.path.isdir(os.path.join(extra, "cairosvg")) and extra not in sys.path:
                sys.path.insert(0, extra)
                try:
                    import cairosvg
                    break
                except ImportError:
                    cairosvg = None
        else:
            cairosvg = None
    if cairosvg is None:
        print("NOTE   : raster : cairosvg indisponible -> controle STRUCTUREL et GEOMETRIQUE "
              "uniquement, PAS visuel.")
        return

    masques = {}
    for nom in FICHIERS:
        source = os.path.join(DOSSIER, nom)
        sortie = "/tmp/controle_icones_%s.png" % nom.replace(".svg", "")
        try:
            cairosvg.svg2png(url=source, write_to=sortie,
                             output_width=40, output_height=40)
        except Exception as e:  # pragma: no cover - depend de l'environnement
            echec(nom, "rasterisation impossible : %s" % e)
            continue
        try:
            masque, largeur, hauteur = _png_masque(sortie)
        except Exception as e:
            echec(nom, "lecture du PNG rasterise impossible : %s" % e)
            continue
        if (largeur, hauteur) != (40, 40):
            echec(nom, "rendu %dx%d au lieu de 40x40" % (largeur, hauteur))
        else:
            ok(nom, "rasterise en 40x40 par cairosvg")
        if not masque:
            echec(nom, "l'icone rasterisee est VIDE (aucun pixel encr)")
        else:
            xs = [p[0] for p in masque]
            ys = [p[1] for p in masque]
            ok(nom, "rendu non vide : %d pixels encrs, occupe x %d..%d / y %d..%d"
               % (len(masque), min(xs), max(xs), min(ys), max(ys)))
        masques[nom] = masque

    if len(masques) == 2:
        a, b = (masques[FICHIERS[0]], masques[FICHIERS[1]])
        communs = len(a & b)
        if communs == 0:
            echec("forme", "les 2 icones n'ont AUCUN pixel en commun : ce ne sont pas les memes formes")
        elif communs < 0.98 * min(len(a), len(b)):
            echec("forme", "les 2 icones n'ont pas la meme forme : %d pixels communs "
                  "(%.2f%% du plus petit)" % (communs, 100.0 * communs / min(len(a), len(b))))
        else:
            ok("forme", "les 2 icones ont la MEME forme : %d pixels encres communs "
               "(%.2f%% du plus petit masque)" % (communs, 100.0 * communs / min(len(a), len(b))))


def main():
    print("Controle hostile des icones livrees : %s" % DOSSIER)
    for nom in FICHIERS:
        auditer(nom)
    rasteriser()
    print("FIN controle_icones : %d ECHEC" % len(echecs))
    return 1 if echecs else 0


if __name__ == "__main__":
    sys.exit(main())
