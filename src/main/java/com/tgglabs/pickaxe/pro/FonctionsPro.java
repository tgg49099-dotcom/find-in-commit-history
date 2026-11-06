package com.tgglabs.pickaxe.pro;

import com.tgglabs.pickaxe.engine.PickaxeEngine;
import com.tgglabs.pickaxe.engine.PickaxeException;
import com.tgglabs.pickaxe.engine.PickaxeHit;
import com.tgglabs.pickaxe.engine.PickaxeQuery;
import com.tgglabs.pickaxe.engine.PickaxeRepository;
import com.tgglabs.pickaxe.engine.PorteeRecherche;
import org.eclipse.jgit.lib.Repository;

import java.io.IOException;
import java.util.ArrayList;
import java.util.Collections;
import java.util.List;

/**
 * Les 4 fonctions Pro du pickaxe.
 *
 * <p>Chacune est <b>conditionnee par la licence</b> : sans licence, elle est
 * refusee avec un message clair
 * ({@link LicenceEtat#MESSAGE_LICENCE_REQUISE}) — jamais une exception
 * brute, jamais un plantage de l'IDE. Avec une licence, elle s'execute
 * normalement.</p>
 *
 * <table border="1">
 *   <caption>Les 4 fonctions</caption>
 *   <tr><th>#</th><th>Fonction</th><th>Ce qu'elle fait</th></tr>
 *   <tr><td>P1</td><td>{@link #rechercherParMessages} /
 *       {@link #rechercherParMessagesEtDiffs}</td>
 *       <td>recherche dans les messages de commit ({@code git log --grep})</td></tr>
 *   <tr><td>P2</td><td>{@link #exporter}</td>
 *       <td>export des resultats (CSV / Markdown / liste de patchs)</td></tr>
 *   <tr><td>P3</td><td>{@link #sauvegarderRecherche} /
 *       {@link #recherchesSauvegardees}</td>
 *       <td>recherches enregistrees, par depot</td></tr>
 *   <tr><td>P4</td><td>{@link #rechercherDansTousLesDepots}</td>
 *       <td>recherche multi-depots</td></tr>
 * </table>
 *
 * <p>Ne depend QUE du moteur (JGit) et de Java : aucun appel a l'IDE, aucun
 * appel reseau. C'est ce qui rend les tests possibles hors IDE.</p>
 */
public final class FonctionsPro {

    private final LicenceEtat licence;
    private final RecherchesSauvegardees recherches;
    private final FournisseurDepots depots;

    /**
     * @param licence    l'etat de la licence (injecte)
     * @param recherches le service des recherches enregistrees (injecte)
     * @param depots     la source des depots de la recherche multi-depots (injecte)
     */
    public FonctionsPro(LicenceEtat licence,
                        RecherchesSauvegardees recherches,
                        FournisseurDepots depots) {
        if (licence == null) {
            throw new IllegalArgumentException("licence must not be null");
        }
        if (recherches == null) {
            throw new IllegalArgumentException("recherches must not be null");
        }
        if (depots == null) {
            throw new IllegalArgumentException("depots must not be null");
        }
        this.licence = licence;
        this.recherches = recherches;
        this.depots = depots;
    }

    /** {@code true} si la licence Pro est active. */
    public boolean estPro() {
        return licence.estPro();
    }

    /**
     * P1 — recherche dans les MESSAGES de commit ({@code git log --grep}).
     *
     * @param repository le depot interroge
     * @param query      la requete (chaine, mode, filtre de chemin)
     * @return les commits dont le message correspond, du plus recent au plus ancien
     * @throws FonctionProRefuseeException si aucune licence Pro n'est active
     * @throws PickaxeException             si le depot ne peut pas etre lu
     */
    public List<PickaxeHit> rechercherParMessages(Repository repository, PickaxeQuery query)
            throws PickaxeException, FonctionProRefuseeException {
        exigerPro("P1");
        return new PickaxeEngine(repository).search(avecPortee(query, PorteeRecherche.MESSAGES));
    }

