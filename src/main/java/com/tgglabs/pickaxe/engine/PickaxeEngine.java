package com.tgglabs.pickaxe.engine;

import org.eclipse.jgit.diff.DiffEntry;
import org.eclipse.jgit.diff.DiffFormatter;
import org.eclipse.jgit.diff.Edit;
import org.eclipse.jgit.diff.EditList;
import org.eclipse.jgit.diff.RawTextComparator;
import org.eclipse.jgit.lib.Constants;
import org.eclipse.jgit.lib.ObjectId;
import org.eclipse.jgit.lib.ObjectLoader;
import org.eclipse.jgit.lib.ObjectReader;
import org.eclipse.jgit.lib.Ref;
import org.eclipse.jgit.lib.Repository;
import org.eclipse.jgit.revwalk.RevCommit;
import org.eclipse.jgit.revwalk.RevObject;
import org.eclipse.jgit.revwalk.RevTag;
import org.eclipse.jgit.revwalk.RevTree;
import org.eclipse.jgit.revwalk.RevWalk;
import org.eclipse.jgit.treewalk.CanonicalTreeParser;
import org.eclipse.jgit.util.io.NullOutputStream;

import java.io.IOException;
import java.nio.charset.StandardCharsets;
import java.util.ArrayList;
import java.util.LinkedHashSet;
import java.util.List;
import java.util.regex.Pattern;

/**
 * Moteur pickaxe : recherche dans l'historique Git les commits qui
 * ajoutent / suppriment une chaine ({@code git log -S}) ou dont le diff
 * matche une expression ({@code git log -G}).
 *
 * <p><b>Regle de qualite n°1 : zero faux positif.</b> Une chaine reecrite a
 * l'identique ne doit PAS remonter. C'est la raison du mode STRING : on
 * compare le NOMBRE d'occurrences avant / apres, et non la presence de la
 * chaine dans le diff. Un renommage de fichier sans changement de contenu ne
 * remonte pas non plus (le contenu est identique des deux cotes).</p>
 *
 * <p>Le moteur ne depend QUE de JGit : il est donc testable sans IDE, et
 * reutilisable par n'importe quel code de la plateforme.</p>
 */
public final class PickaxeEngine {

    /**
     * Nombre d'octets inspectes au debut d'un blob pour le declarer binaire.
     * C'est le seuil utilise par git lui-meme.
     */
    public static final int BINARY_SNIFF_BYTES = 8000;

    /** Taille maximale d'un blob lu en memoire (garde-fou). */
    private static final long MAX_BLOB_BYTES = 64L * 1024 * 1024;

    private final Repository repository;

    public PickaxeEngine(Repository repository) {
        if (repository == null) {
            throw new IllegalArgumentException("repository must not be null");
        }
        this.repository = repository;
    }

    public Repository getRepository() {
        return repository;
    }

    /**
     * Lance la recherche.
     *
     * @return les commits trouves, du plus recent au plus ancien
     * @throws PickaxeException si le depot ne peut pas etre lu
     */
    public List<PickaxeHit> search(PickaxeQuery query) throws PickaxeException {
        if (query == null) {
            throw new IllegalArgumentException("query must not be null");
        }
        final String needle = query.getNeedle();
        if (needle.isEmpty()) {
            throw new PickaxeException(PickaxeQuery.EMPTY_NEEDLE_MESSAGE);
        }
        final byte[] needleBytes = needle.getBytes(StandardCharsets.UTF_8);
        final Pattern pathPattern = query.compiledPathFilter();
        final Pattern regex = query.compiledRegex();

        final List<PickaxeHit> hits = new ArrayList<>();
        try (RevWalk walk = new RevWalk(repository);
             DiffFormatter formatter = new DiffFormatter(NullOutputStream.INSTANCE)) {
            formatter.setRepository(repository);
            formatter.setDiffComparator(RawTextComparator.DEFAULT);
            // La detection de renommage est indispensable : sans elle, un
            // renommage de fichier apparait comme une suppression + un
            // ajout, et la chaine contenue dans le fichier paraitrait
            // "supprimee" puis "ajoutee" => faux positif.
            formatter.setDetectRenames(true);

            // Points de depart explicites : on n'utilise PAS `git log`, qui
            // echoue sur un depot sans HEAD. Un depot vide renvoie donc une
            // liste vide au lieu d'une exception.
            markStartPoints(walk);

            for (RevCommit commit : walk) {
                if (hits.size() >= query.getMaxResults()) {
                    break;
                }
                List<String> matchedPaths = matchingPaths(commit, walk, formatter, query,
                        needleBytes, pathPattern, regex);
                if (!matchedPaths.isEmpty()) {
                    hits.add(new PickaxeHit(
                            commit.getName(),
                            commit.getFullMessage().split("\n", 2)[0].trim(),
                            commit.getAuthorIdent() == null ? "" : commit.getAuthorIdent().getName(),
                            commit.getCommitTime() * 1000L,
                            matchedPaths));
                }
            }
        } catch (IOException e) {
            throw new PickaxeException("Unable to read the Git repository: " + e.getMessage(), e);
        }
        return hits;
    }

