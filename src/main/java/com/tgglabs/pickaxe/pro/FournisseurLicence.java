package com.tgglabs.pickaxe.pro;

/**
 * Source de l'etat de la licence Pro.
 *
 * <p>L'interface existe pour que le code Pro soit testable SANS IDE et SANS
 * reseau : les tests injectent une implementation de test (licence presente ou
 * absente), le produit injecte l'implementation reelle qui parle a la
 * Marketplace JetBrains ({@code com.tgglabs.pickaxe.ide.LicenceMarketplace}).</p>
 *
 * <p>Cette interface ne depend QUE de Java : aucune classe de la plateforme
 * IntelliJ n'est mentionnee ici.</p>
 */
public interface FournisseurLicence {

    /**
     * L'etat de la licence du code produit Pro.
     *
     * @return {@link Boolean#TRUE} si une licence active le code produit Pro,
     *         {@link Boolean#FALSE} si aucune licence ne l'active,
     *         {@code null} si l'IDE n'a pas encore initialise la verification
     *         (l'etat est alors INCONNU, pas « pas licencie »).
     */
    Boolean licenceProActive();
}
