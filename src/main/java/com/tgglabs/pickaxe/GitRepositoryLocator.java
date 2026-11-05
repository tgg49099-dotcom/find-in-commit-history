package com.tgglabs.pickaxe;

import java.io.IOException;
import java.nio.charset.StandardCharsets;
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

    /** Nom du repertoire (ou du fichier) qui marque la racine d'un depot. */
    public static final String DOT_GIT = ".git";

    /** Prefixe de la ligne qui designe le repertoire Git dans un fichier .git. */
    private static final String GITDIR_PREFIX = "gitdir:";

    /**
     * Nom du fichier qui, dans le repertoire Git d'un WORKTREE, designe le
     * depot COMMUN (celui qui porte les references).
     */
    public static final String COMMONDIR = "commondir";

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
            Path dotGit = current.resolve(DOT_GIT);
            if (Files.isDirectory(dotGit) || Files.isRegularFile(dotGit)) {
                return current;
            }
            current = current.getParent();
        }
        return null;
    }

    /**
     * Renvoie le repertoire Git a ouvrir pour une racine de depot donnee.
     *
     * <p>Cas normal : {@code <racine>/.git} est un REPERTOIRE, et c'est lui
     * qu'il faut donner a JGit.</p>
     *
     * <p>Cas d'un WORKTREE (ou d'un sous-module) : {@code <racine>/.git} est un
     * FICHIER qui contient une ligne {@code gitdir: <chemin>}. Donner ce
     * fichier a JGit fait echouer l'ouverture (« Unable to open the Git
     * repository ») : il faut donc lire la ligne et utiliser le chemin qu'elle
     * designe. Un chemin relatif est resolu depuis la racine du depot.</p>
     *
     * <p>Cas d'un WORKTREE (suite) : le repertoire designe est celui du
     * worktree ({@code <depot-commun>/.git/worktrees/<nom>}), et il contient
     * un fichier {@code commondir} qui designe le depot COMMUN. C'est le
     * depot commun qu'il faut ouvrir : les references y vivent, et JGit n'en
     * trouve aucune dans le repertoire du worktree (la recherche rendrait
     * alors zero resultat, sans erreur). Le repertoire de travail du
     * worktree se declare separement.</p>
     *
     * @param repositoryRoot la racine du depot
     * @return le repertoire Git a ouvrir
     * @throws IOException si le fichier {@code .git} est illisible
     */
    public static Path resolveGitDir(Path repositoryRoot) throws IOException {
        Path dotGit = repositoryRoot.resolve(DOT_GIT);
        if (!Files.isRegularFile(dotGit)) {
            // Depot normal : .git est un repertoire (ou il n'existe pas, et
            // JGit produira alors son propre message d'erreur).
            return dotGit;
        }
        String gitDir = readGitDir(dotGit);
        if (gitDir == null) {
            // Fichier .git illisible ou d'un format inconnu : on rend la main
            // a JGit avec le chemin attendu, il dira pourquoi il refuse.
            return dotGit;
        }
        Path resolved = Paths.get(gitDir);
        if (!resolved.isAbsolute()) {
            resolved = repositoryRoot.resolve(resolved);
        }
        return resolveCommonDir(resolved.normalize());
    }

    /**
     * Renvoie le depot COMMUN si le repertoire Git designe est celui d'un
     * worktree, sinon le meme repertoire.
     *
     * <p>Le fichier {@code commondir} n'existe que dans le repertoire Git
     * d'un worktree. Un depot normal et un sous-module n'en ont pas : ils
     * sont donc renvoyes tels quels (mesure : un sous-module n'a pas de
     * fichier {@code commondir}).</p>
     *
     * @param gitDir le repertoire Git a ouvrir
     * @return le depot commun, ou {@code gitDir} s'il n'y a pas de
     *         {@code commondir}
     * @throws IOException si le fichier {@code commondir} est illisible
     */
    public static Path resolveCommonDir(Path gitDir) throws IOException {
        Path commonDirFile = gitDir.resolve(COMMONDIR);
        if (!Files.isRegularFile(commonDirFile)) {
            return gitDir;
        }
        for (String line : Files.readAllLines(commonDirFile, StandardCharsets.UTF_8)) {
            String value = line.trim();
            if (value.isEmpty()) {
                continue;
            }
            Path common = Paths.get(value);
            if (!common.isAbsolute()) {
                // Le contenu de « commondir » est relatif au repertoire Git
                // du worktree (« ../.. » en general).
                common = gitDir.resolve(common);
            }
            return common.normalize();
        }
        return gitDir;
    }

    /**
     * Lit la ligne {@code gitdir: <chemin>} d'un fichier {@code .git}.
     *
     * @param dotGitFile le fichier {@code .git}
     * @return le chemin qu'il designe, ou {@code null} si la ligne est absente
     *         ou mal formee
     * @throws IOException si le fichier est illisible
     */
    private static String readGitDir(Path dotGitFile) throws IOException {
        for (String line : Files.readAllLines(dotGitFile, StandardCharsets.UTF_8)) {
            String trimmed = line.trim();
            if (trimmed.isEmpty()) {
                continue;
            }
            if (trimmed.regionMatches(true, 0, GITDIR_PREFIX, 0, GITDIR_PREFIX.length())) {
                String value = trimmed.substring(GITDIR_PREFIX.length()).trim();
                return value.isEmpty() ? null : value;
            }
            // Premiere ligne non vide qui n'est pas une directive « gitdir: » :
            // format inconnu, on ne devine pas.
            return null;
        }
        return null;
    }
}
