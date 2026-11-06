package com.tgglabs.pickaxe.ui;

import com.intellij.openapi.application.ApplicationManager;
import com.intellij.openapi.application.ModalityState;
import com.intellij.openapi.fileChooser.FileChooserFactory;
import com.intellij.openapi.fileChooser.FileSaverDescriptor;
import com.intellij.openapi.ide.CopyPasteManager;
import com.intellij.openapi.progress.ProgressIndicator;
import com.intellij.openapi.progress.ProgressManager;
import com.intellij.openapi.progress.Task;
import com.intellij.openapi.project.Project;
import com.intellij.openapi.ui.ComboBox;
import com.intellij.openapi.ui.DialogWrapper;
import com.intellij.openapi.ui.Messages;
import com.intellij.openapi.vfs.VirtualFileWrapper;
import com.intellij.ui.components.JBCheckBox;
import com.intellij.ui.components.JBList;
import com.intellij.ui.components.JBLabel;
import com.intellij.ui.components.JBScrollPane;
import com.intellij.ui.components.JBTextField;
import com.tgglabs.pickaxe.GitRepositoryLocator;
import com.tgglabs.pickaxe.engine.PickaxeEngine;
import com.tgglabs.pickaxe.engine.PickaxeException;
import com.tgglabs.pickaxe.engine.PickaxeHit;
import com.tgglabs.pickaxe.engine.PickaxeMode;
import com.tgglabs.pickaxe.engine.PickaxeQuery;
import com.tgglabs.pickaxe.engine.PickaxeRepository;
import com.tgglabs.pickaxe.engine.PorteeRecherche;
import com.tgglabs.pickaxe.ide.FonctionsProIDE;
import com.tgglabs.pickaxe.pro.FonctionProRefuseeException;
import com.tgglabs.pickaxe.pro.FonctionsPro;
import com.tgglabs.pickaxe.pro.FormatExport;
import com.tgglabs.pickaxe.pro.LicenceEtat;
import com.tgglabs.pickaxe.pro.RechercheSauvee;
import com.tgglabs.pickaxe.pro.ResultatParDepot;
import org.eclipse.jgit.lib.Repository;
import org.jetbrains.annotations.NotNull;
import org.jetbrains.annotations.Nullable;

import javax.swing.AbstractAction;
import javax.swing.Action;
import javax.swing.DefaultListModel;
import javax.swing.JButton;
import javax.swing.JComponent;
import javax.swing.JPanel;
import javax.swing.ListModel;
import java.awt.BorderLayout;
import java.awt.GridBagConstraints;
import java.awt.GridBagLayout;
import java.awt.Insets;
import java.awt.datatransfer.StringSelection;
import java.awt.event.MouseAdapter;
import java.awt.event.MouseEvent;
import java.io.IOException;
import java.nio.charset.StandardCharsets;
import java.nio.file.Files;
import java.nio.file.Path;
import java.util.ArrayList;
import java.util.Collections;
import java.util.List;
import java.util.function.BooleanSupplier;

/**
 * Dialogue « saisir une chaine → lister les commits ».
 *
 * <p>Interface volontairement minimale (elle peut s'enrichir plus tard) mais
 * deja branchee sur le moteur : le bouton « Search » appelle
 * {@link PickaxeEngine}.</p>
 *
 * <p>Regle de robustesse : un champ vide ne doit jamais declencher une
 * exception — le dialogue affiche un message et ne lance rien.</p>
 *
 * <p>Regle de fluidite : la recherche ne doit jamais tourner sur le thread
 * EDT (celui de Swing). Sur un gros depot elle gelerait l'IDE. Elle est donc
 * confiee a une tache de fond, et son resultat est applique au modele dans
 * {@code invokeLater} (donc sur l'EDT).</p>
 *
 * <p>Copie du hash : un double-clic dans la liste des resultats — ou le
 * bouton « Copy hash » — met le hash du commit selectionne dans le
 * presse-papier. La copie passe par {@link HashClipboard}, qui ne depend que
 * de l'engine : aucune API de suivi de version, aucun plugin tiers. La
 * destination est le presse-papier de la plateforme.</p>
 *
 * <p><b>Fonctions Pro (P1 a P4)</b> : elles sont branchees ici et chacune
 * est conditionnee par {@link LicenceEtat#estPro()}. Sans licence, la
 * fonction est refusee avec le message « fonction Pro — licence requise » :
 * jamais une exception brute, jamais un plantage de l'IDE. Le coeur gratuit
 * (recherche dans les diffs, filtre de chemin, copie du hash) n'est jamais
 * affecte par l'etat de la licence.</p>
 */
