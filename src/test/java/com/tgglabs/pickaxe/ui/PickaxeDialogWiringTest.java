package com.tgglabs.pickaxe.ui;

import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Test;

import java.nio.charset.StandardCharsets;
import java.nio.file.Files;
import java.nio.file.Path;
import java.nio.file.Paths;

import static org.junit.jupiter.api.Assertions.assertTrue;

/**
 * Test de CABLAGE de la fonction « double-clic = copier le hash ».
 *
 * <p>Le dialogue Swing ne peut PAS etre instancie hors IDE (il herite de
 * {@code DialogWrapper}, qui exige une application IntelliJ). On verifie donc
 * ici, au niveau de la SOURCE, que la fonction est reellement cablee :</p>
 *
 * <ol>
 *   <li>le double-clic est detecte ({@code getClickCount() == 2}) ;</li>
 *   <li>un bouton « Copy hash » existe et declenche la copie ;</li>
 *   <li>la copie passe bien par {@link HashClipboard} (et non par une copie
 *       « maison ») ;</li>
 *   <li>la destination est le presse-papier de la plateforme
 *       ({@code CopyPasteManager}) — et NON l'API {@code com.intellij.vcs.log}
 *       ni le plugin Git, qui ajouteraient une dependance tierce.</li>
 * </ol>
 *
 * <p>Le comportement du presse-papier lui-meme est verifie par
 * {@link HashClipboardTest} (test reel, hors IDE).</p>
 */
class PickaxeDialogWiringTest {

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
    @DisplayName("le dialogue est cable : double-clic + bouton Copy hash + presse-papier de la plateforme")
    void dialogIsWiredForCopyingTheHash() throws Exception {
        String src = sourceOfDialog();

        assertTrue(src.contains("getClickCount() == 2"),
                "le double-clic doit etre detecte dans la liste des resultats");
        assertTrue(src.contains("Copy hash"),
                "un bouton « Copy hash » doit exister dans le dialogue");
        assertTrue(src.contains("copyHashAt"),
                "la copie doit passer par HashClipboard.copyHashAt");
        assertTrue(src.contains("CopyPasteManager"),
                "la destination doit etre le presse-papier de la plateforme");
    }

    @Test
    @DisplayName("le dialogue n'utilise NI l'API vcs.log NI le plugin Git")
    void dialogUsesNoVcsLogApi() throws Exception {
        String src = sourceOfDialog();

        assertTrue(!src.contains("com.intellij.vcs.log"),
                "l'API com.intellij.vcs.log est interdite (dependance tierce)");
        assertTrue(!src.contains("git4idea"),
                "le plugin Git (git4idea) est interdit (dependance tierce)");
    }
}
