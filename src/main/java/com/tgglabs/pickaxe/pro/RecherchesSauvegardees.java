package com.tgglabs.pickaxe.pro;

import com.tgglabs.pickaxe.engine.PickaxeQuery;

import java.util.ArrayList;
import java.util.Collections;
import java.util.List;

/**
 * Les recherches enregistrees, par depot (fonction Pro P3).
 *
 * <p>Regle : <b>les 10 dernieres par depot</b> sont conservees, la plus
 * recente en premier. Enregistrer une recherche sous un nom deja utilise
 * remplace l'ancienne (le nom est la clef, pas la position).</p>
 *
 * <p>Ne depend QUE de Java : testable hors IDE.</p>
 */
public final class RecherchesSauvegardees {

    /** Nombre maximum de recherches conservees PAR DEPOT. */
    public static final int MAX_PAR_DEPOT = 10;

    private final StockageRecherches stockage;

    public RecherchesSauvegardees(StockageRecherches stockage) {
        if (stockage == null) {
            throw new IllegalArgumentException("stockage must not be null");
        }
        this.stockage = stockage;
    }

    /**
     * Enregistre une recherche pour un depot.
     *
     * @param depot la racine du depot
     * @param nom   le nom donne par l'utilisateur
     * @param query la requete a rejouer
     */
    public void sauvegarder(String depot, String nom, PickaxeQuery query) {
        if (depot == null || depot.isEmpty()) {
            throw new IllegalArgumentException("depot must not be empty");
        }
        if (nom == null || nom.trim().isEmpty()) {
            throw new IllegalArgumentException("name must not be empty");
        }
        List<RechercheSauvee> liste = new ArrayList<>(charger(depot));
        liste.removeIf(r -> r.getNom().equals(nom.trim()));
        liste.add(0, RechercheSauvee.de(nom.trim(), depot, query));
        while (liste.size() > MAX_PAR_DEPOT) {
            liste.remove(liste.size() - 1);
        }
        stockage.enregistrer(depot, liste);
    }

    /**
     * Les recherches enregistrees d'un depot.
     *
     * @param depot la racine du depot
     * @return la liste, la plus recente en premier ; jamais {@code null}
     */
    public List<RechercheSauvee> parDepot(String depot) {
        return Collections.unmodifiableList(charger(depot));
    }

    private List<RechercheSauvee> charger(String depot) {
        if (depot == null || depot.isEmpty()) {
            return Collections.emptyList();
        }
        List<RechercheSauvee> liste = stockage.charger(depot);
        return liste == null ? Collections.emptyList() : liste;
    }
}
