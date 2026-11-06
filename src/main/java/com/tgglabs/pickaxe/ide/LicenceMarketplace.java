package com.tgglabs.pickaxe.ide;

import com.intellij.ui.LicensingFacade;
import com.tgglabs.pickaxe.pro.FournisseurLicence;

/**
 * L'etat de la licence Pro, lu dans la Marketplace JetBrains.
 *
 * <p>C'est l'unique endroit du plugin qui parle a la verification de licence
 * de la plateforme. La doc officielle (« Add license verification calls to the
 * plugin code ») dit :</p>
 * <ul>
 *   <li>« *Licenses will first be checked by the IDE on startup. After that,
 *       there will be additional checks at least once a day* » ;</li>
 *   <li>« *all the licensing-related communication, including plugin license
 *       checks, is done on the IntelliJ Platform side* » ;</li>
 *   <li>« *LicensingFacade.getInstance() == null* » signifie que
 *       l'initialisation n'est pas terminee : l'etat est alors INCONNU
 *       (pas « pas licencie »).</li>
 * </ul>
 *
 * <p>Le code produit demande ici est <b>exactement</b> celui du
 * {@code <product-descriptor code="…">} du {@code plugin.xml} : c'est lui que
 * la plateforme associe a la licence achetee.</p>
 *
 * <p>Cette classe est la SEULE qui depend de la plateforme pour la licence :
 * le reste du code Pro ne depend que de l'interface
 * {@link FournisseurLicence}, ce qui permet de le tester hors IDE.</p>
 */
public final class LicenceMarketplace implements FournisseurLicence {

    /**
     * Code produit de l'offre Pro.
     *
     * <p>DOIT etre identique au {@code code} du {@code <product-descriptor>}
     * du {@code plugin.xml} ({@code PPICKAXEPRO}) : c'est la clef que la
     * Marketplace associe a la licence vendue.</p>
     */
    public static final String CODE_PRODUIT = "PPICKAXEPRO";

    @Override
    public Boolean licenceProActive() {
        final LicensingFacade facade = LicensingFacade.getInstance();
        if (facade == null) {
            // L'IDE n'a pas encore initialise la verification : l'etat est
            // INCONNU, il ne doit pas etre confondu avec « pas licencie ».
            return null;
        }
        final String stamp = facade.getConfirmationStamp(CODE_PRODUIT);
        if (stamp == null || stamp.trim().isEmpty()) {
            // Pas de « licensing stamp » = licence manquante pour ce code
            // produit (doc officielle : l'absence de stamp = licence absente).
            return Boolean.FALSE;
        }
        return Boolean.TRUE;
    }
}
