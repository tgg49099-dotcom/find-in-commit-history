package com.tgglabs.pickaxe.ui;

import com.intellij.openapi.actionSystem.AnAction;
import com.intellij.openapi.actionSystem.AnActionEvent;
import com.intellij.openapi.project.Project;
import com.intellij.openapi.ui.Messages;
import com.tgglabs.pickaxe.GitRepositoryLocator;
import org.jetbrains.annotations.NotNull;

import java.nio.file.Path;

/**
 * Action « Find in Commit History… » : ouvre le dialogue de recherche dans
 * l'historique Git du projet.
 *
 * <p>L'action est branchee sur le moteur pickaxe (elle ouvre le dialogue qui
 * l'appelle) : c'est la preuve que le moteur n'est pas du code mort.</p>
 */
public class FindInHistoryAction extends AnAction {

    @Override
    public void actionPerformed(@NotNull AnActionEvent e) {
        Project project = e.getProject();
        if (project == null) {
            return;
        }
        String basePath = project.getBasePath();
        Path repositoryRoot = GitRepositoryLocator.findRepositoryRoot(basePath);
        if (repositoryRoot == null) {
            Messages.showWarningDialog(project,
                    "No Git repository was found for this project.\n"
                            + "Open a project that is inside a Git working copy.",
                    "Find in Commit History");
            return;
        }
        PickaxeDialog dialog = new PickaxeDialog(project, repositoryRoot);
        dialog.show();
    }

    @Override
    public void update(@NotNull AnActionEvent e) {
        e.getPresentation().setEnabled(e.getProject() != null);
    }
}
