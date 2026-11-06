package com.tgglabs.pickaxe.pro;

/** Formats d'export des resultats (fonction Pro P2). */
public enum FormatExport {

    /** CSV : hash, date, auteur, sujet, chemins. */
    CSV("CSV"),

    /** Markdown : tableau pret pour une revue de code. */
    MARKDOWN("Markdown"),

    /** Liste de patchs : une commande par resultat, a coller dans un terminal. */
    PATCHES("Liste de patchs");

    private final String libelle;

    FormatExport(String libelle) {
        this.libelle = libelle;
    }

    /** Le libelle affiche dans l'interface. */
    public String libelle() {
        return libelle;
    }

    /** L'extension de fichier conseillee. */
    public String extension() {
        switch (this) {
            case CSV:
                return "csv";
            case MARKDOWN:
                return "md";
            default:
                return "txt";
        }
    }
}
