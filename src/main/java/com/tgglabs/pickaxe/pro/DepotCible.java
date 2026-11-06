package com.tgglabs.pickaxe.pro;

import java.nio.file.Path;
import java.nio.file.Paths;

/** Un depot Git dans lequel une recherche multi-depots est lancee (P4). */
public final class DepotCible {

    private final String chemin;
    private final String nom;

    /**
     * @param chemin la racine du depot (celle qui porte le {@code .git})
     * @param nom    le nom affiche dans l'interface
     */
    public DepotCible(String chemin, String nom) {
        this.chemin = chemin == null ? "" : chemin;
        this.nom = nom == null ? this.chemin : nom;
    }

    public DepotCible(Path chemin, String nom) {
        this(chemin == null ? "" : chemin.toString(), nom);
    }

    /** La racine du depot, en texte. */
    public String getChemin() {
        return chemin;
    }

    /** La racine du depot, en chemin. */
    public Path getCheminPath() {
        return Paths.get(chemin);
    }

    /** Le nom affiche. */
    public String getNom() {
        return nom;
    }

    @Override
    public String toString() {
        return nom + " (" + chemin + ")";
    }
}
