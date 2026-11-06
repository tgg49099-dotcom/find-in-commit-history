# MISE-VENTE-TGG.md — formulaire « Upload plugin » (JetBrains Marketplace)

> **Ce que c'est** : la fiche de saisie, champ par champ, pour que Tgg puisse téléverser
> `Find in Commit History` en 10 minutes sans rien deviner.
> **Ce que ce n'est pas** : ce document ne publie rien. 0 POST, 0 PUT, 0 jeton Marketplace
> lu ou posé. Le plugin n'est **pas** publié au 05/11/2026 18:31.
>
> **Source de vérité** : `/work/pickaxe/` (code, `plugin.xml`, `SHA256.txt`, `FICHE-MARKETPLACE.md`).
> Les empreintes ci-dessous sont celles du **ZIP livré** (reconstruit le 06/11 à 07:26 : revue du jury `aba5`, ajout de la copie du hash, tri des résultats par date décroissante, puis **reconstruction en `since-build 243` = compatibilité IntelliJ 2024.3**) : **ne pas reconstruire**.

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

⚠ La description et les change-notes du formulaire (champs 5 et 6) sont ceux du
`plugin.xml`, qui n'a **pas** été modifié : ils ne mentionnent donc pas encore la copie
du hash. **Arbitrage de la mère** : le `plugin.xml` n'est pas touché (le ZIP et le
pré-vol sont figés) ; une éventuelle mention dans la fiche se fera dans une version
ultérieure.

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
| 2 | **Vendor email** | `tgg.apps.support@gmail.com` | `plugin.xml` ligne 5 → `<vendor email="tgg.apps.support@gmail.com" …>` | L'email du profil vendor existant est `tgg49099@gmail.com` (API) ; **celui du plugin** est `tgg.apps.support@gmail.com` (celui du `plugin.xml`). C'est ce second qui est demandé ici. |
| 3 | **Plugin name** | `Find in Commit History` | `plugin.xml` ligne 3 → `<name>` | **22 caractères** (limite 30). Ne pas ajouter de « … » ni de version. |
| 4 | **Short description** (≤ 300 car.) | `Find in Commit History cherche dans l'historique Git les commits qui ajoutent ou suppriment une chaîne (git log -S et -G), directement dans l'IDE. 100 % local, sans compte ni télémétrie.` | consigne de la mère du 05/11/2026 18:24 — **copier mot pour mot** | **186 caractères mesurés** (≤ 300 ✓, il reste 114). |
| 5 | **Description** (longue) | *ne rien réécrire* — elle est déjà dans le ZIP : `<description>` du `plugin.xml` (822 car. bruts, **601 car. de texte réel**) | `plugin.xml` lignes 7–23 | Si le formulaire exige une zone de texte vide, y coller **exactement** le bloc ci-dessous (il est identique au `<description>` du ZIP). |
| 6 | **Change notes** | *ne rien réécrire* — `<change-notes>` du `plugin.xml` (1 189 car. bruts, **963 car. de texte réel**) | `plugin.xml` lignes 28–48 | Coller **exactement** le bloc ci-dessous. La mère : « copie-le, ne le réécris pas ». |
| 7 | **License** (liste déroulante) | `MIT` | `/work/pickaxe/LICENSE` (1 065 o, texte MIT complet) + `FICHE-MARKETPLACE.md` § 4 | Décision de la mère du 05/11/2026. |
| 8 | **License URL** | `https://labs.chiffreo.ch/find-in-commit-history-eula.html` | `/work/pickaxe/EULA.md` + consigne ; page en ligne | **HTTP 200, 4 253 o** (re-vérifié le 05/11/2026 18:31). Doc officielle : « You must provide your own end user license agreement ». |
| 9 | **Source code URL** | `https://github.com/tgg49099-dotcom/find-in-commit-history` | consigne ; dépôt public `git remote` | commit du CODE **d5da65779adf50ef1ccba809a9878399a68c20ff** (des commits de documentation peuvent être au-dessus), **70 fichiers** suivis (re-vérifié le 06/11 02:55). Obligatoire : licence open-source ⇒ lien du code source. |
| 10 | **Privacy policy URL** | `https://labs.chiffreo.ch/find-in-commit-history-privacy.html` | `FICHE-MARKETPLACE.md` § 5 (ligne `privacyPolicyUrl`) | **HTTP 200, 4 754 o** (re-vérifié le 05/11/2026 18:31). |
| 11 | **Support / bug tracker URL** | `https://github.com/tgg49099-dotcom/find-in-commit-history/issues` | consigne ; `FICHE-MARKETPLACE.md` § 5 (`bugtrackerUrl`) | — |
| 12 | **Category** | `VCS` | `FICHE-MARKETPLACE.md` § 3 ; API `GET /api/tags` → `{"id":250,"name":"VCS","link":"/tag/250-vcs"}` | **Tag officiel** de la liste du Marketplace (170 entrées). |
| 13 | **Keywords / mots-clés** | `git` · `pickaxe` · `search` · `history` · `log` | consigne de la mère | ⚠ **Mesuré** : sur les 170 tags officiels (`GET /api/tags`), **seul `VCS` existe** ; `git`, `pickaxe`, `search`, `history`, `log` n'en font pas partie → à saisir comme **mots-clés libres** (champ texte), **pas** comme tags privilégiés. Bonus mesuré : `GET /api/searchPlugins?search=pickaxe` → **0 plugin** ⇒ le mot-clé est libre ; `search=commit history` → 151 plugins. |
| 14 | **Compatible IDEs / since-build** | `243` — IntelliJ IDEA 2024.3 / PyCharm 2024.3 (build **243.21565.199**) | `plugin.xml` → `<idea-version since-build="243"/>` ; `product-info.json` de `/work/ide/pycharm-2024.3` | Aucune borne haute (`until-build` **absent**, volontaire : le plugin ne dépend que de `com.intellij.modules.platform`). Le plugin a été **chargé** dans PyCharm Community 2024.3 (build 243.21565.199) et le **Plugin Verifier officiel** y rend le verdict *« Compatible. 1 usage of deprecated API »* (0 problème de compatibilité). Il reste **compatible avec 2026.2** (le `since-build` est un minimum, pas une égalité). IntelliJ IDEA 2024.3 : **même build 243**, mais **non testé** (à dire tel quel si le formulaire demande une validation). |
| 15 | **Price** | `Free` / **gratuit** (0 $) | `FICHE-MARKETPLACE.md` § 4 | Plugin gratuit : **aucun revenu**, **aucun lien de don** (`donationLinks = []`, production Gumroad arrêtée). |
| 16 | **Release channel** | laisser le canal **par défaut** (publication publique) | — | Un canal custom (Alpha / Beta / EAP) n'est utile que pour ne pas publier largement ; à ne cocher que sur décision du propriétaire. |
| 17 | **Hidden** | **décoché** (plugin visible) | — | La case « hidden » garde le plugin caché même après approbation. |
| 18 | **Ads / containsAds** | **non** (décoché) | — | Le plugin ne fait aucune communication commerciale. |
| 19 | **File to upload** | `/work/pickaxe/build/distributions/FindinCommitHistory-0.0.1.zip` | § 0 ci-dessus | Le ZIP contient un seul dossier racine et les `.jar` dans `lib/`. |
| 20 | **Media / captures** | les 3 fichiers du § 3 | `/work/preuves/` | ⚠ **le formulaire de dépôt ne prend PAS les captures** : la doc officielle dit qu'on les ajoute « *under the Media section in the admin panel of the plugin page **after uploading your plugin*** » → c'est l'étape 7. Taille mini recommandée : **1200 × 760 px**. Les 3 retenues font **1200 × 780** ✓ (recadrées sur le dialogue : **pas de fond d'IDE**). |

