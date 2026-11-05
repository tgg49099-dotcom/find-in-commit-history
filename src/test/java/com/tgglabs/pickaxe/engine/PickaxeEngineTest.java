package com.tgglabs.pickaxe.engine;

import org.eclipse.jgit.api.Git;
import org.eclipse.jgit.lib.Repository;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.io.TempDir;

import java.nio.charset.StandardCharsets;
import java.nio.file.Path;
import java.util.ArrayList;
import java.util.Arrays;
import java.util.List;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertFalse;
import static org.junit.jupiter.api.Assertions.assertThrows;
import static org.junit.jupiter.api.Assertions.assertTrue;

/**
 * Tests du moteur pickaxe.
 *
 * <p><b>Les resultats attendus sont ecrits a la main</b> (tableaux de
 * messages de commit ci-dessous) : ils ne sont pas produits par le moteur.
 * Chaque cas correspond a une ligne du depot de test construit par
 * {@link TestRepository}.</p>
 *
 * <p>Ordre attendu : du commit le plus recent au plus ancien (comme
 * {@code git log}).</p>
 */
class PickaxeEngineTest {

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

    private List<String> subjects(PickaxeQuery query) throws PickaxeException {
        List<String> subjects = new ArrayList<>();
        for (PickaxeHit hit : engine.search(query)) {
            subjects.add(hit.getSubject());
        }
        return subjects;
    }

    private PickaxeQuery stringQuery(String needle) {
        return PickaxeQuery.builder(PickaxeMode.STRING, needle).build();
    }

    // =====================================================================
    // Mode -S : comptage des occurrences avant / apres
    // =====================================================================

    @Test
    @DisplayName("-S trouve le commit qui ajoute la chaine et celui qui la supprime")
    void stringSearchFindsAdditionAndRemoval() throws Exception {
        // Le commit 2 ajoute la chaine, le commit 6 la supprime.
        // Le commit 3 la reecrit a l'identique, le 4 l'ajoute dans un binaire,
        // le 5 renomme le fichier : aucun de ces trois ne doit resortir.
        List<String> expected = Arrays.asList(
                TestRepository.SUBJECT_REMOVE,
                TestRepository.SUBJECT_ADD);
        assertEquals(expected, subjects(stringQuery(TestRepository.NEEDLE)));
    }

    @Test
    @DisplayName("-S ne remonte PAS une chaine reecrite a l'identique (le piege)")
    void stringSearchIgnoresIdenticalRewrite() throws Exception {
        List<String> found = subjects(stringQuery(TestRepository.NEEDLE));
        assertFalse(found.contains(TestRepository.SUBJECT_REWRITE),
                "une reecriture a l'identique ne doit pas remonter : " + found);
    }

    @Test
    @DisplayName("-S ne remonte PAS un ajout dans un fichier binaire")
    void stringSearchIgnoresBinaryFiles() throws Exception {
        List<String> found = subjects(stringQuery(TestRepository.NEEDLE));
        assertFalse(found.contains(TestRepository.SUBJECT_BINARY),
                "un fichier binaire doit etre ignore : " + found);
    }

    @Test
    @DisplayName("-S ne remonte PAS un renommage de fichier sans changement")
    void stringSearchIgnoresRename() throws Exception {
        List<String> found = subjects(stringQuery(TestRepository.NEEDLE));
        assertFalse(found.contains(TestRepository.SUBJECT_RENAME),
                "un renommage sans changement de contenu ne doit pas remonter : " + found);
    }

    @Test
    @DisplayName("apres un renommage, la chaine est trouvee dans le NOUVEAU fichier")
    void stringSearchFindsChainInRenamedFile() throws Exception {
        // Le commit 5 renomme src/config.py en src/settings.py. Apres ce
        // renommage, la chaine est toujours presente dans le fichier, mais
        // sous un AUTRE chemin : elle doit rester trouvable, et le chemin
        // signale doit etre le nouveau nom. Le commit de renommage
        // lui-meme ne doit pas resortir (le contenu n'a pas change).
        List<PickaxeHit> hits = engine.search(stringQuery(TestRepository.NEEDLE));
        assertEquals(2, hits.size(), "deux commits attendus, pas plus : " + subjects(stringQuery(TestRepository.NEEDLE)));
        assertEquals(TestRepository.SUBJECT_REMOVE, hits.get(0).getSubject());
        assertEquals(Arrays.asList("src/settings.py"), hits.get(0).getPaths(),
                "la chaine supprimee apres le renommage est dans le NOUVEAU fichier");
        assertEquals(TestRepository.SUBJECT_ADD, hits.get(1).getSubject());
        assertEquals(Arrays.asList("src/config.py"), hits.get(1).getPaths(),
                "la chaine ajoutee avant le renommage est dans l'ANCIEN fichier");
        // Le renommage seul ne doit pas apparaitre.
        assertFalse(subjects(stringQuery(TestRepository.NEEDLE)).contains(TestRepository.SUBJECT_RENAME),
                "le renommage sans changement ne doit pas remonter");
    }

