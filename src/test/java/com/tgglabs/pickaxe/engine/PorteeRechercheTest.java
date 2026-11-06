package com.tgglabs.pickaxe.engine;

import org.eclipse.jgit.lib.Repository;
import org.junit.jupiter.api.AfterEach;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.io.TempDir;

import java.nio.file.Path;
import java.util.List;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertTrue;

/**
 * La portee de la recherche : les diffs (coeur gratuit), les messages de
 * commit (fonction Pro P1, equivalente de `git log --grep`), ou les deux.
 *
 * <p>Le depot de test contient 6 commits : le mot « token » n'apparait que
 * dans les MESSAGES (commits 3 et 6), la chaine « s3cret-needle » que dans
 * les DIFFS (commits 2 et 6).</p>
 */
class PorteeRechercheTest {

    @TempDir
    Path tempDir;

    private Repository repository;

    @BeforeEach
    void setUp() throws Exception {
        TestRepository.build(tempDir);
        repository = PickaxeRepository.open(tempDir);
    }

    @AfterEach
    void tearDown() {
        if (repository != null) {
            repository.close();
        }
    }

    @Test
    @DisplayName("la portee par defaut est « les diffs seulement » (le coeur gratuit)")
    void laPorteeParDefautEstLesDiffsSeulement() {
        PickaxeQuery query = PickaxeQuery.builder(PickaxeMode.STRING, TestRepository.NEEDLE).build();
        assertEquals(PorteeRecherche.DIFFS, query.getPortee());
    }

    @Test
    @DisplayName("portee « diffs » : un mot present seulement dans un message est ignore")
    void porteeDiffsIgnoreLesMessages() throws Exception {
        List<PickaxeHit> hits = new PickaxeEngine(repository).search(
                PickaxeQuery.builder(PickaxeMode.STRING, "token").build());
        assertTrue(hits.isEmpty(), "« token » n'est que dans les messages : 0 resultat");
    }

    @Test
    @DisplayName("portee « messages » : les commits dont le MESSAGE contient le mot sont trouves")
    void porteeMessagesTrouveLesCommitsParMessage() throws Exception {
        List<PickaxeHit> hits = new PickaxeEngine(repository).search(
                PickaxeQuery.builder(PickaxeMode.STRING, "token")
                        .portee(PorteeRecherche.MESSAGES)
                        .build());
        assertEquals(2, hits.size());
        assertEquals("fix: remove the token line", hits.get(0).getSubject());
        assertEquals("style: annotate the token line", hits.get(1).getSubject());
    }

    @Test
    @DisplayName("portee « messages » : une chaine presente seulement dans les diffs est ignoree")
    void porteeMessagesIgnoreLesDiffs() throws Exception {
        List<PickaxeHit> hits = new PickaxeEngine(repository).search(
                PickaxeQuery.builder(PickaxeMode.STRING, TestRepository.NEEDLE)
                        .portee(PorteeRecherche.MESSAGES)
                        .build());
        assertTrue(hits.isEmpty(), "« s3cret-needle » n'est que dans les diffs : 0 resultat");
    }

    @Test
    @DisplayName("portee « diffs et messages » : les deux sources sont parcourues")
    void porteeDiffsEtMessagesParcourtLesDeux() throws Exception {
        PickaxeEngine engine = new PickaxeEngine(repository);

        List<PickaxeHit> parMessages = engine.search(
                PickaxeQuery.builder(PickaxeMode.STRING, "token")
                        .portee(PorteeRecherche.DIFFS_ET_MESSAGES)
                        .build());
        assertEquals(2, parMessages.size(), "les 2 commits dont le message contient « token »");

        List<PickaxeHit> parDiffs = engine.search(
                PickaxeQuery.builder(PickaxeMode.STRING, TestRepository.NEEDLE)
                        .portee(PorteeRecherche.DIFFS_ET_MESSAGES)
                        .build());
        assertEquals(2, parDiffs.size(), "les 2 commits dont le diff contient la chaine");
    }

    @Test
    @DisplayName("portee « messages » + mode REGEX : la regex s'applique au message")
    void porteeMessagesAccepteLaRegex() throws Exception {
        List<PickaxeHit> hits = new PickaxeEngine(repository).search(
                PickaxeQuery.builder(PickaxeMode.REGEX, "tok.n")
                        .portee(PorteeRecherche.MESSAGES)
                        .build());
        assertEquals(2, hits.size());
    }

    @Test
    @DisplayName("le filtre de chemin s'applique aussi a la portee « messages »")
    void leFiltreDeCheminSAppliqueALaPorteeMessages() throws Exception {
        List<PickaxeHit> hits = new PickaxeEngine(repository).search(
                PickaxeQuery.builder(PickaxeMode.STRING, "token")
                        .pathFilter("fichier-inexistant.txt")
                        .portee(PorteeRecherche.MESSAGES)
                        .build());
        assertTrue(hits.isEmpty(), "aucun commit ne touche ce fichier : 0 resultat");
    }
}
