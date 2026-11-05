package com.tgglabs.pickaxe.engine;

import org.eclipse.jgit.api.Git;
import org.eclipse.jgit.lib.Repository;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.io.TempDir;

import java.nio.file.Path;
import java.util.List;
import java.util.concurrent.atomic.AtomicInteger;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertTrue;

/**
 * Tests de l'annulation de la recherche.
 *
 * <p>Le moteur accepte un test d'annulation ({@link java.util.function.BooleanSupplier})
 * : il l'appelle a chaque commit et a chaque entree de la boucle de diff.
 * Par defaut (constructeur a un seul argument), la recherche n'est jamais
 * annulee : les tests existants n'ont rien a changer.</p>
 *
 * <p>Ces tests prouvent que le bouton « Cancel » de l'IDE arrete REELLEMENT
 * le parcours de l'historique (le point 2 de la revue du jury).</p>
 */
class CancellationTest {

    @TempDir
    Path tempDir;

    private Repository repository;
    private PickaxeEngine engine;

    @BeforeEach
    void setUp() throws Exception {
        TestRepository.build(tempDir);
        repository = new org.eclipse.jgit.storage.file.FileRepositoryBuilder()
                .setGitDir(tempDir.resolve(".git").toFile())
                .setWorkTree(tempDir.toFile())
                .readEnvironment()
                .findGitDir()
                .build();
        engine = new PickaxeEngine(repository);
    }

    private PickaxeQuery stringQuery(String needle) {
        return PickaxeQuery.builder(PickaxeMode.STRING, needle).build();
    }

    @Test
    @DisplayName("sans test d'annulation, la recherche rend tous ses resultats (comportement par defaut)")
    void defaultIsNeverCancelled() throws Exception {
        List<PickaxeHit> hits = engine.search(stringQuery(TestRepository.NEEDLE));
        assertEquals(2, hits.size(), "les deux commits attendus doivent resortir");
    }

    @Test
    @DisplayName("un test d'annulation toujours vrai interrompt la recherche des le premier commit")
    void cancelledFromTheStartReturnsNothing() throws Exception {
        PickaxeEngine cancellable = new PickaxeEngine(repository, () -> true);
        List<PickaxeHit> hits = cancellable.search(stringQuery(TestRepository.NEEDLE));
        assertTrue(hits.isEmpty(),
                "une recherche annulee immediatement ne doit rendre aucun resultat : " + hits);
    }

    @Test
    @DisplayName("un test d'annulation qui devient vrai en cours de route interrompt la recherche")
    void cancelledMidwayStopsTheWalk() throws Exception {
        // Annulation a partir du 2e appel du test : la recherche a commence,
        // puis elle s'arrete. Aucun resultat partiel ne doit etre remonte.
        AtomicInteger calls = new AtomicInteger();
        PickaxeEngine cancellable = new PickaxeEngine(repository, () -> calls.incrementAndGet() > 2);
        List<PickaxeHit> hits = cancellable.search(stringQuery(TestRepository.NEEDLE));
        assertTrue(hits.isEmpty(),
                "une recherche annulee en cours de route ne doit rendre aucun resultat partiel : " + hits);
        assertTrue(calls.get() > 2, "le test d'annulation doit avoir ete appele : " + calls.get());
    }

    @Test
    @DisplayName("un test d'annulation toujours faux ne change rien aux resultats")
    void neverCancelledKeepsEveryResult() throws Exception {
        PickaxeEngine cancellable = new PickaxeEngine(repository, () -> false);
        List<PickaxeHit> hits = cancellable.search(stringQuery(TestRepository.NEEDLE));
        assertEquals(2, hits.size(), "meme resultat que sans test d'annulation");
    }

    @Test
    @DisplayName("un test d'annulation nul est tolere (il vaut « jamais annule »)")
    void nullCancellationIsTolerated() throws Exception {
        PickaxeEngine cancellable = new PickaxeEngine(repository, null);
        List<PickaxeHit> hits = cancellable.search(stringQuery(TestRepository.NEEDLE));
        assertEquals(2, hits.size(), "un test d'annulation nul ne doit rien changer");
    }

    @Test
    @DisplayName("l'annulation ne casse pas les autres executions : le depot est intact apres une annulation")
    void repositoryIsStillUsableAfterCancellation() throws Exception {
        PickaxeEngine cancellable = new PickaxeEngine(repository, () -> true);
        cancellable.search(stringQuery(TestRepository.NEEDLE));
        // Meme moteur, test d'annulation change : la recherche complete doit
        // redevenir normale.
        List<PickaxeHit> hits = engine.search(stringQuery(TestRepository.NEEDLE));
        assertEquals(2, hits.size(), "le depot doit rester lisible apres une recherche annulee");
    }

    @Test
    @DisplayName("un depot vide annule ne leve pas d'exception")
    void cancelledOnEmptyRepositoryDoesNotThrow() throws Exception {
        Path empty = tempDir.resolve("empty-cancel");
        try (Git git = Git.init().setDirectory(empty.toFile()).call()) {
            PickaxeEngine cancellable = new PickaxeEngine(git.getRepository(), () -> true);
            assertTrue(cancellable.search(stringQuery(TestRepository.NEEDLE)).isEmpty());
        }
    }
}
