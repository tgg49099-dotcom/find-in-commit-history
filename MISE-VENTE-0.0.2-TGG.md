# MISE-VENTE-0.0.2-TGG.md — mettre en vente la 0.0.2 payante (Freemium natif JetBrains)

> **3 gestes. Un geste = UNE phrase. Rien d'autre à faire.**
> Le code de la 0.0.2 est **écrit, testé et compilé** (82 tests verts, ZIP construit et vérifié le
> 06/11/2026) : il ne manque que ces 3 gestes pour que la vente existe.
> Ce fichier remplace la partie « mise en vente » de `MISE-VENTE-TGG.md` (qui reste valable pour
> le téléversement de la **0.0.1**, gratuite).

---

## 0. Ce qu'il faut téléverser (le ZIP livré — ne pas reconstruire)

| | |
|---|---|
| **Fichier** | `/work/pickaxe/build/distributions/FindinCommitHistory-0.0.2.zip` |
| **Taille** | **3 159 786 octets** |
| **md5** | `9bb750148ad16f273355c4b512980027` |
| **sha256** | `da160fe666879508b0cd69f917a0f90d4c753df730f8f545310b2099adf208f7` |
| **Contenu** | 3 jars : le plugin, JGit 6.10.1, JavaEWAH 1.1.12 — **aucun slf4j**, aucun `.lic` |
| **Copie durable (même fichier, même md5)** | `/work/A_ENVOYER/pickaxe/FindinCommitHistory-0.0.2.zip` (à côté de la 0.0.1, qui reste intacte) |

**Ne pas re-zipper, ne pas renommer, ne pas re-compresser** ce fichier : c'est lui, tel quel, qui
doit être déposé. La 0.0.1 (`FindinCommitHistory-0.0.1.zip`, md5 `b5e1d00b93eec4883699f9ea6eaed649`)
**n'est pas concernée** : elle a déjà été envoyée, elle ne se reconstruit pas.

**Contrôle avant de déposer** (1 ligne) :

```
md5sum /work/pickaxe/build/distributions/FindinCommitHistory-0.0.2.zip
```

→ doit afficher `9bb750148ad16f273355c4b512980027`. Sinon, **arrête-toi** et envoie la ligne.

---

## 1. Les 3 gestes

### Geste 1 — téléverser le ZIP 0.0.2

> **Sur `https://plugins.jetbrains.com/plugin/add`, joindre `/work/pickaxe/build/distributions/FindinCommitHistory-0.0.2.zip` (3 159 786 octets) et valider l'envoi — c'est cet envoi qui fait passer la fiche du plugin du modèle gratuit au modèle payant/freemium.**

*(Le ZIP contient déjà le descripteur de produit : `<product-descriptor code="PPICKAXEPRO" release-date="20261106" release-version="20261" optional="true"/>` — **rien à cocher dans le formulaire** pour le faire.)*

### Geste 2 — saisir le code produit, le prix et l'essai dans l'onglet Sales Info

> **Dans l'onglet « Sales Info » de la page du plugin — `https://plugins.jetbrains.com/plugin/<ID>-find-in-commit-history/sales/info` — cliquer sur le bouton « Add to Marketplace » et y saisir le code produit `PPICKAXEPRO`, le palier « Personal » à 29 $ pour 1 an, et une période d'essai de 14 jours, puis valider le formulaire.**

`<ID>` = le **numéro attribué par le Marketplace** au téléversement (il remplace `<ID>` dans le
lien ci-dessus ; le slug du plugin est `find-in-commit-history`, d'après son nom « Find in Commit
History »).

⚠ **L'essai de 14 jours se règle ICI, dans ce formulaire — il n'y a aucun code d'essai dans le
plugin** (le plugin ne fait que lire l'état de licence renvoyé par l'IDE). La valeur par défaut
serait **30 jours** : il faut donc **changer le champ « Trial Period »** (bouton « Edit Section »,
valeurs possibles : 7, 10, 14, 30 jours ou désactivé).

⚠ **Si le bouton « Add to Marketplace » n'apparaît pas**, la doc officielle dit exactement ce qu'il
faut faire : vérifier les **coordonnées bancaires** dans l'onglet « Trader Details » du profil
vendor — si le statut Trader est déjà positionné et l'IBAN déjà saisi (c'est le cas : statut Trader
et IBAN sont en place), **fais 1 capture de l'écran et envoie-la avec le message exact**, sans
modifier ni le code produit, ni le prix, ni le statut.

### Geste 3 — activer les ventes

> **Une fois la revue Marketplace passée (notification « the status of the review changes », « we will review your plugin within two business days », ≈ 2 jours ouvrés), ouvrir la page publique du plugin et vérifier que le prix « 29 $ / an » et l'essai « 14 jours » y sont bien affichés : c'est là que les ventes sont actives, et il n'y a plus rien à faire.**

