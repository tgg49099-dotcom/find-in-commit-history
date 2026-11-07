package com.tgglabs.pickaxe.engine;

import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Test;

import java.lang.reflect.Method;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertThrows;

/**
 * LE NOM DE LA METHODE DE DATE (point 4 du jury du 06/11/2026).
 *
 * <p>La methode s'appelait {@code getAuthorTimeMillis()} alors que la valeur
 * qu'elle renvoie est la date du COMMITTEUR ({@code commit.getCommitTime()}) :
 * le nom etait trompeur. Elle est renommee en {@code getAuthorTimestampMillis}
 * (le nom demande par la consigne du 06/11/2026) et l'ancien nom doit
 * disparaitre PARTOUT.</p>
 *
 * <p>Le test passe par la REFLEXION : il compile donc tel quel AVANT la
 * correction (et non apres), ce qui permet la contre-epreuve rouge/vert
 * demandee par la consigne : avant, la nouvelle methode n'existe pas (le test
 * echoue) ; apres, elle existe et l'ancienne a disparu.</p>
 */
class NomMethodeDateTest {

    @Test
    @DisplayName("la methode de date a un nom clair et l'ancien nom a disparu")
    void leNomDeLaMethodeDeDateEstRenomme() throws Exception {
        Method methode = PickaxeHit.class.getMethod("getAuthorTimestampMillis");
        assertEquals(long.class, methode.getReturnType(),
                "la methode doit renvoyer l'horodatage en millisecondes");

        assertThrows(NoSuchMethodException.class,
                () -> PickaxeHit.class.getMethod("getAuthorTimeMillis"),
                "l'ancien nom getAuthorTimeMillis doit avoir disparu de l'API");
    }
}
