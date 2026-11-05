package com.tgglabs.pickaxe.engine;

/**
 * Mode de recherche du moteur pickaxe.
 *
 * <ul>
 *   <li>{@link #STRING} — equivalent de {@code git log -S&lt;chaine&gt;} : un commit
 *       ressort si le NOMBRE d'occurrences de la chaine change entre le commit
 *       parent et le commit (ajout, suppression, ou modification du nombre).
 *       Une chaine reecrite a l'identique ne change pas le nombre
 *       d'occurrences : elle ne ressort donc PAS.</li>
 *   <li>{@link #REGEX} — equivalent de {@code git log -G&lt;expression&gt;} : un commit
 *       ressort si une ligne AJOUTEE ou SUPPRIMEE par le commit matche
 *       l'expression.</li>
 * </ul>
 */
public enum PickaxeMode {

    /** Mode {@code -S} : comptage des occurrences avant / apres. */
    STRING,

    /** Mode {@code -G} : expression reguliere appliquee au diff. */
    REGEX
}