### Textes à copier tels quels (blocs 5 et 6)

**Description longue (bloc `<description>`, `plugin.xml` lignes 7–23) — 601 car. de texte réel :**

```html
<p>Search your <b>Git history</b> for the commits that add or remove a
    string — the <code>git log -S</code> and <code>git log -G</code> ("pickaxe")
    search, inside your IDE.</p>
    <ul>
      <li><b>Find where a string came from</b> — type a string, get the list of
      commits that added or removed it, most recent first.</li>
      <li>A line rewritten identically is not reported: only a real change in
      the number of occurrences is.</li>
      <li><b>Regular expressions</b> — match the diff itself with
      <code>git log -G</code> semantics.</li>
      <li><b>Filter by path</b> — restrict the search to the files you care
      about. Binary files are ignored.</li>
      <li><b>Works with your own repository</b> — the history is read locally,
      nothing is sent anywhere.</li>
    </ul>
```

> ⚠ Règle officielle (« Best practices for listing your plugin ») : « **The first 40 characters of
> the plugin description must be in English and contain a short summary.** » → la description
> ci-dessus commence par « Search your **Git history** for the commits… » : **anglais ✓**.
> (La *short description* du champ 4 est en français : c'est un champ distinct, à part.)

**Change notes (bloc `<change-notes>`, `plugin.xml` lignes 28–48) — 963 car. de texte réel :**

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

---

## 2. Les 6 étapes, dans l'ordre

1. **Se connecter** — ouvrir `https://plugins.jetbrains.com/author/me` et se connecter au compte
   JetBrains de Tgg (le compte qui porte le vendor `Tgg Labs`, id **21195**). En haut à droite :
   menu du compte → **« Upload plugin »**.
   *Raccourci : `https://plugins.jetbrains.com/plugin/add` est directement la page de dépôt
   (HTTP 200 vérifié le 05/11 19:05) — elle demande la connexion.*
2. **Choisir / créer le vendor** — à l'étape « Select the Vendor profile » : si **« Tgg Labs »**
   apparaît dans la liste, le **sélectionner** ; sinon, comme c'est le tout premier upload,
   accepter la **Marketplace Developer Agreement** puis **créer le Vendor profile**
   (nom public `Tgg Labs`, email `tgg.apps.support@gmail.com`).
   ⚠ *Si le formulaire demande le **statut de commerçant** (obligatoire même pour un plugin
   gratuit) : c'est un acte juridique réservé à Tgg — **ne rien cocher à sa place**, le signaler
   à la mère. Notre vendor est `isTrader: false` (mesuré sur l'API) ; la doc officielle dit que
   les vendeurs non vérifiés peuvent être suspendus, donc la question doit être vue par Tgg.*
3. **Remplir le formulaire** — reprendre les 20 lignes du § 1, dans l'ordre des champs.
   Les blocs longs (5 et 6) se collent tels quels, **sans retouche**.
4. **Déposer le ZIP** — joindre `/work/pickaxe/build/distributions/FindinCommitHistory-0.0.1.zip`
   (3 133 609 o). **Ne pas zipper, renommer ni re-compresser** le fichier.
5. **Options de distribution** — prix `Free`, canal par défaut, **pas** de canal custom,
   **hidden décoché**, **pas** d'ads, `since-build 243`, catégorie `VCS`,
   mots-clés `git pickaxe search history log`, puis joindre les **3 captures** du § 3.
6. **Soumettre pour relecture** — clic sur **« Submit »** / « Upload » ; le plugin part en
   relecture (statut `approve:false` / `listed:false` tant que JetBrains n'a pas validé).
   ⚠ **Attendre le verdict** : rien n'est publié tant que l'approbation n'est pas donnée.
   Si le formulaire signale une erreur, **copier le message exact** et me le transmettre —
   je corrige la cause sans toucher au ZIP livré tant que possible.

---

## 3. Les 3 captures à joindre (si le formulaire en demande)

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

## 4. Ce qu'il ne faut surtout pas faire

* ❌ **Reconstruire le ZIP** (change le md5/sha256, invalide le pré-vol).
* ❌ Modifier `plugin.xml` (la description et les change-notes sont propres ; pas de `<license>`
  racine : la licence se saisit dans le formulaire, elle sera ajoutée en 0.0.2).
* ❌ Toucher au moteur.
* ❌ Cocher « trader » / inventer un numéro de registre : acte juridique réservé à Tgg.
* ❌ Créer un 2ᵉ vendor, ou un compte.
* ❴ Payer quoi que ce soit (le plugin est gratuit, 0 $).

---

## 5. Ce qu'il faut faire juste APRÈS la soumission

### 5.1 ⭐ Le second geste, celui qui met le plugin sur le Marketplace
L'upload **crée la fiche** du plugin, mais **ne le met pas en ligne**. La doc officielle
(« Release the plugin ») l'écrit :

> *« Once your plugin is ready for release, start the release process. Make sure that you have
> created a Vendor profile, **set the trader status**, and submitted your trader and banking
> information under the Trader Details tab. […] If this is your initial plugin release, upload
> the plugin to JetBrains Marketplace. […] **Go to the Sales Info tab on the Plugin page and
> press the “Add to Marketplace” button** to fill in the sales details. If you don't see this
> button, please make sure you specified your banking details under the Trader Details tab for
> your Vendor profile. »*

Concrètement, après le « Submit » de l'étape 6 :

1. ouvrir la **page du plugin** (elle existe maintenant : le ZIP est téléversé, le plugin a un
   numéro) ;
2. onglet **« Sales Info »** → bouton **« Add to Marketplace »** ;
3. dans les détails de vente : **prix = Free / 0 $** (plugin gratuit, aucun palier payant,
   aucun « Who is the plugin for? » payant) ; vérifier la **version = 0.0.1** et la date ;
4. ⚠ **si le bouton « Add to Marketplace » n'apparaît pas** : le profil vendor n'a pas de
   **statut de commerçant** sélectionné — ce réglage est dans l'onglet **« Main Information »**
   du vendor, et l'onglet « Trader Details » (coordonnées bancaires) n'apparaît qu'après.
   ⚠ **c'est un acte juridique réservé à Tgg** : ne rien cocher à sa place, ne pas inventer de
   numéro de registre ni de coordonnées bancaires — signaler à la mère.
5. ⚠ le plugin reste **non listé** tant que JetBrains ne l'a pas approuvé (`approve:false`) :
   c'est normal, et c'est noté dans `NOTES-PUBLICATION-PROCEDURE.md`.

### 5.2 La suite

1. Relever le **numéro numérique** attribué par le Marketplace (il remplace `<ID>` dans
   `FICHE-MARKETPLACE.md` § 5, champ `url`).
2. Le porter dans `/rapports/produits.json` (plateforme `jetbrains`, `id` = ce numéro) — c'est
   ce qui fera relever les vrais chiffres chaque matin.
3. Suivre la procédure `/work/pickaxe/NOTES-PUBLICATION-PROCEDURE.md` (page accessible, chargement dans
   l'IDE, URL définitives, téléchargements à J+1 / J+7 / J+14).

---

## 6. Les pages de la doc officielle (toutes vérifiées **HTTP 200** le 05/11/2026 19:05)

| Ce qu'on y trouve | URL |
|---|---|
| Le dépôt d'un **premier** plugin (les 2 étapes, 400 Mo max, licence, tags, canaux, ads, hidden) | https://plugins.jetbrains.com/docs/marketplace/uploading-a-new-plugin.html |
| La mise en ligne **après** l'upload (« Sales Info » → « Add to Marketplace », statut de commerçant) | https://plugins.jetbrains.com/docs/marketplace/release-plugin.html |
| Le profil **vendor** (création, statut de commerçant) | https://plugins.jetbrains.com/docs/marketplace/organizations.html |
| Les bonnes pratiques de fiche (captures **≥ 1200 × 760**, « pas de fond d'écran », « les 40 premiers caractères en anglais ») | https://plugins.jetbrains.com/docs/marketplace/best-practices-for-listing.html |
| Les critères d'approbation (logo **40 × 40 SVG**, nom **≤ 30 caractères**) | https://plugins.jetbrains.com/docs/marketplace/jetbrains-marketplace-approval-guidelines.html |
| Les **erreurs fréquentes** (à lire si le formulaire refuse quelque chose) | https://plugins.jetbrains.com/docs/marketplace/list-of-common-errors-and-warnings.html |
| Page d'entrée « publier et lister son plugin » | https://plugins.jetbrains.com/docs/marketplace/publishing-and-listing-your-plugin.html |

⚠ Le contact officiel en cas de blocage du formulaire : `marketplace@jetbrains.com` (doc
officielle) — **ne rien envoyer sans l'accord de Tgg** (et il n'y a rien à envoyer : le
brouillon « trader » existe déjà, non envoyé).
