package com.tgglabs.pickaxe.engine;

import java.util.regex.Pattern;
import java.util.regex.PatternSyntaxException;

/**
 * Description immuable d'une recherche pickaxe.
 *
 * <p>Construite avec {@link #builder(PickaxeMode, String)}. La validation est
 * faite ici, pas dans le moteur : une requete invalide ne doit jamais
 * atteindre le code qui lit le depot.</p>
 */
public final class PickaxeQuery {

    /** Message d'erreur pour une chaine vide (utilise par l'interface). */
    public static final String EMPTY_NEEDLE_MESSAGE = "The search string must not be empty.";

    private final PickaxeMode mode;
    private final String needle;
    private final String pathFilter;
    private final boolean includeBinary;
    private final int maxResults;

    private PickaxeQuery(Builder builder) {
        this.mode = builder.mode;
        this.needle = builder.needle;
        this.pathFilter = builder.pathFilter;
        this.includeBinary = builder.includeBinary;
        this.maxResults = builder.maxResults;
    }

    public static Builder builder(PickaxeMode mode, String needle) {
        return new Builder(mode, needle);
    }

    public PickaxeMode getMode() {
        return mode;
    }

    public String getNeedle() {
        return needle;
    }

    /** Filtre de chemin (expression reguliere), ou {@code null} si aucun. */
    public String getPathFilter() {
        return pathFilter;
    }

    /** {@code true} si les fichiers binaires sont pris en compte. */
    public boolean isIncludeBinary() {
        return includeBinary;
    }

    public int getMaxResults() {
        return maxResults;
    }

    /** Le filtre de chemin compile, ou {@code null}. */
    Pattern compiledPathFilter() {
        if (pathFilter == null || pathFilter.isEmpty()) {
            return null;
        }
        try {
            return Pattern.compile(pathFilter);
        } catch (PatternSyntaxException e) {
            throw new IllegalArgumentException("Invalid path filter: " + e.getMessage(), e);
        }
    }

    /** L'expression reguliere du mode REGEX compilee, ou {@code null}. */
    Pattern compiledRegex() {
        if (mode != PickaxeMode.REGEX) {
            return null;
        }
        try {
            return Pattern.compile(needle);
        } catch (PatternSyntaxException e) {
            throw new IllegalArgumentException("Invalid regular expression: " + e.getMessage(), e);
        }
    }

    @Override
    public String toString() {
        return "PickaxeQuery{mode=" + mode
                + ", needle=" + needle
                + ", pathFilter=" + pathFilter
                + ", includeBinary=" + includeBinary
                + ", maxResults=" + maxResults
                + '}';
    }

    /** Constructeur de {@link PickaxeQuery}, avec validation. */
    public static final class Builder {

        private final PickaxeMode mode;
        private final String needle;
        private String pathFilter;
        private boolean includeBinary = false;
        private int maxResults = 500;

        private Builder(PickaxeMode mode, String needle) {
            if (mode == null) {
                throw new IllegalArgumentException("mode must not be null");
            }
            if (needle == null || needle.isEmpty()) {
                throw new IllegalArgumentException(EMPTY_NEEDLE_MESSAGE);
            }
            this.mode = mode;
            this.needle = needle;
        }

        /** Ne garder que les fichiers dont le chemin matche cette expression. */
        public Builder pathFilter(String pathFilter) {
            this.pathFilter = pathFilter;
            return this;
        }

        /**
         * Inclure les fichiers binaires.
         *
         * <p>Par defaut ils sont IGNORES : le diff d'un binaire n'est pas du
         * texte, et compter des occurrences dans des octets arbitraires
         * produirait des faux positifs.</p>
         */
        public Builder includeBinary(boolean includeBinary) {
            this.includeBinary = includeBinary;
            return this;
        }

        /** Nombre maximum de commits renvoyes. */
        public Builder maxResults(int maxResults) {
            if (maxResults <= 0) {
                throw new IllegalArgumentException("maxResults must be greater than 0");
            }
            this.maxResults = maxResults;
            return this;
        }

        public PickaxeQuery build() {
            // Les expressions sont compilees ici pour que l'erreur soit
            // levee AVANT toute lecture du depot.
            PickaxeQuery query = new PickaxeQuery(this);
            query.compiledPathFilter();
            query.compiledRegex();
            return query;
        }
    }
}
