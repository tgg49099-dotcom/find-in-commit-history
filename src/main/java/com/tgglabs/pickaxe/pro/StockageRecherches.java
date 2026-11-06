package com.tgglabs.pickaxe.pro;

import java.util.List;

/**
 * Ou sont stockees les recherches enregistrees (fonction Pro P3).
 *
 * <p>Interface volontairement minimale : l'implémentation de production
 * s'appuie sur les reglages de l'IDE
 * ({@code com.tgglabs.pickaxe.ide.StockageRecherchesIDE}), les tests
 * utilisent une implementation en memoire. Le code Pro ne depend donc
 * jamais directement de la plateforme : il est testable hors IDE.</p>
 */
public interface StockageRecherches {

    /**
     * Les recherches enregistrees d'un depot.
     *
     * @param depot la racine du depot (cle)
     * @return la liste des recherches (vide si aucune) ; jamais {@code null}
     */
    List<RechercheSauvee> charger(String depot);

    /**
     * Ecrit les recherches d'un depot.
     *
     * @param depot      la racine du depot (cle)
     * @param recherches les recherches a conserver
     */
    void enregistrer(String depot, List<RechercheSauvee> recherches);
}
