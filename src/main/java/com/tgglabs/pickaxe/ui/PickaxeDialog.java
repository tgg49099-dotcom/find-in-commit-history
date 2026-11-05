package com.tgglabs.pickaxe.ui;

import com.intellij.openapi.project.Project;
import com.intellij.openapi.ui.ComboBox;
import com.intellij.openapi.ui.DialogWrapper;
import com.intellij.ui.components.JBList;
import com.intellij.ui.components.JBLabel;
import com.intellij.ui.components.JBScrollPane;
import com.intellij.ui.components.JBTextField;
import com.tgglabs.pickaxe.engine.PickaxeEngine;
import com.tgglabs.pickaxe.engine.PickaxeException;
import com.tgglabs.pickaxe.engine.PickaxeHit;
import com.tgglabs.pickaxe.engine.PickaxeMode;
import com.tgglabs.pickaxe.engine.PickaxeQuery;
import org.eclipse.jgit.lib.Constants;
import org.eclipse.jgit.lib.Repository;
import org.eclipse.jgit.storage.file.FileRepositoryBuilder;
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
 */
public class PickaxeDialog extends DialogWrapper {

    private final Path repositoryRoot;

    private final JBTextField needleField = new JBTextField();
    private final JBTextField pathField = new JBTextField();
    private final ComboBox<PickaxeMode> modeCombo =
            new ComboBox<>(new PickaxeMode[]{PickaxeMode.STRING, PickaxeMode.REGEX});
    private final JBList<String> resultList = new JBList<>();
    private final JBLabel statusLabel = new JBLabel(" ");

    public PickaxeDialog(@Nullable Project project, @NotNull Path repositoryRoot) {
        super(project, false);
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
        return new Action[]{new SearchAction(), getCancelAction()};
    }

    /** Bouton « Search » : lance la recherche et garde le dialogue ouvert. */
    private class SearchAction extends AbstractAction {
        SearchAction() {
            super("Search");
        }

        @Override
        public void actionPerformed(java.awt.event.ActionEvent e) {
            runSearch();
        }
    }

    /** Lance la recherche. Ne leve jamais d'exception vers l'IDE. */
    private void runSearch() {
        String needle = needleField.getText();
        if (needle == null || needle.trim().isEmpty()) {
            setStatus(PickaxeQuery.EMPTY_NEEDLE_MESSAGE, true);
            return;
        }
        setStatus("Searching…", false);
        try {
            List<PickaxeHit> hits = search(needle);
            DefaultListModel<String> model = new DefaultListModel<>();
            for (PickaxeHit hit : hits) {
                model.addElement(hit.getShortId() + "  " + hit.getSubject()
                        + (hit.getPaths().isEmpty() ? "" : "  [" + String.join(", ", hit.getPaths()) + "]"));
            }
            resultList.setModel(model);
            setStatus(hits.size() + (hits.size() == 1 ? " commit found." : " commits found."), false);
        } catch (PickaxeException ex) {
            setStatus(ex.getMessage() == null ? "Search failed." : ex.getMessage(), true);
        } catch (RuntimeException ex) {
            // Filet de securite : l'IDE ne doit jamais voir une exception
            // brute issue d'une action utilisateur.
            setStatus("Search failed: " + ex.getClass().getSimpleName()
                    + (ex.getMessage() == null ? "" : " — " + ex.getMessage()), true);
        }
    }

    private List<PickaxeHit> search(String needle) throws PickaxeException {
        try (Repository repository = new FileRepositoryBuilder()
                .setGitDir(repositoryRoot.resolve(Constants.DOT_GIT).toFile())
                .readEnvironment()
                .findGitDir()
                .build()) {
            PickaxeEngine engine = new PickaxeEngine(repository);
            PickaxeQuery query = PickaxeQuery.builder(
                    (PickaxeMode) modeCombo.getSelectedItem(), needle)
                    .pathFilter(pathField.getText())
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
