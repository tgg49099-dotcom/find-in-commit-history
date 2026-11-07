package com.tgglabs.pickaxe.engine;

import org.eclipse.jgit.api.Git;
import org.eclipse.jgit.lib.Constants;
import org.eclipse.jgit.lib.ObjectId;
import org.eclipse.jgit.lib.PersonIdent;
import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.io.TempDir;

import java.nio.charset.StandardCharsets;
import java.nio.file.Files;
import java.nio.file.Path;
import java.util.ArrayList;
import java.util.Date;
import java.util.List;
import java.util.TimeZone;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertTrue;

/**
 * Test de l'ordre des resultats : du PLUS RECENT au PLUS ANCIEN.
 *
 * <p>La fiche publique du plugin promet cet ordre (« commits that added or
 * removed it, most recent first »). Un parcours de commits sans tri
 * explicite ne le garantit pas : JGit rend les commits dans l'ordre
 * topologique (un enfant avant son parent), comme {@code git log}, et cet
 * ordre n'est PAS un ordre par date quand les dates sont dans le
 * desordre.</p>
 *
 * <p>Le depot de ce test est construit pour que les deux ordres ne PUISSENT
 * pas coincider :</p>
 * <ul>
 *   <li>deux branches (« main » et « feature ») et une fusion ;</li>
 *   <li>des dates de commit volontairement dans le desordre : le commit
 *       {@code A}, qui est l'ANCETRE de tous les autres, est le plus
 *       RECENT (decalage d'horloge) ; son fils {@code B} est, lui, le plus
 *       ancien.</li>
 * </ul>
 *
 * <p>Le parcours topologique rend alors {@code C, D, B, A} — le commit le
 * plus recent arrive en DERNIER. L'ordre par date decroissante rend
 * {@code A, C, D, B}. Les deux sont differents : le test est donc rouge tant
 * que le moteur ne trie pas.</p>
 */
class ChronologicalOrderTest {

    /** Chaine cherchee (la meme que dans {@link TestRepository}). */
    private static final String NEEDLE = TestRepository.NEEDLE;

    /** 2026-01-01T00:00:00Z : reference des dates fixes du test. */
    private static final long EPOCH_2026_01_01 = 1_767_225_600L;

    /** Message du commit A : l'ancetre, mais le plus recent. */
    private static final String SUBJECT_A = "feat: A adds the token (the most recent commit)";

    /** Message du commit B : le plus ancien, alors qu'il est le fils de A. */
    private static final String SUBJECT_B = "feat: B adds the token (older than its own parent)";

    /** Message du commit de la branche « feature ». */
    private static final String SUBJECT_C = "feat: C adds the token (on the feature branch)";

    /** Message du commit D de la branche principale. */
    private static final String SUBJECT_D = "feat: D adds the token";

    /** Message du commit de fusion. */
    private static final String SUBJECT_MERGE = "Merge branch 'feature'";

    @TempDir
    Path tempDir;

