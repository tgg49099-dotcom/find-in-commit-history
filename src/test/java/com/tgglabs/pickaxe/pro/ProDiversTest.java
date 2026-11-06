package com.tgglabs.pickaxe.pro;

import com.tgglabs.pickaxe.engine.PickaxeMode;
import com.tgglabs.pickaxe.engine.PickaxeQuery;
import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.io.TempDir;

import java.io.IOException;
import java.nio.file.Files;
import java.nio.file.Path;
import java.util.ArrayList;
import java.util.HashMap;
import java.util.List;
import java.util.Map;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertFalse;
import static org.junit.jupiter.api.Assertions.assertTrue;

/**
 * Regles des recherches enregistrees (P3) et decouverte des depots (P4).
 *
 * <p>Tout se joue hors IDE : un stockage en memoire, des repertoires
 * temporaires.</p>
 */
class ProDiversTest {

    @TempDir
    Path tempDir;

    // =====================================================================
    // P3 — les recherches enregistrees
    // =====================================================================

    @Test
    @DisplayName("P3 : les 10 dernieres recherches par depot sont conservees")
    void les10DernieresRecherchesSontConservees() {
        RecherchesSauvegardees recherches = new RecherchesSauvegardees(new StockageMemoire());
        for (int i = 1; i <= 12; i++) {
            recherches.sauvegarder("/depot", "recherche-" + i, requete("chaine-" + i));
        }
        List<RechercheSauvee> liste = recherches.parDepot("/depot");
        assertEquals(RecherchesSauvegardees.MAX_PAR_DEPOT, liste.size());
        // La plus recente en premier : « recherche-12 », puis « recherche-11 ».
        assertEquals("recherche-12", liste.get(0).getNom());
        assertEquals("recherche-11", liste.get(1).getNom());
        // La plus ancienne (recherche-1, recherche-2) est tombee.
        assertFalse(liste.stream().anyMatch(r -> r.getNom().equals("recherche-1")));
    }

    @Test
    @DisplayName("P3 : enregistrer sous un nom deja utilise REMPLACE l'ancienne recherche")
    void unNomDejaUtiliseRemplaceLAncienneRecherche() {
        RecherchesSauvegardees recherches = new RecherchesSauvegardees(new StockageMemoire());
        recherches.sauvegarder("/depot", "audit", requete("ancienne"));
        recherches.sauvegarder("/depot", "audit", requete("nouvelle"));
        List<RechercheSauvee> liste = recherches.parDepot("/depot");
        assertEquals(1, liste.size(), "le nom est la clef : pas de doublon");
        assertEquals("nouvelle", liste.get(0).getChaine());
    }

    @Test
    @DisplayName("P3 : les recherches sont separees par depot")
    void lesRecherchesSontSepareesParDepot() {
        RecherchesSauvegardees recherches = new RecherchesSauvegardees(new StockageMemoire());
        recherches.sauvegarder("/depot-a", "audit", requete("a"));
        recherches.sauvegarder("/depot-b", "audit", requete("b"));
        assertEquals(1, recherches.parDepot("/depot-a").size());
        assertEquals(1, recherches.parDepot("/depot-b").size());
        assertEquals("a", recherches.parDepot("/depot-a").get(0).getChaine());
        assertEquals("b", recherches.parDepot("/depot-b").get(0).getChaine());
        assertTrue(recherches.parDepot("/depot-inconnu").isEmpty());
    }

    @Test
    @DisplayName("P3 : la recherche enregistree se rejoue a l'identique")
    void laRechercheEnregistreeSeRejoueALIdentique() {
        RecherchesSauvegardees recherches = new RecherchesSauvegardees(new StockageMemoire());
        recherches.sauvegarder("/depot", "audit", requete("chaine"));
        RechercheSauvee sauvee = recherches.parDepot("/depot").get(0);
        PickaxeQuery rejouee = sauvee.requete();
        assertEquals("chaine", rejouee.getNeedle());
        assertEquals(PickaxeMode.STRING, rejouee.getMode());
        assertEquals("/depot", sauvee.getDepot());
    }

