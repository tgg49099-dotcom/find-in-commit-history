#!/usr/bin/env bash
# =============================================================================
# contre_epreuve_prevol_md5.sh — CONTROLE ROUGE du controle de md5 du pre-vol.
#
# « Un controle qui n'a jamais detecte de defaut n'est pas un controle. »
#
# Le 06/11/2026 (cycle 134), le controle des md5 citable du pre-vol a ete elargi :
# un fichier ZIP est desormais citable SI ET SEULEMENT SI il CONTIENT le ZIP livre
# (c'est le cas du paquet /work/pickaxe-soumission/dossier-pickaxe.zip que Tgg recoit).
#
# ELARGIR un controle, c'est risquer de le desarmer. Ce script prouve que la regle
# nouvelle n'a rien desarme :
#
#   Cas 1 — le md5 du PAQUET (qui contient le ZIP livre) est ACCEPTE  -> le pre-vol sort 0
#   Cas 2 — le md5 d'un ANCIEN ZIP (qui ne contient PAS le ZIP livre) est REFUSE
#   Cas 3 — le md5 d'un fichier qui N'EXISTE PAS est REFUSE
#
# On ne touche PAS a /rapports : le pre-vol est recopie dans un repertoire temporaire,
# avec le chemin des rapports redirige vers un faux /rapports. Les fichiers reels du slot
# ne sont donc jamais modifies.
#
# Usage : bash scripts/contre_epreuve_prevol_md5.sh [/chemin/vers/le/projet]
# Code de retour : 0 si et seulement si les 3 cas se comportent comme annonce.
# =============================================================================
set -u

RACINE_SCRIPT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="${1:-$(cd "$RACINE_SCRIPT/.." && pwd)}"
PREVOL="$ROOT/scripts/jetbrains-prevol.sh"
PAQUET="${PAQUET:-/work/pickaxe-soumission/dossier-pickaxe.zip}"
LOG="$ROOT/build/contre-epreuve-prevol-md5.log"

[ -f "$PREVOL" ] || { echo "ERREUR : pre-vol introuvable : $PREVOL" >&2; exit 3; }
[ -f "$PAQUET" ] || { echo "ERREUR : paquet de livraison introuvable : $PAQUET" >&2; exit 3; }
mkdir -p "$(dirname "$LOG")"
exec > >(tee "$LOG") 2>&1

TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT
mkdir -p "$TMP/rapports"

# --- 1. le pre-vol recopie, avec /rapports redirige -----------------------------
sed "s#\"/rapports\"#\"$TMP/rapports\"#g" "$PREVOL" > "$TMP/jetbrains-prevol.sh"
if ! grep -q "$TMP/rapports" "$TMP/jetbrains-prevol.sh"; then
    echo "ECHEC : la redirection de /rapports n'a pas ete appliquée" >&2
    exit 3
fi

MD5_PAQUET="$(md5sum "$PAQUET" | cut -d' ' -f1)"
# un ZIP ANCIEN : il ne contient pas le ZIP livre (c'est un build d'avant)
ZIP_ANCIEN="$(ls -1 /work/preuves/cycle123/zip2/*.zip 2>/dev/null | head -1)"
[ -n "$ZIP_ANCIEN" ] || { echo "ECHEC : aucun ZIP ancien de reference" >&2; exit 3; }
MD5_ANCIEN="$(md5sum "$ZIP_ANCIEN" | cut -d' ' -f1)"
MD5_INCONNU="0123456789abcdef0123456789abcdef"

echo "paquet     : $PAQUET (md5 $MD5_PAQUET)"
echo "zip ancien : $ZIP_ANCIEN (md5 $MD5_ANCIEN)"

ecran() { # ecrans <nom> <md5 cite> <attendu: ACCEPTE|REFUSE>
    local nom="$1" cite="$2" attendu="$3"
    printf 'md5 de controle : %s\n' "$cite" > "$TMP/rapports/rapport.md"
    printf '{"preuve": "%s"}\n' "$cite" > "$TMP/rapports/etat.json"
    printf '# demandes\n\n%s\n' "$cite" > "$TMP/rapports/demandes.md"
    local out="$TMP/$nom.log"
    bash "$TMP/jetbrains-prevol.sh" "$ROOT" > "$out" 2>&1
    local rc=$?
    if [ "$attendu" = "ACCEPTE" ]; then
        if [ $rc -eq 0 ]; then
            echo "[OK] $nom : le md5 est accepte (pre-vol 0 echec)"
        else
            echo "[KO] $nom : le md5 aurait du etre accepte ; le pre-vol a echoue :" >&2
            grep -E "^ECHEC" "$out" | head -3 >&2
            return 1
        fi
    else
        if [ $rc -ne 0 ] && grep -q "$cite" "$out"; then
            echo "[OK] $nom : le md5 est refuse ET nomme dans le message"
        else
            echo "[KO] $nom : le md5 aurait du etre refuse ; rc=$rc" >&2
            grep -E "^ECHEC" "$out" | head -3 >&2
            return 1
        fi
    fi
    return 0
}

echec=0
ecran "cas1-paquet" "$MD5_PAQUET" "ACCEPTE" || echec=1
ecran "cas2-zip-ancien" "$MD5_ANCIEN" "REFUSE" || echec=1
ecran "cas3-md5-inconnu" "$MD5_INCONNU" "REFUSE" || echec=1

if [ "$echec" -ne 0 ]; then
    echo "CONTRE-EPREUVE PRE-VOL (md5) : ECHEC"
    exit 1
fi
echo "CONTRE-EPREUVE PRE-VOL (md5) : OK (le paquet est accepte, l'ancien ZIP et le md5 inconnu sont refuses)"
exit 0
