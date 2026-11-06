package com.tgglabs.pickaxe.pro;

import com.tgglabs.pickaxe.engine.PickaxeHit;

import java.util.Collections;
import java.util.List;

/**
 * Resultat d'une recherche multi-depots, pour UN depot (fonction Pro P4).
 *
 * <p>Un depot illisible n'interrompt pas les autres : il produit un
 * resultat « en erreur », avec le message exact.</p>
 */
public final class ResultatParDepot {

    private final DepotCible depot;
    private final List<PickaxeHit> resultats;
    private final String erreur;

    public ResultatParDepot(DepotCible depot, List<PickaxeHit> resultats, String erreur) {
        this.depot = depot;
        this.resultats = resultats == null
                ? Collections.emptyList()
                : Collections.unmodifiableList(resultats);
        this.erreur = erreur;
    }

    public DepotCible getDepot() {
        return depot;
    }

    /** Les commits trouves dans ce depot. */
    public List<PickaxeHit> getResultats() {
        return resultats;
    }

    /** Le message d'erreur, ou {@code null} si le depot a ete interroge. */
    public String getErreur() {
        return erreur;
    }

    /** {@code true} si ce depot n'a pas pu etre interroge. */
    public boolean aEchoue() {
        return erreur != null;
    }

    @Override
    public String toString() {
        return "ResultatParDepot{" + depot + ", " + resultats.size() + " resultats"
                + (erreur == null ? "" : ", erreur: " + erreur) + "}";
    }
}
