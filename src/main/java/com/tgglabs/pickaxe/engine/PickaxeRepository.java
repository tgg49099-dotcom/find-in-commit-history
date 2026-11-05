package com.tgglabs.pickaxe.engine;

import com.tgglabs.pickaxe.GitRepositoryLocator;
import org.eclipse.jgit.lib.Repository;
import org.eclipse.jgit.storage.file.FileRepositoryBuilder;

import java.io.IOException;
import java.nio.file.Path;

/**
 * Ouverture du depot Git pour le moteur pickaxe.
 *
 * <p>La construction du depot est ici, et pas dans le dialogue de l'IDE :
 * elle ne depend QUE de JGit, donc elle est testable hors IDE, et le test
 * de regression prouve exactement le chemin suivi par le produit (le
 * dialogue appelle {@link #open(Path)}).</p>
 */
public final class PickaxeRepository {

    private PickaxeRepository() {
    }

    /**
     * Prepare l'ouverture d'un depot.
     *
     * <p>Deux reglages sont indispensables pour qu'un WORKTREE
     * ({@code git worktree add}) fonctionne :</p>
     * <ul>
     *   <li>{@code setGitDir(...)} : le depot COMMUN, designe par le fichier
     *       {@code commondir} du repertoire Git du worktree. C'est la que
     *       vivent HEAD et les references ; JGit n'en trouve aucune dans le
     *       repertoire du worktree ;</li>
     *   <li>{@code setWorkTree(...)} : le repertoire de travail du worktree,
     *       qui n'est PAS le repertoire de travail du depot commun.</li>
     * </ul>
     * <p>Sans ces deux reglages, la recherche dans un worktree rend ZERO
     * resultat, sans lever d'erreur.</p>
     *
     * @param repositoryRoot la racine du depot (celle qui porte le {@code .git})
     * @return le constructeur JGit pret a {@code build()}
     * @throws IOException si le repertoire Git est illisible
     */
    public static FileRepositoryBuilder builderFor(Path repositoryRoot) throws IOException {
        return new FileRepositoryBuilder()
                .setGitDir(GitRepositoryLocator.resolveGitDir(repositoryRoot).toFile())
                .setWorkTree(repositoryRoot.toFile())
                .readEnvironment()
                .findGitDir();
    }

    /**
     * Ouvre le depot situe sous {@code repositoryRoot}.
     *
     * @param repositoryRoot la racine du depot
     * @return le depot ouvert (a fermer par l'appelant)
     * @throws IOException si le depot ne peut pas etre ouvert
     */
    public static Repository open(Path repositoryRoot) throws IOException {
        return builderFor(repositoryRoot).build();
    }
}
