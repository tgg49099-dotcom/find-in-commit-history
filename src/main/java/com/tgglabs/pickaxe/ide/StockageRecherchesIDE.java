package com.tgglabs.pickaxe.ide;

import com.intellij.openapi.components.PersistentStateComponent;
import com.intellij.openapi.components.State;
import com.intellij.openapi.components.Storage;
import com.tgglabs.pickaxe.engine.PickaxeMode;
import com.tgglabs.pickaxe.pro.RechercheSauvee;
import com.tgglabs.pickaxe.pro.StockageRecherches;

import java.util.ArrayList;
import java.util.LinkedHashMap;
import java.util.List;
import java.util.Map;

/**
 * Les recherches enregistrees, stockees dans les reglages de l'IDE
 * (fonction Pro P3).
 *
 * <p>Le fichier {@code pickaxe.xml} est un fichier LOCAL de configuration de
 * l'IDE : ce n'est ni une telemetrie, ni un envoi de donnees. Il ne contient
 * que la chaine cherchee, le mode, le filtre de chemin et le nom du depot.</p>
 *
 * <p>Le service est declare dans le {@code plugin.xml} (une balise
 * {@code <applicationService>}) : la plateforme l'enregistre alors dans ses
 * reglages et le restaure au demarrage de l'IDE.</p>
 */
@State(name = "PickaxeRecherchesSauvegardees",
        storages = @Storage("pickaxe.xml"))
public final class StockageRecherchesIDE
        implements StockageRecherches, PersistentStateComponent<StockageRecherchesIDE.Etat> {

    /** Etat ecrit par la plateforme dans {@code pickaxe.xml}. */
    public static final class Etat {
        /** Les recherches, par depot (cle = racine du depot). */
        public Map<String, List<RechercheSauveeEtat>> parDepot = new LinkedHashMap<>();
    }

    /** Une recherche enregistree, serialisee par la plateforme. */
    public static final class RechercheSauveeEtat {
        public String nom = "";
        public String mode = PickaxeMode.STRING.name();
        public String chaine = "";
        public String filtreChemin = "";
        public boolean binairesInclus = false;
        public int maxResultats = 500;
    }

    private Etat etat = new Etat();

    @Override
    public List<RechercheSauvee> charger(String depot) {
        List<RechercheSauveeEtat> brutes = etat.parDepot.get(depot);
        List<RechercheSauvee> resultats = new ArrayList<>();
        if (brutes == null) {
            return resultats;
        }
        for (RechercheSauveeEtat brute : brutes) {
            if (brute == null) {
                continue;
            }
            PickaxeMode mode;
            try {
                mode = PickaxeMode.valueOf(brute.mode);
            } catch (RuntimeException e) {
                // Mode inconnu (reglages corrompus ou plugin mis a jour) :
                // on retombe sur STRING plutot que de planter.
                mode = PickaxeMode.STRING;
            }
            resultats.add(new RechercheSauvee(brute.nom, depot, mode, brute.chaine,
                    brute.filtreChemin, brute.binairesInclus, brute.maxResultats));
        }
        return resultats;
    }

    @Override
    public void enregistrer(String depot, List<RechercheSauvee> recherches) {
        List<RechercheSauveeEtat> brutes = new ArrayList<>();
        if (recherches != null) {
            for (RechercheSauvee recherche : recherches) {
                if (recherche == null) {
                    continue;
                }
                RechercheSauveeEtat brute = new RechercheSauveeEtat();
                brute.nom = recherche.getNom();
                brute.mode = recherche.getMode().name();
                brute.chaine = recherche.getChaine();
                brute.filtreChemin = recherche.getFiltreChemin();
                brute.binairesInclus = recherche.isBinairesInclus();
                brute.maxResultats = recherche.getMaxResultats();
                brutes.add(brute);
            }
        }
        etat.parDepot.put(depot, brutes);
    }

    @Override
    public Etat getState() {
        return etat;
    }

    @Override
    public void loadState(Etat etat) {
        this.etat = etat == null ? new Etat() : etat;
        if (this.etat.parDepot == null) {
            this.etat.parDepot = new LinkedHashMap<>();
        }
    }
}
