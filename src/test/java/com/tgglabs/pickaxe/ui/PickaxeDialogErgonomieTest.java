package com.tgglabs.pickaxe.ui;

import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Test;

import java.nio.charset.StandardCharsets;
import java.nio.file.Files;
import java.nio.file.Path;
import java.nio.file.Paths;

import static org.junit.jupiter.api.Assertions.assertFalse;
import static org.junit.jupiter.api.Assertions.assertTrue;

/**
 * LES DEUX CORRECTIONS D'ERGONOMIE DE L'INTERFACE (points 1 et 2 du jury
 * du 06/11/2026).
 *
 * <p>Le dialogue Swing ne peut PAS etre instancie hors IDE (il herite de
 * {@code DialogWrapper}, qui exige une application IntelliJ). On verifie donc
 * ici, au niveau de la SOURCE — comme le fait deja
 * {@link PickaxeDialogWiringTest} pour le double-clic — que les deux
 * corrections sont reellement cablees :</p>
 *
 * <ol>
 *   <li><b>Tache modale ou annulation explicite</b> : la recherche tourne
 *       dans une tache MODALE (fenetre de progression et bouton « Cancel »
 *       visibles au-dessus du dialogue) ET la fermeture du dialogue annule
 *       explicitement la recherche en cours ;</li>
 *   <li><b>Bouton « Search » desactive pendant la recherche</b> : il est
 *       desactive quand la recherche demarre, reactive a la fin dans TOUS les
 *       cas (succes, erreur, annulation), et un second lancement est refuse.</li>
 * </ol>
 */
class PickaxeDialogErgonomieTest {

    private static String sourceOfDialog() throws Exception {
        String dir = System.getProperty("pickaxe.src.dir");
        Path base = (dir == null || dir.isEmpty())
                ? Paths.get("").toAbsolutePath()
                : Paths.get(dir);
        Path file = base.resolve("com/tgglabs/pickaxe/ui/PickaxeDialog.java");
        assertTrue(Files.exists(file), "source du dialogue introuvable : " + file);
        return new String(Files.readAllBytes(file), StandardCharsets.UTF_8);
    }

    @Test
    @DisplayName("la recherche est modale et la fermeture du dialogue l'annule explicitement")
    void laRechercheEstModaleEtSaFermetureLAnnule() throws Exception {
        String src = sourceOfDialog();

        assertTrue(src.contains("Task.Modal"),
                "la recherche doit tourner dans une tache MODALE : la fenetre de progression "
                        + "et son bouton « Cancel » doivent etre visibles au-dessus du dialogue");
        assertFalse(src.contains("Task.Backgroundable"),
                "la tache de fond doit etre remplacee par une tache modale");

        assertTrue(src.contains("protected void dispose()"),
                "le dialogue doit surcharger dispose() : fermer le dialogue doit arreter la recherche");
        assertTrue(src.contains("rechercheEnCours.annuler()"),
                "dispose() doit ANNULER EXPLICITEMENT la recherche en cours");
    }

    @Test
    @DisplayName("le bouton Search est desactive pendant la recherche et reactive a la fin")
    void leBoutonSearchEstDesactivePendantLaRecherche() throws Exception {
        String src = sourceOfDialog();

        assertTrue(src.contains("rechercheEnCours.demarrer()"),
                "un second lancement doit etre refuse tant qu'une recherche est en cours");
        assertTrue(src.contains("getOKAction()"),
                "le bouton « Search » est l'action OK du dialogue : c'est elle qu'il faut desactiver");
        assertTrue(src.contains("setSearchEnabled(false)"),
                "le bouton « Search » doit etre desactive au demarrage de la recherche");
        assertTrue(src.contains("setSearchEnabled(true)"),
                "le bouton « Search » doit etre reactive a la fin de la recherche, dans tous les cas");
    }
}
