package com.tgglabs.pickaxe.engine;

import org.eclipse.jgit.api.Git;
import org.eclipse.jgit.lib.PersonIdent;
import org.eclipse.jgit.lib.Repository;
import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.io.TempDir;

import java.nio.charset.StandardCharsets;
import java.nio.file.Files;
import java.nio.file.Path;
import java.util.ArrayList;
import java.util.List;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertFalse;

/**
 * Test de non-duplication des fusions.
 *
 * <p>Cas couvert : une branche ajoute la chaine cherchee, puis elle est
 * fusionnee dans la branche principale. {@code git log -S} n'affiche aucun
 * diff pour un commit de fusion (sans {@code -m}) : le changement remonte
 * UNE SEULE FOIS, via le commit qui l'a fait (celui de la branche).</p>
 *
 * <p>Si le moteur compare un commit de fusion a son premier parent, le
 * changement de la branche remonte une SECONDE fois (via la fusion) : c'est
 * le doublon que ce test interdit.</p>
 */
class MergeSearchTest {

    /** Chaine cherchee (la meme que dans {@link TestRepository}). */
    private static final String NEEDLE = TestRepository.NEEDLE;

    /** Message du commit de la branche qui ajoute la chaine. */
    private static final String SUBJECT_BRANCH = "feat: add the configuration file";

    /** Message du commit de fusion. */
    private static final String SUBJECT_MERGE = "Merge branch 'feature'";

    /** Message du commit sans rapport, sur la branche principale. */
    private static final String SUBJECT_UNRELATED = "chore: unrelated change";

    @TempDir
    Path tempDir;

    @Test
    @DisplayName("une branche ajoute la chaine puis est fusionnee : UN SEUL resultat")
    void mergedBranchIsNotReportedTwice() throws Exception {
        Path directory = tempDir.resolve("merge");
        Files.createDirectories(directory);

        try (Git git = Git.init().setDirectory(directory.toFile()).call()) {
            String main = git.getRepository().getBranch();

            // ---- branche principale : un commit de depart -------------------
            write(directory.resolve("README.md"), "# Alpha\n");
            commit(git, "init: add readme");

            // ---- branche « feature » : elle ajoute la chaine ----------------
            git.checkout().setCreateBranch(true).setName("feature").call();
            write(directory.resolve("src/config.py"), "TOKEN = \"" + NEEDLE + "\"\n");
            commit(git, SUBJECT_BRANCH);

            // ---- la branche principale avance aussi (sinon la fusion serait
            //      un fast-forward et il n'y aurait pas de commit de fusion) --
            git.checkout().setName(main).call();
            write(directory.resolve("README.md"), "# Alpha\n\nUne ligne de plus.\n");
            commit(git, SUBJECT_UNRELATED);

            // ---- fusion de « feature » dans la branche principale ----------
            git.merge().include(git.getRepository().findRef("feature"))
                    .setCommit(true).setMessage(SUBJECT_MERGE).call();

            // ---- le depot contient bien un commit de fusion ----------------
            Repository repository = git.getRepository();
            PickaxeEngine engine = new PickaxeEngine(repository);

            List<String> found = subjects(engine);
            List<String> expected = new ArrayList<>();
            expected.add(SUBJECT_BRANCH);
            assertEquals(expected, found,
                    "le changement de la branche doit remonter UNE SEULE FOIS "
                            + "(commit de branche seul, pas de doublon via la fusion) : " + found);
            assertFalse(found.contains(SUBJECT_MERGE),
                    "un commit de fusion ne doit pas etre rapporte : " + found);
        }
    }

    @Test
    @DisplayName("la fusion ne duplique pas non plus en mode -G")
    void mergedBranchIsNotReportedTwiceInRegexMode() throws Exception {
        Path directory = tempDir.resolve("merge-regex");
        Files.createDirectories(directory);

        try (Git git = Git.init().setDirectory(directory.toFile()).call()) {
            String main = git.getRepository().getBranch();

            write(directory.resolve("README.md"), "# Alpha\n");
            commit(git, "init: add readme");

            git.checkout().setCreateBranch(true).setName("feature").call();
            write(directory.resolve("src/config.py"), "TOKEN = \"" + NEEDLE + "\"\n");
            commit(git, SUBJECT_BRANCH);

            git.checkout().setName(main).call();
            write(directory.resolve("README.md"), "# Alpha\n\nUne ligne de plus.\n");
            commit(git, SUBJECT_UNRELATED);

            git.merge().include(git.getRepository().findRef("feature"))
                    .setCommit(true).setMessage(SUBJECT_MERGE).call();

            PickaxeEngine engine = new PickaxeEngine(git.getRepository());
            List<String> found = new ArrayList<>();
            for (PickaxeHit hit : engine.search(PickaxeQuery.builder(PickaxeMode.REGEX, NEEDLE).build())) {
                found.add(hit.getSubject());
            }
            List<String> expected = new ArrayList<>();
            expected.add(SUBJECT_BRANCH);
            assertEquals(expected, found,
                    "en mode -G aussi, la fusion ne doit pas dupliquer le resultat : " + found);
        }
    }

    // ------------------------------------------------------------------ outils

    private static List<String> subjects(PickaxeEngine engine) throws PickaxeException {
        List<String> subjects = new ArrayList<>();
        for (PickaxeHit hit : engine.search(PickaxeQuery.builder(PickaxeMode.STRING, NEEDLE).build())) {
            subjects.add(hit.getSubject());
        }
        return subjects;
    }

    private static void commit(Git git, String message) throws Exception {
        git.add().addFilepattern(".").call();
        PersonIdent identity = new PersonIdent("Test Author", "author@example.org");
        git.commit()
                .setMessage(message)
                .setAuthor(identity)
                .setCommitter(identity)
                .call();
    }

    private static void write(Path path, String content) throws Exception {
        Files.createDirectories(path.getParent());
        Files.write(path, content.getBytes(StandardCharsets.UTF_8));
    }
}
