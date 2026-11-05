package com.tgglabs.pickaxe.ui;

import com.tgglabs.pickaxe.engine.PickaxeHit;
import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Test;

import java.util.ArrayList;
import java.util.Arrays;
import java.util.Collections;
import java.util.List;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertFalse;
import static org.junit.jupiter.api.Assertions.assertNull;
import static org.junit.jupiter.api.Assertions.assertTrue;

/**
 * Tests de {@link HashClipboard} — la fonction « double-clic = copier le
 * hash » et le bouton « Copy hash ».
 *
 * <p>Ces tests tournent HORS IDE (suite {@code scripts/run_tests.sh}) : la
 * classe testee ne depend que de l'engine, le presse-papier est simule par
 * un {@link HashClipboard.Sink} qui memorise le texte copie. Ce qui est
 * verifie ici est donc exactement ce que fait le bouton et le double-clic :
 * le texte mis dans le presse-papier est le hash du resultat vise.</p>
 */
class HashClipboardTest {

    /** Presse-papier simule : memorise tout ce qui est copie. */
    private static final class RecordingSink implements HashClipboard.Sink {
        final List<String> copied = new ArrayList<>();

        @Override
        public void put(String text) {
            copied.add(text);
        }
    }

    private static PickaxeHit hit(String commitId) {
        return new PickaxeHit(commitId, "feat: un changement", "Auteur", 0L, Collections.emptyList());
    }

    private static List<PickaxeHit> threeHits() {
        return Arrays.asList(
                hit("1111111111111111111111111111111111111111"),
                hit("2222222222222222222222222222222222222222"),
                hit("3333333333333333333333333333333333333333"));
    }

    @Test
    @DisplayName("double-clic sur un resultat : le hash COMPLET de ce resultat est copie")
    void copiesTheFullHashOfTheSelectedResult() {
        RecordingSink sink = new RecordingSink();
        HashClipboard clipboard = new HashClipboard(sink);

        boolean copied = clipboard.copyHashAt(threeHits(), 1);

        assertTrue(copied, "le double-clic doit copier le hash du resultat vise");
        assertEquals(1, sink.copied.size(), "exactement un texte doit etre copie");
        assertEquals("2222222222222222222222222222222222222222", sink.copied.get(0),
                "le texte copie est le hash COMPLET du resultat vise");
    }

    @Test
    @DisplayName("aucune selection : rien n'est copie (le presse-papier reste intact)")
    void copiesNothingWhenNoRowIsSelected() {
        RecordingSink sink = new RecordingSink();
        HashClipboard clipboard = new HashClipboard(sink);

        boolean copied = clipboard.copyHashAt(threeHits(), -1);

        assertFalse(copied, "sans selection, rien ne doit etre copie");
        assertTrue(sink.copied.isEmpty(), "le presse-papier ne doit pas etre touche");
    }

    @Test
    @DisplayName("index hors limites : rien n'est copie")
    void copiesNothingWhenIndexIsOutOfRange() {
        RecordingSink sink = new RecordingSink();
        HashClipboard clipboard = new HashClipboard(sink);

        assertFalse(clipboard.copyHashAt(threeHits(), 3));
        assertFalse(clipboard.copyHashAt(threeHits(), 99));
        assertFalse(clipboard.copyHashAt(threeHits(), -2));
        assertTrue(sink.copied.isEmpty());
    }

    @Test
    @DisplayName("liste vide ou nulle : rien n'est copie")
    void copiesNothingWhenThereIsNoResult() {
        RecordingSink sink = new RecordingSink();
        HashClipboard clipboard = new HashClipboard(sink);

        assertFalse(clipboard.copyHashAt(Collections.emptyList(), 0));
        assertFalse(clipboard.copyHashAt(null, 0));
        assertTrue(sink.copied.isEmpty());
    }

    @Test
    @DisplayName("chaque resultat a SON hash : copier le 1er ne copie pas celui du 2e")
    void eachResultHasItsOwnHash() {
        RecordingSink sink = new RecordingSink();
        HashClipboard clipboard = new HashClipboard(sink);
        List<PickaxeHit> hits = threeHits();

        clipboard.copyHashAt(hits, 0);
        clipboard.copyHashAt(hits, 2);

        assertEquals(Arrays.asList(
                "1111111111111111111111111111111111111111",
                "3333333333333333333333333333333333333333"), sink.copied);
    }

    @Test
    @DisplayName("un resultat sans hash : rien n'est copie")
    void copiesNothingWhenTheCommitHasNoHash() {
        RecordingSink sink = new RecordingSink();
        HashClipboard clipboard = new HashClipboard(sink);

        assertFalse(clipboard.copyHashAt(Arrays.asList(hit("   ")), 0));
        assertFalse(clipboard.copyHashAt(Arrays.asList(hit(null)), 0));
        assertTrue(sink.copied.isEmpty());
        assertNull(HashClipboard.hashAt(Arrays.asList(hit(null)), 0));
    }
}
