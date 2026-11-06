# Find in Commit History — the "pickaxe" search for your Git history (`git log -S` / `git log -G`)

An IntelliJ Platform plugin that searches your **Git history** for the commits that
**added or removed a string** (the equivalent of `git log -S<needle>`), or whose
**diff matches a regular expression** (the equivalent of `git log -G<regex>`).

The plugin is **not published on the JetBrains Marketplace yet**. This repository
holds the source, the tests and the build recipe.

**License: MIT** — see [`LICENSE`](LICENSE).

---

## What it does

* **Find where a string came from** — type a string, get the list of commits that
  added or removed it, most recent first, even if the string no longer exists in
  your working tree.
* **A line rewritten identically is not reported** — only a real change in the
  number of occurrences counts (this is the difference between a correct `-S`
  search and the naive "is the string there?" implementation).
* **Regular expressions** — match the diff itself, with `git log -G` semantics.
* **Merge commits are not diffed** — like `git log -S` without `-m`, a change
  brought in by a merge is reported **once**, by the commit that made it, not
  twice (once by the branch commit, once by the merge).
* **Filter by path** — restrict the search to the files you care about. Binary
  files are ignored.
* **Works in a linked worktree** — in a worktree created by `git worktree add`,
  the `.git` of the working directory is a *file*, and the references live in the
  common repository. The plugin opens the common repository and declares the
  work tree, so the search returns the same commits as `git log -S` there.
* **Local only** — the history is read from the repository on disk. Nothing is
  sent anywhere, no account, no network access.

Use it from **Tools › Find in Commit History…**, or from the **Find Action**
palette (`Ctrl+Shift+A` / `Cmd+Shift+A`).

## Requirements

| | |
|---|---|
| IDE | IntelliJ Platform **2024.3+** (`since-build = 243`) |
| Dependencies | `com.intellij.modules.platform` only — no dependency on a disableable plugin |
| Java | 17 (bytecode), Gradle 8.10+ |

## Build

```bash
./gradlew buildPlugin
```

The plugin ZIP is written to `build/distributions/FindinCommitHistory-0.0.1.zip`.

To build against a **local** IDE installation instead of downloading one from the
JetBrains CDN (useful offline):

```bash
./gradlew buildPlugin -PplatformLocalPath=/path/to/your/ide
```

The archive tasks are configured to be **reproducible** (no file timestamps, stable
entry order): two builds of the same sources produce the same ZIP, byte for byte.
The hashes of the released ZIP are recorded in [`SHA256.txt`](SHA256.txt).

## Tests

```bash
./gradlew test
```

The test suite is a set of **pure engine tests** (no IDE needed): they build a
small Git repository with JGit and check the results of the `-S` / `-G` searches,
including the identical-rewrite case, merge commits, cancellation, unicode,
binary files, path filters, empty and null queries.

An IDE-free runner is also provided, for a machine without Gradle:

```bash
export JAVA_HOME=/path/to/jdk-21
bash scripts/run_tests.sh
```

It compiles the sources with `javac` and runs the JUnit console launcher. It
expects the JGit / JUnit jars in `libs/` (they are not committed; see
`scripts/fetch_deps.sh`).

### The red proof

A test that has never been red is not a test:

```bash
python3 scripts/contre_epreuve.py
```

The script copies the engine, mutates **the copy** (it replaces the comparison of
the *number of occurrences* by a naive "is the string present on one side or the
other?"), replays the suite and **requires it to fail**. The canonical source is
never touched (its SHA-256 is checked before and after). Exit code `0` means the
red proof is valid.

### Comparison with the real `git log`

```bash
bash scripts/compare_with_git.sh
```

Builds a test repository, then compares the engine and the real `git log -S` /
`git log -G` on six queries (`-S`, `-G`, `--text`, path filter, unicode). The
lists of commit messages must be **identical**.

## Layout

```
src/main/java/com/tgglabs/pickaxe/engine/   pure engine (JGit only, no IDE)
src/main/java/com/tgglabs/pickaxe/ui/       dialog + Tools-menu action
src/main/resources/META-INF/plugin.xml      plugin descriptor
src/main/resources/META-INF/pluginIcon*.svg  40x40 icons (light and dark)
src/test/java/…                             engine tests
scripts/run_tests.sh                        compile + run the tests, no IDE
scripts/compare_with_git.sh                 compare the engine with the real git log
scripts/contre_epreuve.py                   red proof (mutation of a copy)
scripts/preuve_moteur_zip.sh                run the engine contained in the built ZIP
scripts/preuve_worktree_zip.sh              same, inside a real linked worktree
```

## Why JGit is bundled

Measured on the jars of PyCharm 2026.2.4 (build 262.11879.98):

* `org.jetbrains.jgit`: **0 class** in the 1,378 jars of the IDE;
* `org.eclipse.jgit`: present, but **only** inside `lib/intellij.settingsSync.core.jar`
  — the jar of the *Settings Sync* plugin, **not** of the platform;
* the IDE's own Git plugin (`Git4Idea`) does not reference a single
  `org/eclipse/jgit` class.

A third-party plugin therefore does not see JGit, unless it declares a dependency
on `com.intellij.settingsSync` — i.e. it would make a disableable plugin mandatory,
which has nothing to do with version control. JGit is therefore bundled, in the
**exact** version the IDE itself uses (6.10.1).

## Known limitations

* The UI is a **modal dialog**: there is no clickable results panel and no
  integrated diff yet.
* The search runs on a background thread (the IDE never freezes) and the
  **Cancel** button really stops it — the engine checks the cancellation at
  every commit and at every diff entry — but the progress of a very large
  repository is not detailed.
* The plugin has been verified on **PyCharm 2026.2.4** (compiled against it) and
  on **PyCharm Community 2024.3** (`since-build 243`): the official JetBrains
  Plugin Verifier returns *“Compatible. 1 usage of deprecated API”* there, and
  the plugin is really loaded by that IDE. It has not been tested on
  IntelliJ IDEA (it only uses `com.intellij.modules.platform`, so nothing in the
  code is PyCharm-specific).

## Privacy

The plugin reads the local repository and nothing else. No network access, no
telemetry, no account.
