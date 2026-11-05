package com.tgglabs.pickaxe.engine;

import org.eclipse.jgit.api.Git;
import org.eclipse.jgit.api.errors.GitAPIException;
import org.eclipse.jgit.lib.Constants;
import org.eclipse.jgit.lib.PersonIdent;
import org.eclipse.jgit.lib.Repository;

import java.io.IOException;
import java.nio.charset.StandardCharsets;
import java.nio.file.Files;
import java.nio.file.Path;
import java.util.ArrayList;
import java.util.Date;
import java.util.List;
import java.util.TimeZone;

/**
 * Depot de test du moteur pickaxe.
 *
 * <p>Il est ecrit a la main (contenu des fichiers, messages de commit,
 * dates) et construit avec JGit, sans dependre du binaire {@code git} : les
 * tests sont donc hermetiques et reproductibles.</p>
 *
 * <p>Les six commits couvrent chacun un cas :</p>
 * <table>
 *   <caption>Commits du depot de test</caption>
 *   <tr><th>#</th><th>message</th><th>cas couvert</th></tr>
 *   <tr><td>1</td><td>init: add app and readme</td><td>ajout (et deux occurrences de « wörld »)</td></tr>
 *   <tr><td>2</td><td>feat: add the configuration file</td><td>ajout de la chaine cherchée</td></tr>
 *   <tr><td>3</td><td>style: annotate the token line</td><td>réécriture à l'identique (le PIEGE)</td></tr>
 *   <tr><td>4</td><td>chore: add a binary asset</td><td>ajout dans un fichier binaire</td></tr>
 *   <tr><td>5</td><td>refactor: rename config.py to settings.py</td><td>renommage sans changement</td></tr>
 *   <tr><td>6</td><td>fix: remove the token line</td><td>suppression (et une occurrence de « wörld »)</td></tr>
 * </table>
 */
public final class TestRepository {

    /** Chaine cherchee dans la plupart des tests. */
    public static final String NEEDLE = "s3cret-needle";

    /** Chaine unicode, presente deux fois puis une fois. */
    public static final String UNICODE_NEEDLE = "wörld";

    /** Chaine simple, ajoutee une seule fois. */
    public static final String SIMPLE_NEEDLE = "hello";

    /** Messages de commit, dans l'ordre chronologique. */
    public static final String SUBJECT_INIT = "init: add app and readme";
    public static final String SUBJECT_ADD = "feat: add the configuration file";
    public static final String SUBJECT_REWRITE = "style: annotate the token line";
    public static final String SUBJECT_BINARY = "chore: add a binary asset";
    public static final String SUBJECT_RENAME = "refactor: rename config.py to settings.py";
    public static final String SUBJECT_REMOVE = "fix: remove the token line";

    /** Un commit du depot de test. */
    public static final class Commit {
        private final String id;
        private final String subject;

        Commit(String id, String subject) {
            this.id = id;
            this.subject = subject;
        }

        public String getId() {
            return id;
        }

        public String getSubject() {
            return subject;
        }
    }

    private TestRepository() {
    }

