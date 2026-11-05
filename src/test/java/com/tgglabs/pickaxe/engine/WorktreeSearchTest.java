package com.tgglabs.pickaxe.engine;

import org.eclipse.jgit.api.Git;
import org.eclipse.jgit.lib.PersonIdent;
import org.eclipse.jgit.lib.Ref;
import org.eclipse.jgit.lib.Repository;
import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.io.TempDir;

import java.io.IOException;
import java.nio.charset.StandardCharsets;
import java.nio.file.Files;
import java.nio.file.Path;
import java.util.ArrayList;
import java.util.Arrays;
import java.util.Date;
import java.util.List;
import java.util.TimeZone;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertTrue;

/**
 * Test de REGRESSION du cas « worktree ».
 *
 * <p>Dans un worktree cree par {@code git worktree add}, le repertoire de
 * travail porte un fichier {@code .git} (et non un repertoire). Les
 * REFERENCES, en revanche, vivent dans le depot COMMUN : un lecteur qui
 * ouvre le repertoire du worktree ne voit ni HEAD ni aucune reference, et la
 * recherche rend alors ZERO resultat — silencieusement, sans erreur.</p>
 *
 * <p>Ce test passe par le MOTEUR ({@link PickaxeEngine}) et par le chemin
 * d'ouverture du produit ({@link PickaxeRepository#open(Path)}) : il doit
 * donc etre ROUGE avant le correctif et VERT apres.</p>
 */
class WorktreeSearchTest {

    /** Chaine propre a la branche du worktree : absente du depot principal. */
    private static final String WORKTREE_NEEDLE = "worktree-only-needle-4711";

    /** Message du commit propre a la branche du worktree. */
    private static final String SUBJECT_WORKTREE = "feat: worktree only commit";

    /** Nom de la branche checkout dans le worktree. */
    private static final String FEATURE_BRANCH = "feature";

    @TempDir
    Path tempDir;

    // =====================================================================
    // Le cas qui etait casse
    // =====================================================================

    @Test
    @DisplayName("worktree : la recherche trouve le commit de la branche du worktree")
    void searchInAWorktreeFindsTheCommitOfTheWorktreeBranch() throws Exception {
        Path main = tempDir.resolve("repo");
        Path worktree = tempDir.resolve("wt");
        createRepositoryWithFeatureBranch(main);
        createLinkedWorktree(main, worktree, FEATURE_BRANCH);

        try (Repository repository = PickaxeRepository.open(worktree)) {
            PickaxeEngine engine = new PickaxeEngine(repository);
            List<PickaxeHit> hits = engine.search(
                    PickaxeQuery.builder(PickaxeMode.STRING, WORKTREE_NEEDLE).build());

            assertEquals(1, hits.size(),
                    "le commit propre au worktree doit etre trouve : " + describe(repository));
            assertEquals(SUBJECT_WORKTREE, hits.get(0).getSubject(),
                    "le commit trouve est celui de la branche du worktree : " + describe(repository));
            assertEquals(Arrays.asList("src/worktree.txt"), hits.get(0).getPaths(),
                    "le fichier du worktree doit etre signale : " + describe(repository));
        }
    }

    @Test
    @DisplayName("worktree : les commits du depot principal restent visibles depuis le worktree")
    void searchInAWorktreeAlsoFindsTheMainRepositoryCommits() throws Exception {
        Path main = tempDir.resolve("repo");
        Path worktree = tempDir.resolve("wt");
        createRepositoryWithFeatureBranch(main);
        createLinkedWorktree(main, worktree, FEATURE_BRANCH);

        try (Repository repository = PickaxeRepository.open(worktree)) {
            PickaxeEngine engine = new PickaxeEngine(repository);
            List<PickaxeHit> hits = engine.search(
                    PickaxeQuery.builder(PickaxeMode.STRING, TestRepository.NEEDLE).build());

            assertEquals(2, hits.size(),
                    "les deux commits de la chaine de base doivent etre trouves : " + describe(repository));
            assertEquals(TestRepository.SUBJECT_REMOVE, hits.get(0).getSubject());
            assertEquals(TestRepository.SUBJECT_ADD, hits.get(1).getSubject());
        }
    }

