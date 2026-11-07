package com.tgglabs.pickaxe.pro;

import com.tgglabs.pickaxe.engine.PickaxeHit;

import java.time.Instant;
import java.util.ArrayList;
import java.util.Collections;
import java.util.List;

/**
 * Mise en forme des resultats pour l'export (fonction Pro P2).
 *
 * <p>Trois formats :</p>
 * <ul>
 *   <li><b>CSV</b> — une ligne par commit : hash, date, auteur, sujet,
 *       chemins. Les guillemets sont doubles (RFC 4180) : un message de
 *       commit contenant une virgule ou un retour a la ligne ne casse pas
 *       le fichier.</li>
 *   <li><b>Markdown</b> — un tableau, pret a etre colle dans une revue de
 *       code.</li>
 *   <li><b>Liste de patchs</b> — une commande {@code git show <hash>} par
 *       resultat : la selection se rejoue dans un terminal.</li>
 * </ul>
 *
 * <p>Le code ne depend QUE de Java : il est testable hors IDE.</p>
 */
public final class ExportResultats {

    private ExportResultats() {
    }

    /**
     * Formate les resultats dans le format demande.
     *
     * @param hits   les resultats a exporter (peut etre vide)
     * @param format le format vise
     * @return le contenu du fichier a ecrire
     */
    public static String formater(List<PickaxeHit> hits, FormatExport format) {
        if (format == null) {
            throw new IllegalArgumentException("format must not be null");
        }
        List<PickaxeHit> liste = hits == null ? Collections.emptyList() : hits;
        switch (format) {
            case CSV:
                return enCsv(liste);
            case MARKDOWN:
                return enMarkdown(liste);
            case PATCHES:
                return listePatchs(liste);
            default:
                throw new IllegalArgumentException("Unsupported format: " + format);
        }
    }

    /** Export CSV (RFC 4180). */
    public static String enCsv(List<PickaxeHit> hits) {
        StringBuilder out = new StringBuilder();
        out.append("hash,date,author,subject,paths\n");
        for (PickaxeHit hit : hits) {
            out.append(csv(hit.getCommitId())).append(',')
                    .append(csv(dateIso(hit.getAuthorTimestampMillis()))).append(',')
                    .append(csv(hit.getAuthorName())).append(',')
                    .append(csv(hit.getSubject())).append(',')
                    .append(csv(String.join(" | ", hit.getPaths())))
                    .append('\n');
        }
        return out.toString();
    }

    /** Export Markdown (un tableau). */
    public static String enMarkdown(List<PickaxeHit> hits) {
        StringBuilder out = new StringBuilder();
        out.append("| Hash | Date | Author | Subject | Paths |\n");
        out.append("|---|---|---|---|---|\n");
        for (PickaxeHit hit : hits) {
            out.append("| ").append(md(hit.getShortId())).append(" | ")
                    .append(md(dateIso(hit.getAuthorTimestampMillis()))).append(" | ")
                    .append(md(hit.getAuthorName())).append(" | ")
                    .append(md(hit.getSubject())).append(" | ")
                    .append(md(String.join(", ", hit.getPaths()))).append(" |\n");
        }
        return out.toString();
    }

    /** Liste de patchs : une commande {@code git show} par resultat. */
    public static String listePatchs(List<PickaxeHit> hits) {
        StringBuilder out = new StringBuilder();
        for (PickaxeHit hit : hits) {
            out.append("git show ").append(hit.getCommitId()).append('\n');
        }
        return out.toString();
    }

    /** Date ISO-8601 (UTC) du commit. */
    static String dateIso(long millis) {
        return Instant.ofEpochMilli(millis).toString();
    }

    /** Champ CSV echappe (guillemets doublés, guillemets autour si besoin). */
    static String csv(String value) {
        String v = value == null ? "" : value;
        boolean besoinDeGuillemets = v.indexOf(',') >= 0
                || v.indexOf('"') >= 0
                || v.indexOf('\n') >= 0
                || v.indexOf('\r') >= 0;
        if (!besoinDeGuillemets) {
            return v;
        }
        StringBuilder out = new StringBuilder(v.length() + 2);
        out.append('"');
        for (int i = 0; i < v.length(); i++) {
            char c = v.charAt(i);
            if (c == '"') {
                out.append('"');
            }
            out.append(c);
        }
        out.append('"');
        return out.toString();
    }

    /** Cellule Markdown : le separateur de colonnes est neutralise. */
    static String md(String value) {
        String v = value == null ? "" : value;
        return v.replace("|", "\\|").replace("\r", " ").replace("\n", " ");
    }

    /** Liste defensive (les hits sont deja immuables, la liste ne l'est pas). */
    static List<PickaxeHit> copie(List<PickaxeHit> hits) {
        return hits == null ? new ArrayList<>() : new ArrayList<>(hits);
    }
}