    /**
     * Construit le depot de test dans {@code directory}.
     *
     * @return les commits crees, du plus ancien au plus recent
     */
    public static List<Commit> build(Path directory) throws GitAPIException, IOException {
        Files.createDirectories(directory);
        List<Commit> commits = new ArrayList<>();

        try (Git git = Git.init().setDirectory(directory.toFile()).call()) {
            Repository repository = git.getRepository();

            // ---- commit 1 : ajout de l'application et du README -------------
            write(directory.resolve("src/app.py"),
                    "def main():\n"
                            + "    print(\"hello\")\n");
            write(directory.resolve("README.md"),
                    "# Alpha\n"
                            + "\n"
                            + "Le monde wörld wörld.\n");
            commits.add(commit(git, SUBJECT_INIT, 1));

            // ---- commit 2 : ajout du fichier de configuration ---------------
            write(directory.resolve("src/config.py"),
                    "TOKEN = \"" + NEEDLE + "\"\n"
                            + "TIMEOUT = 30\n");
            commits.add(commit(git, SUBJECT_ADD, 2));

            // ---- commit 3 : réécriture À L'IDENTIQUE ------------------------
            // La ligne contient deja la chaine ; on ne fait qu'ajouter un
            // commentaire. Le NOMBRE d'occurrences ne change pas : ce commit
            // ne doit PAS remonter en mode -S. C'est le piege : une
            // implementation qui cherche la chaine dans le diff le
            // remonterait a tort.
            write(directory.resolve("src/config.py"),
                    "TOKEN = \"" + NEEDLE + "\"  # noqa\n"
                            + "TIMEOUT = 30\n");
            commits.add(commit(git, SUBJECT_REWRITE, 3));

            // ---- commit 4 : ajout d'un fichier BINAIRE ----------------------
            // Le binaire contient TOUTE la chaine (comme un vrai fichier
            // binaire qui embarquerait ce texte), mais il contient aussi un
            // octet nul : il est binaire, donc ignore (mode -S et mode -G)
            // sauf si l'utilisateur demande explicitement les binaires.
            byte[] header = {'P', 'N', 'G', 0, 1, 2};
            byte[] needle = NEEDLE.getBytes(StandardCharsets.UTF_8);
            byte[] binary = new byte[header.length + needle.length + 3];
            System.arraycopy(header, 0, binary, 0, header.length);
            System.arraycopy(needle, 0, binary, header.length, needle.length);
            binary[header.length + needle.length] = 0;
            binary[header.length + needle.length + 1] = (byte) 0xFF;
            binary[header.length + needle.length + 2] = (byte) 0xFE;
            writeBytes(directory.resolve("assets/logo.bin"), binary);
            commits.add(commit(git, SUBJECT_BINARY, 4));

            // ---- commit 5 : renommage SANS changement de contenu -------------
            // Le contenu est strictement identique : un renommage ne doit
            // pas remonter.
            git.rm().addFilepattern("src/config.py").call();
            write(directory.resolve("src/settings.py"),
                    "TOKEN = \"" + NEEDLE + "\"  # noqa\n"
                            + "TIMEOUT = 30\n");
            git.add().addFilepattern("src/settings.py").call();
            commits.add(commit(git, SUBJECT_RENAME, 5));

            // ---- commit 6 : suppression -------------------------------------
            // La ligne qui contient la chaine disparait, et l'une des deux
            // occurrences de la chaine unicode disparait aussi.
            write(directory.resolve("src/settings.py"),
                    "TIMEOUT = 30\n");
            write(directory.resolve("README.md"),
                    "# Alpha\n"
                            + "\n"
                            + "Le monde wörld.\n");
            commits.add(commit(git, SUBJECT_REMOVE, 6));

            repository.close();
        }
        return commits;
    }

    private static Commit commit(Git git, String message, int index) throws GitAPIException, IOException {
        // `git add .` : ajoute les nouveaux fichiers ET les fichiers
        // modifies. Les suppressions, elles, sont staged explicitement par
        // `git rm` (commit du renommage) : `git add .` ne les prend pas.
        git.add().addFilepattern(".").call();
        // Date fixe : les identifiants des commits sont reproductibles.
        long seconds = 1_767_225_600L + index * 60L; // 2026-01-01T12:00:00Z + n minutes
        // Date fixe : les identifiants des commits sont reproductibles.
        PersonIdent identity = new PersonIdent("Test Author", "author@example.org",
                new Date(seconds * 1000L), TimeZone.getTimeZone("UTC"));
        git.commit()
                .setMessage(message)
                .setAuthor(identity)
                .setCommitter(identity)
                .call();
        String id = git.getRepository().resolve(Constants.HEAD).name();
        return new Commit(id, message);
    }

    private static void write(Path path, String content) throws IOException {
        Files.createDirectories(path.getParent());
        Files.write(path, content.getBytes(StandardCharsets.UTF_8));
    }

    private static void writeBytes(Path path, byte[] content) throws IOException {
        Files.createDirectories(path.getParent());
        Files.write(path, content);
    }
}
