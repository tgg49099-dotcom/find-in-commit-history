package com.tgglabs.pickaxe;

import java.nio.file.Files;
import java.nio.file.Path;
import java.nio.file.Paths;

/**
 * Trouve la racine d'un depot Git a partir d'un chemin de projet.
 *
 * <p>On remonte l'arborescence en cherchant un {@code .git} (dossier pour un
 * depot normal, fichier pour un sous-module ou un *worktree*). Le moteur
 * pickaxe lit le depot directement avec JGit : il ne depend donc pas du plugin
 * Git de l'IDE, qui peut etre desactive sans rendre le plugin inutilisable.</p>
 */
public final class GitRepositoryLocator {

    private GitRepositoryLocator() {
    }

    /**
     * @param basePath un chemin du projet
     * @return la racine du depot, ou {@code null} si le projet n'est pas dans
     *         un depot Git
     */
    public static Path findRepositoryRoot(String basePath) {
        if (basePath == null || basePath.isEmpty()) {
            return null;
        }
        Path current = Paths.get(basePath).toAbsolutePath().normalize();
        while (current != null) {
            Path dotGit = current.resolve(".git");
            if (Files.isDirectory(dotGit) || Files.isRegularFile(dotGit)) {
                return current;
            }
            current = current.getParent();
        }
        return null;
    }
}
