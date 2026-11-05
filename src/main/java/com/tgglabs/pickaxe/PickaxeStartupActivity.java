package com.tgglabs.pickaxe;

import com.intellij.openapi.diagnostic.Logger;
import com.intellij.openapi.project.Project;
import com.intellij.openapi.startup.StartupActivity;
import com.tgglabs.pickaxe.engine.PickaxeEngine;
import org.jetbrains.annotations.NotNull;

/**
 * Tache de demarrage : journalise que le moteur pickaxe est pret, avec la
 * version de JGit reellement chargee.
 *
 * <p>Cette ligne est la PREUVE que la bibliotheque git du moteur se charge
 * dans un vrai IDE (et pas seulement dans les tests).</p>
 */
public class PickaxeStartupActivity implements StartupActivity.Background {

    private static final Logger LOG = Logger.getInstance(PickaxeStartupActivity.class);

    @Override
    public void runActivity(@NotNull Project project) {
        LOG.info("Pickaxe: engine ready (JGit " + PickaxeEngine.jgitVersion() + ")");
    }
}
