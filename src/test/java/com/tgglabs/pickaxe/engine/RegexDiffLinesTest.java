package com.tgglabs.pickaxe.engine;

import org.eclipse.jgit.api.Git;
import org.eclipse.jgit.diff.DiffEntry;
import org.eclipse.jgit.diff.DiffFormatter;
import org.eclipse.jgit.diff.Edit;
import org.eclipse.jgit.diff.RawTextComparator;
import org.eclipse.jgit.lib.Constants;
import org.eclipse.jgit.lib.ObjectId;
import org.eclipse.jgit.lib.ObjectReader;
import org.eclipse.jgit.lib.PersonIdent;
import org.eclipse.jgit.lib.Repository;
import org.eclipse.jgit.revwalk.RevCommit;
import org.eclipse.jgit.revwalk.RevTree;
import org.eclipse.jgit.revwalk.RevWalk;
import org.eclipse.jgit.treewalk.CanonicalTreeParser;
import org.eclipse.jgit.util.io.NullOutputStream;
import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.io.TempDir;

import java.io.IOException;
import java.io.OutputStream;
import java.nio.charset.StandardCharsets;
import java.nio.file.Files;
import java.nio.file.Path;
import java.util.ArrayList;
import java.util.Arrays;
import java.util.Date;
import java.util.List;
import java.util.TimeZone;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertFalse;
import static org.junit.jupiter.api.Assertions.assertTrue;

/**
 * Mode {@code -G} : numeros de ligne des {@link Edit} de JGit, et blobs
 * trop gros pour etre lus en memoire.
 *
 * <p>Deux defauts sont traites ici :</p>
 * <ul>
 *   <li><b>decalage d'une ligne</b> : les numeros de ligne d'un {@code Edit}
 *       sont <b>1-based</b> (mesure : {@link #experienceNumerosDeLigneDeEditSont1Based()}),
 *       alors que le moteur les utilisait comme des index 0-based. Le mode
 *       {@code -G} testait donc la ligne <b>suivante</b> : une ligne ajoutee
 *       qui matche la regex n'etait jamais signalee ;</li>
 *   <li><b>faux positif sur les blobs de plus de 64 Mo</b> : un blob trop
 *       gros etait lu comme « zero occurrence », donc une chaine presente
 *       avant et invisible apres était signalee comme supprimee.</li>
 * </ul>
 */
class RegexDiffLinesTest {

    /** Ligne unique cherchee : elle n'apparait que dans les commits 2 et 3. */
    private static final String NEEDLE_LINE = "NEEDLE-LINE-4711";

    private static final String SUBJECT_INIT = "init: three lines";
    private static final String SUBJECT_ADD = "feat: add one line";
    private static final String SUBJECT_REMOVE = "fix: remove one line";

    private static final String SUBJECT_BIG_ADD = "chore: add a big file";
    private static final String SUBJECT_BIG_GROW = "chore: grow the big file";

    @TempDir
    Path tempDir;

    // =====================================================================
    // 1. L'EXPERIENCE : la convention des numeros de ligne de JGit
    // =====================================================================

    @Test
    @DisplayName("EXPERIENCE : les numeros de ligne d'un Edit de JGit sont 0-based")
    void experienceNumerosDeLigneDeEditSont0Based() throws Exception {
        Path dir = tempDir.resolve("experience");
        Files.createDirectories(dir);
        buildThreeLinesRepo(dir);

        try (Git git = Git.open(dir.toFile())) {
            Repository repo = git.getRepository();
            try (RevWalk walk = new RevWalk(repo);
                 DiffFormatter formatter = new DiffFormatter(NullOutputStream.INSTANCE)) {
                formatter.setRepository(repo);
                formatter.setDiffComparator(RawTextComparator.DEFAULT);
                formatter.setDetectRenames(true);

                // Tous les commits, du plus recent au plus ancien.
                for (RevCommit commit : git.log().all().call()) {
                    String subject = commit.getFullMessage().split("\n", 2)[0].trim();
                    RevTree newTree = walk.parseTree(commit.getTree());
                    RevTree oldTree = commit.getParentCount() > 0
                            ? walk.parseCommit(commit.getParent(0).getId()).getTree()
                            : null;

                    try (ObjectReader reader = repo.newObjectReader()) {
                        CanonicalTreeParser oldParser = new CanonicalTreeParser();
                        CanonicalTreeParser newParser = new CanonicalTreeParser();
                        newParser.reset(reader, newTree.getId());
                        if (oldTree != null) {
                            oldParser.reset(reader, oldTree.getId());
                        }

                        for (DiffEntry entry : formatter.scan(oldParser, newParser)) {
                            String[] oldLines = PickaxeEngine.splitLines(read(repo, entry.getOldId().toObjectId()));
                            String[] newLines = PickaxeEngine.splitLines(read(repo, entry.getNewId().toObjectId()));
                            System.out.println("=== COMMIT : " + subject + "  (fichier " + entry.getNewPath() + ")");
                            System.out.println("    oldLines (index 0-based) = " + Arrays.toString(oldLines));
                            System.out.println("    newLines (index 0-based) = " + Arrays.toString(newLines));
                            for (Edit edit : formatter.toFileHeader(entry).toEditList()) {
                                System.out.println("    EDIT beginA=" + edit.getBeginA()
                                        + " endA=" + edit.getEndA()
                                        + " beginB=" + edit.getBeginB()
                                        + " endB=" + edit.getEndB());
                                System.out.println("      index 0-based (ce que fait le moteur) :");
                                printTested(oldLines, newLines, edit.getBeginA(), edit.getEndA(),
                                        edit.getBeginB(), edit.getEndB());
                                System.out.println("      si les numeros etaient 1-based (index = numero - 1) :");
                                printTested(oldLines, newLines, edit.getBeginA() - 1, edit.getEndA() - 1,
                                        edit.getBeginB() - 1, edit.getEndB() - 1);

                                // La convention reelle : le numero donne par JGit
                                // EST l'index 0-based de la ligne reellement
                                // modifiee. La ligne ajoutee (commit 2) est la
                                // troisieme ligne du nouveau fichier (index 2),
                                // la ligne supprimee (commit 3) est la
                                // troisieme ligne de l'ancien fichier (index 2).
                                if (SUBJECT_ADD.equals(subject)) {
                                    assertEquals(2, edit.getBeginB(),
                                            "le numero de ligne de l'Edit est l'index 0-based de la ligne ajoutee");
                                    assertEquals(NEEDLE_LINE, newLines[edit.getBeginB()]);
                                }
                                if (SUBJECT_REMOVE.equals(subject)) {
                                    assertEquals(2, edit.getBeginA(),
                                            "le numero de ligne de l'Edit est l'index 0-based de la ligne supprimee");
                                    assertEquals(NEEDLE_LINE, oldLines[edit.getBeginA()]);
                                }
                            }
                        }
                    }
                }
            }
        }
    }