    // =====================================================================
    // Controles : aucun regresse
    // =====================================================================

    @Test
    @DisplayName("controle : un depot normal n'a pas regresse")
    void searchInANormalRepositoryStillWorks() throws Exception {
        Path main = tempDir.resolve("repo");
        TestRepository.build(main);

        try (Repository repository = PickaxeRepository.open(main)) {
            PickaxeEngine engine = new PickaxeEngine(repository);
            List<PickaxeHit> hits = engine.search(
                    PickaxeQuery.builder(PickaxeMode.STRING, TestRepository.NEEDLE).build());

            assertEquals(2, hits.size(), "deux commits attendus : " + describe(repository));
            assertEquals(TestRepository.SUBJECT_REMOVE, hits.get(0).getSubject());
            assertEquals(TestRepository.SUBJECT_ADD, hits.get(1).getSubject());
        }
    }

    @Test
    @DisplayName("controle : un sous-module n'a pas regresse")
    void searchInASubmoduleStillWorks() throws Exception {
        Path child = tempDir.resolve("child");
        Path superRepo = tempDir.resolve("super");
        TestRepository.build(child);
        createSuperRepositoryWithSubmodule(superRepo, child);

        Path submodule = superRepo.resolve("sub");
        assertTrue(Files.isRegularFile(submodule.resolve(".git")),
                "dans un sous-module, .git doit etre un FICHIER");

        try (Repository repository = PickaxeRepository.open(submodule)) {
            PickaxeEngine engine = new PickaxeEngine(repository);
            List<PickaxeHit> hits = engine.search(
                    PickaxeQuery.builder(PickaxeMode.STRING, TestRepository.NEEDLE).build());

            assertEquals(2, hits.size(), "deux commits attendus : " + describe(repository));
            assertEquals(TestRepository.SUBJECT_REMOVE, hits.get(0).getSubject());
            assertEquals(TestRepository.SUBJECT_ADD, hits.get(1).getSubject());
        }
    }

    // =====================================================================
    // Outillage du decor
    // =====================================================================

    /** Description courte du depot ouvert (pour les messages d'echec). */
    private static String describe(Repository repository) throws IOException {
        StringBuilder sb = new StringBuilder();
        sb.append("[dossier=").append(repository.getDirectory());
        sb.append(" refs=");
        for (Ref ref : repository.getRefDatabase().getRefs()) {
            sb.append(ref.getName()).append(' ');
        }
        sb.append(']');
        return sb.toString();
    }

    /**
     * Depot principal + branche {@code feature} portant un commit que la
     * branche principale ne contient pas.
     */
    private void createRepositoryWithFeatureBranch(Path main) throws Exception {
        TestRepository.build(main);
        try (Git git = Git.open(main.toFile())) {
            String fullBranch = git.getRepository().getFullBranch();
            String baseBranch = fullBranch.startsWith("refs/heads/")
                    ? fullBranch.substring("refs/heads/".length())
                    : fullBranch;
            git.checkout().setCreateBranch(true).setName(FEATURE_BRANCH).call();
            Files.createDirectories(main.resolve("src"));
            Files.write(main.resolve("src/worktree.txt"),
                    ("TOKEN = \"" + WORKTREE_NEEDLE + "\"\n").getBytes(StandardCharsets.UTF_8));
            git.add().addFilepattern(".").call();
            long seconds = 1_767_225_600L + 600L;
            PersonIdent identity = new PersonIdent("Test Author", "author@example.org",
                    new Date(seconds * 1000L), TimeZone.getTimeZone("UTC"));
            git.commit()
                    .setMessage(SUBJECT_WORKTREE)
                    .setAuthor(identity)
                    .setCommitter(identity)
                    .call();
            // On revient sur la branche de base : la branche « feature » ne
            // sera plus checkoute nulle part, et le worktree pourra la
            // prendre.
            git.checkout().setName(baseBranch).call();
        }
    }