    @Test
    @DisplayName("-S compare le NOMBRE d'occurrences, pas la presence de la chaine")
    void stringSearchCountsOccurrencesNotContent() throws Exception {
        // « wörld » apparait DEUX fois dans le commit 1, puis UNE fois apres
        // le commit 6 : les deux commits ressortent, parce que le NOMBRE
        // d'occurrences a change. Un simple « la chaine est-elle presente ? »
        // ne donnerait que le commit 1.
        List<String> expected = Arrays.asList(
                TestRepository.SUBJECT_REMOVE,
                TestRepository.SUBJECT_INIT);
        assertEquals(expected, subjects(stringQuery(TestRepository.UNICODE_NEEDLE)));
    }

    @Test
    @DisplayName("-S avec filtre de chemin : seul le bon fichier est concerne")
    void stringSearchWithPathFilter() throws Exception {
        // Apres le renommage (commit 5), la chaine vit dans src/settings.py.
        // Le commit 6 la supprime la : il ressort. Le commit 2 l'a ajoutee dans
        // src/config.py : il ne ressort pas avec ce filtre.
        List<String> expected = Arrays.asList(TestRepository.SUBJECT_REMOVE);
        assertEquals(expected, subjects(PickaxeQuery.builder(PickaxeMode.STRING, TestRepository.NEEDLE)
                .pathFilter("settings\\.py")
                .build()));

        // Et l'inverse : le filtre sur l'ancien nom ne voit que l'ajout.
        List<String> expectedOldName = Arrays.asList(TestRepository.SUBJECT_ADD);
        assertEquals(expectedOldName, subjects(PickaxeQuery.builder(PickaxeMode.STRING, TestRepository.NEEDLE)
                .pathFilter("config\\.py")
                .build()));
    }

    @Test
    @DisplayName("-S avec includeBinary : le commit binaire ressort alors")
    void includeBinaryFindsBinaryCommit() throws Exception {
        List<String> expected = Arrays.asList(
                TestRepository.SUBJECT_REMOVE,
                TestRepository.SUBJECT_BINARY,
                TestRepository.SUBJECT_ADD);
        assertEquals(expected, subjects(PickaxeQuery.builder(PickaxeMode.STRING, TestRepository.NEEDLE)
                .includeBinary(true)
                .build()));
    }

    @Test
    @DisplayName("-S signale le chemin du fichier qui a declenche la correspondance")
    void stringSearchReportsPaths() throws Exception {
        List<PickaxeHit> hits = engine.search(stringQuery(TestRepository.NEEDLE));
        assertEquals(2, hits.size());
        assertEquals(Arrays.asList("src/settings.py"), hits.get(0).getPaths());
        assertEquals(Arrays.asList("src/config.py"), hits.get(1).getPaths());
        assertEquals(40, hits.get(0).getCommitId().length());
        assertEquals(hits.get(0).getCommitId().substring(0, 7), hits.get(0).getShortId());
    }

    // =====================================================================
    // Mode -G : expression reguliere appliquee au diff
    // =====================================================================

    @Test
    @DisplayName("-G trouve les lignes ajoutees, supprimees ET reecrites")
    void regexSearchMatchesChangedLines() throws Exception {
        // Le commit 3 reecrit la ligne : elle apparait dans le diff (une
        // version suprimee, une version ajoutee) => -G le voit, contrairement
        // a -S. Le commit 4 (binaire) et le commit 5 (renommage) restent
        // dehors.
        List<String> expected = Arrays.asList(
                TestRepository.SUBJECT_REMOVE,
                TestRepository.SUBJECT_REWRITE,
                TestRepository.SUBJECT_ADD);
        assertEquals(expected, subjects(PickaxeQuery.builder(PickaxeMode.REGEX, TestRepository.NEEDLE)
                .build()));
    }

    @Test
    @DisplayName("-G trouve l'ajout ET la suppression de la meme ligne")
    void regexSearchOnAddedAnnotation() throws Exception {
        // Le commit 3 AJOUTE le commentaire "# noqa" ; le commit 6 SUPPRIME
        // la ligne qui le contient. Les deux doivent resortir : -G regarde
        // les lignes ajoutees ET supprimees. Le commit 5 (renommage) ne
        // resortit pas : le contenu ne change pas.
        List<String> expected = Arrays.asList(
                TestRepository.SUBJECT_REMOVE,
                TestRepository.SUBJECT_REWRITE);
        assertEquals(expected, subjects(PickaxeQuery.builder(PickaxeMode.REGEX, "noqa").build()));
    }

