package com.tgglabs.pickaxe.ide;

import com.tgglabs.pickaxe.pro.LicenceEtat;

/**
 * Construction de l'etat de licence utilise par le plugin.
 *
 * <p>Isolé ici pour que {@link LicenceEtat} (le code testable) ne depende
 * JAMAIS de la plateforme : l'IDE est le seul a appeler cette fabrique.</p>
 */
public final class LicenceEtatIDE {

    private LicenceEtatIDE() {
    }

    /** L'etat de licence reel, base sur la Marketplace JetBrains. */
    public static LicenceEtat parDefaut() {
        return new LicenceEtat(new LicenceMarketplace());
    }
}