public class PickaxeDialog extends DialogWrapper {

    /** Libelles du selecteur de portee (l'ordre est celui de {@link PorteeRecherche}). */
    private static final String[] PORTEE_LIBELLES = {
            "Diffs only (free)",
            "Diffs + commit messages (Pro)",
            "Commit messages only (Pro)"
    };

    private final Project project;
    private final Path repositoryRoot;

    private final JBTextField needleField = new JBTextField();
    private final JBTextField pathField = new JBTextField();
    private final ComboBox<PickaxeMode> modeCombo =
            new ComboBox<>(new PickaxeMode[]{PickaxeMode.STRING, PickaxeMode.REGEX});
    private final ComboBox<String> scopeCombo = new ComboBox<>(PORTEE_LIBELLES);
    private final ComboBox<String> savedSearchCombo = new ComboBox<>(new String[]{""});
    private final JBCheckBox allRepositoriesCheck =
            new JBCheckBox("All repositories of the project (Pro)");
    private final JBList<String> resultList = new JBList<>();
    private final JBLabel statusLabel = new JBLabel(" ");

    /**
     * Les resultats de la DERNIERE recherche, dans l'ordre de la liste
     * affichee : c'est eux qui portent le hash a copier. La liste et le
     * modele sont toujours mis a jour ensemble (voir {@code showResults}).
     */
    private List<PickaxeHit> lastHits = Collections.emptyList();

    /**
     * Les fonctions Pro (P1 a P4). Elles sont INJECTEES : le dialogue ne
     * construit pas lui-meme l'etat de licence, ce qui permet de tester le
     * dialogue avec un etat de licence factice.
     */
    private final FonctionsPro fonctionsPro;

    /**
     * Presse-papier. La destination est injectee : le code de copie reste
     * ainsi testable HORS IDE (cf. {@link HashClipboard} et ses tests).
     */
    private final HashClipboard clipboard = new HashClipboard(
            text -> CopyPasteManager.getInstance().setContents(new StringSelection(text)));

    public PickaxeDialog(@Nullable Project project, @NotNull Path repositoryRoot) {
        this(project, repositoryRoot, FonctionsProIDE.parDefaut(repositoryRoot));
    }

    /**
     * Dialogue avec des fonctions Pro injectees (tests, ou appel explicite).
     *
     * @param project       le projet (peut etre {@code null})
     * @param repositoryRoot la racine du depot interroge
     * @param fonctionsPro  les fonctions Pro (P1 a P4)
     */
    public PickaxeDialog(@Nullable Project project,
                         @NotNull Path repositoryRoot,
                         @NotNull FonctionsPro fonctionsPro) {
        super(project, false);
        this.project = project;
        this.repositoryRoot = repositoryRoot;
        this.fonctionsPro = fonctionsPro;
        setTitle("Find in Commit History");
        init();
        chargerRecherchesSauvegardees();
    }

