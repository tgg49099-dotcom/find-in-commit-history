package com.tgglabs.pickaxe;

import com.tgglabs.pickaxe.engine.TestRepository;
import org.eclipse.jgit.lib.Repository;
import org.eclipse.jgit.storage.file.FileRepositoryBuilder;
import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.io.TempDir;

import java.nio.charset.StandardCharsets;
import java.nio.file.Files;
import java.nio.file.Path;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertNotNull;
import static org.junit.jupiter.api.Assertions.assertTrue;

/**
 * Tests de {@link GitRepositoryLocator}.
 *
 * <p>Le cas cover par ces tests est celui d'un WORKTREE : dans un worktree,
 * {@code .git} n'est pas un repertoire mais un FICHIER qui contient
 * {@code gitdir: <chemin>}. C'est ce chemin qu'il faut donner a JGit ; lui
 * donner le fichier lui-meme fait echouer l'ouverture du depot.</p>
 */
class GitRepositoryLocatorTest {

    @TempDir
    Path tempDir;

    @Test
    @DisplayName("depot normal : .git est un repertoire, il est utilise tel quel")
    void gitDirectoryIsUsedWhenDotGitIsADirectory() throws Exception {
        TestRepository.build(tempDir);

        Path gitDir = GitRepositoryLocator.resolveGitDir(tempDir);

        assertEquals(tempDir.resolve(".git").toAbsolutePath().normalize(), gitDir);
        assertTrue(Files.isDirectory(gitDir));
    }

    @Test
    @DisplayName("worktree : le fichier .git designe le vrai repertoire Git")
    void gitFileIsResolvedToTheRealGitDirectory() throws Exception {
        TestRepository.build(tempDir);
        Path realGitDir = tempDir.resolve(".git").toAbsolutePath().normalize();

        Path worktree = Files.createDirectories(tempDir.resolve("worktree"));
        Files.write(worktree.resolve(".git"),
                ("gitdir: " + realGitDir + System.lineSeparator()).getBytes(StandardCharsets.UTF_8));

        Path resolved = GitRepositoryLocator.resolveGitDir(worktree);

        assertEquals(realGitDir, resolved.toAbsolutePath().normalize());
        assertTrue(Files.isDirectory(resolved), "le chemin designe doit etre un repertoire");
    }

    @Test
    @DisplayName("worktree : le depot designe s'ouvre reellement avec JGit")
    void repositoryOfAWorktreeCanBeOpened() throws Exception {
        TestRepository.build(tempDir);
        Path realGitDir = tempDir.resolve(".git").toAbsolutePath().normalize();

        Path worktree = Files.createDirectories(tempDir.resolve("worktree"));
        Files.write(worktree.resolve(".git"),
                ("gitdir: " + realGitDir + System.lineSeparator()).getBytes(StandardCharsets.UTF_8));

        try (Repository repository = new FileRepositoryBuilder()
                .setGitDir(GitRepositoryLocator.resolveGitDir(worktree).toFile())
                .readEnvironment()
                .findGitDir()
                .build()) {
            assertNotNull(repository.resolve("HEAD"), "HEAD doit exister dans le depot resolu");
            assertEquals(realGitDir, repository.getDirectory().toPath().toAbsolutePath().normalize());
        }
    }

    @Test
    @DisplayName("worktree : un chemin relatif est resolu depuis la racine du depot")
    void relativeGitDirIsResolvedAgainstTheRepositoryRoot() throws Exception {
        TestRepository.build(tempDir);

        Path worktree = Files.createDirectories(tempDir.resolve("worktree"));
        Files.write(worktree.resolve(".git"),
                ("gitdir: ../.git" + System.lineSeparator()).getBytes(StandardCharsets.UTF_8));

        Path resolved = GitRepositoryLocator.resolveGitDir(worktree);

        assertEquals(tempDir.resolve(".git").toAbsolutePath().normalize(), resolved.toAbsolutePath().normalize());
    }

    @Test
    @DisplayName("la racine du depot est trouvee meme quand .git est un fichier")
    void repositoryRootIsFoundWhenGitIsAFile() throws Exception {
        TestRepository.build(tempDir);
        Path worktree = Files.createDirectories(tempDir.resolve("worktree"));
        Files.write(worktree.resolve(".git"),
                ("gitdir: " + tempDir.resolve(".git").toAbsolutePath() + System.lineSeparator())
                        .getBytes(StandardCharsets.UTF_8));

        Path root = GitRepositoryLocator.findRepositoryRoot(worktree.resolve("src").toString());

        assertNotNull(root, "la racine du depot doit etre trouvee");
        assertEquals(worktree.toAbsolutePath().normalize(), root.toAbsolutePath().normalize());
    }

    @Test
    @DisplayName("un fichier .git sans directive gitdir ne fait pas echouer la resolution")
    void unknownGitFileFallsBackToTheDotGitPath() throws Exception {
        Path worktree = Files.createDirectories(tempDir.resolve("worktree"));
        Files.write(worktree.resolve(".git"),
                ("ceci n'est pas une directive" + System.lineSeparator()).getBytes(StandardCharsets.UTF_8));

        Path resolved = GitRepositoryLocator.resolveGitDir(worktree);

        assertEquals(worktree.resolve(".git").toAbsolutePath().normalize(), resolved.toAbsolutePath().normalize());
    }
}
