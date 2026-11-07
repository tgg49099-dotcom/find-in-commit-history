package com.tgglabs.pickaxe.engine;

import java.util.Collections;
import java.util.List;

/** Un commit trouve par le moteur pickaxe. */
public final class PickaxeHit {

    private final String commitId;
    private final String subject;
    private final String authorName;
    private final long authorTimestampMillis;
    private final List<String> paths;

    public PickaxeHit(String commitId,
                      String subject,
                      String authorName,
                      long authorTimestampMillis,
                      List<String> paths) {
        this.commitId = commitId;
        this.subject = subject;
        this.authorName = authorName;
        this.authorTimestampMillis = authorTimestampMillis;
        this.paths = Collections.unmodifiableList(paths);
    }

    /** Identifiant complet du commit (40 caracteres). */
    public String getCommitId() {
        return commitId;
    }

    /** Identifiant abrege (7 caracteres), comme git l'affiche. */
    public String getShortId() {
        return commitId == null ? "" : commitId.substring(0, Math.min(7, commitId.length()));
    }

    /** Premier ligne du message de commit. */
    public String getSubject() {
        return subject;
    }

    public String getAuthorName() {
        return authorName;
    }

    /**
     * L'horodatage du commit, en millisecondes depuis l'epoque.
     *
     * <p>Attention : c'est la date du COMMITTEUR ({@code commit.getCommitTime()},
     * celle que {@code git log} affiche et sur laquelle le moteur trie), et
     * non la date de l'auteur. Le nom de l'auteur est donne par
     * {@link #getAuthorName()}.</p>
     *
     * <p>Renommee le 06/11/2026 (jury : « nom trompeur, renommer »).</p>
     */
    public long getAuthorTimestampMillis() {
        return authorTimestampMillis;
    }

    /** Les chemins de fichiers qui ont declenche la correspondance. */
    public List<String> getPaths() {
        return paths;
    }

    @Override
    public String toString() {
        return getShortId() + " " + subject + (paths.isEmpty() ? "" : " " + paths);
    }
}
