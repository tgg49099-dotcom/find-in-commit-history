package com.tgglabs.pickaxe.ide;

import com.intellij.openapi.application.Application;
import com.intellij.openapi.application.ApplicationManager;
import com.tgglabs.pickaxe.pro.DepotsDuProjet;
import com.tgglabs.pickaxe.pro.FonctionsPro;
import com.tgglabs.pickaxe.pro.RecherchesSauvegardees;
import com.tgglabs.pickaxe.pro.StockageRecherches;

import java.nio.file.Path;

/**
 * Construction des fonctions Pro utilisees par l'interface.
 *
 * <p>Isolé ici pour que tout le code Pro testable ({@link FonctionsPro}) ne
 * depende jamais de la plateforme : l'IDE est le seul a appeler cette
 * fabrique.</p>
 */
public final class FonctionsProIDE {

    private FonctionsProIDE() {
    }

    /**
     * Les fonctions Pro, avec le stockage des recherches enregistrees de
     * l'IDE (si le service est disponible) et les depots du projet.
     *
     * @param racineProjet la racine du projet (ou du depot courant)
     */
    public static FonctionsPro parDefaut(Path racineProjet) {
        StockageRecherches stockage = null;
        Application app = ApplicationManager.getApplication();
        if (app != null) {
            stockage = app.getService(StockageRecherchesIDE.class);
        }
        if (stockage == null) {
            // Service indisponible (IDE en cours d'initialisation, ou
            // enregistrement absent du plugin.xml) : les recherches sont
            // alors conservees en memoire seulement — l'IDE ne plante pas.
            stockage = new StockageRecherchesIDE();
        }
        return new FonctionsPro(
                LicenceEtatIDE.parDefaut(),
                new RecherchesSauvegardees(stockage),
                new DepotsDuProjet(racineProjet));
    }
}
