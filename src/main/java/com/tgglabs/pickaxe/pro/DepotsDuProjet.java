package com.tgglabs.pickaxe.pro;

import java.io.IOException;
import java.nio.file.Files;
import java.nio.file.Path;
import java.util.ArrayList;
import java.util.Collections;
import java.util.List;

/**
 * Les depots Git d'un projet (fonction Pro P4).
 *
 * <p>Parcours en largeur depuis la racine du projet, jusqu'a
 * {@link #PROFONDEUR_MAX} niveaux : un repertoire qui porte un {@code .git}
 * (repertoire OU fichier — c'est le cas d'un worktree) est un depot ; on
 * ne descend pas dedans. Les repertoires commences par un point
 * ({@code .git}, {@code .idea}, {@code node_modules}…) sont ignores.</p>
 *
 * <p>Ne depend QUE de Java : testable hors IDE.</p>
 */
public final class DepotsDuProjet implements FournisseurDepots {

    /** Profondeur maximale de la recherche de depots. */
    public static final int PROFONDEUR_MAX = 3;

    private final Path racine;

    /**
     * @param racine la racine du projet
     */
    public DepotsDuProjet(Path racine) {
        if (racine == null) {
            throw new IllegalArgumentException("racine must not be null");
        }
        this.racine = racine;
    }

    @Override
    public List<DepotCible> depots() {
        List<DepotCible> trouves = new ArrayList<>();
        if (!Files.isDirectory(racine)) {
            return trouves;
        }
        // Le projet peut LUI-MEME etre le depot (cas le plus courant : on
        // ouvre le dossier du depot dans l'IDE). La racine est alors le
        // premier depot de la liste.
        if (estDepot(racine)) {
            trouves.add(new DepotCible(racine, nomDu(racine)));
            return trouves;
        }
        explorer(racine, 0, trouves);
        return trouves;
    }

    /** Le nom lisible d'un depot : le nom du repertoire, sinon son chemin. */
    private static String nomDu(Path chemin) {
        Path nom = chemin.getFileName();
        return nom == null ? chemin.toString() : nom.toString();
    }

    private void explorer(Path repertoire, int profondeur, List<DepotCible> trouves) {
        if (profondeur > PROFONDEUR_MAX || !Files.isDirectory(repertoire)) {
            return;
        }
        List<Path> enfants = new ArrayList<>();
        try (java.util.stream.Stream<Path> flux = Files.list(repertoire)) {
            flux.filter(Files::isDirectory).forEach(enfants::add);
        } catch (IOException e) {
            // Repertoire illisible : on l'ignore (les autres sont traites).
            return;
        }
        Collections.sort(enfants);
        for (Path enfant : enfants) {
            String nom = enfant.getFileName() == null ? "" : enfant.getFileName().toString();
            if (nom.startsWith(".")) {
                continue;
            }
            if (estDepot(enfant)) {
                trouves.add(new DepotCible(enfant, nom));
                // On ne descend pas dans un depot : ses sous-repertoires
                // (sous-modules, etc.) ne font pas partie de ce projet.
                continue;
            }
            explorer(enfant, profondeur + 1, trouves);
        }
    }

    /** {@code true} si le repertoire porte un {@code .git} (dossier ou fichier). */
    static boolean estDepot(Path repertoire) {
        Path git = repertoire.resolve(".git");
        return Files.isDirectory(git) || Files.isRegularFile(git);
    }
}
