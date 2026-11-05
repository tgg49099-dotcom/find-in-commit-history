# NOTES-PUBLICATION-PROCEDURE.md — suivi après publication (« Find in Commit History »)

> ⚠ **Déplacé le 05/11/2026 (cycle 125)** : sur consigne de la mère, `NOTES-PUBLICATION.md` ne
> contient plus que **la ligne d'état** de la 0.0.2 ; cette procédure a été déplacée **ici, sans
> changement de contenu**, pour rester disponible pour Tgg (le 06/11 au matin).
> Les renvois vers `NOTES-PUBLICATION.md` dans `MISE-VENTE-TGG.md` ont été corrigés le même jour.

> **Écrit le 05/11/2026 18:31**, avant la publication : le plugin **n'est pas encore publié**
> (0 POST, 0 PUT, 0 jeton Marketplace lu ou posé).
> Cette fiche est **la procédure à exécuter une fois le 1ᵉʳ upload fait par Tgg**, dans l'ordre.
> Chaque ligne est **datée** et **vérifiable** : commande exacte + résultat attendu + emplacement
> du résultat.

**T0 = la date de la publication (le jour où JetBrains met la version 0.0.1 en ligne).**
Remplacer `<ID>` par le **numéro numérique** attribué par le Marketplace, et `T0` par la date
réelle, dans tout ce document.

**Rappel du contexte** : le plugin est **gratuit** (`pricingModel` attendu `FREE`) → **le revenu est
0 $**, quoi qu'il arrive ; les « téléchargements » ne sont **pas** des ventes. Ne jamais annoncer
autre chose que ce qui est mesuré.

---

## 0. Avant de commencer — les 3 prérequis

