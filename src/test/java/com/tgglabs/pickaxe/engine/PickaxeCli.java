package com.tgglabs.pickaxe.engine;

import org.eclipse.jgit.storage.file.FileRepositoryBuilder;
import org.eclipse.jgit.lib.Repository;

import java.nio.file.Path;
import java.nio.file.Paths;
import java.util.List;

/**
 * Petit utilitaire en ligne de commande (outil de developpement, pas livre
 * dans le plugin) : affiche le resultat du moteur pickaxe pour une requete.
 *
 * <p>Usage : {@code PickaxeCli <depot> <STRING|REGEX> <chaine> [filtre_chemin] [includeBinary]}</p>
 *
 * <p>Il sert a comparer le moteur avec le vrai {@code git log -S / -G}
 * (script {@code scripts/compare_with_git.sh}).</p>
 */
public final class PickaxeCli {

    private PickaxeCli() {
    }

    public static void main(String[] args) throws Exception {
        if (args.length < 3) {
            System.err.println("usage: PickaxeCli <repo> <STRING|REGEX> <needle> [pathFilter] [includeBinary]");
            System.exit(2);
        }
        Path repoPath = Paths.get(args[0]);
        PickaxeMode mode = PickaxeMode.valueOf(args[1]);
        String needle = args[2];
        String pathFilter = args.length > 3 && !args[3].isEmpty() ? args[3] : null;
        boolean includeBinary = args.length > 4 && "true".equalsIgnoreCase(args[4]);

        try (Repository repository = new FileRepositoryBuilder()
                .setGitDir(repoPath.resolve(".git").toFile())
                .setWorkTree(repoPath.toFile())
                .readEnvironment()
                .findGitDir()
                .build()) {
            PickaxeEngine engine = new PickaxeEngine(repository);
            PickaxeQuery query = PickaxeQuery.builder(mode, needle)
                    .pathFilter(pathFilter)
                    .includeBinary(includeBinary)
                    .build();
            List<PickaxeHit> hits = engine.search(query);
            for (PickaxeHit hit : hits) {
                System.out.println(hit.getShortId() + "\t" + hit.getSubject()
                        + "\t" + String.join(",", hit.getPaths()));
            }
            System.out.println("# " + hits.size() + " commit(s)");
        }
    }
}
