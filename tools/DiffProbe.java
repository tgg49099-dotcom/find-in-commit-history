import org.eclipse.jgit.api.Git;
import org.eclipse.jgit.diff.DiffEntry;
import org.eclipse.jgit.diff.DiffFormatter;
import org.eclipse.jgit.diff.RawTextComparator;
import org.eclipse.jgit.lib.ObjectReader;
import org.eclipse.jgit.revwalk.RevCommit;
import org.eclipse.jgit.revwalk.RevTree;
import org.eclipse.jgit.revwalk.RevWalk;
import org.eclipse.jgit.treewalk.CanonicalTreeParser;
import org.eclipse.jgit.treewalk.TreeWalk;
import org.eclipse.jgit.util.io.NullOutputStream;

import java.nio.file.Files;
import java.nio.file.Path;
import java.util.List;

public class DiffProbe {
    public static void main(String[] args) throws Exception {
        Path dir = Files.createTempDirectory("probe");
        com.tgglabs.pickaxe.engine.TestRepository.build(dir);
        try (Git git = Git.open(dir.toFile())) {
            org.eclipse.jgit.lib.Repository repo = git.getRepository();
            try (RevWalk walk = new RevWalk(repo)) {
                for (RevCommit c : git.log().all().call()) {
                    RevTree newTree = walk.parseTree(c.getTree().getId());
                    RevTree oldTree = c.getParentCount() > 0
                            ? walk.parseCommit(c.getParent(0).getId()).getTree() : null;

                    // variante A : AbstractTreeIterator + detectRenames
                    DiffFormatter fa = new DiffFormatter(NullOutputStream.INSTANCE);
                    fa.setRepository(repo);
                    fa.setDiffComparator(RawTextComparator.DEFAULT);
                    fa.setDetectRenames(true);
                    ObjectReader reader = repo.newObjectReader();
                    CanonicalTreeParser a1 = new CanonicalTreeParser();
                    CanonicalTreeParser a2 = new CanonicalTreeParser();
                    a2.reset(reader, newTree.getId());
                    if (oldTree != null) a1.reset(reader, oldTree.getId());
                    List<DiffEntry> ea = fa.scan(a1, a2);

                    // variante B : scan(RevTree, RevTree)
                    DiffFormatter fb = new DiffFormatter(NullOutputStream.INSTANCE);
                    fb.setRepository(repo);
                    fb.setDiffComparator(RawTextComparator.DEFAULT);
                    fb.setDetectRenames(true);
                    List<DiffEntry> eb = oldTree != null ? fb.scan(oldTree, newTree) : fa.scan(a1, a2);
                    // variante C : iterateurs + RenameDetector manuel
                    DiffFormatter fc = new DiffFormatter(NullOutputStream.INSTANCE);
                    fc.setRepository(repo);
                    fc.setDiffComparator(RawTextComparator.DEFAULT);
                    fc.setDetectRenames(true);
                    ObjectReader rd2 = repo.newObjectReader();
                    CanonicalTreeParser c1 = new CanonicalTreeParser();
                    CanonicalTreeParser c2 = new CanonicalTreeParser();
                    c2.reset(rd2, newTree.getId());
                    if (oldTree != null) c1.reset(rd2, oldTree.getId());
                    List<DiffEntry> ec = fc.scan(c1, c2);
                    org.eclipse.jgit.diff.RenameDetector det = new org.eclipse.jgit.diff.RenameDetector(repo);
                    det.setRenameScore(60);
                    det.addAll(ec);
                    ec = det.compute();

                    System.out.println("COMMIT " + c.getFullMessage().split("\n")[0]);
                    System.out.println("   A(iterators): " + describe(ea));
                    System.out.println("   B(revtree)  : " + describe(eb));
                    System.out.println("   C(manual RD): " + describe(ec));
                }
            }
        }
    }
    static String describe(List<DiffEntry> entries) {
        StringBuilder sb = new StringBuilder();
        for (DiffEntry e : entries) {
            sb.append(e.getChangeType()).append("(").append(e.getOldPath()).append("->").append(e.getNewPath())
              .append(",old=").append(e.getOldId().name()).append(",new=").append(e.getNewId().name()).append(") ");
        }
        return sb.toString();
    }
}
