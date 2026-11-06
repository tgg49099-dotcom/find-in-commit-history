#!/usr/bin/env bash
# =============================================================================
# verif_cycle140.sh — controle mécanique des 10 items de la CONSIGNE 5d
# (06/11/2026). Lecture seule : n'ecrit rien, ne construit rien.
# Sortie : /work/preuves/cycle140/verif-cycle140.log
# =============================================================================
set -u
ROOT=/work/pickaxe
ZIP="$ROOT/build/distributions/FindinCommitHistory-0.0.2.zip"
PKG=/work/A_ENVOYER/pickaxe/dossier-pickaxe.zip
RAPP=/work
OLD_PREFIX="e160068""c"        # prefixe du md5 PERIME du ZIP 0.0.2 (ancien build) :
                               # ecrit en 2 morceaux pour que ce fichier ne soit
                               # PAS compte par le grep de verification lui-meme.
RC=0
ok()   { echo "  [VERT ] $1"; }
ko()   { echo "  [ROUGE] $1"; RC=1; }
verif(){ if [ "$2" = "1" ]; then ok "$1"; else ko "$1${3:+ — $3}"; fi; }

echo "================================================================"
echo "VERIFICATION CYCLE 140 — les 10 items de la CONSIGNE 5d"
echo "================================================================"