    @Override
    protected @Nullable JComponent createCenterPanel() {
        JPanel form = new JPanel(new GridBagLayout());
        GridBagConstraints c = new GridBagConstraints();
        c.insets = new Insets(2, 4, 2, 4);
        c.anchor = GridBagConstraints.WEST;

        c.gridx = 0;
        c.gridy = 0;
        form.add(new JBLabel("Search for:"), c);
        c.gridx = 1;
        c.weightx = 1;
        c.fill = GridBagConstraints.HORIZONTAL;
        form.add(needleField, c);

        c.gridx = 0;
        c.gridy = 1;
        c.weightx = 0;
        c.fill = GridBagConstraints.NONE;
        form.add(new JBLabel("Mode:"), c);
        c.gridx = 1;
        c.weightx = 1;
        c.fill = GridBagConstraints.HORIZONTAL;
        form.add(modeCombo, c);

        c.gridx = 0;
        c.gridy = 2;
        c.weightx = 0;
        c.fill = GridBagConstraints.NONE;
        form.add(new JBLabel("Search in:"), c);
        c.gridx = 1;
        c.weightx = 1;
        c.fill = GridBagConstraints.HORIZONTAL;
        form.add(scopeCombo, c);

        c.gridx = 0;
        c.gridy = 3;
        c.weightx = 0;
        c.fill = GridBagConstraints.NONE;
        form.add(new JBLabel("Path filter (optional):"), c);
        c.gridx = 1;
        c.weightx = 1;
        c.fill = GridBagConstraints.HORIZONTAL;
        form.add(pathField, c);

        c.gridx = 0;
        c.gridy = 4;
        c.gridwidth = 2;
        c.weightx = 1;
        c.fill = GridBagConstraints.NONE;
        form.add(allRepositoriesCheck, c);
        c.gridwidth = 1;

        ListModel<String> model = new DefaultListModel<>();
        resultList.setModel(model);
        JBScrollPane scroll = new JBScrollPane(resultList);
        scroll.setPreferredSize(new java.awt.Dimension(520, 220));

        // Double-clic sur un resultat : le hash de ce commit part dans le
        // presse-papier. Le premier clic du double-clic a deja selectionne
        // ligne : `getSelectedIndex()` est donc le resultat vise.
        resultList.addMouseListener(new MouseAdapter() {
            @Override
            public void mouseClicked(MouseEvent e) {
                if (e.getClickCount() == 2) {
                    copySelectedHash();
                }
            }
        });

        JButton copyHashButton = new JButton("Copy hash");
        copyHashButton.setToolTipText("Copy the full hash of the selected commit to the clipboard");
        copyHashButton.addActionListener(e -> copySelectedHash());

        // Boutons Pro : ils sont TOUJOURS presents (pour que l'utilisateur
        // voie ce qui existe), mais leur action est refusee sans licence,
        // avec un message clair.
        JButton exportButton = new JButton("Export… (Pro)");
        exportButton.setToolTipText("Export the results as CSV, Markdown or a list of patches");
        exportButton.addActionListener(e -> exporterResultats());

        JButton saveSearchButton = new JButton("Save search (Pro)");
        saveSearchButton.setToolTipText("Save this search for this repository");
        saveSearchButton.addActionListener(e -> enregistrerRecherche());

        JPanel savedRow = new JPanel(new BorderLayout(4, 0));
        savedRow.add(new JBLabel("Saved searches (Pro):"), BorderLayout.WEST);
        savedSearchCombo.addActionListener(e -> chargerRechercheSauvee());
        savedRow.add(savedSearchCombo, BorderLayout.CENTER);

        JPanel buttons = new JPanel(new BorderLayout(4, 4));
        JPanel topButtons = new JPanel(new BorderLayout(4, 0));
        topButtons.add(exportButton, BorderLayout.WEST);
        topButtons.add(saveSearchButton, BorderLayout.CENTER);
        buttons.add(topButtons, BorderLayout.NORTH);
        buttons.add(savedRow, BorderLayout.SOUTH);

        JPanel south = new JPanel(new BorderLayout(8, 0));
        south.add(statusLabel, BorderLayout.CENTER);
        south.add(copyHashButton, BorderLayout.EAST);

        JPanel root = new JPanel(new BorderLayout(0, 6));
        root.add(form, BorderLayout.NORTH);
        root.add(scroll, BorderLayout.CENTER);
        JPanel bas = new JPanel(new BorderLayout(0, 4));
        bas.add(buttons, BorderLayout.NORTH);
        bas.add(south, BorderLayout.SOUTH);
        root.add(bas, BorderLayout.SOUTH);
        return root;
    }

    @Override
    protected Action @NotNull [] createActions() {
        return new Action[]{getOKAction(), getCancelAction()};
    }

    /**
     * L'action OK par defaut de {@link DialogWrapper} ferme le dialogue : la
     * touche ENTRÉE ne lancierait alors rien. On la remplace par l'action de
     * RECHERCHE : ENTRÉE lance donc exactement la meme recherche qu'un clic
     * sur « Search », et le dialogue reste ouvert pour afficher les resultats.
     */
    @Override
    protected void createDefaultActions() {
        super.createDefaultActions();
        myOKAction = new SearchAction();
    }

    /** Bouton « Search » : lance la recherche et garde le dialogue ouvert. */
    private class SearchAction extends AbstractAction {
        SearchAction() {
            super("Search");
            // « DefaultAction » est la clef que la plateforme regarde pour
            // designer le bouton touche par la touche ENTRÉE.
            putValue(DialogWrapper.DEFAULT_ACTION, Boolean.TRUE);
        }

        @Override
        public void actionPerformed(java.awt.event.ActionEvent e) {
            runSearch();
        }
    }

