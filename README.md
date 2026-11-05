# Find in Commit History — moteur « pickaxe » (`git log -S` / `git log -G`)

Plugin IntelliJ Platform qui recherche, dans l'historique Git d'un projet, les
commits qui **ajoutent ou suppriment une chaîne** (équivalent de
`git log -S<chaîne>`) ou dont le **diff** matche une expression (équivalent de
`git log -G<regex>`).

Ce dépôt contient **le moteur et ses preuves**. Il ne publie rien, ne lit
aucun jeton, ne coûte rien.

---

## 1. Ce qui est dans la boîte

```
src/main/java/com/tgglabs/pickaxe/engine/   moteur pur (JGit seul, aucun IDE)
src/main/java/com/tgglabs/pickaxe/ui/       dialogue + action de menu
src/main/resources/META-INF/plugin.xml      descripteur de plugin
src/test/java/…                            22 tests du moteur
scripts/run_tests.sh                       compile + lance les tests (hors IDE)
scripts/contre_epreuve_rouge.sh             preuve ROUGE (mutation du moteur)
scripts/build_zip.sh                       construit le ZIP (hors reseau)
scripts/compare_with_git.sh                compare le moteur au VRAI `git log`
scripts/preuve_ide.sh                      lance l'IDE et prend les captures
```

## 2. Lancer les tests (aucun réseau, aucun IDE)

```bash
export JAVA_HOME=/work/tools/jdk-21.0.12.1+1
bash scripts/run_tests.sh
```

Code de sortie **0** si et seulement si tous les tests passent.
Le script compile le moteur avec `javac` puis lance la console JUnit
(`libs/junit-platform-console-standalone-1.10.2.jar`).

## 3. La preuve rouge — un test qui n'a jamais été rouge n'est pas un test

```bash
bash scripts/contre_epreuve_rouge.sh
```

Le script **copie** le moteur, mute la copie (il remplace la comparaison du
*nombre d'occurrences* par un « la chaîne est-elle présente ? »), rejoue la
suite et **exige qu'elle échoue**. Le source canonique n'est jamais touché
(le sha256 est contrôlé avant / après).

Résultat mesuré : **7 tests en échec, code de retour 1**, source canonique
intact.

## 4. Comparaison avec le vrai `git log`

```bash
bash scripts/compare_with_git.sh
```

Construit un dépôt Git de test, puis compare le moteur et `git log` sur six
requêtes (`-S`, `-G`, `--text`, filtre de chemin, chaîne unicode). Les listes
de messages de commit doivent être **identiques**.

## 5. Construire le ZIP

```bash
bash scripts/build_zip.sh
```

Compile **contre l'IDE exact** (`$IDE`, par défaut l'IDE PyCharm 2026.2.4
installé dans le conteneur) avec le **JDK 25 embarqué dans l'IDE**
(`$IDE/jbr/bin/javac`) : les jars de la plateforme 2026.2 sont en version de
class file 69, que seul un `javac` 25 sait lire. Le bytecode **produit** reste
en Java 17 (`--release 17`), comme l'exige la plateforme pour `since-build 243`.

Le ZIP produit contient exactement :

```
FindinCommitHistory/lib/FindinCommitHistory-0.0.1.jar   (le plugin)
FindinCommitHistory/lib/org.eclipse.jgit-6.10.1…-r.jar    (JGit, embarque)
FindinCommitHistory/lib/JavaEWAH-1.1.12.jar               (JavaEWAH, embarque)
```

**`slf4j-api` n'y est pas** : la plateforme le fournit (`lib/util-8.jar`).
Le script vérifie ce point et le refuse si un jar `slf4j` apparaît.

## 6. Pourquoi JGit est embarqué

Mesuré sur les 415 jars de `lib/` de PyCharm 2026.2.4 :

* `org.jetbrains.jgit` : **0 classe** dans tout l'IDE ;
* `org.eclipse.jgit` : présent, mais **uniquement** dans
  `lib/intellij.settingsSync.core.jar` — le jar du plugin *Settings Sync*,
  **pas** le classpath de la plateforme.

Un plugin tiers ne voit donc pas JGit, sauf à déclarer une dépendance à
`com.intellij.settingsSync` — c'est-à-dire à rendre obligatoire un plugin que
l'utilisateur peut désactiver, sans rapport avec la gestion de version.
On embarque donc JGit, dans la version **exactement** celle que l'IDE
utilise (6.10.1).

## 7. Preuve dans l'IDE

```bash
bash scripts/preuve_ide.sh
```

Installe le ZIP dans une configuration neuve, lance PyCharm sur l'affichage
virtuel `:99`, ouvre un dépôt Git de démonstration, prend les captures
(panneau Git Log, « Show History for Selection », action du plugin) et relève
la ligne de chargement :

```
Loaded custom plugins: Find in Commit History (0.0.1)
```

## 8. Journal des étapes

Un commit par étape (voir `git log`).
