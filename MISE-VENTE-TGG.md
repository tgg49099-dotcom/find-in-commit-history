# MISE-VENTE-TGG.md — formulaire « Upload plugin » (JetBrains Marketplace) — version du 06/11/2026

> **Ce que c'est** : la fiche de saisie, champ par champ, pour que Tgg puisse téléverser
> `Find in Commit History` en 10 minutes sans rien deviner.
> **Ce que ce n'est pas** : ce document ne publie rien. 0 POST, 0 PUT, 0 jeton Marketplace
> lu ou posé. Le plugin **n'est pas publié** au 06/11/2026 11:28.
>
> **Source de vérité** : `/work/pickaxe/` (code, `plugin.xml`, `SHA256.txt`, `FICHE-MARKETPLACE.md`).
> Les empreintes ci-dessous sont celles du **ZIP livré** (reconstruit le 06/11 à 07:26 : revue du jury
> `aba5`, ajout de la copie du hash, tri des résultats par date décroissante, puis **reconstruction en
> `since-build 243`** = compatibilité IntelliJ 2024.3) : **ne pas reconstruire**.
>
> ⭐ **Version du 06/11/2026 12:45 — le « faux blocage » a été corrigé.**
> La version précédente affirmait que le bouton « Add to Marketplace » était obligatoire pour
> mettre un plugin **gratuit** en ligne, qu'il exigeait un **statut de commerçant**, et que
> `approve:false` signifiait « plugin non listé = échec ». **C'était faux.** La procédure réelle,
> mesurée et vérifiée, est au **§ 3 (étape 2 et étape 6)** et au **§ 6.1**. Sources et date au **§ 9**.
>
> ⭐ **Version du 06/11/2026 20:20 — pour la 0.0.2 payante, seuls les 3 gestes de
> `MISE-VENTE-0.0.2-TGG.md` changent ; les 20 champs de la fiche restent identiques.**
> Ce document reste la fiche de saisie de la **0.0.1** (gratuite) : les 20 champs, les blocs de
> texte à coller et la marche à suivre ne changent pas. Pour la **0.0.2 payante**, la marche à
> suivre est **`MISE-VENTE-0.0.2-TGG.md`** (3 gestes : téléverser le ZIP 0.0.2, saisir le code
> produit / le prix / l'essai dans « Sales Info », puis activer les ventes).
>
> ⚠ **Cette version est celle qui est dans le paquet**
> `/work/A_ENVOYER/pickaxe/dossier-pickaxe.zip` (reconstruit le 06/11/2026 à 20:2x avec le ZIP
> 0.0.2 et la correction du statut commerçant ; son md5 est donné dans le rapport du cycle). La
> copie de `MISE-VENTE-TGG.md` **du paquet** et ce fichier-ci sont **identiques** (même md5).

---

## 0. Le fichier à téléverser (ZIP LIVRÉ — ne pas reconstruire)

| | |
|---|---|
| **Chemin** | `/work/pickaxe/build/distributions/FindinCommitHistory-0.0.1.zip` |
| Taille | **3 133 609 octets** (400 Mo max selon la doc officielle — large marge) |
| Construit le | 2026-11-06 **07:26:43** CET (`scripts/build_zip.sh`, 0 téléchargement, 0 $), **après la revue du jury `aba5`, l'ajout de la copie du hash, le tri des résultats par date décroissante et la reconstruction en `since-build 243`** |
| **md5** | `b5e1d00b93eec4883699f9ea6eaed649` |
| **sha256** | `406d58a44aa3b253b650c3b6f2f6bbc97d737df77ef2497351ace3aab254c82e` |
| Source | `/work/pickaxe/SHA256.txt` (source de vérité unique), § 8 de `FICHE-MARKETPLACE.md` |

**Contrôle avant de cliquer « Submit »** (à faire sur la machine qui détient le fichier) :

```
cd /work/pickaxe
sha256sum -c SHA256.txt          # doit afficher : build/distributions/FindinCommitHistory-0.0.1.zip: OK
md5sum    build/distributions/FindinCommitHistory-0.0.1.zip
# attendu : b5e1d00b93eec4883699f9ea6eaed649
```

⚠ Une empreinte différente ⇒ **le fichier reçu n'est pas celui annoncé** : ne pas téléverser.
### Ce que le ZIP livré contient (06/11 07:26)

* **Copie du hash** : dans la liste des résultats, un **double-clic** (ou le bouton
  **« Copy hash »**) met l'identifiant **complet** du commit dans le presse-papier.
  Aucune API de suivi de version, aucun plugin tiers.
* Les correctifs des cycles 122 et 123 : fusions non dupliquées, annulation réelle,
  fuite de ressource fermée, blobs de plus de 64 Mo ignorés au lieu d'être
  signalés à tort.
* **L'ordre des résultats est garanti du plus récent au plus ancien** (cycle 128). Le
  parcours de JGit est topologique (comme `git log`) : il rend un commit avant ses
  enfants, donc ce n'est pas un ordre par date quand les dates de commit sont dans
  le désordre (décalage d'horloge, cherry-pick, rebase). Les résultats sont donc triés
  explicitement par date de commit décroissante — la promesse « most recent first »
  de la fiche est ainsi tenue. Test : `ChronologicalOrderTest` (rouge avant le
  correctif, vert après) ; suite complète : **57 tests, 57 verts**.

⚠ Le `<description>` et les `<change-notes>` **du ZIP** n'ont pas été modifiés : ils disent la
version d'avant la copie du hash. C'est volontaire — **le ZIP est figé**. La description
**publique** que les visiteurs voient est celle du § 2 de ce fichier, posée après le
téléversement (le Marketplace permet d'éditer la description d'une fiche **sans**
téléverser une nouvelle version : voir § 3, étape 3-bis).

⚠ **Ne pas reconstruire le ZIP** : un rebuild change les empreintes et invalide le pré-vol
officiel, qui n'est valable que 24 h.

**Le logo est déjà dans le ZIP** : `META-INF/pluginIcon.svg` et `META-INF/pluginIcon_dark.svg`,
**40 × 40 px en SVG** — critère d'approbation officiel : « *Must be provided in one size:
40 px by 40 px. Must be in SVG format* » → **rien à fournir dans le formulaire**.

---

## 1. Le formulaire, champ par champ

Chaque ligne = **la valeur EXACTE à saisir** + **le fichier local d'où elle vient**.
« Source » = le fichier de `/work/pickaxe/` (ou la consigne de la mère) qui fait foi.

| # | Champ du formulaire | VALEUR EXACTE à saisir | SOURCE | Contrôle / remarque |
|---|---|---|---|---|
| 1 | **Vendor profile** (étape 1 du formulaire) | `Tgg Labs` | `src/main/resources/META-INF/plugin.xml` ligne 5 → `<vendor …>Tgg Labs</vendor>` ; API : `GET /api/plugins/35551` → `vendor.id = 21195`, `vendor.publicName = "Tgg Labs"` | ⚠ **Au premier upload, Tgg doit CRÉER le profil vendor** (accepter la Marketplace Developer Agreement puis créer le Vendor profile — doc officielle « Uploading a new plugin », étape 1). Le vendor existe déjà côté API (id **21195**) : si le formulaire propose « Tgg Labs », le sélectionner ; sinon le créer. **Ne pas créer un 2ᵉ vendor.** |
| 2 | **Vendor email** | `tgg.apps.support@gmail.com` | `plugin.xml` ligne 5 → `<vendor email="tgg.apps.support@gmail.com" …>` | L'email du profil vendor est l'adresse personnelle du propriétaire (API ; **non reproduite ici**) ; **celui du plugin** est `tgg.apps.support@gmail.com` (celui du `plugin.xml`). C'est ce second qui est demandé ici. |
| 3 | **Plugin name** | `Find in Commit History` | `plugin.xml` ligne 3 → `<name>` | **22 caractères**. La limite dure est **60** ; la doc *recommande* « 1–4 mots, max 20 caractères » (« *Use a short, relevant, memorable name that's 1-4 words long (max 20 characters). There is a limitation of max 60 characters* ») → **22 > 20 mais ≪ 60 : accepté**. Le nom vient du XML : **il n'est pas modifiable dans le formulaire** (« *The core elements of a plugin's Overview page are extracted from the Plugin Configuration File — plugin.xml and cannot be changed without uploading a new plugin version* »). Un jour plus court = une nouvelle version ; **pas pour le 08/11**. |
| 4 | **Short description** (≤ 300 car.) | `Find in Commit History: find the commit that added a string in your Git history - git log -S and git log -G, right inside your IDE. 100% local: no account, no telemetry.` | consigne de la mère du 06/11/2026 13:55 — **copier mot pour mot** | **169 caractères mesurés** (≤ 300 ✓, il reste 131). Texte **en anglais** : décision de la mère du 06/11/2026 (doc officielle « *Use English as the primary language* » ; le nom et la description sont déjà en anglais, l'audience du Marketplace est internationale). |
| 5 | **Description** (longue) | **le bloc du § 2** — c'est la version **mise à jour** de ce fichier (elle contient « git log -S », « git log -G », « find the commit that added », « search in git history », « blame ») | ce fichier, § 2 | Voir § 2 et § 3 étape 3-bis : où la coller exactement. |
| 6 | **Change notes** | *ne rien réécrire* — `<change-notes>` du `plugin.xml` (1 189 car. bruts, **963 car. de texte réel**) | `plugin.xml` lignes 28–48 | Coller **exactement** le bloc ci-dessous. La mère : « copie-le, ne le réécris pas ». |
| 7 | **License** (liste déroulante) | `MIT` | `/work/pickaxe/LICENSE` (1 065 o, texte MIT complet) + `FICHE-MARKETPLACE.md` § 4 | Décision de la mère du 05/11/2026. ⚠ La licence du **cœur gratuit** reste MIT ; la version **Pro** est un dossier séparé (`/work/soumission/PAYDANT-0.0.2.md`). |
| 8 | **License URL** | `https://labs.chiffreo.ch/find-in-commit-history-eula.html` | `/work/pickaxe/EULA.md` + consigne ; page en ligne | **HTTP 200, 4 253 o** (re-vérifié le 06/11/2026 11:45). Doc officielle : « You must provide your own end user license agreement ». |
| 9 | **Source code URL** | `https://github.com/tgg49099-dotcom/find-in-commit-history` | consigne ; dépôt public `git remote` | Le **code** du ZIP livré est celui du commit **`386c1f8`** (« compatibilite: since-build 243 » — le dernier commit qui touche `src/`). Le `HEAD` public **`77a62dfbc1a1d538c9d75c4ff3faadbd61edc0a4`** n'ajoute que **2 scripts de preuve** (`scripts/verif_aba5.sh`, `scripts/contre_epreuve_aba5.py`) : **les sources du plugin sont identiques**. Dépôt public : **HTTP 200** (vérifié le 06/11/2026). Obligatoire : licence open-source ⇒ lien du code source. |
| 10 | **Privacy policy URL** | `https://labs.chiffreo.ch/find-in-commit-history-privacy.html` | `FICHE-MARKETPLACE.md` § 5 (ligne `privacyPolicyUrl`) | **HTTP 200, 4 754 o** (re-vérifié le 06/11/2026 11:45). |
| 11 | **Support / bug tracker URL** | `https://github.com/tgg49099-dotcom/find-in-commit-history/issues` | consigne ; `FICHE-MARKETPLACE.md` § 5 (`bugtrackerUrl`) | **HTTP 200** (vérifié le 06/11/2026 11:45). |
| 12 | **Category** | `VCS` | `FICHE-MARKETPLACE.md` § 3 ; API `GET /api/tags` → `{"id":250,"name":"VCS","link":"/tag/250-vcs"}` | **Tag officiel** de la liste du Marketplace (170 entrées). |
| 13 | **Tags / mots-clés** | **5 tags officiels** (voir ci-dessous) | `GET /api/tags` (170 tags, mesuré le 06/11/2026 11:45) | Les tags officiels **sont les filtres de recherche** du Marketplace (« *they are used as search filters* ») : on en met **5**, tous vérifiés existants : `VCS` (id 250) · `VCS Integration` (id 288) · `Search and Replace` (id 251) · `Code Tools` (id 15) · `Tools Integration` (id 19). ⚠ **Il n'existe pas de tag « git », « pickaxe », « search », « history » ou « log »** dans la liste officielle (mesuré : les 170 noms) → ces 5 mots-là sont des **mots-clés libres**, pas des tags : ils sont déjà dans le nom, le titre de la description et le texte (§ 2). |
| 14 | **Compatible IDEs / since-build** | `243` — IntelliJ IDEA 2024.3 / PyCharm 2024.3 (build **243.21565.199**) | `plugin.xml` → `<idea-version since-build="243"/>` ; `product-info.json` de `/work/ide/pycharm-2024.3` | Aucune borne haute (`until-build` **absent**, volontaire : le plugin ne dépend que de `com.intellij.modules.platform`). Le plugin a été **chargé** dans PyCharm Community 2024.3 (build 243.21565.199) et le **Plugin Verifier officiel** y rend le verdict *« Compatible. 1 usage of deprecated API »* (0 problème de compatibilité). Il reste **compatible avec 2026.2** (le `since-build` est un minimum, pas une égalité). IntelliJ IDEA 2024.3 : **même build 243**, mais **non testé** (à dire tel quel si le formulaire demande une validation). |
| 15 | **Price** | `Free` / **gratuit** (0 $) | `FICHE-MARKETPLACE.md` § 4 | Plugin gratuit : **aucun revenu**, **aucun lien de don** (`donationLinks = []`, production Gumroad arrêtée). **La version payante est un dossier à part** : `/work/soumission/PAYDANT-0.0.2.md`. |
| 16 | **Release channel** | laisser le canal **par défaut** (publication publique) | — | Un canal custom (Alpha / Beta / EAP) n'est utile que pour ne pas publier largement ; à ne cocher que sur décision du propriétaire. |
| 17 | **Hidden** | **décoché** (plugin visible) | — | La case « hidden » garde le plugin caché même après approbation. |
| 18 | **Ads / containsAds** | **non** (décoché) | — | Le plugin ne fait aucune communication commerciale. |
| 19 | **File to upload** | `/work/pickaxe/build/distributions/FindinCommitHistory-0.0.1.zip` | § 0 ci-dessus | Le ZIP contient un seul dossier racine et les `.jar` dans `lib/`. **Ne pas zipper, renommer ni re-compresser.** |
| 20 | **Media / captures** | les 3 fichiers du § 4 | `/work/preuves/` | ⚠ **le formulaire de dépôt ne prend PAS les captures** : la doc officielle dit qu'on les ajoute « *under the Media section in the admin panel of the plugin page **after uploading your plugin*** » → c'est l'étape 7. Taille mini recommandée : **1200 × 760 px**. Les 3 retenues font **1200 × 780** ✓ (recadrées sur le dialogue : **pas de fond d'IDE**). |
| 21 | **Page du plugin** (à compléter après le téléversement) | `https://plugins.jetbrains.com/plugin/<ID>-find-in-commit-history` | le numéro est attribué par le Marketplace au téléversement | Tant que le plugin n'est pas téléversé, **cette URL n'existe pas** (contrôle : un identifiant inexistant renvoie **HTTP 404**). **Stable et vérifiable dès maintenant** : la page vendor `https://plugins.jetbrains.com/vendor/tgg-labs` (**HTTP 200**) liste tous nos plugins, dont les 2 déjà en ligne (`…/plugin/35551-git-branch-badge` et `…/plugin/35416-ml-experiment-cockpit`, **HTTP 200** tous les deux). Noter le numéro obtenu dans `FICHE-MARKETPLACE.md` § 5 et dans `/rapports/produits.json` (plateforme `jetbrains`). |

### 1 bis — la *short description* (anglais)

La *short description* est **en anglais** : c'est la **décision de la mère du 06/11/2026**, la
question est close. La doc officielle recommande l'anglais en première langue (« *Use English as
the primary language* »), le nom du plugin et la description longue sont déjà en anglais, et
l'audience du Marketplace est internationale : une fiche à moitié française nuit au référencement.

**Texte à copier dans le champ 4 — identique à la ligne 4 du tableau ci-dessus :**

```
Find in Commit History: find the commit that added a string in your Git history - git log -S and git log -G, right inside your IDE. 100% local: no account, no telemetry.
```

**169 caractères mesurés** (≤ 300 ✓ ; il reste 131).

---

## 2. Les textes à coller tels quels

### 2.1 Description longue (champ 5) — **VERSION MISE À JOUR DU 06/11/2026**

> **Pourquoi cette version remplace celle du ZIP** : elle contient les mots que les gens tapent
> ("find the commit that added", "search in git history", "blame"…), et elle dit ce que le plugin
> **ne fait pas**. Elle est **en anglais** (la fiche est internationale) et elle respecte la règle
> officielle « *The first 40 characters of the plugin description must be in English and contain a
> short summary* » : le texte commence par « Find the commit that added a string — git log -S … ».
>
> ⚠ Elle **diffère** du `<description>` du `plugin.xml` (figé dans le ZIP). C'est **voulu** et sans
> risque : le Marketplace permet d'éditer la description d'une fiche **sans** téléverser de
> nouvelle version (§ 3, étape 3-bis).

```html
<p>Find the commit that added a string — <code>git log -S</code> and <code>git log -G</code> inside your IDE. Type a string or a regular expression and search in git history for every commit that added or removed it, most recent first.</p>
<ul>
  <li><b>Find the commit that added a string</b> — the result of <code>git log -S "your string"</code>, in a table, from <em>Tools | Find in Commit History…</em>.</li>
  <li><b>Search by regular expression</b> — <code>git log -G</code> semantics: the added and the removed lines are tested.</li>
  <li><b>Filter by path</b> — restrict the search to the files you care about; binary files are ignored.</li>
  <li><b>Copy the commit hash</b> — double-click a result to copy its full hash to the clipboard.</li>
  <li><b>Known limits</b> — the search stops after 500 matching commits, and a merge commit is not diffed: the change it brought in is reported by the commit that made it.</li>
  <li><b>Local only</b> — the history is read from the repository on disk; nothing is sent anywhere.</li>
</ul>
<p><b>What it does not do:</b> it is not a blame tool — it does not tell you who last changed each line of the file you are reading, and it does not search a remote server, only the Git repository open in your IDE.</p>
<p><b>Example:</b> a production key was removed from <code>config/app.yml</code> and you need to find the commit that added it: search for <code>AKIA</code> with the path filter <code>config/</code> — the list gives every commit that added or removed that string, newest first, and the hash you paste into <code>git show</code>.</p>
```

**Contrôle automatique des mots-clés (fait le 06/11/2026, script `/work/scripts/verif_description_seo.py` — 26 contrôles, tous verts) :**

| Mot-clé demandé | Présent ? | Où |
|---|---|---|
| `git log -S` | ✅ | 1ʳᵉ phrase + 1ᵉʳ point |
| `git log -G` | ✅ | 1ʳᵉ phrase + 2ᵉ point |
| `find the commit that added` | ✅ | 1ᵉʳ point (« Find the commit that added a string ») **et** l'exemple (« … to find the commit that added it ») |
| `search in git history` | ✅ | 2ᵉ phrase (« … and search in git history for every commit … ») |
| `blame` | ✅ | la phrase « What it does not do » (« it is not a blame tool ») |

Structure demandée : **2 phrases** sur ce que ça fait (le 1ᵉ paragraphe) · **1 phrase** honnête sur ce
que ça ne fait PAS (le paragraphe « What it does not do ») · **1 exemple** concret (le dernier
paragraphe). Aucune promesse infondée : les limites réelles (500 commits, fusions non diffées) sont
écrites dans la fiche.

### 2.2 Change notes (champ 6) — **inchangé** (bloc `<change-notes>` du `plugin.xml`, 963 car. de texte réel)

```html
<p><b>First release.</b> Find the commits that added or removed a string in
    your Git history — the <code>git log -S</code> / <code>git log -G</code>
    ("pickaxe") search, inside your IDE.</p>
    <ul>
      <li>Type a string, get the commits that added or removed it (a change in
      the <em>number</em> of occurrences counts), most recent first, across
      every reference of the repository — not only the current branch — even if
      the string no longer exists in your working tree. The search stops after
      500 matching commits.</li>
      <li>Match the diff itself with a regular expression: added <em>and</em>
      removed lines are tested, like <code>git log -G</code> (Java regular
      expressions; a merge commit is not diffed, so a change brought in by a
      merge is reported once, by the commit that made it).</li>
      <li>Restrict the search to the files you care about: the path filter is
      a regular expression matched anywhere in the path. Binary files are
      ignored.</li>
      <li>The history is read locally from the repository on disk — the plugin
      makes no network access at runtime, no account, no telemetry.</li>
    </ul>
```

⚠ Ce bloc vient du XML du ZIP : **il ne parle pas de la copie du hash** (le `plugin.xml` n'a pas été
touché). C'est assumé : le ZIP est figé. La copie du hash est, elle, dans la **description** (§ 2.1).

---

## 3. Les étapes, dans l'ordre

1. **Se connecter** — ouvrir `https://plugins.jetbrains.com/author/me` et se connecter au compte
   JetBrains de Tgg (le compte qui porte le vendor `Tgg Labs`, id **21195**). En haut à droite :
   menu du compte → **« Upload plugin »**.
   *Raccourci : `https://plugins.jetbrains.com/plugin/add` est directement la page de dépôt
   (HTTP 200 vérifié le 06/11/2026 11:45) — elle demande la connexion.*
2. **Choisir / créer le vendor** — à l'étape « Select the Vendor profile » : si **« Tgg Labs »**
   apparaît dans la liste, le **sélectionner** ; sinon, comme c'est le tout premier upload,
   accepter la **Marketplace Developer Agreement** puis **créer le Vendor profile**
   (nom public `Tgg Labs`, email `tgg.apps.support@gmail.com`).
   ⚠ **Statut de commerçant : on n'y touche pas, et ce n'est pas un obstacle.**
   Le vendor `Tgg Labs` (id 21195) est **commerçant** (`isTrader:true`, mesuré par l'API
   publique le 06/11/2026 17:48) et nos **2 plugins sont déjà en ligne**
   (113 + 22 téléchargements, pages publiques) : **un plugin gratuit n'a rien à voir avec le
   statut de commerçant**. Ne coche rien, ne remplis **aucun IBAN**, n'invente aucun numéro de
   registre. ⚠ *Si un champ obligatoire empêche de valider : **arrête-toi**, fais **1 capture**
   de l'écran et envoie-la — avec le **message exact**. Tu ne « corriges » rien en cochant une
   case qui t engage juridiquement.*
3. **Remplir le formulaire** — reprendre les 20 lignes du § 1, dans l'ordre des champs.
   Les blocs longs (5 et 6) se collent tels quels, **sans retouche**.
   **3-bis. ⭐ Poster la description à mots-clés (après le « Submit »)**
   La page du plugin (nouvel onglet « General Information ») permet d'**éditer la description**
   d'une fiche **sans téléverser de nouvelle version**. C'est la doc officielle qui le dit
   (« *You can also edit the description on the plugin's page. In this case, the description is
   stored separately from the plugin archive, allowing you to update it without uploading a new
   plugin version* »). Concrètement :
   1. ouvrir la page du plugin → **General Information** → champ **Description** ;
   2. **coller le bloc du § 2.1** (remplace la description issue du XML) ;
   3. quand le Marketplace demande d'arbitrer, **choisir « Always use the description from the
      plugin page »** (« *The edited description will be applied, but future plugin uploads will
      continue to use the description from plugin.xml* ») ;
   4. **vérifier** : recharger la page publique du plugin et relire le texte affiché.
   ⚠ Si le formulaire d'upload affiche lui-même un champ « Description », y coller le bloc du § 2.1
   **directement** : c'est le même texte, ça ne coûte rien.
4. **Déposer le ZIP** — joindre `/work/pickaxe/build/distributions/FindinCommitHistory-0.0.1.zip`
   (3 133 609 o). **Ne pas zipper, renommer ni re-compresser** le fichier.
5. **Options de distribution** — prix `Free`, canal par défaut, **pas** de canal custom,
   **hidden décoché**, **pas** d'ads, `since-build 243`, catégorie `VCS`,
   tags `VCS` · `VCS Integration` · `Search and Replace` · `Code Tools` · `Tools Integration`.
6. **Soumettre pour relecture** — clic sur **« Submit »** / « Upload ». C'est **le téléversement
   qui crée la fiche** du plugin (première version) : il part ensuite en relecture par l'équipe
   Marketplace, **« we will review your plugin within two business days »** (≈ 2 jours ouvrés).
   ⚠ **Pendant l'examen, la fiche n'est pas encore publique — ce n'est PAS un échec.**
   Une notification arrive quand le statut de la relecture change (« *You will receive a
   notification as soon as the status of the review changes* »). Il n'y a **rien** à cocher,
   rien à envoyer, rien à payer pour cette étape.
   Si le formulaire signale une erreur, **copier le message exact** et me le transmettre —
   je corrige la cause sans toucher au ZIP livré tant que possible.

---

## 4. Les 3 captures à joindre (si le formulaire en demande)

**Prises sur le ZIP du 05/11/2026** — le ZIP livré du 06/11/2026 n'en diffère que par le tri des
résultats, qui ne change rien à ces écrans — le 05/11/2026 à 21:45, dans PyCharm 2026.2.4
(build 262.11879.98). Format **1200 × 780 px** (minimum officiel 1200 × 760) :
le **dialogue du plugin remplit le cadre**, il n'y a **aucun fond d'IDE** (le recadrage est le
rectangle exact de la fenêtre du dialogue) et **aucune bulle jaune**.

| # | Chemin exact | Dimensions · md5 | Ce qu'elle montre |
|---|---|---|---|
| 1 | `/work/preuves/cycle124/captures/02-resultats.png` | 1200 × 780 · `6f57bc2956c4fdb3208eab898cb54206` | **la capture qui dit tout** : chaîne `pi3rre-magique-7749`, mode `STRING`, les **2 commits trouvés** (« eaf798cd fix: remove the token line [src/app.py] », « 54481bb feat: add the configuration file [src/app.py] »), mention « **2 commits found.** », et le bouton « **Copy hash** » en bas à droite |
| 2 | `/work/preuves/cycle124/captures/03-hash-copie.png` | 1200 × 780 · `a45bf5d86ce47e31f10d68e38b4b782b` | **la nouveauté** : la 1ʳᵉ ligne est sélectionnée et la barre d'état affiche « **Hash copied to the clipboard: ea798cd8cbd537e83e93d55e228ea0cacfe67980** » — le double-clic a bien copié le hash |
| 3 | `/work/preuves/cycle124/captures/05-dialogue-filtre-chemin.png` | 1200 × 780 · `7303a0778ada4df871457090f70871dc` | le **filtre de chemin** en action (`app\.py`) : la recherche se restreint aux fichiers choisis |

*Vérification pixel par pixel : `/work/preuves/cycle124/verification-captures.log` (dimensions
exactes, md5 tous distincts, écart-type non nul = écran vivant, recadrage = rectangle de la
fenêtre du dialogue ⇒ pas un pixel de fond d'IDE).*

*Deux autres images, **techniques** (elles ne vont pas sur la fiche) :*
`/work/preuves/cycle124/captures/01-dialogue-chaine.png` (état initial, liste vide) et
`/work/preuves/cycle124/captures/04-verif-presse-papier.png` (**le hash recollé dans le champ** :
preuve que le presse-papier contient bien le hash copié).

⚠ **À ne plus utiliser** : les captures des cycles 117 / 119 / 120 reprises jusqu'ici — elles sont
recadrées sur la **fenêtre de l'IDE** et montrent donc un **fond d'IDE**, ce que la doc
officielle interdit (« Include desktop backgrounds … in your screenshots »).

---

## 5. Ce qu'il ne faut surtout pas faire

* ❌ **Reconstruire le ZIP** (change le md5/sha256, invalide le pré-vol).
* ❌ Modifier `plugin.xml` (il est dans le ZIP ; la description *publique* se règle dans le panneau
  d'administration, § 3 étape 3-bis).
* ❌ Toucher au moteur.
* ❌ **Modifier le statut Trader ou l'IBAN** : ils sont DEJA en place (isTrader:true, IBAN saisi —
  mesuré par l'API publique le **06/11/2026 20:10**).
* ❌ Créer un 2ᵉ vendor, ou un compte.
* ❴ Payer quoi que ce soit (le plugin est gratuit, 0 $).

---

## 6. Ce qu'il faut faire juste APRÈS la soumission

### 6.1 ⭐ Comment le plugin arrive en ligne — la procédure **mesurée** (elle remplace l'ancienne version)

> ⚠ **Ce que la version précédente de ce fichier affirmait (et qui était faux)** :
> « si le bouton "Add to Marketplace" n'apparaît pas : le profil vendor n'a pas de statut de
> commerçant […] le plugin reste non listé tant que `approve:false` ». **À jeter.**
> La version précédente demandait un geste **payant/banking** pour un plugin **gratuit**.

**La procédure réelle, en 4 temps :**

1. **Upload = 1ʳᵉ version, à la main.** Pour une **première version**, c'est le **téléversement
   du ZIP qui crée la fiche** du plugin (« *If this is your initial plugin release, upload the
   plugin to JetBrains Marketplace* »). Aucun bouton « Add to Marketplace » n'est nécessaire pour
   cela.
2. **Examen ≈ 2 jours ouvrés.** L'équipe Marketplace examine la fiche : « *we will review your
   plugin within two business days* ». Une notification arrive quand le statut change.
3. **Mise en ligne après approbation.** Tant que l'examen n'est pas terminé, **la fiche n'est pas
   encore publique** : **ce n'est pas un échec**, c'est l'état normal de l'attente. Il n'y a rien
   à relancer, rien à envoyer.
4. **Si** une étape « Sales Info » → « Add to Marketplace » **se présente** (c'est la procédure du
   **modèle payant** — *« If you are switching the model from being a free plugin to paid/freemium,
   upload an update »*) : choisir **Free / 0 $**, vérifier **version = 0.0.1**, puis valider.
   ⚠ **Si le bouton manque, ce n'est PAS bloquant pour un plugin gratuit** → **1 capture** de
   l'écran, envoyée à la mère. **Ne change surtout pas le statut de commerçant pour faire
   apparaître un bouton**, et ne remplis aucun IBAN.

**La preuve que ce n'est pas bloquant : nous.** Nos **2** plugins sont **déjà en ligne** avec le
**même vendor non-commerçant** :

| Preuve | Mesure (API publique, 06/11/2026 20:10) |
|---|---|
| `GET /api/plugins/35416` | HTTP 200 · **113 téléchargements** · `vendor.id = 21195` · `vendor.publicName = "Tgg Labs"` · **`vendor.isTrader:true`** (mesuré le **06/11/2026 20:10**) · `vendor.isVerified: false` · page publique : **HTTP 200** |
| `GET /api/plugins/35551` | HTTP 200 · **22 téléchargements** · **même vendor 21195**, `isTrader:true` (mesuré le **06/11/2026 20:10**) · page publique : **HTTP 200** |
| `GET https://plugins.jetbrains.com/vendor/tgg-labs` | HTTP 200 · les 2 plugins listés |

⇒ **Un vendor non-commerçant publie des plugins sur le Marketplace.** Le statut de commerçant
n'est demandé que pour **encaisser des paiements via le Marketplace** — pas pour publier.

**Sources (avec la date) :** voir **§ 9**.

### 6.2 La suite

1. Relever le **numéro numérique** attribué par le Marketplace (il remplace `<ID>` dans le champ 21
   ci-dessus, dans `FICHE-MARKETPLACE.md` § 5, et dans `LISEZMOI.md`).
2. Le porter dans `/rapports/produits.json` (plateforme `jetbrains`, `id` = ce numéro) — c'est
   ce qui fera relever les vrais chiffres chaque matin.
3. Suivre la procédure `/work/pickaxe/NOTES-PUBLICATION-PROCEDURE.md` (page accessible, chargement dans
   l'IDE, URL définitives, téléchargements à J+1 / J+7 / J+14).

---

## 7. Les URL de ce fichier — vérifiées par `curl` le 06/11/2026 (11:45)

| URL | HTTP | Où elle est utilisée |
|---|---|---|
| `https://github.com/tgg49099-dotcom/find-in-commit-history` | **200** | champ 9 — dépôt public (code source) |
| `https://github.com/tgg49099-dotcom/find-in-commit-history/issues` | **200** | champ 11 — support / bug tracker |
| `https://labs.chiffreo.ch/find-in-commit-history-eula.html` | **200** | champ 8 — licence (EULA) |
| `https://labs.chiffreo.ch/find-in-commit-history-privacy.html` | **200** | champ 10 — politique de confidentialité |
| `https://plugins.jetbrains.com/plugin/add` | **200** | § 3 étape 1 — page de dépôt (demande la connexion) |
| `https://plugins.jetbrains.com/author/me` | **200** | § 3 étape 1 — menu du compte |
| `https://plugins.jetbrains.com/vendor/tgg-labs` | **200** | champ 21 — page vendor (liste nos plugins) |
| `https://plugins.jetbrains.com/plugin/35551-git-branch-badge` | **200** | § 6.2 — l'autre plugin du vendor |
| `https://plugins.jetbrains.com/plugin/35416-ml-experiment-cockpit` | **200** | § 6.2 — l'autre plugin du vendor |
| `https://plugins.jetbrains.com/tag/250-vcs` | **200** | champ 12/13 — tag officiel VCS |
| `https://plugins.jetbrains.com/api/tags` | **200** | champ 13 — la liste des 170 tags officiels |
| `https://plugins.jetbrains.com/api/plugins/35551` | **200** | champs 1 et 21 — id vendor 21195, `isTrader:true` (mesuré le **06/11/2026 20:10**) |
| `https://plugins.jetbrains.com/plugin/<ID>-find-in-commit-history` | **404 tant que le ZIP n'est pas téléversé** | champ 21 — l'URL définitive, à compléter après l'upload |

---

## 8. Les pages de la doc officielle (toutes vérifiées **HTTP 200** le 06/11/2026 11:40)

| Ce qu'on y trouve | URL |
|---|---|
| Le dépôt d'un **premier** plugin (les 2 étapes, 400 Mo max, licence, tags, canaux, ads, hidden) | https://plugins.jetbrains.com/docs/marketplace/uploading-a-new-plugin.html |
| La mise en ligne : **upload = 1ʳᵉ version**, examen « within two business days », « Sales Info » / « Add to Marketplace » = **modèle payant** | https://plugins.jetbrains.com/docs/marketplace/release-plugin.html |
| Le profil **vendor** (création ; le **statut de commerçant n'est pas nécessaire** pour un plugin gratuit — voir § 6.1) | https://plugins.jetbrains.com/docs/marketplace/organizations.html |
| Les bonnes pratiques de fiche (captures **≥ 1200 × 760**, « pas de fond d'écran », « les 40 premiers caractères en anglais », **« you can also edit the description on the plugin's page »**) | https://plugins.jetbrains.com/docs/marketplace/best-practices-for-listing.html |
| Les critères d'approbation (logo **40 × 40 SVG**, nom **≤ 30 caractères**) | https://plugins.jetbrains.com/docs/marketplace/jetbrains-marketplace-approval-guidelines.html |
| Les **erreurs fréquentes** (à lire si le formulaire refuse quelque chose) | https://plugins.jetbrains.com/docs/marketplace/list-of-common-errors-and-warnings.html |
| Page d'entrée « publier et lister son plugin » | https://plugins.jetbrains.com/docs/marketplace/publishing-and-listing-your-plugin.html |
| La version **payante** (produit, `product-descriptor`, licence, essai 30 j) | https://plugins.jetbrains.com/docs/marketplace/paid-plugins.html |

⚠ Le contact officiel en cas de blocage du formulaire : `marketplace@jetbrains.com` (doc
officielle) — **ne rien envoyer sans l'accord de Tgg** (et il n'y a rien à envoyer : le
brouillon « trader » existe déjà, non envoyé).

---

## 9. Sources de la correction du « faux blocage » (avec la date)

| Source | Ce qu'elle dit **exactement** | Relevé |
|---|---|---|
| `https://plugins.jetbrains.com/docs/marketplace/release-plugin.html` | « *If this is your initial plugin release, upload the plugin to JetBrains Marketplace* » · « *we will review your plugin within two business days* » · « *If you are switching the model from being a free plugin to paid/freemium, upload an update* » · « *Go to the Sales Info tab on the Plugin page and press the Add to Marketplace button to fill in the sales details* » · « *If you don't see this button, please make sure you specified your banking details under the Trader Details tab for your Vendor profile* » · « *You will receive a notification as soon as the status of the review changes* » | **HTTP 200**, page relue le **06/11/2026 12:33** (13 076 o) — les 6 citations ci-dessus sont **textuelles** |
| `GET https://plugins.jetbrains.com/api/plugins/35416` | `vendor.id = 21195`, `vendor.publicName = "Tgg Labs"`, **`vendor.isTrader:true`** (mesuré le **06/11/2026 20:10**), `vendor.isVerified = false`, `downloads = 113` | **HTTP 200**, mesuré le **06/11/2026 20:10** |
| `GET https://plugins.jetbrains.com/api/plugins/35551` | même vendor 21195, **`isTrader:true`** (mesuré le **06/11/2026 20:10**), `downloads = 22` | **HTTP 200**, mesuré le **06/11/2026 20:10** |
| `GET https://plugins.jetbrains.com/vendor/tgg-labs` | les 2 plugins du vendor sont listés | **HTTP 200**, mesuré le **06/11/2026 12:40** |

**Ce que ces 4 sources disent ensemble** : la publication d'un plugin **gratuit** passe par
l'**upload**, puis un **examen d'environ 2 jours ouvrés**, puis la **mise en ligne** — sans statut
de commerçant, sans IBAN, sans « Add to Marketplace ». Le bouton « Add to Marketplace » et les
coordonnées bancaires appartiennent à la **procedure de vente** (« fill in the sales details »),
c'est-à-dire au modèle **payant** — objet de `/work/soumission/PAYDANT-0.0.2.md` (route
« Externally Paid », hors Marketplace).
