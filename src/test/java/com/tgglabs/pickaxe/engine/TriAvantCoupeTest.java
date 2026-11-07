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

/**
 * LA COUPE APRES LE TRI (point 3 du jury du 06/11/2026).
 *
 * <p>Le moteur parcourait l'historique dans l'ordre TOPOLOGIQUE (comme
 * {@code git log}) et s'arretait dès qu'il avait {@code maxResults} resultats
 * : la coupe Portrait donc dans un ordre qui n'est pas un ordre par date. Le
 * tri par date etait applique APRÈS, sur les resultats deja coupes. Sur un
 * historique dont les dates sont dans le desordre (decalage d'horloge,
 * cherry-pick, rebase), un commit RECENT pouvait donc manquer, alors que la
 * fiche publique promet « most recent first ».</p>
 *
 * <p>Le depot de ce test est construit pour que les deux ordres ne PUISSENT
 * pas coincider :</p>
 * <ul>
 *   <li>{@code A} est la RACINE de l'historique, mais son horodatage est le
 *       plus RECENT (20 janvier) ;</li>
 *   <li>{@code B} est le FILS de {@code A}, mais son horodatage est le plus
 *       ANCIEN (5 janvier) ;</li>
 *   <li>{@code C} part de {@code A} sur une autre branche (10 janvier).</li>
 * </ul>
 *
 * <p>Le parcours topologique rend alors les commits dans un ordre qui
 * commence par {@code C} ou {@code B} — donc par un commit qui n'est PAS le
 * plus recent. Avec {@code maxResults = 1}, l'ancien code gardait ce premier
 * commit du parcours ; le code corrigé garde le plus RECENT ({@code A}).</p>
 */
class TriAvantCoupeTest {

    /** Chaine cherchee dans les fichiers de chaque commit. */
    private static final String NEEDLE = "s3cret-needle";

    /** 2026-01-01T00:00:00Z : reference des dates fixes du test. */
    private static final long EPOCH_2026_01_01 = 1_767_225_600L;

    /** A : la racine de l'historique, mais le commit le plus RECENT. */
    private static final String SUBJECT_A = "A : la racine, mais le commit le plus recent";

    /** B : le fils de A, mais le commit le plus ANCIEN. */
    private static final String SUBJECT_B = "B : le fils de A, mais le commit le plus ancien";

    /** C : la branche parallele, date intermediaire. */
    private static final String SUBJECT_C = "C : la branche parallele, date intermediaire";

    @TempDir
    Path tempDir;

    @Test
    @DisplayName("la limite de resultats est appliquee APRES le tri : le commit le plus recent est conserve")
    void laCoupeAppliqueLeTriEtPasLOrdreDuParcours() throws Exception {
        try (Git git = depotAvecDatesDesordonnees()) {
            PickaxeEngine engine = new PickaxeEngine(git.getRepository());
            List<PickaxeHit> hits = engine.search(
                    PickaxeQuery.builder(PickaxeMode.STRING, NEEDLE).maxResults(1).build());

            assertEquals(1, hits.size(), "la limite de resultats doit etre respectee");
            assertEquals(SUBJECT_A, hits.get(0).getSubject(),
                    "le resultat conserve doit etre le PLUS RECENT (20 janvier) et non le "
                            + "premier commit du parcours topologique");
        }
    }

    @Test
    @DisplayName("la limite de resultats garde les plus recents, du plus recent au plus ancien")
    void laCoupeGardeLesPlusRecentsDansLOrdre() throws Exception {
        try (Git git = depotAvecDatesDesordonnees()) {
            PickaxeEngine engine = new PickaxeEngine(git.getRepository());
            List<PickaxeHit> hits = engine.search(
                    PickaxeQuery.builder(PickaxeMode.STRING, NEEDLE).maxResults(2).build());

            List<String> subjects = new ArrayList<>();
            for (PickaxeHit hit : hits) {
                subjects.add(hit.getSubject());
            }
            List<String> attendus = new ArrayList<>();
            attendus.add(SUBJECT_A);   // 20 janvier
            attendus.add(SUBJECT_C);   // 10 janvier
            assertEquals(attendus, subjects,
                    "les 2 resultats doivent etre les 2 plus recents, dans l'ordre decroissant");
        }
    }

    @Test
    @DisplayName("a date egale, la coupe garde celui du parcours le plus ancien (tri stable)")
    void laCoupeEstStableALaDateEgale() throws Exception {
        Path directory = tempDir.resolve("tri-egalite");
        Files.createDirectories(directory);
        try (Git git = Git.init().setDirectory(directory.toFile()).call()) {
            // A : la racine, date du 10 janvier.
            write(directory.resolve("f1.txt"), "TOKEN = \"" + NEEDLE + "\"\n");
            commit(git, "A : la racine", day(10, 12));
            // B : le FILS de A, MEME date (10 janvier) : le parcours rend
            // B avant A (ordre topologique), et le tri est stable : c'est
            // donc B qui doit etre conserve si la limite vaut 1.
            write(directory.resolve("f2.txt"), "TOKEN = \"" + NEEDLE + "\"\n");
            commit(git, "B : le fils, meme date", day(10, 12));

            PickaxeEngine engine = new PickaxeEngine(git.getRepository());
            List<PickaxeHit> hits = engine.search(
                    PickaxeQuery.builder(PickaxeMode.STRING, NEEDLE).maxResults(1).build());

            assertEquals(1, hits.size(), "la limite de resultats doit etre respectee");
            assertEquals("B : le fils, meme date", hits.get(0).getSubject(),
                    "a date egale, le tri est stable : le premier du parcours est conserve");
        }
    }

    // ------------------------------------------------------------------ outils

    /**
     * Construit le depot : A (20 janvier, la racine), B (5 janvier, le fils
     * de A) et C (10 janvier, sur une branche qui part de A).
     */
    private Git depotAvecDatesDesordonnees() throws Exception {
        Path directory = tempDir.resolve("tri-avant-coupe");
        Files.createDirectories(directory);
        Git git = Git.init().setDirectory(directory.toFile()).call();

        // A : la RACINE, date du 20 janvier — le plus recent de tous.
        write(directory.resolve("f1.txt"), "TOKEN = \"" + NEEDLE + "\"\n");
        commit(git, SUBJECT_A, day(20, 12));
        ObjectId commitA = git.getRepository().resolve(Constants.HEAD);

        // B : le FILS de A, date du 5 janvier — le plus ancien de tous.
        write(directory.resolve("f2.txt"), "TOKEN = \"" + NEEDLE + "\"\n");
        commit(git, SUBJECT_B, day(5, 12));

        // C : une branche qui part de A, date du 10 janvier.
        git.checkout().setCreateBranch(true).setName("feature")
                .setStartPoint(commitA.name()).call();
        write(directory.resolve("f3.txt"), "TOKEN = \"" + NEEDLE + "\"\n");
        commit(git, SUBJECT_C, day(10, 12));

        return git;
    }

    /** Epoch du jour donne, a l'heure donnee (UTC). */
    private static long day(int dayOfMonth, int hour) {
        return EPOCH_2026_01_01 + (dayOfMonth - 1L) * 86_400L + hour * 3_600L;
    }

    private static void commit(Git git, String message, long seconds) throws Exception {
        git.add().addFilepattern(".").call();
        // Date fixe pour l'AUTEUR et le COMMITTEUR.
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