    // =====================================================================
    // P4 — la decouverte des depots du projet
    // =====================================================================

    @Test
    @DisplayName("P4 : les depots du projet sont trouves, jusqu'a 3 niveaux")
    void lesDepotsDuProjetSontTrouves() throws IOException {
        // depot-a : .git est un REPERTOIRE (depot normal)
        Path depotA = Files.createDirectories(tempDir.resolve("depot-a"));
        Files.createDirectories(depotA.resolve(".git"));
        // depot-b : .git est un FICHIER (sous-module ou worktree)
        Path depotB = Files.createDirectories(tempDir.resolve("depot-b"));
        Files.write(depotB.resolve(".git"),
                "gitdir: ../depot-a/.git/worktrees/b\n".getBytes(java.nio.charset.StandardCharsets.UTF_8));
        // depot-c : deux niveaux plus bas
        Path depotC = Files.createDirectories(tempDir.resolve("niveau1/niveau2/depot-c"));
        Files.createDirectories(depotC.resolve(".git"));

        List<DepotCible> trouves = new DepotsDuProjet(tempDir).depots();
        List<String> noms = new ArrayList<>();
        for (DepotCible cible : trouves) {
            noms.add(cible.getNom());
        }
        assertTrue(noms.contains("depot-a"), noms.toString());
        assertTrue(noms.contains("depot-b"), noms.toString());
        assertTrue(noms.contains("depot-c"), noms.toString());
        assertEquals(3, trouves.size());
    }

    @Test
    @DisplayName("P4 : un depot trop profond n'est pas cherche")
    void unDepotTropProfondNEstPasCherche() throws IOException {
        Path depot = Files.createDirectories(tempDir.resolve("a/b/c/d/depot"));
        Files.createDirectories(depot.resolve(".git"));
        assertTrue(new DepotsDuProjet(tempDir).depots().isEmpty(),
                "au-dela de 3 niveaux, le depot n'est pas cherche");
    }

    @Test
    @DisplayName("P4 : les repertoires caches (.git, .idea) sont ignores")
    void lesRepertoiresCachesSontIgnores() throws IOException {
        Path cache = Files.createDirectories(tempDir.resolve(".cache/depot"));
        Files.createDirectories(cache.resolve(".git"));
        assertTrue(new DepotsDuProjet(tempDir).depots().isEmpty());
    }

    @Test
    @DisplayName("P4 : le projet qui EST le depot est lui-meme un depot de la liste")
    void leProjetQuiEstLeDepotEstUnDepotDeLaListe() throws IOException {
        Files.createDirectories(tempDir.resolve(".git"));
        List<DepotCible> trouves = new DepotsDuProjet(tempDir).depots();
        assertEquals(1, trouves.size());
        assertEquals(tempDir.toAbsolutePath().normalize(),
                trouves.get(0).getCheminPath().toAbsolutePath().normalize());
    }

    @Test
    @DisplayName("P4 : un dossier qui n'est pas un depot ne rend aucun depot")
    void unDossierQuiNEstPasUnDepotNeRendAucunDepot() {
        assertTrue(new DepotsDuProjet(tempDir).depots().isEmpty());
    }

    // =====================================================================
    // Outils
    // =====================================================================

    private PickaxeQuery requete(String chaine) {
        return PickaxeQuery.builder(PickaxeMode.STRING, chaine).build();
    }

    /** Stockage en memoire : aucun IDE, aucun disque. */
    private static final class StockageMemoire implements StockageRecherches {
        private final Map<String, List<RechercheSauvee>> parDepot = new HashMap<>();

        @Override
        public List<RechercheSauvee> charger(String depot) {
            List<RechercheSauvee> liste = parDepot.get(depot);
            return liste == null ? new ArrayList<>() : new ArrayList<>(liste);
        }

        @Override
        public void enregistrer(String depot, List<RechercheSauvee> recherches) {
            parDepot.put(depot, new ArrayList<>(recherches));
        }
    }
}