    /**
     * Marque les points de depart de la parcours : HEAD et toutes les
     * references. Un depot sans aucun commit n'a aucun point de depart :
     * la parcours ne rend alors aucun commit (liste vide), sans exception.
     */
    private void markStartPoints(RevWalk walk) throws IOException {
        ObjectId head = repository.resolve(Constants.HEAD);
        if (head != null) {
            markStart(walk, head);
        }
        for (Ref ref : repository.getAllRefs().values()) {
            ObjectId id = ref.getObjectId();
            if (id == null) {
                continue;
            }
            try {
                markStart(walk, id);
            } catch (IOException e) {
                // Reference cassee ou illisible : on l'ignore plutot que de
                // faire echouer toute la recherche.
            }
        }
    }

    /** Point de depart, en dereferencant les etiquettes annotees. */
    private void markStart(RevWalk walk, ObjectId id) throws IOException {
        RevObject object = walk.parseAny(id);
        if (object instanceof RevTag) {
            object = walk.parseAny(((RevTag) object).getObject().getId());
        }
        if (object instanceof RevCommit) {
            walk.markStart((RevCommit) object);
        }
    }

    /** Chemins (et commit) qui declenchent la correspondance. */
    private List<String> matchingPaths(RevCommit commit,
                                        RevWalk walk,
                                        DiffFormatter formatter,
                                        PickaxeQuery query,
                                        byte[] needleBytes,
                                        Pattern pathPattern,
                                        Pattern regex) throws IOException {
        final List<String> matched = new ArrayList<>();

        RevTree commitTree = walk.parseTree(commit.getTree().getId());
        RevTree parentTree = null;
        if (commit.getParentCount() > 0) {
            // On compare avec le PREMIER parent, comme `git log` par defaut
            // sur un commit non-merge.
            RevCommit parent = walk.parseCommit(commit.getParent(0).getId());
            parentTree = walk.parseTree(parent.getTree().getId());
        }

        // JGit ne compare que des arbres de commit : on convertit les RevTree
        // en CanonicalTreeParser (l'iterateur d'arbre du diff). Pour le commit
        // initial, le parseur "ancien" n'est pas initialise : il est vide,
        // comme l'arbre vide de git.
        ObjectReader reader = repository.newObjectReader();
        CanonicalTreeParser oldTreeParser = new CanonicalTreeParser();
        CanonicalTreeParser newTreeParser = new CanonicalTreeParser();
        newTreeParser.reset(reader, commitTree.getId());
        if (parentTree != null) {
            oldTreeParser.reset(reader, parentTree.getId());
        }
        List<DiffEntry> entries = formatter.scan(oldTreeParser, newTreeParser);

        for (DiffEntry entry : entries) {
            String path = entry.getChangeType() == DiffEntry.ChangeType.DELETE
                    ? entry.getOldPath()
                    : entry.getNewPath();
            if (pathPattern != null && !pathPattern.matcher(path).find()) {
                continue;
            }

            byte[] oldBytes = loadBlob(entry.getOldId().toObjectId());
            byte[] newBytes = loadBlob(entry.getNewId().toObjectId());

            if (!query.isIncludeBinary() && (isBinary(oldBytes) || isBinary(newBytes))) {
                // Fichier binaire : on l'ignore (contrainte de la consigne :
                // un binaire n'est pas du texte, compter des occurrences
                // dans des octets arbitraires ne veut rien dire).
                continue;
            }

            boolean hit;
            if (query.getMode() == PickaxeMode.REGEX) {
                hit = regexMatchesDiff(formatter, entry, oldBytes, newBytes, regex);
            } else {
                hit = countOccurrences(oldBytes, needleBytes) != countOccurrences(newBytes, needleBytes);
            }
            if (hit) {
                matched.add(path);
            }
        }
        return matched;
    }

