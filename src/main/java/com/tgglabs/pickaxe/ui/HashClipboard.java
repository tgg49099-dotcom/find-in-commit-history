package com.tgglabs.pickaxe.ui;

import com.tgglabs.pickaxe.engine.PickaxeHit;

import java.util.List;

/**
 * Presse-papier : copie le hash d'un commit.
 *
 * <p>Cette classe ne depend QUE de l'engine : AUCUN appel a l'API de la
 * plateforme IntelliJ, et surtout AUCUN appel a {@code com.intellij.vcs.log}
 * ni au plugin Git (le Plugin Verifier le signalerait comme une dependance
 * tierce). Elle est donc compilable et testable HORS IDE, comme toute la
 * suite executee par {@code scripts/run_tests.sh}.</p>
 *
 * <p>La destination du texte copié est INJECTEE ({@link Sink}) : l'IDE
 * fournit une implementation qui ecrit dans le presse-papier systeme, les
 * tests fournissent une implementation qui memorise ce qui a ete copie.
 * L'UI ne contient ainsi aucun code metier : elle ne fait qu'appeler
 * {@link #copyHashAt(List, int)}.</p>
 */
public final class HashClipboard {

    /** Destination du texte copie (le presse-papier, reellement). */
    public interface Sink {
        void put(String text);
    }

    private final Sink sink;

    public HashClipboard(Sink sink) {
        if (sink == null) {
            throw new IllegalArgumentException("sink must not be null");
        }
        this.sink = sink;
    }

    /**
     * Copie le hash du resultat numero {@code index} (0-based) dans le
     * presse-papier.
     *
     * @param hits  les resultats affiches (dans l'ordre de la liste)
     * @param index l'index du resultat choisi
     * @return true si le hash a ete copie, false si rien n'a ete copie
     *         (aucune selection, index hors limites, hash vide)
     */
    public boolean copyHashAt(List<PickaxeHit> hits, int index) {
        String hash = hashAt(hits, index);
        if (hash == null) {
            return false;
        }
        sink.put(hash);
        return true;
    }

    /**
     * Le hash (identifiant COMPLET du commit) du resultat numero
     * {@code index}, ou null si ce resultat n'existe pas.
     *
     * <p>On copie l'identifiant complet et non l'abrege : git accepte les
     * deux, mais l'identifiant complet est le seul qui soit non ambigu.</p>
     */
    public static String hashAt(List<PickaxeHit> hits, int index) {
        if (hits == null || index < 0 || index >= hits.size()) {
            return null;
        }
        PickaxeHit hit = hits.get(index);
        if (hit == null) {
            return null;
        }
        String commitId = hit.getCommitId();
        if (commitId == null) {
            return null;
        }
        String trimmed = commitId.trim();
        return trimmed.isEmpty() ? null : trimmed;
    }
}
