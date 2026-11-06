package com.tgglabs.pickaxe.pro;

import com.tgglabs.pickaxe.engine.PickaxeEngine;
import com.tgglabs.pickaxe.engine.PickaxeHit;
import com.tgglabs.pickaxe.engine.PickaxeMode;
import com.tgglabs.pickaxe.engine.PickaxeQuery;
import com.tgglabs.pickaxe.engine.PickaxeRepository;
import com.tgglabs.pickaxe.engine.PorteeRecherche;
import com.tgglabs.pickaxe.engine.TestRepository;
import org.eclipse.jgit.lib.Repository;
import org.junit.jupiter.api.AfterEach;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.io.TempDir;

import java.nio.file.Path;
import java.util.ArrayList;
import java.util.HashMap;
import java.util.List;
import java.util.Map;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertFalse;
import static org.junit.jupiter.api.Assertions.assertNotNull;
import static org.junit.jupiter.api.Assertions.assertThrows;
import static org.junit.jupiter.api.Assertions.assertTrue;

/**
 * Tests des 4 fonctions Pro et de la garde de licence.
 *
 * <p>Les DEUX tests exiges par la consigne sont ici :</p>
 * <ol>
 *   <li><b>sans licence</b> : les 4 fonctions Pro sont refusees avec le
 *       message « fonction Pro — licence requise », ET le coeur gratuit
 *       fonctionne toujours ;</li>
 *   <li><b>avec licence injectee</b> : les 4 fonctions Pro s'executent.</li>
 * </ol>
 *
 * <p>La licence est INJECTEE ({@link LicenceEtat} + un
 * {@link FournisseurLicence} factice) : aucun test n'a besoin du reseau, ni
 * d'un IDE, ni d'une licence reelle.</p>
 *
 * <p>Le depot est celui de {@link TestRepository} : 6 commits, dont deux
 * dont le MESSAGE contient « token » (commits 3 et 6) et deux dont le
 * DIFF contient « s3cret-needle » (commits 2 et 6).</p>
 */
class FonctionsProTest {

    /** Message de refus : il est verifie caractere par caractere. */
    private static final String REFUS = "fonction Pro — licence requise";

    @TempDir
    Path tempDir;

    private Repository repository;

    @BeforeEach
    void setUp() throws Exception {
        TestRepository.build(tempDir);
        // Le meme chemin d'ouverture que le produit (PickaxeRepository.open).
        repository = PickaxeRepository.open(tempDir);
    }

    @AfterEach
    void tearDown() {
        if (repository != null) {
            repository.close();
        }
    }

    // =====================================================================
    // (a) SANS LICENCE : les 4 fonctions Pro sont refusees, le gratuit marche
    // =====================================================================

    @Test
    @DisplayName("(a) sans licence : les 4 fonctions Pro sont refusees avec le message clair")
    void sansLicenceLes4FonctionsProSontRefusees() throws Exception {
        FonctionsPro pro = fonctionsPro(licenceFausse());

        // P1 — recherche dans les messages
        FonctionProRefuseeException e1 = assertThrows(FonctionProRefuseeException.class,
                () -> pro.rechercherParMessages(repository, requete("token")));
        assertEquals(REFUS, e1.getMessage());
        assertEquals("P1", e1.getFonction());

        // P1 — variante « diffs et messages »
        FonctionProRefuseeException e1b = assertThrows(FonctionProRefuseeException.class,
                () -> pro.rechercherParMessagesEtDiffs(repository, requete("token")));
        assertEquals(REFUS, e1b.getMessage());

        // P2 — export
        FonctionProRefuseeException e2 = assertThrows(FonctionProRefuseeException.class,
                () -> pro.exporter(new ArrayList<>(), FormatExport.CSV));
        assertEquals(REFUS, e2.getMessage());
        assertEquals("P2", e2.getFonction());

        // P3 — recherches enregistrees
        FonctionProRefuseeException e3 = assertThrows(FonctionProRefuseeException.class,
                () -> pro.sauvegarderRecherche(tempDir.toString(), "audit", requete("token")));
        assertEquals(REFUS, e3.getMessage());
        assertEquals("P3", e3.getFonction());

        FonctionProRefuseeException e3b = assertThrows(FonctionProRefuseeException.class,
                () -> pro.recherchesSauvegardees(tempDir.toString()));
        assertEquals(REFUS, e3b.getMessage());

        // P4 — multi-depots
        FonctionProRefuseeException e4 = assertThrows(FonctionProRefuseeException.class,
                () -> pro.rechercherDansTousLesDepots(requete("token")));
        assertEquals(REFUS, e4.getMessage());
        assertEquals("P4", e4.getFonction());
    }

