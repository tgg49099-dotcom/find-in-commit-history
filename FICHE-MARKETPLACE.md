# FICHE MARKETPLACE — « Find in Commit History » (plugin `com.tgglabs.pickaxe`, version 0.0.1)

> **PRÊTE À ÊTRE COPIÉE — PAS PUBLIÉE.** Rien n'a été écrit sur le Marketplace
> (0 POST, 0 PUT, 0 jeton lu ou posé). Cette fiche décrit l'état exact du ZIP livré
> et ne cache aucune limite connue.

---

## 1. Nom public

**Find in Commit History** — **22 caractères mesurés** (la limite du Marketplace est 30).

Le même nom est utilisé partout : `<name>` de `plugin.xml`, `pluginName` de
`gradle.properties`, libellé de l'action (« Find in Commit History… »), nom affiché
par l'IDE (`Loaded custom plugins: Find in Commit History (0.0.1)`), et nom du ZIP
(`FindinCommitHistory-0.0.1.zip` — forme mécanique sans espaces, imposée par le
Marketplace).

**Identifiant définitif** : `com.tgglabs.pickaxe` (ne plus le changer après publication).

## 2. Description (celle du `plugin.xml`, à copier telle quelle)

```html
<p>Search your <b>Git history</b> for the commits that add or remove a
    string — the <code>git log -S</code> and <code>git log -G</code> ("pickaxe")
    search, inside your IDE.</p>
    <ul>
      <li><b>Find where a string came from</b> — type a string, get the list of
      commits that added or removed it, most recent first.</li>
      <li><b>No false positives</b> — a line rewritten identically is not
      reported: only a real change in the number of occurrences is.</li>
      <li><b>Regular expressions</b> — match the diff itself with
      <code>git log -G</code> semantics.</li>
      <li><b>Filter by path</b> — restrict the search to the files you care
      about. Binary files are ignored.</li>
      <li><b>Works with your own repository</b> — the history is read locally,
      nothing is sent anywhere.</li>
    </ul>
```

## 3. Tags (10 — le Marketplace en demande 5 à 10)

`git` · `git history` · `git log` · `pickaxe` · `search` · `vcs` · `version control` ·
`developer tools` · `find` · `commit`

## 4. Prix et licence

| Champ | Valeur |
|---|---|
| Prix | **gratuit** (`0 $`) — pas d'offre payante, pas de période d'essai |
| Licence | **MIT** (décision de la mère, 05/11/2026) — `LICENSE` à la racine du dépôt |
| `donationLinks` | `[]` — plugin gratuit, aucun lien de don (la production Gumroad est arrêtée) |

## 5. Les 8 champs d'URL

| Champ | Valeur |
|---|---|
| `sourceCodeUrl` | `https://github.com/tgg49099-dotcom/find-in-commit-history` |
| `licenseUrl` | `https://github.com/tgg49099-dotcom/find-in-commit-history/blob/main/LICENSE` |
| `privacyPolicyUrl` | `https://labs.chiffreo.ch/find-in-commit-history-privacy.html` |
| `url` | `https://plugins.jetbrains.com/plugin/<ID>-find-in-commit-history` — **`<ID>` est le numéro numérique que le Marketplace attribue à la première publication : à remplacer juste après le dépôt.** En attendant, on peut mettre le lien du dépôt : `https://github.com/tgg49099-dotcom/find-in-commit-history`. |
| `forumUrl` | idem `url` (le plugin n'a pas de forum propre) |
| `bugtrackerUrl` | `https://github.com/tgg49099-dotcom/find-in-commit-history/issues` |
| `docUrl` | `https://github.com/tgg49099-dotcom/find-in-commit-history#readme` |
| `donationLinks` | `[]` |

## 6. Compatibilité

| Champ | Valeur | Raison |
|---|---|---|
| `since-build` | `262` | IntelliJ Platform 2026.2 — le numéro de build exact de l'IDE de référence (PyCharm 2026.2.4 = build 262.11879.98, mesuré dans `product-info.json`) ; c'est aussi l'IDE contre lequel le plugin est compilé |
| `until-build` | *absent* | le plugin ne dépend que de `com.intellij.modules.platform` ; aucune borne haute n'est justifiée par une mesure |
| Dépendances | `com.intellij.modules.platform` **seule** | 0 dépendance à un plugin désactivable |
| Java | bytecode 21 | niveau de référence de la plateforme 2026.2 |

## 7. Ce que la fiche ne cache pas (limites connues, assumées)

- L'interface est un **dialogue modal** : pas encore de panneau de résultats cliquable, pas de
  diff intégrée, pas de raccourci clavier pour l'action (elle est dans le menu
  **Tools ▸ Find in Commit History…**, et dans *Find Action*).
