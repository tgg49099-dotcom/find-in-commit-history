package com.tgglabs.pickaxe.pro;

import java.util.List;

/**
 * D'ou viennent les depots dans lesquels une recherche multi-depots est
 * lancee (fonction Pro P4).
 *
 * <p>Comme pour la licence, l'interface permet de tester le code Pro hors
 * IDE : les tests fournissent leurs propres depots, le produit fournit ceux
 * du projet ouvert.</p>
 */
public interface FournisseurDepots {

    /**
     * Les depots a interroger.
     *
     * @return la liste des depots (vide si aucun) ; jamais {@code null}
     */
    List<DepotCible> depots();
}