    /**
     * Lance la recherche.
     *
     * <p>La lecture du depot est faite par une tache de fond
     * ({@link Task.Backgroundable}) : l'EDT reste libre, l'IDE ne gele pas,
     * et la tache affiche sa progression et peut etre annulee. Le resultat est
     * applique au modele dans {@code invokeLater}, donc sur l'EDT.</p>
     *
     * <p>Ne leve jamais d'exception vers l'IDE.</p>
     */
    private void runSearch() {
        final String needle = needleField.getText();
        if (needle == null || needle.trim().isEmpty()) {
            setStatus(PickaxeQuery.EMPTY_NEEDLE_MESSAGE, true);
            return;
        }
        // Les champs Swing sont lus ICI, sur l'EDT : un thread de fond n'a
        // pas le droit de les toucher.
        final PickaxeMode mode = (PickaxeMode) modeCombo.getSelectedItem();
        final String pathFilter = pathField.getText();
        final PorteeRecherche portee = porteeChoisie();
        final boolean tousLesDepots = allRepositoriesCheck.isSelected();
        // Modalite capturee sur l'EDT : le resultat sera applique dans le meme
        // etat de modalite (ce dialogue est modal).
        final ModalityState modality = ModalityState.defaultModalityState();

        setStatus("Searching…", false);
        ProgressManager.getInstance().run(new Task.Backgroundable(
                project, "Searching Git history", true) {
            @Override
            public void run(@NotNull ProgressIndicator indicator) {
                indicator.setIndeterminate(true);
                final List<Entree> entrees;
                try {
                    // L'indicateur de la tache de fond est le signal
                    // d'annulation : le moteur le teste a chaque commit et a
                    // chaque entree de la boucle de diff. « Cancel » arrete
                    // donc vraiment le parcours, au lieu de n'etre qu'un
                    // decoratif.
                    entrees = chercher(needle, mode, pathFilter, portee, tousLesDepots,
                            indicator::isCanceled);
                } catch (FonctionProRefuseeException ex) {
                    // Fonction Pro sans licence : message clair, pas de crash.
                    final String message = ex.getMessage();
                    ApplicationManager.getApplication().invokeLater(() -> setStatus(message, true), modality);
                    return;
                } catch (PickaxeException ex) {
                    final String message = ex.getMessage() == null ? "Search failed." : ex.getMessage();
                    ApplicationManager.getApplication().invokeLater(() -> setStatus(message, true), modality);
                    return;
                } catch (RuntimeException ex) {
                    // Filet de securite : l'IDE ne doit jamais voir une
                    // exception brute issue d'une action utilisateur.
                    final String message = "Search failed: " + ex.getClass().getSimpleName()
                            + (ex.getMessage() == null ? "" : " — " + ex.getMessage());
                    ApplicationManager.getApplication().invokeLater(() -> setStatus(message, true), modality);
                    return;
                }
                if (indicator.isCanceled()) {
                    // L'utilisateur a annule : le resultat est jete (onCancel()
                    // met le message « Search cancelled. »).
                    return;
                }
                ApplicationManager.getApplication().invokeLater(() -> showResults(entrees), modality);
            }

            @Override
            public void onCancel() {
                setStatus("Search cancelled.", false);
            }
        });
    }

    /**
     * La recherche elle-meme, sur un thread de fond.
     *
     * <p>Trois cas :</p>
     * <ul>
     *   <li>portee « diffs » et UN depot : le coeur gratuit (moteur seul) ;</li>
     *   <li>portee « messages » : fonction Pro P1 ;</li>
     *   <li>tous les depots du projet : fonction Pro P4 (les resultats sont
     *       regroupes par depot).</li>
     * </ul>
     */
    private List<Entree> chercher(String needle, PickaxeMode mode, String pathFilter,
                                  PorteeRecherche portee, boolean tousLesDepots,
                                  BooleanSupplier cancelled)
            throws PickaxeException, FonctionProRefuseeException {
        final PickaxeQuery query = PickaxeQuery.builder(mode, needle)
                .pathFilter(pathFilter)
                .portee(portee)
                .build();
        if (tousLesDepots) {
            List<Entree> entrees = new ArrayList<>();
            for (ResultatParDepot resultat : fonctionsPro.rechercherDansTousLesDepots(query)) {
                for (PickaxeHit hit : resultat.getResultats()) {
                    entrees.add(new Entree(hit, resultat.getDepot().getNom()));
                }
            }
            return entrees;
        }
        try (Repository repository = PickaxeRepository.open(repositoryRoot)) {
            final List<PickaxeHit> hits;
            if (portee == PorteeRecherche.DIFFS) {
                // Coeur gratuit : le moteur, sans condition de licence.
                hits = new PickaxeEngine(repository, cancelled).search(query);
            } else if (portee == PorteeRecherche.MESSAGES) {
                hits = fonctionsPro.rechercherParMessages(repository, query);
            } else {
                hits = fonctionsPro.rechercherParMessagesEtDiffs(repository, query);
            }
            List<Entree> entrees = new ArrayList<>();
            for (PickaxeHit hit : hits) {
                entrees.add(new Entree(hit, null));
            }
            return entrees;
        } catch (IOException e) {
            // `FileRepositoryBuilder.build()` leve une IOException controlee :
            // on la transforme en PickaxeException pour que l'IDE ne voie
            // jamais d'exception brute (voir runSearch()).
            throw new PickaxeException("Unable to open the Git repository at "
                    + repositoryRoot + ": " + e.getMessage(), e);
        }
    }

