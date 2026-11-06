package com.tgglabs.pickaxe.pro;

/**
 * Etat de la licence Pro, tel que vu par le plugin.
 *
 * <p>C'est le SEUL point du code qui decide si une fonction Pro est ouverte.
 * Il interroge un {@link FournisseurLicence} — donc, en production, la
 * licence de la Marketplace JetBrains — et expose {@link #estPro()}.</p>
 *
 * <p>Deux garanties :</p>
 * <ol>
 *   <li><b>Jamais d'exception.</b> Si la source de licence leve une
 *       exception (ou si la classe de la plateforme manque), l'etat vaut
 *       « pas Pro » : le coeur gratuit continue de fonctionner, aucune
 *       fenetre de l'IDE ne plante.</li>
 *   <li><b>Inconnu != pas licencie.</b> Un etat {@code null} (verification
 *       pas encore initialisee par l'IDE) est distingue du refus : voir
 *       {@link #licenceInconnue()}.</li>
 * </ol>
 *
 * <p>Cette classe ne depend QUE de Java : elle est donc testable hors IDE,
 * sans reseau.</p>
 */
public final class LicenceEtat {

    /**
     * Message affiche quand une fonction Pro est demandee sans licence.
     * Le texte est FIXE : c'est lui que les tests verifient.
     */
    public static final String MESSAGE_LICENCE_REQUISE = "fonction Pro — licence requise";

    private final FournisseurLicence fournisseur;

    /**
     * @param fournisseur la source de l'etat de licence (injectee)
     */
    public LicenceEtat(FournisseurLicence fournisseur) {
        if (fournisseur == null) {
            throw new IllegalArgumentException("fournisseur must not be null");
        }
        this.fournisseur = fournisseur;
    }

    /**
     * @return {@code true} si le code produit Pro est licence ; {@code false}
     *         sinon (licence absente, verification impossible, ou erreur).
     */
    public boolean estPro() {
        return Boolean.TRUE.equals(lire());
    }

    /**
     * @return {@code true} si l'etat n'a pas pu etre determine (l'IDE
     *         n'a pas encore initialise la verification de licence).
     */
    public boolean licenceInconnue() {
        return lire() == null;
    }

    /**
     * Lit l'etat sans jamais laisser remonter une exception : une source de
     * licence qui plante ne doit pas fermer l'IDE.
     */
    private Boolean lire() {
        try {
            Boolean etat = fournisseur.licenceProActive();
            return etat;
        } catch (RuntimeException | LinkageError e) {
            // RuntimeException : erreur de la source de licence.
            // LinkageError : classe de la plateforme absente a l'execution
            // (le plugin doit alors se comporter comme « pas Pro »).
            return Boolean.FALSE;
        }
    }

    @Override
    public String toString() {
        return "LicenceEtat{pro=" + estPro() + "}";
    }
}
