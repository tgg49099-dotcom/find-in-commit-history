package com.tgglabs.pickaxe.engine;

/**
 * Erreur fonctionnelle du moteur pickaxe (depot illisible, objet git
 * corrompu, expression reguliere invalide…).
 *
 * <p>Elle est distinguee des {@link RuntimeException} pour que l'interface
 * puisse la traiter proprement : un message lisible pour l'utilisateur, jamais
 * une pile d'exceptions dans l'IDE.</p>
 */
public class PickaxeException extends Exception {

    private static final long serialVersionUID = 1L;

    public PickaxeException(String message) {
        super(message);
    }

    public PickaxeException(String message, Throwable cause) {
        super(message, cause);
    }
}
