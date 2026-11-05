# Find in Commit History — moteur « pickaxe » (`git log -S` / `git log -G`)

Plugin IntelliJ Platform qui recherche, dans l'historique Git d'un projet, les
commits qui **ajoutent ou suppriment une chaîne** (équivalent de
`git log -S<chaîne>`) ou dont le **diff** matche une expression (équivalent de
`git log -G<regex>`).

Ce dépôt contient **le moteur, ses tests et ses preuves**. Il ne publie rien,
ne lit aucun jeton, ne coûte rien.

**Licence : MIT** (voir [`LICENSE`](LICENSE)).

---

## 1. Ce qui est dans la boîte

```
src/main/java/com/tgglabs/pickaxe/engine/   moteur pur (JGit seul, aucun IDE)
src/main/java/com/tgglabs/pickaxe/ui/       dialogue + action de menu
src/main/resources/META-INF/plugin.xml      descripteur de plugin
src/test/java/…                            22 tests du moteur
scripts/run_tests.sh                       compile + lance les tests (hors IDE)
scripts/contre_epreuve_rouge.sh             preuve ROUGE (mutation du moteur)
scripts/compare_with_git.sh                compare le moteur au VRAI `git log`
scripts/preuve_moteur_zip.sh               prouve le moteur CONTENU DANS LE ZIP livré
scripts/preuve_ide.sh                      lance l'IDE et prend les captures
scripts/build_zip.sh                       construit le ZIP (hors reseau, recette de secours)
```

## 2. Lancer les tests (aucun réseau, aucun IDE)

```bash
export JAVA_HOME=/work/tools/jdk-21.0.12.1+1
bash scripts/run_tests.sh
```

Code de sortie **0** si et seulement si tous les tests passent (22/22).
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

## 5. Construire le ZIP (recette Gradle officielle)

```bash
export JAVA_HOME=/work/tools/jdk-21.0.12.1+1          # JDK 21 (daemon Gradle)
export PATH="$JAVA_HOME/bin:$PATH"

./gradlew --offline buildPlugin \
    -PplatformLocalPath=/work/ide/pycharm-2026.2.4 \
    -Porg.gradle.java.installations.paths=/work/ide/pycharm-2026.2.4/jbr
```

Le ZIP produit est `build/distributions/FindinCommitHistory-0.0.1.zip`.

### 5.1 Les deux JDK, et pourquoi il y en a deux

| Rôle | Chemin | Pourquoi |
|---|---|---|
| Daemon Gradle | `/work/tools/jdk-21.0.12.1+1` | Gradle 8.10.2 **ne peut pas** tourner sur un JVM 25 (mesuré : `Unsupported class file major version 69`). |
| Compilateur (toolchain) | `/work/ide/pycharm-2026.2.4/jbr` | Les classes de la plateforme 2026.2.4 sont en **class file 69** (Java 25). Un `javac` 21 refuse de les lire : `bad class file … wrong version 69.0, should be 65.0` → 38 erreurs. |

Le JDK 21 est celui du conteneur ; le JDK 25 est le **JBR déjà installé dans
l'IDE de référence** (rien n'est téléchargé). Le **bytecode produit** reste en
**Java 21** (`sourceCompatibility`/`targetCompatibility` = 21).

### 5.2 Le ZIP, sans réseau

* `platformLocalPath` : compile **contre l'IDE déjà installé**
  (build `262.11879.98`) → le `since-build` 262 est l'exact numéro de build de
  l'IDE compilé, et **zéro téléchargement**.
* Sans cette propriété, le build télécharge l'IDE `platformVersion` depuis le
  CDN JetBrains (mode réseau normal).
* `instrumentCode = false` : l'instrumentation du bytecode par JetBrains
  résout `com.jetbrains.intellij.java:java-compiler-ant-tasks:262.11879.98`
  depuis Maven ; en mode `--offline` cet artefact n'est pas dans le cache et
  le build échoue. Désactivée : le jar du plugin ne contient pas les
  assertions `@NotNull` injectées (aucun effet sur le comportement à
  l'exécution).

### 5.3 Contenu du ZIP

```
FindinCommitHistory/lib/FindinCommitHistory-0.0.1.jar   (le plugin, bytecode 21)
FindinCommitHistory/lib/org.eclipse.jgit-6.10.1…-r.jar    (JGit, embarqué)
FindinCommitHistory/lib/JavaEWAH-1.2.3.jar               (JavaEWAH, embarqué)
FindinCommitHistory/lib/FindinCommitHistory-0.0.1-searchableOptions.jar (vide)
```

**`slf4j-api` n'y est pas** : la plateforme le fournit (`lib/util-8.jar`).

## 6. Prouver que le ZIP livré fonctionne (pas seulement les tests)

```bash
bash scripts/preuve_moteur_zip.sh
```

Le script prend **les jars du ZIP de distribution** (pas le code source),
les charge dans une JVM et cherche une chaîne dans un dépôt Git de
démonstration ; le résultat est comparé au vrai `git log -S`. Les deux
listes doivent être **identiques**, sinon le script sort en erreur.

## 7. Preuve dans l'IDE

```bash
bash scripts/preuve_ide.sh
```

Installe le ZIP dans une configuration neuve, lance PyCharm sur l'affichage
virtuel `:99`, ouvre un dépôt Git de démonstration, prend les captures et
relève la ligne de chargement :

```
Loaded custom plugins: Find in Commit History (0.0.1)
```

## 8. Pourquoi JGit est embarqué

Mesuré sur les jars de `lib/` de PyCharm 2026.2.4 :

* `org.jetbrains.jgit` : **0 classe** dans tout l'IDE ;
* `org.eclipse.jgit` : présent, mais **uniquement** dans
  `lib/intellij.settingsSync.core.jar` — le jar du plugin *Settings Sync*,
  **pas** le classpath de la plateforme.

Un plugin tiers ne voit donc pas JGit, sauf à déclarer une dépendance à
`com.intellij.settingsSync` — c'est-à-dire à rendre obligatoire un plugin que
l'utilisateur peut désactiver, sans rapport avec la gestion de version.
On embarque donc JGit, dans la version **exactement** celle que l'IDE
utilise (6.10.1).

## 9. Journal des étapes

Un commit par étape (voir `git log`).