    /**
     * Mode {@code -G} : une ligne ajoutee ou supprimee matche l'expression.
     *
     * <p>On passe par la liste des editions ({@link EditList}) : elle donne,
     * pour chaque zone modifiee, les numeros de ligne AVANT et APRES. Les
     * lignes de l'ancien contenu (supprimees) et du nouveau (ajoutees) sont
     * testees une par une — exactement ce que fait git.</p>
     */
    private boolean regexMatchesDiff(DiffFormatter formatter,
                                     DiffEntry entry,
                                     byte[] oldBytes,
                                     byte[] newBytes,
                                     Pattern regex) {
        if (regex == null) {
            return false;
        }
        EditList edits;
        try {
            edits = formatter.toFileHeader(entry).toEditList();
        } catch (IOException e) {
            return false;
        }
        String[] oldLines = splitLines(oldBytes);
        String[] newLines = splitLines(newBytes);
        for (Edit edit : edits) {
            for (int i = edit.getBeginA(); i < edit.getEndA() && i < oldLines.length; i++) {
                if (regex.matcher(oldLines[i]).find()) {
                    return true;
                }
            }
            for (int i = edit.getBeginB(); i < edit.getEndB() && i < newLines.length; i++) {
                if (regex.matcher(newLines[i]).find()) {
                    return true;
                }
            }
        }
        return false;
    }

    /** Contenu d'un blob ; {@code null} si l'objet n'existe pas. */
    private byte[] loadBlob(ObjectId id) throws IOException {
        if (id == null || ObjectId.zeroId().equals(id)) {
            return null;
        }
        ObjectLoader loader = repository.open(id);
        if (loader.getSize() > MAX_BLOB_BYTES) {
            return null;
        }
        return loader.getBytes();
    }

    /**
     * Un blob est binaire s'il contient un octet nul dans ses
     * {@value #BINARY_SNIFF_BYTES} premiers octets (heuristique de git).
     */
    static boolean isBinary(byte[] content) {
        if (content == null) {
            return false;
        }
        int limit = Math.min(content.length, BINARY_SNIFF_BYTES);
        for (int i = 0; i < limit; i++) {
            if (content[i] == 0) {
                return true;
            }
        }
        return false;
    }

    /**
     * Nombre d'occurrences (sans chevauchement) d'un motif dans un contenu.
     * Renvoie 0 si le contenu ou le motif est absent.
     */
    static int countOccurrences(byte[] content, byte[] needle) {
        if (content == null || needle == null || needle.length == 0) {
            return 0;
        }
        int count = 0;
        int from = 0;
        while (from <= content.length - needle.length) {
            int index = indexOf(content, needle, from);
            if (index < 0) {
                break;
            }
            count++;
            from = index + needle.length;
        }
        return count;
    }

    private static int indexOf(byte[] haystack, byte[] needle, int from) {
        int limit = haystack.length - needle.length;
        outer:
        for (int i = Math.max(0, from); i <= limit; i++) {
            for (int j = 0; j < needle.length; j++) {
                if (haystack[i + j] != needle[j]) {
                    continue outer;
                }
            }
            return i;
        }
        return -1;
    }

    /** Decoupe un contenu en lignes (separateur {@code \n}, comme git). */
    static String[] splitLines(byte[] content) {
        if (content == null || content.length == 0) {
            return new String[0];
        }
        String text = new String(content, StandardCharsets.UTF_8);
        String[] raw = text.split("\n", -1);
        // La derniere ligne vide provient du "\n" final : on la retire,
        // comme git, qui ne compte pas de ligne apres le dernier retour.
        int count = raw.length;
        if (count > 0 && raw[count - 1].isEmpty()) {
            count--;
        }
        String[] lines = new String[count];
        for (int i = 0; i < count; i++) {
            String line = raw[i];
            if (line.endsWith("\r")) {
                line = line.substring(0, line.length() - 1);
            }
            lines[i] = line;
        }
        return lines;
    }

    /**
     * Version de JGit reellement chargee (lue dans le manifeste du jar).
     * Sert a prouver, dans le journal de l'IDE, que le moteur tourne avec
     * la bonne bibliotheque.
     */
    public static String jgitVersion() {
        Package pkg = Constants.class.getPackage();
        if (pkg != null && pkg.getImplementationVersion() != null) {
            return pkg.getImplementationVersion();
        }
        return "unknown";
    }

    @Override
    public String toString() {
        return "PickaxeEngine{jgit=" + jgitVersion() + ", repository=" + repository.getDirectory() + '}';
    }

    /** Liste des chemins donnes, sans doublon, dans l'ordre. */
    static List<String> unique(List<String> paths) {
        return new ArrayList<>(new LinkedHashSet<>(paths));
    }
}