| | Valeur attendue | Vérification |
|---|---|---|
| Le ZIP livré | md5 `00f2bc2495fcd34b7a46cc9da5e8a8d4` · sha256 `9687a8551e4d4147558c772d34b9bffd888303921b12cac8e94ab45a415578d9` · 3 133 212 o | `cd /work/pickaxe && sha256sum -c SHA256.txt && md5sum build/distributions/FindinCommitHistory-0.0.1.zip` |
| Le numéro numérique | `<ID>` (attribué par le Marketplace à l'upload) | `GET https://plugins.jetbrains.com/api/vendors/tgg-labs/plugins` → le champ `id` de l'entrée `com.tgglabs.pickaxe` |
| Le commit du CODE dans le dépôt public | `1dbbcb0eb9b9efc55e42a3f8f17760b7af3eb9ef` (67 fichiers ; des commits de documentation peuvent être au-dessus) | `GET https://api.github.com/repos/tgg49099-dotcom/find-in-commit-history/commits?per_page=1` |

---

## (a) La page est accessible et le plugin se charge dans l'IDE

**À faire : T0 + 0 (le soir de la publication), puis T0 + 1.**

| # | Contrôle | Commande | Attendu |
|---|---|---|---|
| a1 | La page du plugin répond | `curl -s -o /dev/null -w "%{http_code}\n" "https://plugins.jetbrains.com/plugin/<ID>-find-in-commit-history"` | `200` |
| a2 | La page contient le bon nom | `curl -s "https://plugins.jetbrains.com/plugin/<ID>-find-in-commit-history" \| grep -c "Find in Commit History"` | ≥ 1 |
| a3 | L'API renvoie la bonne fiche | `curl -s "https://plugins.jetbrains.com/api/plugins/<ID>"` | `xmlId` = `com.tgglabs.pickaxe` · `name` = `Find in Commit History` · `pricingModel` = `FREE` · `isHidden` = `false` · `isBlocked` = `false` |
| a4 | La version 0.0.1 est listée | `curl -s "https://plugins.jetbrains.com/api/plugins/<ID>/updates"` | un objet `version` = `0.0.1`, `approve` = `true`, `listed` = `true`, `since` = `262`, `size` = `3133212` |
| a5 | Les captures sont bien en ligne | `curl -s "https://plugins.jetbrains.com/api/plugins/<ID>"` → champ `screens` | **3** entrées (les 3 du § e) |
| a6 | Le ZIP **servi par le Marketplace** est le nôtre | `curl -sL "https://plugins.jetbrains.com/plugin/download?pluginId=<ID>&version=0.0.1" -o /tmp/dl.zip && unzip -p /tmp/dl.zip '*/lib/FindinCommitHistory-0.0.1.jar' \| md5sum` | le md5 du **jar interne** = celui de notre ZIP. ⚠ **le md5 du ZIP servi ne sera pas forcément le nôtre** : le Marketplace réécrit le répertoire central (écart mesuré de 5 660 o sur le plugin 35416). Comparer le **jar**, pas l'enveloppe. |
| a7 | **Le plugin se charge dans un vrai IDE** | installer le ZIP **téléchargé depuis le Marketplace** dans une config neuve de PyCharm 2026.2.4 et le lancer | ligne de log **exacte** : `Loaded custom plugins: Find in Commit History (0.0.1)` · **0** erreur sur `com.tgglabs.pickaxe` |
| a8 | ⭐ **Le plugin a bien été « ajouté au Marketplace »** | sur la page du plugin, onglet **« Sales Info »** : le bouton « Add to Marketplace » a bien été actionné | ⚠ **l'upload seul ne suffit pas** : sans ce second geste, le plugin existe mais n'est pas en ligne (doc officielle « Release the plugin », § 5.1 de `MISE-VENTE-TGG.md`). Tant que `approve` = `false`, il n'est pas listé : c'est **normal**. |

**Preuve à conserver** : `/work/preuves/cycle124/` — captures **prises sur le ZIP livré**
(`/work/preuves/cycle124/captures/`, 5 images de 1200 × 780 px, recadrées sur la fenêtre du
dialogue) + `/work/preuves/cycle124/verification-captures.log` (contrôle pixel par pixel) +
`/work/preuves/cycle124/preuves-v8/idecfg/log/idea.log` (chargement du plugin : « Loaded custom
plugins: Find in Commit History (0.0.1) »).
⚠ Rappel d'expérience : la preuve IDE du cycle 120 a vérifié le **chargement** mais ses captures
montraient l'écran d'accueil, pas le dialogue (le dialogue ne s'ouvrait pas dans le flux de captures).
Il faut **explicitement** piloter l'ouverture du dialogue et le capturer.
⚠ Autre rappel mesuré le 05/11 19:05 : une **config IDE neuve** fait apparaître la modale
« Meet the Islands Theme », qui **intercepte tous les clics** (elle est dessinée *dans* la
fenêtre de l'IDE : `xdotool search --name "Islands"` ne la trouve pas). → pour une preuve IDE,
**réutiliser une config déjà nettoyée** (c'est ce qu'a fait le cycle 119), ou cliquer sur
« Skip » avant toute manipulation.

---

## (b) Remplacer l'URL par le numéro numérique — fiche ET dépôt public

**À faire : T0 + 0**, dès que `<ID>` est connu.

| # | Où | Quoi | Comment |
|---|---|---|---|
| b1 | `FICHE-MARKETPLACE.md` **§ 5**, champ **`url`** | remplacer `https://plugins.jetbrains.com/plugin/<ID>-find-in-commit-history` (le `<ID>`) par le vrai numéro | édition du fichier local `/work/pickaxe/FICHE-MARKETPLACE.md` |
| b2 | `FICHE-MARKETPLACE.md` § 5, champ **`forumUrl`** | idem (`forumUrl` = `url` : le plugin n'a pas de forum propre) | idem |
| b3 | `FICHE-MARKETPLACE.md` § 5, champ **`docUrl`** / **`bugtrackerUrl`** | inchangés (GitHub) | — |
| b4 | **Dépôt public** | `README.md` (et tout fichier qui cite l'URL du plugin) : remplacer par l'URL à numéro | commit + push |
| b5 | **Fiche Marketplace côté plateforme** | `PUT https://plugins.jetbrains.com/api/plugins/<ID>` avec le bloc `urls` **complet** | ⚠ ce PUT **remplace tout le bloc `urls`** : renvoyer **les 8 clés ensemble** (`url`, `forumUrl`, `licenseUrl`, `privacyPolicyUrl`, `bugtrackerUrl`, `docUrl`, `sourceCodeUrl`, `donationLinks`), sinon les autres liens disparaissent. |
| b6 | `README.md` (public) + `SHA256.txt` | si le ZIP a été reconstruit entre-temps, **remesurer** md5 + sha256 et réécrire les 4 documents (`SHA256.txt`, `FICHE-MARKETPLACE.md`, `rapport.md`, `etat.json`) | puis **rejouer le pré-vol** : toute modification d'un de ces 4 documents impose de rejouer `scripts/jetbrains-prevol.sh` **après** la dernière écriture |
| b7 | `/rapports/produits.json` | **ajouter** l'entrée : `{"plateforme": "jetbrains", "id": "<ID>", "nom": "Find in Commit History", "xmlId": "com.tgglabs.pickaxe", "version": "0.0.1", "url": "https://plugins.jetbrains.com/plugin/<ID>-find-in-commit-history"}` | c'est ce qui fait **relever les vrais chiffres chaque matin** par le serveur |
| b8 | `/rapports/etat.json` | `statut` → mentionner que le plugin est en ligne et approuvé | — |

---

## (c) Mesurer les téléchargements à J+1, J+7, J+14

**L'API publique du Marketplace** (aucun jeton, aucun compte) :

```
curl -s "https://plugins.jetbrains.com/api/plugins/<ID>" | python3 -c "import sys,json; d=json.load(sys.stdin); print('downloads =', d['downloads'])"
```

| Quand | Date à remplir | Ce qu'on mesure | Où l'écrire |
|---|---|---|---|
| **J+1** | T0 + 1 | `downloads` | `/rapports/etat.json` → `preuve` + une ligne dans `rapport.md` |
| **J+7** | T0 + 7 | `downloads` | idem, **en citant J+1 dans le texte** (la différence est ce qui parle) |
| **J+14** | T0 + 14 | `downloads` | idem |

**Règles d'honnêteté, non négociables :**
* `downloads` = **téléchargements**, **pas** des ventes. Le plugin est **gratuit** ⇒
  **`revenu_declare_usd = 0`**, quel que soit le chiffre.
* Écrire le nombre **tel quel**, avec la date. Jamais « environ », jamais un pourcentage.
* Le compteur monte aussi du fait des **mises à jour** et des **robots** : c'est un indicateur
  d'audience, rien de plus.
* ⚠ **Le plugin est en `approve:false` tant qu'il n'est pas approuvé** : les téléchargements ne
  commences à compter qu'à partir de la **mise en ligne réelle**. Mesurer `approve`/`listed` en
  même temps que `downloads`, sinon on compare un compteur à un état.

---

## (d) Un avis public est arrivé — quoi répondre

**Règle absolue : on ne contacte JAMAIS l'utilisateur.** Ni courriel, ni message privé, ni
réponse sur la page d'avis. Le plugin n'a pas de « support » humain : c'est une politique, pas une
promesse.

**Ce que l'avis déclenche : une version suivante.**

1. **Lire** l'avis (page `/plugin/<ID>-find-in-commit-history/reviews` ou l'API des avis).
2. **Classer** :
   * **Bug** (la fonction ne fait pas ce qu'elle annonce) → **reproduire** dans un dépôt de test,
     écrire un **test de régression rouge → vert**, corriger, **reconstruire**, **remesurer** les
     empreintes, réécrire les 4 documents, rejouer le pré-vol, publier **0.0.2**.
   * **Demande de fonctionnalité** → la **noter** dans `NOTES.md` et dans le dossier de décisions.
     **Ne pas promettre** de date, ne pas répondre, ne pas implémenter dans l'urgence.
   * **Confusion d'usage** (le plugin a mal été compris) → la réponse est **la documentation** :
     `README.md` et les notes de version de la version suivante.
3. **La réponse publiée, c'est la version suivante + ses notes de version.** Concrètement : la
   version 0.0.2 dont les `<change-notes>` mentionnent la correction ou la clarification.
4. **Ne jamais** éditer, supprimer ni commenter un avis sur le Marketplace.

---

## (e) Les captures à ajouter à la page du Marketplace

Les **3 captures de la fiche** sont dans `MISE-VENTE-TGG.md` § 3 : elles sont prises sur le **ZIP
livré** (05/11/2026, 21:45), font **1200 × 780 px** et ne montrent **que le dialogue du plugin**
(pas de fond d'IDE, pas de bulle jaune) :
`02-resultats.png` · `03-hash-copie.png` · `05-dialogue-filtre-chemin.png`
(dossier : `/work/preuves/cycle124/captures/`).

Si le formulaire en demande **plus de 3**, ajouter celles-ci, dans cet ordre :

| # | Chemin exact | Ce qu'elle montre |
|---|---|---|
| 4 | `/work/preuves/cycle124/captures/01-dialogue-chaine.png` | l'état initial du dialogue : la chaîne saisie, le mode `STRING`, le champ de filtre — liste encore vide |
| 5 | `/work/preuves/cycle124/captures/04-verif-presse-papier.png` | le hash **recollé** dans le champ : la preuve que le presse-papier contient bien le hash copié par le double-clic |

⚠ Les anciennes captures n° 4 et n° 5 (cycles 116 et 119) sont **retirées** : la n° 5 portait deux
bulles d'avertissement jaunes de l'IDE et les deux montraient le **fond d'IDE**.

---

## F. Ce qu'il ne faut pas faire

* ❌ Ne pas reconstruire le ZIP « pour rafraîchir » : les empreintes changent et le pré-vol saute.
  Reconstruire **seulement** pour une correction de code, puis remesurer et réécrire les 4 documents.
* ❌ Ne pas répondre aux utilisateurs, ni en privé, ni sur la page d'avis.
* ❌ Ne pas annoncer de revenu : le plugin est gratuit.
* ❌ Ne pas publier une version si le pré-vol officiel n'est pas **vert** après la dernière
  modification d'un des 4 documents.
* ❌ Ne pas oublier `/rapports/produits.json` (b7) : sans l'identifiant, le serveur ne relèvera
  jamais les chiffres.

---

## G. Tableau de suivi (à remplir au fil de l'eau)

| Date | Étape | Résultat mesuré | Où |
|---|---|---|---|
| 05/11/2026 18:31 | cette fiche est écrite | — | `/work/pickaxe/NOTES-PUBLICATION.md` |
| T0 | upload manuel par Tgg | `approve` / `listed` | `GET /api/plugins/<ID>` |
| T0 | § b (URL + dépôt + produits.json) | | |
| T0 + 1 | § c — J+1 | `downloads = …` | `etat.json` |
| T0 + 7 | § c — J+7 | `downloads = …` | `etat.json` |
| T0 + 14 | § c — J+14 | `downloads = …` | `etat.json` |
| à chaque avis | § d | version suivante | `NOTES.md` |
