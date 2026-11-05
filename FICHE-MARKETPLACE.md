# FICHE MARKETPLACE — plugin « Find in Commit History » (pickaxe)

> **PREPARÉE, PAS PUBLIÉE.** Rien n'a été écrit sur le Marketplace (0 POST, 0 PUT, 0 jeton lu).
> La mère lit et écrit la fiche finale. Les points à trancher sont signalés `[À TRANCHER]`.

---

## 1. Nom public

**Find in Commit History** — identique partout : `<name>` de `plugin.xml`, `pluginName` de `gradle.properties`,
`<action text>` (« Find in Commit History… »), nom affiché par l'IDE
(`Loaded custom plugins: Find in Commit History (0.0.1)`), nom du ZIP
(`FindinCommitHistory-0.0.1.zip` — forme mécanique sans espaces, imposée par le Marketplace).

**Identifiant** : `com.tgglabs.pickaxe` (définitif après publication — ne pas changer).

## 2. Description EN (proposée — honnête, et avec les mots que l'acheteur tape)

> **Find in Commit History** — search your Git history for the commits that added or removed a
> string, right inside your IDE.
>
> This is the IDE equivalent of `git log -S` and `git log -G` (the "pickaxe" search).
> Type a string, and the plugin lists the commits that **added** or **removed** it — even if that
> string no longer exists in your working tree.
>
> - **Find where a string came from** — type a string, get the list of commits that added or removed
>   it, most recent first.
> - **No false positives** — a line rewritten identically is not reported: only a real change in the
>   number of occurrences is.
> - **Regular expressions** — match the diff itself with `git log -G` semantics.
> - **Filter by path** — restrict the search to the files you care about. Binary files are ignored.
> - **Works with your own repository** — the history is read locally, nothing is sent anywhere.
>
> Use it from **Tools › Find in Commit History…**, or from the **Find Action** palette
> (`Ctrl+Shift+A` / `Cmd+Shift+A`).

**Mots clés présents dans le texte** (recherche Marketplace) : `git log`, `find in commit`,
`search in git history`, `pickaxe`, `git log -S`, `git log -G`, `Git history`, `commit`.

**Ce que la description ne dit pas** (et c'est volontaire) : ni « instantané », ni « index »,
ni « tout l'historique », ni « results panel », ni « diff preview ». Le plugin lit le dépôt **local**
et rend une **liste de commits** dans un dialogue.

## 3. Tags proposés

`git` · `git history` · `git log` · `pickaxe` · `search` · `vcs` · `version control` ·
`developer tools` · `find` · `commit`

`[À TRANCHER]` — le Marketplace demande 5 à 10 tags ; le tri par pertinence compte.

## 4. Lien du code source (**obligatoire** à la publication)

```
https://github.com/<ORGUE-DU-PROPRIETAIRE>/find-in-commit-history
```

**Le dépôt GitHub sera créé par le propriétaire.** Emplacement laissé vide exprès.
`[À TRANCHER]` — nom exact du dépôt et de l'organisation, et licence à afficher sur la page.

## 5. Compatibilité

| Champ | Valeur | Raison |
|---|---|---|
| `since-build` | `243` (2024.3) | plancher demandé par la mère ; la 0.0.21 publiée est en `243.0 → 263.*` |
| `until-build` | `263.*` | **choix de ce cycle** : `262.*` excluait la 2026.3 EAP sans raison ; `263.*` aligne sur la 0.0.21 |
| IDE de compilation | PyCharm Professional **2024.3** (`platformVersion`) | IDE déjà dans le cache Gradle du conteneur |
| Dépendances | `com.intellij.modules.platform` **seule** | 0 dépendance à un plugin désactivable |

## 6. Prix / licence

`[À TRANCHER — décision du propriétaire]` Le plugin n'a ni licence, ni prix, ni EULA (interdit par la
consigne de ce cycle). Or **une fiche Marketplace exige une licence** (« EULA », « MIT », etc.) :
c'est un **point bloquant pour la publication**, à trancher par le propriétaire avant la soumission.

## 7. Ce que la fiche ne cache pas (limites connues, à assumer)

- L'interface est un **dialogue modal** : pas encore de panneau de résultats cliquable, pas de
  diff intégrée, pas de raccourci clavier pour l'action (il faut passer par *Find Action*).
- La touche **Entrée** ne déclenche pas la recherche (il faut cliquer « Search »). Défaut connu,
  signalé, non corrigé à ce jour.
- La preuve a été faite sur **PyCharm 2026.2.4** ; l'IDE **IntelliJ IDEA** n'a pas été testé
  (le plugin ne dépend que de `com.intellij.modules.platform` : rien dans le code n'est spécifique
  à PyCharm, mais la preuve n'a pas été faite).
- Le moteur est **entièrement local** : aucune donnée ne sort de la machine.

## 8. Ce qui est prêt pour la soumission

- ZIP construit par la **recette Gradle officielle** (`./gradlew buildPlugin`) — voir
  `/rapports/rapport.md` du cycle 116 pour le chemin, la taille et le sha256.
- `plugin.xml` : `<id>`, `<name>`, `<version>`, `<vendor>`, `<depends>`, `<idea-version>`, `<actions>`.
- Revue de code du jury : **en attente** (demande `aba5`, verdict attendu vers 19:50 le 05/11).
  Le seul avis rendu à ce jour (`e048`) porte sur **un autre plugin** (ML Experiment) et son patch
  **ne s'applique pas** ici.