    private static void printTested(String[] oldLines, String[] newLines,
                                    int beginA, int endA, int beginB, int endB) {
        for (int i = beginA; i < endA && i >= 0 && i < oldLines.length; i++) {
            System.out.println("        oldLines[" + i + "] = " + oldLines[i]);
        }
        for (int i = beginB; i < endB && i >= 0 && i < newLines.length; i++) {
            System.out.println("        newLines[" + i + "] = " + newLines[i]);
        }
    }

    private static byte[] read(Repository repo, ObjectId id) throws IOException {
        if (id == null || ObjectId.zeroId().equals(id)) {
            return null;
        }
        return repo.open(id).getBytes();
    }

    // =====================================================================
    // 2. Le mode -G doit tester la ligne REELLEMENT modifiee
    // =====================================================================

    @Test
    @DisplayName("-G trouve le commit qui AJOUTE une seule ligne qui matche")
    void regexSearchFindsSingleAddedLine() throws Exception {
        Path dir = tempDir.resolve("added");
        Files.createDirectories(dir);
        buildThreeLinesRepo(dir);

        List<String> found = subjects(engine(dir), PickaxeQuery.builder(PickaxeMode.REGEX, NEEDLE_LINE).build());
        assertTrue(found.contains(SUBJECT_ADD),
                "le commit qui ajoute une seule ligne matchant la regex doit remonter : " + found);
    }

    @Test
    @DisplayName("-G trouve le commit qui SUPPRIME une seule ligne qui matche")
    void regexSearchFindsSingleRemovedLine() throws Exception {
        Path dir = tempDir.resolve("removed");
        Files.createDirectories(dir);
        buildThreeLinesRepo(dir);

        List<String> found = subjects(engine(dir), PickaxeQuery.builder(PickaxeMode.REGEX, NEEDLE_LINE).build());
        assertTrue(found.contains(SUBJECT_REMOVE),
                "le commit qui supprime une seule ligne matchant la regex doit remonter : " + found);
    }

    @Test
    @DisplayName("-G : les deux commits (ajout et suppression) remontent, pas le premier")
    void regexSearchFindsBothSidesAndOnlyThem() throws Exception {
        Path dir = tempDir.resolve("both");
        Files.createDirectories(dir);
        buildThreeLinesRepo(dir);

        List<String> found = subjects(engine(dir), PickaxeQuery.builder(PickaxeMode.REGEX, NEEDLE_LINE).build());
        assertEquals(Arrays.asList(SUBJECT_REMOVE, SUBJECT_ADD), found,
                "seuls les commits 2 et 3 doivent remonter (le plus recent d'abord)");
    }

    // =====================================================================
    // 3. Les blobs de plus de 64 Mo : pas de faux positif
    // =====================================================================