    /**
     * P1 — recherche dans les diffs ET dans les messages de commit.
     *
     * @param repository le depot interroge
     * @param query      la requete (chaine, mode, filtre de chemin)
     * @return les commits qui correspondent, du plus recent au plus ancien
     * @throws FonctionProRefuseeException si aucune licence Pro n'est active
     * @throws PickaxeException             si le depot ne peut pas etre lu
     */
    public List<PickaxeHit> rechercherParMessagesEtDiffs(Repository repository, PickaxeQuery query)
            throws PickaxeException, FonctionProRefuseeException {
        exigerPro("P1");
        return new PickaxeEngine(repository).search(avecPortee(query, PorteeRecherche.DIFFS_ET_MESSAGES));
    }

    /**
     * P2 — export des resultats.
     *
     * @param hits   les resultats a exporter
     * @param format le format (CSV / Markdown / liste de patchs)
     * @return le contenu du fichier a ecrire
     * @throws FonctionProRefuseeException si aucune licence Pro n'est active
     */
    public String exporter(List<PickaxeHit> hits, FormatExport format) throws FonctionProRefuseeException {
        exigerPro("P2");
        return ExportResultats.formater(hits, format);
    }

    /**
     * P3 — enregistre une recherche pour un depot.
     *
     * @param depot la racine du depot
     * @param nom   le nom donne par l'utilisateur
     * @param query la requete a rejouer
     * @throws FonctionProRefuseeException si aucune licence Pro n'est active
     */
    public void sauvegarderRecherche(String depot, String nom, PickaxeQuery query)
            throws FonctionProRefuseeException {
        exigerPro("P3");
        recherches.sauvegarder(depot, nom, query);
    }

    /**
     * P3 — les recherches enregistrees d'un depot.
     *
     * @param depot la racine du depot
     * @return la liste des recherches (la plus recente en premier)
     * @throws FonctionProRefuseeException si aucune licence Pro n'est active
     */
    public List<RechercheSauvee> recherchesSauvegardees(String depot) throws FonctionProRefuseeException {
        exigerPro("P3");
        return recherches.parDepot(depot);
    }

    /**
     * P4 — la meme recherche dans TOUS les depots connus, resultats regroupes
     * par depot.
     *
     * <p>Un depot illisible n'interrompt pas les autres : il produit un
     * resultat « en erreur » qui porte le message exact.</p>
     *
     * @param query la requete a rejouer dans chaque depot
     * @return un resultat par depot, dans l'ordre des depots
     * @throws FonctionProRefuseeException si aucune licence Pro n'est active
     */
    public List<ResultatParDepot> rechercherDansTousLesDepots(PickaxeQuery query)
            throws FonctionProRefuseeException {
        exigerPro("P4");
        List<ResultatParDepot> resultats = new ArrayList<>();
        List<DepotCible> cibles = depots.depots();
        if (cibles == null) {
            return resultats;
        }
        for (DepotCible cible : cibles) {
            resultats.add(rechercherDans(cible, query));
        }
        return resultats;
    }

    /** Recherche dans UN depot ; une erreur est capturee, pas propagee. */
    private ResultatParDepot rechercherDans(DepotCible cible, PickaxeQuery query) {
        try (Repository repository = PickaxeRepository.open(cible.getCheminPath())) {
            List<PickaxeHit> hits = new PickaxeEngine(repository).search(query);
            return new ResultatParDepot(cible, hits, null);
        } catch (IOException | PickaxeException | RuntimeException e) {
            String message = e.getMessage() == null ? e.getClass().getSimpleName() : e.getMessage();
            return new ResultatParDepot(cible, Collections.emptyList(), message);
        }
    }

    /** La garde : sans licence, la fonction est refusee (message clair). */
    private void exigerPro(String fonction) throws FonctionProRefuseeException {
        if (!licence.estPro()) {
            throw new FonctionProRefuseeException(fonction);
        }
    }

    /** Copie de la requete avec une autre portee. */
    private static PickaxeQuery avecPortee(PickaxeQuery query, PorteeRecherche portee) {
        if (query == null) {
            throw new IllegalArgumentException("query must not be null");
        }
        return PickaxeQuery.builder(query.getMode(), query.getNeedle())
                .pathFilter(query.getPathFilter())
                .includeBinary(query.isIncludeBinary())
                .maxResults(query.getMaxResults())
                .portee(portee)
                .build();
    }
}