    @Test
    @DisplayName("les resultats sont du plus recent au plus ancien (dates dans le desordre, 2 branches + fusion)")
    void resultsAreSortedByCommitDateDescending() throws Exception {
        Path directory = tempDir.resolve("chrono");
        Files.createDirectories(directory);

        try (Git git = Git.init().setDirectory(directory.toFile()).call()) {
            String main = git.getRepository().getBranch();

            // ---- A : 20 janvier, le plus RECENT de tous ------------------------
            write(directory.resolve("f1.txt"), "TOKEN = \"" + NEEDLE + "\"\n");
            commit(git, SUBJECT_A, day(20, 12));
            ObjectId commitA = git.getRepository().resolve(Constants.HEAD);

            // ---- B : 5 janvier, donc plus ancien que son propre parent A -----
            write(directory.resolve("f2.txt"), "TOKEN = \"" + NEEDLE + "\"\n");
            commit(git, SUBJECT_B, day(5, 12));

            // ---- la branche « feature » part de A et ajoute C : 10 janvier ----
            git.checkout().setCreateBranch(true).setName("feature").setStartPoint(commitA.name()).call();
            write(directory.resolve("f3.txt"), "TOKEN = \"" + NEEDLE + "\"\n");
            commit(git, SUBJECT_C, day(10, 12));

            // ---- retour sur « main » : D, du 8 janvier ------------------------
            git.checkout().setName(main).call();
            write(directory.resolve("f4.txt"), "TOKEN = \"" + NEEDLE + "\"\n");
            commit(git, SUBJECT_D, day(8, 12));

            // ---- fusion de « feature » dans « main » -------------------------
            git.merge().include(git.getRepository().findRef("feature"))
                    .setCommit(true).setMessage(SUBJECT_MERGE).call();

            // ---- le parcours du moteur ----------------------------------------
            PickaxeEngine engine = new PickaxeEngine(git.getRepository());
            List<PickaxeHit> hits = engine.search(
                    PickaxeQuery.builder(PickaxeMode.STRING, NEEDLE).build());

            List<String> found = new ArrayList<>();
            for (PickaxeHit hit : hits) {
                found.add(hit.getSubject());
            }

            // Ordre attendu : du plus recent au plus ancien (dates decroissantes).
            List<String> expected = new ArrayList<>();
            expected.add(SUBJECT_A);   // 20 janvier
            expected.add(SUBJECT_C);   // 10 janvier
            expected.add(SUBJECT_D);   // 8 janvier
            expected.add(SUBJECT_B);   // 5 janvier

            assertEquals(expected, found,
                    "les resultats doivent etre du plus recent au plus ancien : " + found);
        }
    }

    @Test
    @DisplayName("les horodatages affiches sont decroissants (ils correspondent a la date du commit)")
    void hitTimestampsAreDecreasing() throws Exception {
        Path directory = tempDir.resolve("chrono-time");
        Files.createDirectories(directory);

        try (Git git = Git.init().setDirectory(directory.toFile()).call()) {
            String main = git.getRepository().getBranch();

            write(directory.resolve("f1.txt"), "TOKEN = \"" + NEEDLE + "\"\n");
            commit(git, SUBJECT_A, day(20, 12));
            ObjectId commitA = git.getRepository().resolve(Constants.HEAD);

            write(directory.resolve("f2.txt"), "TOKEN = \"" + NEEDLE + "\"\n");
            commit(git, SUBJECT_B, day(5, 12));

            git.checkout().setCreateBranch(true).setName("feature").setStartPoint(commitA.name()).call();
            write(directory.resolve("f3.txt"), "TOKEN = \"" + NEEDLE + "\"\n");
            commit(git, SUBJECT_C, day(10, 12));

            git.checkout().setName(main).call();
            write(directory.resolve("f4.txt"), "TOKEN = \"" + NEEDLE + "\"\n");
            commit(git, SUBJECT_D, day(8, 12));

            git.merge().include(git.getRepository().findRef("feature"))
                    .setCommit(true).setMessage(SUBJECT_MERGE).call();

            PickaxeEngine engine = new PickaxeEngine(git.getRepository());
            List<PickaxeHit> hits = engine.search(
                    PickaxeQuery.builder(PickaxeMode.STRING, NEEDLE).build());

            assertTrue(hits.size() >= 4,
                    "les 4 commits qui ajoutent la chaine doivent etre trouves : " + hits);
            for (int i = 1; i < hits.size(); i++) {
                long previous = hits.get(i - 1).getAuthorTimestampMillis();
                long current = hits.get(i).getAuthorTimestampMillis();
                assertTrue(previous > current,
                        "les horodatages doivent etre decroissants : " + hits.get(i - 1)
                                + " (" + previous + ") avant " + hits.get(i) + " (" + current + ")");
            }
        }
    }

    // ------------------------------------------------------------------ outils

    /** Epoch du jour donne, a l'heure donnee (UTC). */
    private static long day(int dayOfMonth, int hour) {
        return EPOCH_2026_01_01 + (dayOfMonth - 1L) * 86_400L + hour * 3_600L;
    }

    private static void commit(Git git, String message, long seconds) throws Exception {
        git.add().addFilepattern(".").call();
        // Date fixe pour l'AUTEUR et le COMMITTEUR : c'est la date du
        // COMMITTEUR que le moteur affiche et qui doit servir au tri.
        PersonIdent identity = new PersonIdent("Test Author", "author@example.org",
                new Date(seconds * 1000L), TimeZone.getTimeZone("UTC"));
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
