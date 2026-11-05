package com.tgglabs.pickaxe.engine;

import java.nio.file.Path;
import java.nio.file.Paths;
import java.util.List;

/**
 * Outil de developpement : construit le depot de test sur disque, pour
 * pouvoir le comparer avec le vrai {@code git log -S / -G}.
 *
 * <p>Usage : {@code BuildTestRepo <repertoire>}</p>
 *
 * <p>Le depot est construit par {@link TestRepository}, c'est-a-dire par le
 * meme code que les tests : la comparaison avec git porte donc sur le meme
 * objet, et non sur deux depots « presque » identiques.</p>
 */
public final class BuildTestRepo {

    private BuildTestRepo() {
    }

    public static void main(String[] args) throws Exception {
        if (args.length < 1) {
            System.err.println("usage: BuildTestRepo <repertoire>");
            System.exit(2);
        }
        Path directory = Paths.get(args[0]);
        List<TestRepository.Commit> commits = TestRepository.build(directory);
        for (TestRepository.Commit commit : commits) {
            System.out.println(commit.getId() + "\t" + commit.getSubject());
        }
    }
}