# --- 1. plugin.xml de la 0.0.2, dans le ZIP livre ----------------------
echo
echo "[1] plugin.xml 0.0.2 (dans le ZIP livre)"
TMP=$(mktemp -d); ( cd "$TMP" && unzip -q -o "$ZIP" ) || { echo "  [ROUGE] ZIP illisible"; RC=1; }
JARNAME=$(cd "$TMP" && ls FindinCommitHistory/lib/*.jar | head -1)
( cd "$TMP" && unzip -q -o "$JARNAME" META-INF/plugin.xml )
X="$TMP/META-INF/plugin.xml"
verif "version = 2026.1.0"            "$(grep -q '<version>2026.1.0</version>' "$X" && echo 1 || echo 0)"
verif "release-version = 20261"        "$(grep -q 'release-version="20261"' "$X" && echo 1 || echo 0)"
verif "release-date = 20261106"        "$(grep -q 'release-date="20261106"' "$X" && echo 1 || echo 0)"
verif "code = PPICKAXEPRO"           "$(grep -q 'code="PPICKAXEPRO"' "$X" && echo 1 || echo 0)"
verif "optional = true"                "$(grep -q 'optional="true"' "$X" && echo 1 || echo 0)"
verif "since-build inchange (243)"     "$(grep -q 'since-build="243"' "$X" && echo 1 || echo 0)"
VM=$(grep -o '<version>[^<]*' "$X" | head -1 | cut -d'>' -f2)
VMAJ=$(echo "$VM" | cut -d. -f1,2 | tr -d '.')
RV=$(grep -o 'release-version="[^"]*' "$X" | head -1 | cut -d'"' -f2)
verif "version et release-version correspondent (${VM} <-> ${RV})" \
      "$([ "$VMAJ" = "$RV" ] && echo 1 || echo 0)"
verif "le descripteur de produit est present" \
      "$(grep -q '<product-descriptor' "$X" && echo 1 || echo 0)"

# --- 2. etat de licence injectable --------------------------------------
echo
echo "[2] classe d'etat de licence injectable"
F="$ROOT/src/main/java/com/tgglabs/pickaxe/pro/LicenceEtat.java"
I="$ROOT/src/main/java/com/tgglabs/pickaxe/pro/FournisseurLicence.java"
M="$ROOT/src/main/java/com/tgglabs/pickaxe/ide/LicenceMarketplace.java"
verif "LicenceEtat.java existe"                 "$([ -f "$F" ] && echo 1 || echo 0)"
verif "LicenceEtat expose estPro()"             "$(grep -q 'estPro()' "$F" && echo 1 || echo 0)"
verif "la source de licence est une interface injectable" \
      "$([ -f "$I" ] && grep -q 'interface FournisseurLicence' "$I" && echo 1 || echo 0)"
verif "le code produit lu est exactement PPICKAXEPRO" \
      "$(grep -q 'CODE_PRODUIT = "PPICKAXEPRO"' "$M" && echo 1 || echo 0)"
verif "l'impl IDE appelle LicensingFacade.getConfirmationStamp(CODE_PRODUIT)" \
      "$(grep -q 'getConfirmationStamp(CODE_PRODUIT)' "$M" && echo 1 || echo 0)"
verif "l'impl IDE lit com.intellij.ui.LicensingFacade" \
      "$(grep -q 'com.intellij.ui.LicensingFacade' "$M" && echo 1 || echo 0)"
verif "getInstance() == null => etat INCONNU (distinct de 'pas licencie')" \
      "$(grep -q 'facade == null' "$M" && grep -q 'licenceInconnue' "$F" && echo 1 || echo 0)"

# --- 3. les 4 fonctions Pro sont gardees --------------------------------
echo
echo "[3] branchement Pro des 4 fonctions"
P="$ROOT/src/main/java/com/tgglabs/pickaxe/pro/FonctionsPro.java"
verif "FonctionsPro.java existe"        "$([ -f "$P" ] && echo 1 || echo 0)"
verif "P1 recherche dans les messages"  "$(grep -q 'rechercherParMessages' "$P" && echo 1 || echo 0)"
verif "P2 export"                       "$(grep -q 'exporter' "$P" && echo 1 || echo 0)"
verif "P3 recherches enregistrees"     "$(grep -q 'recherchesSauvegardees' "$P" && echo 1 || echo 0)"
verif "P4 multi-depots"                 "$(grep -q 'rechercherDansTousLesDepots' "$P" && echo 1 || echo 0)"
NB=$(grep -oE '^\s*public [A-Za-z<>, ]+ [a-zA-Z]+\(' "$P" | grep -oE '[a-zA-Z]+\($' | tr -d '(' | LC_ALL=C sort | tr '\n' ' ')
LISTE_ATT="estPro exporter rechercherDansTousLesDepots rechercherParMessages rechercherParMessagesEtDiffs recherchesSauvegardees sauvegarderRecherche "
echo "         (methodes publiques de FonctionsPro.java : $NB)"
verif "le message de refus est fixe : 'fonction Pro — licence requise'" \
      "$(grep -q 'fonction Pro — licence requise' "$F" && \
         grep -q 'fonction Pro — licence requise' "$ROOT/src/main/java/com/tgglabs/pickaxe/pro/FonctionProRefuseeException.java" && echo 1 || echo 0)"
verif "aucune 5e fonction Pro : la liste des methodes publiques est exactement celle connue" \
      "$([ "$NB" = "$LISTE_ATT" ] && echo 1 || echo 0)" "($NB)"

# --- 4. les 2 tests exiges ----------------------------------------------
echo
echo "[4] les 2 tests de licence exiges"
T="$ROOT/src/test/java/com/tgglabs/pickaxe/pro/FonctionsProTest.java"
verif "sansLicenceLes4FonctionsProSontRefusees" \
      "$(grep -q 'void sansLicenceLes4FonctionsProSontRefusees' "$T" && echo 1 || echo 0)"
verif "avecLicenceLes4FonctionsProSExecutent" \
      "$(grep -q 'void avecLicenceLes4FonctionsProSExecutent' "$T" && echo 1 || echo 0)"
verif "le coeur gratuit sans licence est teste" \
      "$(grep -q 'void sansLicenceLeCoeurGratuitMarcheToujours' "$T" && echo 1 || echo 0)"
RES=$(bash "$ROOT/scripts/run_tests.sh" 2>&1 | grep -E 'tests (found|successful|failed)' | tr -s ' ')
echo "         $RES"
verif "82 tests trouves / 82 verts / 0 rouge" \
      "$(echo "$RES" | grep -q '82 tests found' && echo "$RES" | grep -q '82 tests successful' && \
         echo "$RES" | grep -q '0 tests failed' && echo 1 || echo 0)"
verif "contre-epreuve : le test (a) devient ROUGE quand l'etat change" \
      "$(grep -q 'CONTRE-EPREUVE CONCLUANTE' /work/preuves/cycle140/contre-epreuve-licence.log && echo 1 || echo 0)"

# --- 5. ZIP 0.0.2 + SHA256.txt ------------------------------------------
echo
echo "[5] ZIP 0.0.2 et SHA256.txt"
verif "le ZIP existe" "$([ -f "$ZIP" ] && echo 1 || echo 0)"
echo "         md5    : $(md5sum "$ZIP" | cut -d' ' -f1)"
echo "         sha256 : $(sha256sum "$ZIP" | cut -d' ' -f1)"
echo "         taille : $(stat -c%s "$ZIP") o"
verif "md5 + sha256 + taille dans SHA256.txt" \
      "$(grep -q '9bb750148ad16f273355c4b512980027' "$ROOT/SHA256.txt" && \
         grep -q 'da160fe666879508b0cd69f917a0f90d4c753df730f8f545310b2099adf208f7' "$ROOT/SHA256.txt" && \
         grep -qE '3 ?159 ?786' "$ROOT/SHA256.txt" && echo 1 || echo 0)"
verif "sha256sum -c SHA256.txt : 2/2 OK" \
      "$([ "$(cd "$ROOT" && sha256sum -c SHA256.txt 2>/dev/null | grep -c ': OK')" = "2" ] && echo 1 || echo 0)"

# --- 6. PAYDANT § 6 refait, § 7 intact ---------------------------------
echo
echo "[6] PAYDANT-0.0.2.md : § 6 refait, § 7 inchange"
PA=/work/soumission/PAYDANT-0.0.2.md
verif "§ 6 dit 'ce qui EST FAIT'" \
      "$(grep -q 'ce qui EST FAIT' "$PA" && echo 1 || echo 0)"
verif "§ 6 ne contient plus la phrase 'decrit ce qui sera fait'" \
      "$(grep -q 'decrit ce qui sera fait' "$PA" && echo 0 || echo 1)"
S7A=$(python3 -c "import re,hashlib,sys;t=open(sys.argv[1],encoding='utf-8').read();i=t.index('## 7.');j=t.find(chr(10)+'## ',i+1);s=t[i:j if j>0 else len(t)];print(hashlib.md5(s.rstrip(chr(10)).encode()).hexdigest())" "$PA")
S7B=$(python3 -c "import hashlib,sys;t=open(sys.argv[1],encoding='utf-8').read();print(hashlib.md5(t.rstrip(chr(10)).encode()).hexdigest())" /work/verifs-cycle139/sections/sec7.apres.md 2>/dev/null)
echo "         § 7 actuel (sans saut de ligne final) : $S7A"
echo "         § 7 cycle 139 (idem)                : $S7B"
verif "§ 7 byte-identique au § 7 du cycle 139 (saut de ligne final normalise)" \
      "$([ -n "$S7B" ] && [ "$S7A" = "$S7B" ] && echo 1 || echo 0)"

# --- 7. la fiche de vente 0.0.2 ----------------------------------------
echo
echo "[7] MISE-VENTE-0.0.2-TGG.md"
V=/work/pickaxe/MISE-VENTE-0.0.2-TGG.md
verif "le fichier existe"                       "$([ -f "$V" ] && echo 1 || echo 0)"
verif "code produit en clair : PPICKAXEPRO"   "$(grep -q 'PPICKAXEPRO' "$V" && echo 1 || echo 0)"
verif "prix : 29 \$ / an"                       "$(grep -q '29 \$' "$V" && echo 1 || echo 0)"
verif "essai : 14 jours"                        "$(grep -q '14 jours' "$V" && echo 1 || echo 0)"
verif "le ZIP a televerser est nomme"           "$(grep -q 'FindinCommitHistory-0.0.2.zip' "$V" && echo 1 || echo 0)"
verif "3 gestes (3 titres 'Geste')"             "$([ "$(grep -c '^### Geste' "$V")" = "3" ] && echo 1 || echo 0)"
verif "lien exact du depot : /plugin/add"       "$(grep -q 'https://plugins.jetbrains.com/plugin/add' "$V" && echo 1 || echo 0)"
verif "lien exact de Sales Info"                "$(grep -q 'sales/info' "$V" && echo 1 || echo 0)"
NG=$(awk '/^### Geste/{n++} /^> \*\*/{if(n>0 && n<=3) b[n]++} END{print b[1]" "b[2]" "b[3]}' "$V")
verif "chaque geste = UNE phrase (1 bloc '> **' par geste)" \
      "$([ "$NG" = "1 1 1" ] && echo 1 || echo 0)" "($NG)"

# --- 8. UNE phrase corrigee dans MISE-VENTE-TGG.md ---------------------
echo
echo "[8] MISE-VENTE-TGG.md : les corrections D2 (statut commercant) appliquees"
OLD=/work/preuves/cycle142/avant/MISE-VENTE-TGG.md
NEW=/work/pickaxe/MISE-VENTE-TGG.md
PAT_FAUX=$(printf 'isTrader:%s' 'false')
NBREM=$(diff "$OLD" "$NEW" | grep -c '^<')
verif "aucune occurrence de la mention fausse dans le fichier" \
      "$(grep -qF "$PAT_FAUX" "$NEW" && echo 0 || echo 1)"
verif "les corrections D2 ont ete appliquees (au moins 6 lignes retirees)" \
      "$([ "$NBREM" -ge 6 ] && echo 1 || echo 0)" "($NBREM ligne(s) retirees)"
verif "la date de mesure du 06/11/2026 20:10 est citee" \
      "$(grep -q '06/11/2026 20:10' "$NEW" && echo 1 || echo 0)"
verif "la ligne « Modifier le statut Trader ou l'IBAN » est en place" \
      "$(grep -q "Modifier le statut Trader ou l'IBAN" "$NEW" && echo 1 || echo 0)"
verif "les copies locales sont identiques (pickaxe / soumission / A_ENVOYER)" \
      "$([ "$(md5sum "$NEW" | cut -d' ' -f1)" = "$(md5sum /work/A_ENVOYER/pickaxe/MISE-VENTE-TGG.md | cut -d' ' -f1)" ] && \
       [ "$(md5sum "$NEW" | cut -d' ' -f1)" = "$(md5sum /work/soumission/MISE-VENTE-TGG.md | cut -d' ' -f1)" ] && echo 1 || echo 0)"

# --- 9. paquet de livraison + balayage des md5 --------------------------
echo
echo "[9] dossier-pickaxe.zip : les 4 elements demandes, PAS le 0.0.1"
verif "le paquet existe" "$([ -f "$PKG" ] && echo 1 || echo 0)"
NBENT=$(unzip -l "$PKG" | tail -1 | awk '{print $2}')
echo "         md5    : $(md5sum "$PKG" | cut -d' ' -f1)"
echo "         taille : $(stat -c%s "$PKG") o — $NBENT entrees"
unzip -l "$PKG" | awk 'NR>3 && NF>=4 {print "           " $4}'
verif "7 entrees (ZIP 0.0.2 + MISE-VENTE-0.0.2-TGG + MISE-VENTE-TGG + 3 captures)" \
      "$([ "$NBENT" = "7" ] && echo 1 || echo 0)"
ZIN=$(unzip -p "$PKG" FindinCommitHistory-0.0.2.zip | md5sum | cut -d' ' -f1)
verif "le ZIP 0.0.2 dans le paquet est bit-identique (9bb75014…)" \
      "$([ "$ZIN" = "9bb750148ad16f273355c4b512980027" ] && echo 1 || echo 0)"
verif "le ZIP 0.0.1 n'est PAS dans le paquet" \
      "$(unzip -l "$PKG" | grep -q 'FindinCommitHistory-0.0.1.zip' && echo 0 || echo 1)"
MI=$(unzip -p "$PKG" MISE-VENTE-TGG.md | md5sum | cut -d' ' -f1)
verif "MISE-VENTE-TGG.md dans le paquet = la version corrigee (ee78807c…)" \
      "$([ "$MI" = "$(md5sum /work/pickaxe/MISE-VENTE-TGG.md | cut -d' ' -f1)" ] && echo 1 || echo 0)"
M2=$(unzip -p "$PKG" MISE-VENTE-0.0.2-TGG.md | md5sum | cut -d' ' -f1)
verif "MISE-VENTE-0.0.2-TGG.md dans le paquet = la version a jour (meme md5 que /work/pickaxe)" \
      "$([ "$M2" = "$(md5sum /work/pickaxe/MISE-VENTE-0.0.2-TGG.md | cut -d' ' -f1)" ] && echo 1 || echo 0)"
verif "le ZIP 0.0.1 livre n'a pas ete reconstruit" \
      "$([ "$(md5sum /work/A_ENVOYER/pickaxe/FindinCommitHistory-0.0.1.zip | cut -d' ' -f1)" = "b5e1d00b93eec4883699f9ea6eaed649" ] && echo 1 || echo 0)"
LISTE=$(grep -rl -- "$OLD_PREFIX" /work/A_ENVOYER /work/pickaxe /work/soumission /work/produits 2>/dev/null | grep -v '/build/' || true)
NB=$(printf '%s' "$LISTE" | grep -c . || true)
[ -n "$LISTE" ] && echo "         fichiers qui matchent encore : $LISTE"
verif "aucun md5 perime dans les documents vivants (dossier, fiches, produit)" \
      "$([ "$NB" = "0" ] && echo 1 || echo 0)" "($NB fichier(s))"

# --- 10. taches Jules ---------------------------------------------------
echo
echo "[10] taches Jules deposees"
JL=/work/jules-a-faire.txt
N=$(grep -c ' | ' "$JL")
verif "3 a 6 taches deposees" "$([ "$N" -ge 3 ] && [ "$N" -le 6 ] && echo 1 || echo 0)" "($N lignes)"
verif "chaque ligne de tache a la forme 'chemin | consigne'" \
      "$(grep ' | ' "$JL" | awk -F' \\| ' 'NF!=2{bad=1} END{exit bad+0}' && echo 1 || echo 0)"
verif "les chemins sont relatifs a /work et existent" \
      "$(grep ' | ' "$JL" | while IFS='|' read -r p _; do [ -e "/work/$(echo "$p" | tr -d ' ')" ] || exit 1; done && echo 1 || echo 0)"
verif "les chemins commencent par produits/pickaxe (dossier de produit reconnu)" \
      "$(grep ' | ' "$JL" | cut -d'|' -f1 | tr -d ' ' | grep -c '^produits/pickaxe/' | grep -q '^6$' && echo 1 || echo 0)"

rm -rf "$TMP"
echo
echo "================================================================"
if [ "$RC" = "0" ]; then echo "RESULTAT : TOUT VERT (RC 0)"; else echo "RESULTAT : AU MOINS 1 CONTROLE ROUGE (RC 1)"; fi
echo "================================================================"
exit $RC