    /**
     * Cree un vrai worktree lie : {@code git worktree add <chemin> feature}.
     * Si le binaire {@code git} est absent, la meme arborescence est ecrite
     * a la main (c'est exactement ce que git ecrit).
     */
    private void createLinkedWorktree(Path main, Path worktree, String branch) throws Exception {
        String git = gitBinary();
        if (git != null) {
            runGit(git, main, "worktree", "add", worktree.toAbsolutePath().toString(), branch);
            return;
        }
        createLinkedWorktreeLayout(main, worktree, branch);
    }

    /** Arborescence d'un worktree lie, ecrite a la main. */
    private void createLinkedWorktreeLayout(Path main, Path worktree, String branch) throws IOException {
        Path worktreeGitDir = main.resolve(".git").resolve("worktrees").resolve("wt");
        Files.createDirectories(worktreeGitDir);
        Files.write(worktreeGitDir.resolve("HEAD"),
                ("ref: refs/heads/" + branch + "\n").getBytes(StandardCharsets.UTF_8));
        Files.write(worktreeGitDir.resolve("commondir"),
                ("../..\n").getBytes(StandardCharsets.UTF_8));
        Files.createDirectories(worktree);
        Files.write(worktree.resolve(".git"),
                ("gitdir: " + worktreeGitDir.toAbsolutePath() + "\n").getBytes(StandardCharsets.UTF_8));
        Files.write(worktreeGitDir.resolve("gitdir"),
                (worktree.resolve(".git").toAbsolutePath() + "\n").getBytes(StandardCharsets.UTF_8));
    }

    /** Depot « parent » contenant le depot « child » en sous-module. */
    private void createSuperRepositoryWithSubmodule(Path superRepo, Path child) throws Exception {
        String git = gitBinary();
        if (git == null) {
            throw new IOException("le binaire git est necessaire pour le controle « sous-module »");
        }
        Files.createDirectories(superRepo);
        runGit(git, superRepo, "init", "-q", "-b", "main", ".");
        runGit(git, superRepo, "-c", "user.email=test@example.org", "-c", "user.name=Test",
                "commit", "-q", "--allow-empty", "-m", "init: empty repository");
        runGit(git, superRepo, "-c", "protocol.file.allow=always", "submodule", "-q", "add",
                child.toAbsolutePath().toString(), "sub");
        runGit(git, superRepo, "-c", "user.email=test@example.org", "-c", "user.name=Test",
                "commit", "-q", "-m", "feat: add the submodule");
    }

    /** Cherche le binaire {@code git}. */
    private static String gitBinary() {
        for (String candidate : new String[]{"/usr/bin/git", "/bin/git", "/usr/local/bin/git"}) {
            if (Files.isExecutable(Path.of(candidate))) {
                return candidate;
            }
        }
        String path = System.getenv("PATH");
        if (path != null) {
            for (String dir : path.split(java.io.File.pathSeparator)) {
                Path candidate = Path.of(dir, "git");
                if (Files.isExecutable(candidate)) {
                    return candidate.toString();
                }
            }
        }
        return null;
    }

    /** Lance {@code git -C <repo> <args...>} et echoue si git echoue. */
    private static void runGit(String git, Path repo, String... args) throws Exception {
        List<String> command = new ArrayList<>();
        command.add(git);
        command.add("-C");
        command.add(repo.toAbsolutePath().toString());
        command.addAll(Arrays.asList(args));
        Process process = new ProcessBuilder(command).redirectErrorStream(true).start();
        String output = new String(process.getInputStream().readAllBytes(), StandardCharsets.UTF_8);
        int status = process.waitFor();
        if (status != 0) {
            throw new IOException("la commande « " + String.join(" ", command)
                    + " » a echoue (code " + status + ") :\n" + output);
        }
    }
}
