package com.tgglabs.pickaxe.ui;

/**
 * L'etat d'une recherche lancee depuis le dialogue.
 *
 * <p>Le dialogue Swing ne peut pas etre instancie hors IDE (il herite de
 * {@code DialogWrapper}, qui exige une application IntelliJ). Les DEUX
 * regles d'ergonomie qui le concernent sont donc portees par cette classe,
 * qui ne depend QUE de Java : elles sont ainsi verifiables par des tests
 * reels, sans IDE (cf. {@code RechercheEnCoursTest}).</p>
 *
 * <ol>
 *   <li><b>Une seule recherche a la fois</b> : le bouton « Search » est
 *       desactive pendant une recherche ; un second lancement est refuse
 *       (sinon deux recherches concurrentes se disputent l'affichage, et la
 *       plus lente ecrase la plus rapide) ;</li>
 *   <li><b>Annulation explicite</b> : la fermeture du dialogue annule la
 *       recherche en cours — l'indicateur de la tache est annule, et le
 *       moteur s'arrete au commit suivant.</li>
 * </ol>
 *
 * <p>Les methodes sont synchronisees : l'etat est modifie par l'EDT (le
 * dialogue) et par le thread de fond (la tache).</p>
 */
public final class RechercheEnCours {

    /** Une recherche est-elle en cours ? */
    private boolean enCours;

    /** La recherche en cours a-t-elle ete annulee ? */
    private boolean annulee;

    /** L'action d'annulation (annuler l'indicateur de la tache). */
    private Runnable annulation;

    /**
     * Demarre une recherche.
     *
     * @return {@code true} si la recherche a demarre, {@code false} si une
     *         recherche est DEJA en cours (le second lancement est refuse)
     */
    public synchronized boolean demarrer() {
        if (enCours) {
            return false;
        }
        enCours = true;
        annulee = false;
        annulation = null;
        return true;
    }

    /**
     * Branche l'action d'annulation (l'indicateur de la tache de fond).
     *
     * <p>Appele au demarrage de la tache, donc apres {@link #demarrer()}.
     * Si l'annulation a deja ete demandee entre-temps (dialogue ferme avant
     * que la tache ne demarre), l'action est appelee immediatement :
     * l'annulation ne peut pas etre perdue.</p>
     */
    public void brancherAnnulation(Runnable action) {
        if (action == null) {
            return;
        }
        boolean annulerMaintenant;
        synchronized (this) {
            annulation = action;
            annulerMaintenant = annulee;
        }
        if (annulerMaintenant) {
            action.run();
        }
    }

    /**
     * Annule explicitement la recherche en cours.
     *
     * <p>Appele quand le dialogue est ferme : la recherche s'arrete au
     * commit suivant au lieu de continuer en arriere-plan.</p>
     *
     * @return {@code true} si une recherche etait en cours et a ete annulee
     */
    public boolean annuler() {
        Runnable action;
        synchronized (this) {
            if (!enCours) {
                return false;
            }
            annulee = true;
            action = annulation;
            annulation = null;
        }
        // L'action est appelée HORS du bloc synchronise : elle annule
        // l'indicateur, qui peut revenir vers ce objet.
        if (action != null) {
            action.run();
        }
        return true;
    }

    /** La recherche est terminee : le bouton « Search » redevient actif. */
    public synchronized void terminer() {
        enCours = false;
        annulation = null;
    }

    /** Une recherche est-elle en cours ? */
    public synchronized boolean estEnCours() {
        return enCours;
    }

    /** La recherche en cours a-t-elle ete annulee ? */
    public synchronized boolean estAnnulee() {
        return annulee;
    }
}
