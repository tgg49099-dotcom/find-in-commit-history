package com.tgglabs.pickaxe.pro;

import com.tgglabs.pickaxe.engine.PickaxeMode;
import com.tgglabs.pickaxe.engine.PickaxeQuery;

/**
 * Une recherche enregistree (fonction Pro P3).
 *
 * <p>Immuable : une recherche enregistree est une valeur, pas un etat
 * partage. Elle porte tout ce qu'il faut pour rejouer la recherche : le
 * depot, le nom donne par l'utilisateur, le mode, la chaine, le filtre de
 * chemin et la limite de resultats.</p>
 *
 * <p>Ne depend QUE de Java et du moteur : testable hors IDE.</p>
 */
public final class RechercheSauvee {

    private final String nom;
    private final String depot;
    private final PickaxeMode mode;
    private final String chaine;
    private final String filtreChemin;
    private final boolean binairesInclus;
    private final int maxResultats;

    public RechercheSauvee(String nom,
                           String depot,
                           PickaxeMode mode,
                           String chaine,
                           String filtreChemin,
                           boolean binairesInclus,
                           int maxResultats) {
        this.nom = nom == null ? "" : nom;
        this.depot = depot == null ? "" : depot;
        this.mode = mode == null ? PickaxeMode.STRING : mode;
        this.chaine = chaine == null ? "" : chaine;
        this.filtreChemin = filtreChemin;
        this.binairesInclus = binairesInclus;
        this.maxResultats = maxResultats;
    }

    /** Construit une recherche enregistree a partir d'une requete. */
    public static RechercheSauvee de(String nom, String depot, PickaxeQuery query) {
        if (query == null) {
            throw new IllegalArgumentException("query must not be null");
        }
        return new RechercheSauvee(nom, depot, query.getMode(), query.getNeedle(),
                query.getPathFilter(), query.isIncludeBinary(), query.getMaxResults());
    }

    public String getNom() {
        return nom;
    }

    public String getDepot() {
        return depot;
    }

    public PickaxeMode getMode() {
        return mode;
    }

    public String getChaine() {
        return chaine;
    }

    public String getFiltreChemin() {
        return filtreChemin;
    }

    public boolean isBinairesInclus() {
        return binairesInclus;
    }

    public int getMaxResultats() {
        return maxResultats;
    }

    /** Reconstruit la requete, prete a etre rejouee. */
    public PickaxeQuery requete() {
        return PickaxeQuery.builder(mode, chaine)
                .pathFilter(filtreChemin)
                .includeBinary(binairesInclus)
                .maxResults(maxResultats)
                .build();
    }

    @Override
    public String toString() {
        return "RechercheSauvee{" + nom + " @ " + depot + "}";
    }
}
