package com.tgglabs.pickaxe.pro;

/**
 * Une fonction Pro a ete demandee SANS licence : elle est refusee.
 *
 * <p>C'est une exception <b>controlee</b> (doncobligatoire a traiter) et
 * dediee : l'appelant ne peut pas l'oublier, et le message est un message
 * utilisateur clair — jamais une pile d'exceptions dans l'IDE.</p>
 *
 * <p>Le message est FIXE : {@link #MESSAGE}.</p>
 */
public class FonctionProRefuseeException extends Exception {

    private static final long serialVersionUID = 1L;

    /** Message unique affiche a l'utilisateur. */
    public static final String MESSAGE = "fonction Pro — licence requise";

    private final String fonction;

    /**
     * @param fonction identifiant de la fonction refusee (« P1 »…« P4 »)
     */
    public FonctionProRefuseeException(String fonction) {
        super(MESSAGE);
        this.fonction = fonction == null ? "" : fonction;
    }

    /** L'identifiant de la fonction refusee (« P1 »…« P4 »). */
    public String getFonction() {
        return fonction;
    }
}
