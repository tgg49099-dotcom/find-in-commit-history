package com.tgglabs.pickaxe.engine;

/**
 * Portee d'une recherche pickaxe : ou la chaine est cherchee.
 *
 * <ul>
 *   <li>{@link #DIFFS} — le contenu des fichiers modifies (le coeur
 *       gratuit, equivalent de {@code git log -S} / {@code git log -G}).</li>
 *   <li>{@link #DIFFS_ET_MESSAGES} — les diffs ET les messages de commit
 *       (fonction Pro P1).</li>
 *   <li>{@link #MESSAGES} — les messages de commit seulement (fonction Pro
 *       P1, equivalent de {@code git log --grep}).</li>
 * </ul>
 *
 * <p>Le mode par defaut reste {@link #DIFFS} : le coeur gratuit ne change
 * pas de comportement.</p>
 */
public enum PorteeRecherche {

    /** Les diffs seulement : le coeur gratuit ({@code git log -S} / {@code -G}). */
    DIFFS,

    /** Les diffs ET les messages de commit (Pro). */
    DIFFS_ET_MESSAGES,

    /** Les messages de commit seulement (Pro, {@code git log --grep}). */
    MESSAGES
}