    @Test
    @DisplayName("-G avec une expression invalide est refuse avant toute lecture")
    void regexSearchRejectsInvalidPattern() {
        IllegalArgumentException error = assertThrows(IllegalArgumentException.class,
                () -> PickaxeQuery.builder(PickaxeMode.REGEX, "([unclosed").build());
        assertTrue(error.getMessage().startsWith("Invalid regular expression"),
                "message inattendu : " + error.getMessage());
    }

    // =====================================================================
    // Cas limites
    // =====================================================================

    @Test
    @DisplayName("une chaine vide est refusee avec un message explicite")
    void emptyNeedleIsRejected() {
        IllegalArgumentException error = assertThrows(IllegalArgumentException.class,
                () -> PickaxeQuery.builder(PickaxeMode.STRING, "").build());
        assertEquals(PickaxeQuery.EMPTY_NEEDLE_MESSAGE, error.getMessage());
    }

    @Test
    @DisplayName("un depot sans commit ne renvoie rien et ne leve pas d'exception")
    void emptyRepositoryReturnsNoResult() throws Exception {
        Path empty = tempDir.resolve("empty");
        try (Git git = Git.init().setDirectory(empty.toFile()).call()) {
            PickaxeEngine emptyEngine = new PickaxeEngine(git.getRepository());
            assertTrue(emptyEngine.search(stringQuery(TestRepository.NEEDLE)).isEmpty());
        }
    }

    @Test
    @DisplayName("un chemin de filtre invalide est refuse")
    void invalidPathFilterIsRejected() {
        IllegalArgumentException error = assertThrows(IllegalArgumentException.class,
                () -> PickaxeQuery.builder(PickaxeMode.STRING, TestRepository.NEEDLE)
                        .pathFilter("([unclosed")
                        .build());
        assertTrue(error.getMessage().startsWith("Invalid path filter"),
                "message inattendu : " + error.getMessage());
    }

    @Test
    @DisplayName("maxResults limite le nombre de commits renvoyes")
    void maxResultsIsHonoured() throws Exception {
        List<PickaxeHit> hits = engine.search(PickaxeQuery.builder(PickaxeMode.STRING, TestRepository.NEEDLE)
                .maxResults(1)
                .build());
        assertEquals(1, hits.size());
        assertEquals(TestRepository.SUBJECT_REMOVE, hits.get(0).getSubject());
    }

    // =====================================================================
    // Fonctions de base (tests unitaires)
    // =====================================================================

    @Test
    @DisplayName("comptage des occurrences : sans chevauchement")
    void countOccurrencesDoesNotOverlap() {
        assertEquals(2, PickaxeEngine.countOccurrences(
                "aaaa".getBytes(StandardCharsets.UTF_8),
                "aa".getBytes(StandardCharsets.UTF_8)));
        assertEquals(2, PickaxeEngine.countOccurrences(
                "abcabc".getBytes(StandardCharsets.UTF_8),
                "abc".getBytes(StandardCharsets.UTF_8)));
        assertEquals(0, PickaxeEngine.countOccurrences(
                "abc".getBytes(StandardCharsets.UTF_8),
                "zz".getBytes(StandardCharsets.UTF_8)));
        assertEquals(0, PickaxeEngine.countOccurrences(null, "a".getBytes(StandardCharsets.UTF_8)));
    }

    @Test
    @DisplayName("detection binaire : un octet nul suffit")
    void binaryDetection() {
        assertTrue(PickaxeEngine.isBinary(new byte[]{'a', 0, 'b'}));
        assertFalse(PickaxeEngine.isBinary("hello".getBytes(StandardCharsets.UTF_8)));
        assertFalse(PickaxeEngine.isBinary(null));
    }

    @Test
    @DisplayName("decoupe en lignes : comme git, sans ligne vide finale")
    void lineSplitting() {
        assertArrayEqualsIgnoringNull(new String[]{"a", "b"}, PickaxeEngine.splitLines("a\nb\n".getBytes(StandardCharsets.UTF_8)));
        assertArrayEqualsIgnoringNull(new String[]{"a", "b"}, PickaxeEngine.splitLines("a\nb".getBytes(StandardCharsets.UTF_8)));
        // Le retour chariot de fin de ligne (CRLF) est retire.
        assertArrayEqualsIgnoringNull(new String[]{"a", "b"}, PickaxeEngine.splitLines("a\r\nb".getBytes(StandardCharsets.UTF_8)));
    }

    private static void assertArrayEqualsIgnoringNull(String[] expected, String[] actual) {
        assertEquals(Arrays.asList(expected), Arrays.asList(actual));
    }
}