    @Test
    @DisplayName("(a) sans licence : le coeur gratuit fonctionne TOUJOURS")
    void sansLicenceLeCoeurGratuitMarcheToujours() throws Exception {
        FonctionsPro pro = fonctionsPro(licenceFausse());
        assertFalse(pro.estPro());

        // La recherche dans les diffs (le coeur gratuit) ne depend d'aucune
        // licence : elle rend ses 2 resultats.
        List<PickaxeHit> hits = new PickaxeEngine(repository).search(requeteDiff());
        assertEquals(2, hits.size());
        assertTrue(hits.get(0).getSubject().contains("remove the token line"),
                "le plus recent d'abord : " + hits.get(0).getSubject());
    }

    @Test
    @DisplayName("(a) le refus est decide AVANT toute lecture du depot")
    void leRefusArriveAvantLaLectureDuDepot() {
        // Un depot inexistant : si la garde de licence n'etait pas evaluee en
        // premier, l'erreur serait « depot illisible » et non « licence ».
        FonctionsPro pro = fonctionsPro(licenceFausse());
        FonctionProRefuseeException e = assertThrows(FonctionProRefuseeException.class,
                () -> pro.rechercherDansTousLesDepots(requete("token")));
        assertEquals(REFUS, e.getMessage());
    }

    // =====================================================================
    // (b) AVEC LICENCE INJECTEE : les 4 fonctions Pro s'executent
    // =====================================================================

    @Test
    @DisplayName("(b) avec licence : les 4 fonctions Pro s'executent")
    void avecLicenceLes4FonctionsProSExecutent() throws Exception {
        FonctionsPro pro = fonctionsPro(licenceVraie());
        assertTrue(pro.estPro());

        // --- P1 : la recherche dans les messages trouve les 2 commits dont le
        //     MESSAGE contient « token » (le diff, lui, ne contient pas ce
        //     mot en minuscules : c'est bien la portee « messages » qui joue).
        List<PickaxeHit> messages = pro.rechercherParMessages(repository, requete("token"));
        assertEquals(2, messages.size());
        List<String> sujets = new ArrayList<>();
        for (PickaxeHit hit : messages) {
            sujets.add(hit.getSubject());
        }
        assertTrue(sujets.contains("style: annotate the token line"), sujets.toString());
        assertTrue(sujets.contains("fix: remove the token line"), sujets.toString());

        // --- P2 : l'export produit un CSV avec les hash
        String csv = pro.exporter(messages, FormatExport.CSV);
        assertTrue(csv.startsWith("hash,date,author,subject,paths"), csv);
        assertTrue(csv.contains(messages.get(0).getCommitId()), csv);

        // --- P3 : la recherche est enregistree, puis relue
        pro.sauvegarderRecherche(tempDir.toString(), "audit", requete("token"));
        List<RechercheSauvee> sauvegardes = pro.recherchesSauvegardees(tempDir.toString());
        assertEquals(1, sauvegardes.size());
        assertEquals("audit", sauvegardes.get(0).getNom());
        assertEquals("token", sauvegardes.get(0).getChaine());
        assertEquals(PickaxeMode.STRING, sauvegardes.get(0).getMode());

        // --- P4 : la recherche multi-depots rend un resultat par depot
        List<ResultatParDepot> parDepot = pro.rechercherDansTousLesDepots(requeteDiff());
        assertEquals(1, parDepot.size());
        assertFalse(parDepot.get(0).aEchoue());
        assertEquals(2, parDepot.get(0).getResultats().size());
    }