    /** Applique le resultat au modele. Appele sur l'EDT. */
    private void showResults(List<Entree> entrees) {
        List<Entree> resultats = entrees == null
                ? Collections.emptyList()
                : new ArrayList<>(entrees);
        DefaultListModel<String> model = new DefaultListModel<>();
        List<PickaxeHit> hits = new ArrayList<>();
        for (Entree entree : resultats) {
            PickaxeHit hit = entree.hit;
            hits.add(hit);
            String prefixe = entree.prefixe == null ? "" : "[" + entree.prefixe + "] ";
            model.addElement(prefixe + hit.getShortId() + "  " + hit.getSubject()
                    + (hit.getPaths().isEmpty() ? "" : "  [" + String.join(", ", hit.getPaths()) + "]"));
        }
        resultList.setModel(model);
        // La liste des hashs suit la liste affichee : meme ordre, meme
        // longueur. Le double-clic et le bouton copient donc bien le hash du
        // resultat surligne.
        lastHits = hits;
        setStatus(resultats.size() + (resultats.size() == 1 ? " commit found." : " commits found."), false);
    }

    /**
     * Copie dans le presse-papier le hash du commit selectionne.
     *
     * <p>Appele par le bouton « Copy hash » et par un double-clic dans la
     * liste des resultats. Copie l'identifiant COMPLET du commit : git
     * accepte l'abrege comme le complet, mais le complet est le seul qui ne
     * soit jamais ambigu.</p>
     *
     * <p>Ne leve jamais d'exception vers l'IDE : si rien n'est selectionne,
     * le dialogue affiche simplement un message.</p>
     */
    private void copySelectedHash() {
        int index = resultList.getSelectedIndex();
        String hash = HashClipboard.hashAt(lastHits, index);
        if (hash == null) {
            setStatus("Select a commit in the list first.", true);
            return;
        }
        clipboard.copyHashAt(lastHits, index);
        setStatus("Hash copied to the clipboard: " + hash, false);
    }

    /**
     * P2 — export des resultats. Sans licence, la fonction est refusee avec
     * le message « fonction Pro — licence requise ».
     */
    private void exporterResultats() {
        try {
            FormatExport format = choisirFormatExport();
            if (format == null) {
                return;
            }
            String contenu = fonctionsPro.exporter(lastHits, format);
            Path destination = choisirFichierDestination(format);
            if (destination == null) {
                return;
            }
            Files.write(destination, contenu.getBytes(StandardCharsets.UTF_8));
            setStatus("Results exported to " + destination, false);
        } catch (FonctionProRefuseeException ex) {
            setStatus(ex.getMessage(), true);
        } catch (IOException | RuntimeException e) {
            setStatus("Export failed: " + e.getMessage(), true);
        }
    }

    /** Le format d'export choisi par l'utilisateur. */
    private FormatExport choisirFormatExport() {
        String[] options = new String[FormatExport.values().length];
        for (int i = 0; i < options.length; i++) {
            options[i] = FormatExport.values()[i].libelle();
        }
        int choix = Messages.showChooseDialog(project,
                "Format of the exported results:", "Export results", null,
                options, options[0]);
        if (choix < 0) {
            return null;
        }
        return FormatExport.values()[choix];
    }

    /** Le fichier de destination choisi par l'utilisateur ({@code null} si annule). */
    private Path choisirFichierDestination(FormatExport format) {
        FileSaverDescriptor descriptor = new FileSaverDescriptor(
                "Export results", "Choose where to write the exported results");
        VirtualFileWrapper wrapper = FileChooserFactory.getInstance()
                .createSaveFileDialog(descriptor, project)
                .save(null);
        if (wrapper == null || wrapper.getFile() == null) {
            return null;
        }
        Path destination = wrapper.getFile().toPath();
        String nom = destination.getFileName() == null ? "" : destination.getFileName().toString();
        if (!nom.contains(".")) {
            destination = destination.resolveSibling(nom + "." + format.extension());
        }
        return destination;
    }

