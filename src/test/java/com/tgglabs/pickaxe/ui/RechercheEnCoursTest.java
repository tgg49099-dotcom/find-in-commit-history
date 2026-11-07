package com.tgglabs.pickaxe.ui;

import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Test;

import java.util.ArrayList;
import java.util.List;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertFalse;
import static org.junit.jupiter.api.Assertions.assertTrue;

/**
 * LE CYCLE DE VIE D'UNE RECHERCHE (points 1 et 2 du jury du 06/11/2026).
 *
 * <p>Le dialogue Swing ne peut pas etre instancie hors IDE : les deux
 * regles d'ergonomie qu'il porte sont donc portees par
 * {@link RechercheEnCours}, qui ne depend QUE de Java. Elles sont ainsi
 * verifiees ici par des tests REELS (et non par une lecture de la source).</p>
 *
 * <ol>
 *   <li>le bouton « Search » est desactive pendant la recherche : un second
 *       lancement est refuse (sinon deux recherches concurrentes, dont la
 *       plus lente ecrase l'affichage) ;</li>
 *   <li>fermer le dialogue annule EXPLICITEMENT la recherche en cours :
 *       l'indicateur de la tache est annule, et le moteur s'arrete au commit
 *       suivant.</li>
 * </ol>
 */
class RechercheEnCoursTest {

    @Test
    @DisplayName("une seule recherche a la fois : le second lancement est refuse")
    void uneSeuleRechercheALaFois() {
        RechercheEnCours etat = new RechercheEnCours();

        assertTrue(etat.demarrer(), "la premiere recherche doit demarrer");
        assertTrue(etat.estEnCours(), "la recherche doit etre en cours");
        assertFalse(etat.demarrer(),
                "un second lancement doit etre refuse tant qu'une recherche est en cours");
        assertFalse(etat.demarrer(),
                "et le refus doit etre repete (le bouton « Search » est desactive)");

        etat.terminer();
        assertFalse(etat.estEnCours(), "la recherche est finie");
        assertTrue(etat.demarrer(), "une nouvelle recherche doit pouvoir demarrer apres la fin de la precedente");
        assertFalse(etat.estAnnulee(), "la nouvelle recherche n'est pas annulee");
    }

    @Test
    @DisplayName("fermer le dialogue annule explicitement la recherche en cours")
    void laFermetureDuDialogueAnnuleLaRecherche() {
        RechercheEnCours etat = new RechercheEnCours();
        etat.demarrer();

        final List<String> appels = new ArrayList<>();
        etat.brancherAnnulation(() -> appels.add("annule"));

        assertTrue(etat.annuler(), "l'annulation doit etre signalee");
        assertEquals(1, appels.size(),
                "l'indicateur de la tache doit etre annule : le moteur s'arrete au commit suivant");
        assertTrue(etat.estAnnulee(), "la recherche doit etre marquee comme annulee");
    }

    @Test
    @DisplayName("une annulation demandee avant le branchement de l'indicateur n'est pas perdue")
    void uneAnnulationPrecoceNEstPasPerdue() {
        RechercheEnCours etat = new RechercheEnCours();
        etat.demarrer();

        // Le dialogue est ferme AVANT que la tache n'ait branche son
        // indicateur : l'annulation ne doit pas etre perdue.
        assertTrue(etat.annuler(), "l'annulation doit etre signalee");

        final List<String> appels = new ArrayList<>();
        etat.brancherAnnulation(() -> appels.add("annule"));
        assertEquals(1, appels.size(),
                "l'indicateur branche apres l'annulation doit etre annule immediatement");
    }

    @Test
    @DisplayName("annuler quand aucune recherche n'est en cours ne fait rien")
    void annulerSansRechercheNeFaitRien() {
        RechercheEnCours etat = new RechercheEnCours();
        assertFalse(etat.annuler(), "il n'y a rien a annuler");
        assertFalse(etat.estAnnulee(), "rien ne doit etre marque comme annule");
    }
}