---

## 2. Les valeurs exactes à saisir (rien d'autre)

| Champ (onglet Sales Info) | Valeur | Où elle est décidée |
|---|---|---|
| **Code produit (Product Code)** | **`PPICKAXEPRO`** — **en clair, exactement ces 11 caractères** | dans le `plugin.xml` de la 0.0.2 (c'est le `code` du `<product-descriptor>`) |
| **Prix, palier Personal** | **29 $ / an** (1 utilisateur, 1 an) | décision de Tgg (PAYDANT-0.0.2.md § 2) |
| **Période d'essai (Trial Period)** | **14 jours** | réglage de Tgg dans ce formulaire — **pas du code** |
| **Version** | `2026.1.0` (= `release-version` `20261`) | déjà dans le `plugin.xml` du ZIP ; ne rien changer |
| **Commission JetBrains** | 15 % (hors de notre main) | — |

✅ **Le code produit `PPICKAXEPRO` respecte le format officiel du Marketplace.** La doc
officielle exige : « *Your Product Code must: Start with the letter **P** … Be no shorter than 4
characters … Be no longer than 15 characters … NOT contain any numbers or special symbols …
Contain only **CAPITAL LETTERS**.* » (exemple officiel : `PMAKEMECOFFEE`).
`PPICKAXEPRO` : préfixe `P`, **11 caractères**, majuscules seules, aucun chiffre, aucun
symbole ⇒ **le descripteur ne sera pas refusé pour ce motif**.
C'est **le code du `plugin.xml` du ZIP livré** : **ne le modifie pas** (ni dans le formulaire,
ni dans le ZIP).

---

## 3. Ce qu'il ne faut surtout pas faire

- **Ne pas reconstruire le ZIP 0.0.1** (`b5e1d00b93eec4883699f9ea6eaed649`) : il est déjà envoyé.
- **Ne pas re-zipper** le ZIP 0.0.2, ne pas le renommer, ne pas l'ouvrir et le recompresser.
- **Ne pas modifier le `code` produit, le prix ou la durée de l'essai** sans le signaler : ces
  trois valeurs sont celles mesurées dans le `plugin.xml` et dans `PAYDANT-0.0.2.md`.
- **Ne pas changer le statut Trader, ni inventer un IBAN, ni un numéro de registre** : ils sont
  déjà en place (`isTrader:true` mesuré par l'API publique le 06/11/2026 17:48).
- **Ne pas payer quoi que ce soit** : le téléversement et l'activation des ventes sont gratuits.
- **Ne pas s'inquiéter pendant la revue** : pendant les ≈ 2 jours ouvrés, la fiche n'est pas
  publique — c'est l'état normal, pas un échec.

---

## 4. Les liens (vérifiés le 06/11/2026)

| Lien | HTTP | Sert à quoi |
|---|---|---|
| `https://plugins.jetbrains.com/plugin/add` | **200** | **geste 1** — la page de dépôt |
| `https://plugins.jetbrains.com/plugin/<ID>-find-in-commit-history/sales/info` | route exacte (200 sur l'onglet `…/sales/info` d'un plugin publié) | **geste 2** — l'onglet « Sales Info » du plugin |
| `https://plugins.jetbrains.com/plugin/<ID>-find-in-commit-history` | — | **geste 3** — la page publique, à vérifier après la revue |

⚠ La page du plugin **n'existe pas encore** : tant que le ZIP n'est pas téléversé, l'URL renvoie
**HTTP 404** (c'est le contrôle qui a été fait le 06/11 sur l'ancienne fiche).

## 5. Les sources officielles (relues le 06/11/2026, HTTP 200)

- Vendre un plugin : étapes de publication, « Sales Info », « Add to Marketplace », essai, « two
  business days » : https://plugins.jetbrains.com/docs/marketplace/release-plugin.html
- Descripteur de produit (`code`, `release-date`, `release-version`, `optional`) et **format du code
  produit** : https://plugins.jetbrains.com/docs/marketplace/add-required-parameters.html
- Vérification de licence dans le code (`LicensingFacade`, `getInstance() == null`) :
  https://plugins.jetbrains.com/docs/marketplace/add-marketplace-license-verification-calls-to-the-plugin-code.html
- Freemium : https://plugins.jetbrains.com/docs/marketplace/freemium.html
- Commission 15 %, seuil 200 $ : https://plugins.jetbrains.com/docs/marketplace/revenue-sharing-and-fees.html

---

**Ce que c'est :** 3 gestes, 4 valeurs, 0 $ dépensés, 0 envoi de ma part, 0 publication.
Le reste est déjà fait et vérifié (`/work/soumission/PAYDANT-0.0.2.md` § 6, `SHA256.txt`,
`/work/pickaxe/scripts/contre_epreuve_licence.sh`).