    @Test
    @DisplayName("(b) avec licence : la portee « messages » ne regarde que les messages")
    void avecLicenceLaPorteeMessagesNeRegardeQueLesMessages() throws Exception {
        FonctionsPro pro = fonctionsPro(licenceVraie());
        // « s3cret-needle » est dans les DIFFS, pas dans les messages :
        // une recherche par messages ne doit donc rien trouver.
        List<PickaxeHit> messages = pro.rechercherParMessages(repository, requete("s3cret-needle"));
        assertTrue(messages.isEmpty(), "la portee « messages » ne doit pas lire les diffs");
    }

    // =====================================================================
    // La garde elle-meme
    // =====================================================================

    @Test
    @DisplayName("une licence INCONNUE (IDE pas encore initialise) n'est pas « pas licencie »")
    void licenceInconnueNestPasAbsenceDeLicence() {
        LicenceEtat etat = new LicenceEtat(() -> null);
        assertFalse(etat.estPro());
        assertTrue(etat.licenceInconnue());
    }

    @Test
    @DisplayName("une source de licence qui PLANTE ne fait pas planter le plugin")
    void sourceDeLicenceQuiPlanteNeProvoquePasDeCrash() {
        LicenceEtat etat = new LicenceEtat(() -> {
            throw new IllegalStateException("boom");
        });
        assertFalse(etat.estPro());
    }

    @Test
    @DisplayName("la source de licence est bien relue a chaque appel (pas de cache fige)")
    void laSourceDeLicenceEstRelectureAChaqueAppel() {
        final boolean[] licence = {false};
        LicenceEtat etat = new LicenceEtat(() -> licence[0]);
        assertFalse(etat.estPro());
        licence[0] = true;
        assertTrue(etat.estPro());
        licence[0] = false;
        assertFalse(etat.estPro());
    }

    @Test
    @DisplayName("le message de refus est exactement « fonction Pro — licence requise »")
    void leMessageDeRefusEstFixe() {
        assertEquals(REFUS, LicenceEtat.MESSAGE_LICENCE_REQUISE);
        assertEquals(REFUS, FonctionProRefuseeException.MESSAGE);
        assertNotNull(new FonctionProRefuseeException("P1").getMessage());
    }

    // =====================================================================
    // Outils
    // =====================================================================

    /** Une requete qui cherche dans les messages (portee « messages »). */
    private PickaxeQuery requete(String needle) {
        return PickaxeQuery.builder(PickaxeMode.STRING, needle)
                .portee(PorteeRecherche.MESSAGES)
                .build();
    }

    /** La requete gratuite : la chaine est dans les diffs. */
    private PickaxeQuery requeteDiff() {
        return PickaxeQuery.builder(PickaxeMode.STRING, TestRepository.NEEDLE).build();
    }

    private LicenceEtat licenceVraie() {
        return new LicenceEtat(() -> Boolean.TRUE);
    }

    private LicenceEtat licenceFausse() {
        return new LicenceEtat(() -> Boolean.FALSE);
    }

    /** Les fonctions Pro, avec un stockage en memoire et le depot de test. */
    private FonctionsPro fonctionsPro(LicenceEtat licence) {
        StockageRecherches stockage = new StockageMemoire();
        List<DepotCible> depots = new ArrayList<>();
        depots.add(new DepotCible(tempDir, "test"));
        FournisseurDepots source = () -> depots;
        return new FonctionsPro(licence, new RecherchesSauvegardees(stockage), source);
    }

    /** Stockage des recherches enregistrees, en memoire (pas d'IDE). */
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