    /**
     * P3 — enregistre la recherche courante pour ce depot. Sans licence, la
     * fonction est refusee avec le message « fonction Pro — licence
     * requise ».
     */
    private void enregistrerRecherche() {
        final String needle = needleField.getText();
        if (needle == null || needle.trim().isEmpty()) {
            setStatus(PickaxeQuery.EMPTY_NEEDLE_MESSAGE, true);
            return;
        }
        String nom = Messages.showInputDialog(project,
                "Name of this search:", "Save search", null);
        if (nom == null || nom.trim().isEmpty()) {
            return;
        }
        try {
            PickaxeMode mode = (PickaxeMode) modeCombo.getSelectedItem();
            PickaxeQuery query = PickaxeQuery.builder(mode, needle)
                    .pathFilter(pathField.getText())
                    .portee(porteeChoisie())
                    .build();
            fonctionsPro.sauvegarderRecherche(repositoryRoot.toString(), nom.trim(), query);
            chargerRecherchesSauvegardees();
            setStatus("Search saved: " + nom.trim(), false);
        } catch (FonctionProRefuseeException ex) {
            setStatus(ex.getMessage(), true);
        } catch (RuntimeException e) {
            setStatus("Could not save the search: " + e.getMessage(), true);
        }
    }

    /** Remplit la liste des recherches enregistrees (Pro P3). */
    private void chargerRecherchesSauvegardees() {
        List<String> libelles = new ArrayList<>();
        libelles.add("");
        try {
            for (RechercheSauvee recherche : fonctionsPro.recherchesSauvegardees(repositoryRoot.toString())) {
                libelles.add(recherche.getNom());
            }
        } catch (FonctionProRefuseeException ex) {
            // Pas de licence : la liste reste vide, et le message s'affiche
            // des que l'utilisateur tente de s'en servir.
            return;
        } catch (RuntimeException e) {
            return;
        }
        // Le modele de la boite de deroulante est celui de la plateforme
        // (ComboBox de l'IDE) : on le remplit item par item, pour ne pas
        // remplacer son modele interne par un modele Swing nu.
        savedSearchCombo.removeAllItems();
        for (String libelle : libelles) {
            savedSearchCombo.addItem(libelle);
        }
        savedSearchCombo.setSelectedIndex(0);
    }

    /** Charge dans les champs la recherche enregistree selectionnee. */
    private void chargerRechercheSauvee() {
        Object selection = savedSearchCombo.getSelectedItem();
        if (selection == null) {
            return;
        }
        String nom = selection.toString();
        if (nom.isEmpty()) {
            return;
        }
        try {
            for (RechercheSauvee recherche : fonctionsPro.recherchesSauvegardees(repositoryRoot.toString())) {
                if (recherche.getNom().equals(nom)) {
                    needleField.setText(recherche.getChaine());
                    pathField.setText(recherche.getFiltreChemin() == null ? "" : recherche.getFiltreChemin());
                    modeCombo.setSelectedItem(recherche.getMode());
                    setStatus("Search loaded: " + nom, false);
                    return;
                }
            }
        } catch (FonctionProRefuseeException ex) {
            setStatus(ex.getMessage(), true);
        } catch (RuntimeException e) {
            setStatus("Could not load the search: " + e.getMessage(), true);
        }
    }

    /** La portee choisie dans le selecteur (« diffs » par defaut). */
    private PorteeRecherche porteeChoisie() {
        int index = scopeCombo.getSelectedIndex();
        PorteeRecherche[] valeurs = PorteeRecherche.values();
        if (index < 0 || index >= valeurs.length) {
            return PorteeRecherche.DIFFS;
        }
        return valeurs[index];
    }

    private void setStatus(String message, boolean error) {
        statusLabel.setText(message == null || message.isEmpty() ? " " : message);
        statusLabel.setForeground(error
                ? com.intellij.ui.JBColor.RED
                : com.intellij.ui.JBColor.GRAY);
    }

    /** Un resultat affiche : le commit, et le depot quand la recherche est multi-depots. */
    private static final class Entree {
        private final PickaxeHit hit;
        private final String prefixe;

        Entree(PickaxeHit hit, String prefixe) {
            this.hit = hit;
            this.prefixe = prefixe;
        }
    }
}