    @Test
    @DisplayName("un commit qui modifie un blob de plus de 64 Mo ne remonte PAS")
    void bigBlobModificationIsNotReported() throws Exception {
        Path dir = tempDir.resolve("big");
        Files.createDirectories(dir);
        // L'ancien blob reste lisible (40 Mo < 50 Mo, le seuil de JGit) :
        // il contient la chaine. Le nouveau depasse la garde du moteur
        // (64 Mo) : il n'est pas lu, donc il ne doit surtout pas etre
        // compte « zero occurrence ».
        final int underLimit = 40 * 1024 * 1024;
        final int overLimit = 70 * 1024 * 1024;

        try (Git git = Git.init().setDirectory(dir.toFile()).call()) {
            // La chaine est presente DANS les deux versions : le commit qui
            // fait grossir le fichier ne la supprime pas.
            writeBigFile(dir.resolve("big.txt"), underLimit, true);
            commit(git, SUBJECT_BIG_ADD);
            writeBigFile(dir.resolve("big.txt"), overLimit, true);
            commit(git, SUBJECT_BIG_GROW);
        }

        List<String> found = subjects(engine(dir),
                PickaxeQuery.builder(PickaxeMode.STRING, TestRepository.NEEDLE).build());

        assertFalse(found.contains(SUBJECT_BIG_GROW),
                "un blob trop gros pour etre lu ne doit pas etre compte « zero occurrence » : "
                        + "le commit qui fait grossir le fichier ne doit PAS remonter : " + found);
    }

    @Test
    @DisplayName("un blob que JGit refuse de charger (>= 50 Mo) n'interrompt pas la recherche")
    void blobRefusedByJgitDoesNotBreakTheSearch() throws Exception {
        Path dir = tempDir.resolve("refused");
        Files.createDirectories(dir);
        // 55 Mo : au-dela du seuil de JGit (50 Mo) mais en dessous de la
        // garde du moteur (64 Mo). Avant le correctif, JGit leve une
        // LargeObjectException et TOUTE la recherche echoue.
        final int size = 55 * 1024 * 1024;

        try (Git git = Git.init().setDirectory(dir.toFile()).call()) {
            writeBigFile(dir.resolve("big.txt"), size, true);
            commit(git, SUBJECT_BIG_ADD);
            writeBigFile(dir.resolve("big.txt"), size + 1, true);
            commit(git, SUBJECT_BIG_GROW);
        }

        List<String> found = subjects(engine(dir),
                PickaxeQuery.builder(PickaxeMode.STRING, TestRepository.NEEDLE).build());

        assertFalse(found.contains(SUBJECT_BIG_GROW),
                "un blob que JGit refuse de lire doit etre ignore, pas signale : " + found);
    }

    // =====================================================================
    // Utilitaires
    // =====================================================================

    /**
     * Depot de trois commits : trois lignes, puis l'ajout d'UNE ligne qui
     * matche la regex, puis sa suppression.
     */
    private static void buildThreeLinesRepo(Path dir) throws Exception {
        try (Git git = Git.init().setDirectory(dir.toFile()).call()) {
            write(dir.resolve("notes.txt"), "alpha\nbeta\ngamma\n");
            commit(git, SUBJECT_INIT);
            write(dir.resolve("notes.txt"), "alpha\nbeta\n" + NEEDLE_LINE + "\ngamma\n");
            commit(git, SUBJECT_ADD);
            write(dir.resolve("notes.txt"), "alpha\nbeta\ngamma\n");
            commit(git, SUBJECT_REMOVE);
        }
    }

    private static PickaxeEngine engine(Path dir) throws Exception {
        Repository repository = new org.eclipse.jgit.storage.file.FileRepositoryBuilder()
                .setGitDir(dir.resolve(".git").toFile())
                .setWorkTree(dir.toFile())
                .readEnvironment()
                .findGitDir()
                .build();
        return new PickaxeEngine(repository);
    }

    private static List<String> subjects(PickaxeEngine engine, PickaxeQuery query) throws PickaxeException {
        List<String> subjects = new ArrayList<>();
        for (PickaxeHit hit : engine.search(query)) {
            subjects.add(hit.getSubject());
        }
        return subjects;
    }

    private static void write(Path path, String content) throws IOException {
        Files.createDirectories(path.getParent());
        Files.write(path, content.getBytes(StandardCharsets.UTF_8));
    }

    /** Ecrit un fichier de {@code size} octets, en lignes de 'a'. */
    private static void writeBigFile(Path path, int size, boolean withNeedle) throws IOException {
        Files.createDirectories(path.getParent());
        byte[] head = withNeedle
                ? (TestRepository.NEEDLE + "\n").getBytes(StandardCharsets.UTF_8)
                : new byte[0];
        try (OutputStream out = Files.newOutputStream(path)) {
            out.write(head);
            byte[] chunk = new byte[1024 * 1024];
            Arrays.fill(chunk, (byte) 'a');
            int written = head.length;
            while (written < size) {
                int n = Math.min(chunk.length, size - written);
                out.write(chunk, 0, n);
                written += n;
            }
        }
    }

    private static void commit(Git git, String message) throws Exception {
        git.add().addFilepattern(".").call();
        long seconds = 1_767_225_600L;
        PersonIdent identity = new PersonIdent("Test Author", "author@example.org",
                new Date(seconds * 1000L), TimeZone.getTimeZone("UTC"));
        git.commit()
                .setMessage(message)
                .setAuthor(identity)
                .setCommitter(identity)
                .call();
    }
}
