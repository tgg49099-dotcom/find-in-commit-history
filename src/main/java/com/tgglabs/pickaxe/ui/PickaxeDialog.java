package com.tgglabs.pickaxe.ui;

import com.intellij.openapi.application.ApplicationManager;
import com.intellij.openapi.application.ModalityState;
import com.intellij.openapi.progress.ProgressIndicator;
import com.intellij.openapi.progress.ProgressManager;
import com.intellij.openapi.progress.Task;
import com.intellij.openapi.project.Project;
import com.intellij.openapi.ui.ComboBox;
import com.intellij.openapi.ui.DialogWrapper;
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
import org.eclipse.jgit.lib.Repository;
import org.jetbrains.annotations.NotNull;
import org.jetbrains.annotations.Nullable;

import javax.swing.AbstractAction;
import javax.swing.Action;
import javax.swing.DefaultListModel;
import javax.swing.JComponent;
import javax.swing.JPanel;
import javax.swing.ListModel;
import java.awt.BorderLayout;
import java.awt.GridBagConstraints;
import java.awt.GridBagLayout;
import java.awt.Insets;
import java.io.IOException;
import java.nio.file.Path;
import java.util.List;

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
 */
public class PickaxeDialog extends DialogWrapper {

    private final Project project;
    private final Path repositoryRoot;

    private final JBTextField needleField = new JBTextField();
    private final JBTextField pathField = new JBTextField();
    private final ComboBox<PickaxeMode> modeCombo =
            new ComboBox<>(new PickaxeMode[]{PickaxeMode.STRING, PickaxeMode.REGEX});
    private final JBList<String> resultList = new JBList<>();
    private final JBLabel statusLabel = new JBLabel(" ");

    public PickaxeDialog(@Nullable Project project, @NotNull Path repositoryRoot) {
        super(project, false);
        this.project = project;
        this.repositoryRoot = repositoryRoot;
        setTitle("Find in Commit History");
        init();
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
        form.add(new JBLabel("Path filter (optional):"), c);
        c.gridx = 1;
        c.weightx = 1;
        c.fill = GridBagConstraints.HORIZONTAL;
        form.add(pathField, c);

        ListModel<String> model = new DefaultListModel<>();
        resultList.setModel(model);
        JBScrollPane scroll = new JBScrollPane(resultList);
        scroll.setPreferredSize(new java.awt.Dimension(520, 220));

        JPanel root = new JPanel(new BorderLayout(0, 6));
        root.add(form, BorderLayout.NORTH);
        root.add(scroll, BorderLayout.CENTER);
        root.add(statusLabel, BorderLayout.SOUTH);
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
        // Modalite capturee sur l'EDT : le resultat sera applique dans le meme
        // etat de modalite (ce dialogue est modal).
        final ModalityState modality = ModalityState.defaultModalityState();

        setStatus("Searching…", false);
        ProgressManager.getInstance().run(new Task.Backgroundable(
                project, "Searching Git history", true) {
            @Override
            public void run(@NotNull ProgressIndicator indicator) {
                indicator.setIndeterminate(true);
                final List<PickaxeHit> hits;
                try {
                    hits = search(needle, mode, pathFilter);
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
                ApplicationManager.getApplication().invokeLater(() -> showResults(hits), modality);
            }

            @Override
            public void onCancel() {
                setStatus("Search cancelled.", false);
            }
        });
    }

    /** Applique le resultat au modele. Appele sur l'EDT. */
    private void showResults(List<PickaxeHit> hits) {
        DefaultListModel<String> model = new DefaultListModel<>();
        for (PickaxeHit hit : hits) {
            model.addElement(hit.getShortId() + "  " + hit.getSubject()
                    + (hit.getPaths().isEmpty() ? "" : "  [" + String.join(", ", hit.getPaths()) + "]"));
        }
        resultList.setModel(model);
        setStatus(hits.size() + (hits.size() == 1 ? " commit found." : " commits found."), false);
    }

    /**
     * Ouvre le depot et cherche les commits. Appele sur un thread de fond.
     *
     * <p>L'ouverture passe par {@link PickaxeRepository#open(Path)} : c'est
     * le SEUL endroit ou le depot est construit (le repertoire Git est
     * resolu par {@link GitRepositoryLocator}, qui sait lire le fichier
     * {@code .git} d'un worktree), et c'est aussi le chemin couvert par le
     * test de regression.</p>
     */
    private List<PickaxeHit> search(String needle, PickaxeMode mode, String pathFilter)
            throws PickaxeException {
        try (Repository repository = PickaxeRepository.open(repositoryRoot)) {
            PickaxeEngine engine = new PickaxeEngine(repository);
            PickaxeQuery query = PickaxeQuery.builder(mode, needle)
                    .pathFilter(pathFilter)
                    .build();
            return engine.search(query);
        } catch (IOException e) {
            // `FileRepositoryBuilder.build()` leve une IOException controlee :
            // on la transforme en PickaxeException pour que l'IDE ne voie
            // jamais d'exception brute (voir runSearch()).
            throw new PickaxeException("Unable to open the Git repository at "
                    + repositoryRoot + ": " + e.getMessage(), e);
        }
    }

    private void setStatus(String message, boolean error) {
        statusLabel.setText(message == null || message.isEmpty() ? " " : message);
        statusLabel.setForeground(error
                ? com.intellij.ui.JBColor.RED
                : com.intellij.ui.JBColor.GRAY);
    }
}