- La preuve de chargement a été faite sur **PyCharm 2026.2.4** ; **IntelliJ IDEA n'a pas été
  testé** (le plugin ne dépend que de `com.intellij.modules.platform` : rien dans le code n'est
  spécifique à PyCharm, mais la preuve n'a pas été faite).
- Le moteur est **entièrement local** : aucune donnée ne sort de la machine.

## 8. Le fichier à téléverser

> Ces empreintes sont celles du **ZIP livré** (le fichier réellement déposé sur le
> Marketplace). **Ne pas reconstruire** : voir §9.

| | |
|---|---|
| Chemin | `build/distributions/FindinCommitHistory-0.0.1.zip` |
| Taille | **3 139 880 octets** |
| Construit le | **2026-11-05 17:43:33 CET** (Gradle 8.10.2, `./gradlew --offline buildPlugin`) |
| sha256 | `ee90b66884fa16078495de6768c93bb1164840165bacb78d11558b370fdce980` |
| md5 | `bb18e3f8281476b707a2a595b3c66a2e` |
| Empreintes complètes | `SHA256.txt` (source de vérité unique) |
| Contenu de `lib/` | `FindinCommitHistory-0.0.1.jar` (27 768 o) · `org.eclipse.jgit-6.10.1.202505221210-r.jar` (3 209 491 o) · `JavaEWAH-1.2.3.jar` (170 567 o) · `FindinCommitHistory-0.0.1-searchableOptions.jar` (261 o, vide — sortie normale de la recette officielle) |
| Ni `slf4j-api` ni `commons-codec` | la plateforme les fournit (`lib/util-8.jar` contient 58 classes `org/slf4j/…`) |

Vérification par le destinataire :

```
sha256sum -c SHA256.txt          # doit afficher : OK
md5sum    build/distributions/FindinCommitHistory-0.0.1.zip
# attendu : bb18e3f8281476b707a2a595b3c66a2e
```

## 9. État de la soumission

- **ZIP** : construit par la recette Gradle officielle, **hors ligne** (0 téléchargement).
  Le ZIP livré est celui du **05/11/2026 17:43:33** (après la correction de D1, D2 et D3, et
  le correctif « worktree » du 05/11 : dépôt commun + répertoire de travail, avec son test de
  régression — 32 tests verts).
  **Le `md5` d'un ZIP JetBrains n'est pas un critère de reproductibilité garanti** (mesure de la
  mère le 04/11 : deux ZIP de même contenu, md5 différents). Avec la configuration de build
  actuelle, 2 reconstructions forcées du 05/11 17:43 ont donné le **même md5 et le même
  sha256** : le ZIP est reproductible octet pour octet, mais ce n'est pas un contrat de
  JetBrains. Le critère de contenu (noms + octets, horodatages exclus) reste le plus sûr : sa
  valeur et le nombre de parties hachées sont consignés dans
  `/work/NOTES.md` et `/work/preuves/cycle120/hash-contenu.txt` (le pré-vol réserve l'empreinte
  md5 aux fichiers réels — une valeur qui n'est le md5 d'aucun fichier y serait refusée).
  → **ne pas reconstruire** ; vérifier le fichier reçu avec `sha256sum -c SHA256.txt`.
- **Dépôt public** : `https://github.com/tgg49099-dotcom/find-in-commit-history` (code,
  `LICENSE` MIT, `README.md` en anglais, `.gitignore`, tests).
- **Revue de code du jury** : **en attente** (demande `aba5`, verdict attendu vers 19:50 le
  05/11/2026). Rien ne part sur le Marketplace avant.
- **Publication** : **non publiée**. 0 POST, 0 PUT, 0 jeton Marketplace lu ou posé.
