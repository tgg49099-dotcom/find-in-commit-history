#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
contre_epreuve_aba5.py — PREUVE ROUGE des DEUX correctifs de la revue du
jury `aba5` (05/11/2026) que le jury n'a pas couverts par son patch :

  * la NON-DUPLICATION des fusions  (revue aba5, point 3) ;
  * l'ANNULATION du parcours       (revue aba5, point 2, « non couvert par
    le patch »).

« Un test qui n'a jamais ete rouge n'est pas un test. »

Principe : on mute une COPIE du moteur (le source canonique n'est JAMAIS
touche), on rejoue la suite de tests, et on EXIGE que la suite echoue sur le
test concerne. Si la suite reste verte sur le moteur mute, la preuve est
invalide : le test ne mord pas. On rejoue ensuite la suite sur le code
canonique et on exige qu'elle soit VERTE.

Sortie :
  0 = les DEUX preuves rouges sont validees ET la suite canonique est verte
  1 = au moins une preuve rouge est invalide, ou la suite canonique est rouge
  3 = environnement incomplet (pas de JDK, jar manquant)

Ce fichier est autonome : aucun chemin de conteneur en dur, il ne depend que
de son propre emplacement (la racine du depot = le parent de `scripts/`).
"""

import hashlib
import os
import re
import shutil
import subprocess
import sys
from pathlib import Path

# --------------------------------------------------------------------------
# LES MUTATIONS (deux, une par correctif prouve)
# --------------------------------------------------------------------------
# M1 — FUSIONS : on rend la condition « plus d'un parent » fausse, donc les
# commits de fusion sont de nouveau diffes : le changement remonte en double.
M1_AVANT_REGEX = r"commit\.getParentCount\(\) > 1"
M1_APRES = "commit.getParentCount() > 99"

# M2 — ANNULATION : on neutralise l'appel au test d'annulation, comme si le
# moteur n'en avait pas : le parcours ne s'interrompt jamais.
M2_AVANT_REGEX = r"cancelled\.getAsBoolean\(\)"
M2_APRES = "false"

ROOT = Path(__file__).resolve().parent.parent
ENGINE = "src/main/java/com/tgglabs/pickaxe/engine/PickaxeEngine.java"
WORK = ROOT / "build" / "red-proof-aba5"

# Le test qui doit devenir ROUGE pour chaque mutation.
TEST_ATTENDU = {
    "M1": "MergeSearchTest",
    "M2": "CancellationTest",
}


def log(msg):
    print(msg, flush=True)


def sha256(path: Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest()


def find_jdk():
    home = os.environ.get("JAVA_HOME", "").strip()
    if home and Path(home, "bin", "javac").exists():
        return Path(home, "bin", "javac"), Path(home, "bin", "java")
    for cand in sorted(Path("/usr/lib/jvm").glob("*/bin/javac")):
        if cand.exists():
            return cand, cand.with_name("java")
    javac = shutil.which("javac")
    if javac:
        return Path(javac), Path(shutil.which("java") or "java")
    for cand in sorted(Path("/work/ide").glob("*/jbr/bin/javac")):
        if cand.exists():
            return cand, cand.with_name("java")
    return None, None


def main() -> int:
    javac, java = find_jdk()
    if javac is None:
        log("ERREUR : aucun JDK trouve (JAVA_HOME, /usr/lib/jvm/*, /work/ide/*/jbr, ou javac dans le PATH)")
        return 3

    libs = ROOT / "libs"
    needed = [
        "org.eclipse.jgit-6.10.1.202505221210-r.jar",
        "JavaEWAH-1.1.12.jar",
        "slf4j-api-2.0.13.jar",
        "junit-platform-console-standalone-1.10.2.jar",
    ]
    for jar in needed:
        if not (libs / jar).exists():
            log(f"ERREUR : jar manquant : libs/{jar}")
            return 3
    cp = ":".join(str(libs / j) for j in needed)

    canon = ROOT / ENGINE
    if not canon.exists():
        log(f"ERREUR : source canonique introuvable : {canon}")
        return 3

    log("=== CONTRE-EPREUVE ROUGE — correctifs de la revue aba5 ===")
    log("script          : scripts/contre_epreuve_aba5.py")
    log(f"date            : {subprocess.run(['date','-u','+%Y-%m-%dT%H:%M:%SZ'], capture_output=True, text=True).stdout.strip()}")
    log(f"java            : {subprocess.run([str(java),'-version'], capture_output=True, text=True).stderr.splitlines()[0]}")
    log(f"source canonique: {canon}")
    sha_avant = sha256(canon)
    log(f"sha256 AVANT    : {sha_avant}")

    # --- les mutations doivent etre APPLICABLES au canonique ---------------
    text_canon = canon.read_text(encoding="utf-8")
    for cle, avant in (("M1", M1_AVANT_REGEX), ("M2", M2_AVANT_REGEX)):
        n = len(re.findall(avant, text_canon))
        if n == 0:
            log(f"ERREUR : le motif de la mutation {cle} est absent du source canonique")
            return 3
        log(f"OK : motif {cle} present {n} fois dans le canonique (mutation applicable)")

    # La forme « apres » de M1 ne doit pas se trouver dans les sources.
    src_files = sorted((ROOT / "src").rglob("*.java"))
    for f in src_files:
        if M1_APRES in f.read_text(encoding="utf-8", errors="replace"):
            log(f"ALERTE : la mutation {M1_APRES} est presente dans {f} — preuve invalide")
            return 1
    log("OK : la forme mutante M1 n'est presente dans aucun fichier de src/.")

    resultat_global = 0

    for cle, avant_regex, apres in (("M1", M1_AVANT_REGEX, M1_APRES),
                                    ("M2", M2_AVANT_REGEX, M2_APRES)):
        log("")
        log("#" * 74)
        log(f"# {cle} — mutation : {avant_regex}  ->  {apres}")
        log(f"# test attendu en ROUGE : {TEST_ATTENDU[cle]}")
        log("#" * 74)

        work = WORK / cle
        if work.exists():
            shutil.rmtree(work)
        work.mkdir(parents=True)
        shutil.copytree(ROOT / "src", work / "src")
        mut = work / ENGINE
        text = mut.read_text(encoding="utf-8")
        new_text, n = re.subn(avant_regex, apres.replace("\\", "\\\\"), text)
        if n == 0:
            log("MUTATION IMPOSSIBLE : le motif attendu est absent de la copie")
            resultat_global = 1
            continue
        mut.write_text(new_text, encoding="utf-8")
        log(f"mutation appliquee ({n} occurrence(s)) ; sha256 de la copie mutee : {sha256(mut)}")
        log(f"sha256 du canonique (doit rester {sha_avant}) : {sha256(canon)}")

        classes = work / "classes"
        test_classes = work / "test-classes"
        classes.mkdir(parents=True, exist_ok=True)
        test_classes.mkdir(parents=True, exist_ok=True)

        main_sources = sorted((work / "src" / "main" / "java" / "com" / "tgglabs" / "pickaxe" / "engine").glob("*.java"))
        locator = work / "src" / "main" / "java" / "com" / "tgglabs" / "pickaxe" / "GitRepositoryLocator.java"
        if locator.exists():
            main_sources.append(locator)
        # HashClipboard est la SEULE classe de l'interface compilee hors IDE
        # (elle ne depend que de l'engine) : sans elle, HashClipboardTest ne
        # compile pas. Cf. run_tests.sh, qui fait de meme.
        hashclip = work / "src" / "main" / "java" / "com" / "tgglabs" / "pickaxe" / "ui" / "HashClipboard.java"
        if hashclip.exists():
            main_sources.append(hashclip)
        # RechercheEnCours : meme cas (elle ne depend que du moteur).
        recherche = work / "src" / "main" / "java" / "com" / "tgglabs" / "pickaxe" / "ui" / "RechercheEnCours.java"
        if recherche.exists():
            main_sources.append(recherche)
        # Le paquet `pro` (fonctions Pro, etat de licence) ne depend QUE de
        # Java et du moteur : il est compile et teste HORS IDE, comme le moteur.
        main_sources += sorted((work / "src" / "main" / "java" / "com" / "tgglabs" / "pickaxe" / "pro").glob("*.java"))
        test_sources = sorted((work / "src" / "test" / "java").rglob("*.java"))

        def compile_many(sources, out, extra_cp):
            args = [str(javac), "-encoding", "UTF-8", "--release", "17", "-nowarn",
                    "-cp", extra_cp, "-d", str(out)] + [str(s) for s in sources]
            return subprocess.run(args, capture_output=True, text=True)

        r = compile_many(main_sources, classes, cp)
        if r.returncode != 0:
            log("ECHEC : compilation de la copie mutee")
            log(r.stderr[-2000:])
            resultat_global = 1
            continue
        r = compile_many(test_sources, test_classes, f"{cp}:{classes}")
        if r.returncode != 0:
            log("ECHEC : compilation des tests")
            log(r.stderr[-2000:])
            resultat_global = 1
            continue
        log("OK : compilation reussie")

        log("")
        log(f"=== {cle} — suite sur le moteur MUTE (doit etre ROUGE) ===")
        proc = subprocess.run(
            [str(java), f"-Dpickaxe.src.dir={ROOT / 'src' / 'main' / 'java'}",
             "-jar", str(libs / "junit-platform-console-standalone-1.10.2.jar"),
             "--class-path", f"{cp}:{classes}:{test_classes}",
             "--scan-class-path", str(test_classes),
             "--details", "tree", "--disable-ansi-colors", "--disable-banner"],
            capture_output=True, text=True)
        out = proc.stdout + proc.stderr
        for line in out.splitlines():
            if ("tests " in line or "Test run" in line or "Failures" in line
                    or "AssertionFailedError" in line or "=> org.opentest4j" in line
                    or TEST_ATTENDU[cle] in line):
                log("    " + line.strip())
        code = proc.returncode
        log(f"=== {cle} — code de retour de la suite mutee : {code} ===")

        if code == 0:
            log(f"=== {cle} — PREUVE ROUGE INVALIDEE ===")
            log("La suite est VERTE sur le moteur mute : la mutation ne mord pas.")
            resultat_global = 1
        else:
            log(f"=== {cle} — PREUVE ROUGE VALIDEE ===")
            log("La suite echoue sur le moteur mute : le test mord.")

        if sha256(canon) != sha_avant:
            log("ALERTE : le source canonique a ete modifie pendant la contre-epreuve")
            resultat_global = 1

    # --- suite canonique : elle doit etre VERTE ----------------------------
    log("")
    log("#" * 74)
    log("# SUITE CANONIQUE (code intact) : elle doit etre VERTE")
    log("#" * 74)
    work = WORK / "canonique"
    if work.exists():
        shutil.rmtree(work)
    work.mkdir(parents=True)
    shutil.copytree(ROOT / "src", work / "src")
    classes = work / "classes"
    test_classes = work / "test-classes"
    classes.mkdir(parents=True, exist_ok=True)
    test_classes.mkdir(parents=True, exist_ok=True)
    main_sources = sorted((work / "src" / "main" / "java" / "com" / "tgglabs" / "pickaxe" / "engine").glob("*.java"))
    locator = work / "src" / "main" / "java" / "com" / "tgglabs" / "pickaxe" / "GitRepositoryLocator.java"
    if locator.exists():
        main_sources.append(locator)
    hashclip = work / "src" / "main" / "java" / "com" / "tgglabs" / "pickaxe" / "ui" / "HashClipboard.java"
    if hashclip.exists():
        main_sources.append(hashclip)
    recherche = work / "src" / "main" / "java" / "com" / "tgglabs" / "pickaxe" / "ui" / "RechercheEnCours.java"
    if recherche.exists():
        main_sources.append(recherche)
    # Le paquet `pro` (fonctions Pro, etat de licence) ne depend QUE de
    # Java et du moteur : il est compile et teste HORS IDE, comme le moteur.
    main_sources += sorted((work / "src" / "main" / "java" / "com" / "tgglabs" / "pickaxe" / "pro").glob("*.java"))
    test_sources = sorted((work / "src" / "test" / "java").rglob("*.java"))

    def compile_many2(sources, out, extra_cp):
        args = [str(javac), "-encoding", "UTF-8", "--release", "17", "-nowarn",
                "-cp", extra_cp, "-d", str(out)] + [str(s) for s in sources]
        return subprocess.run(args, capture_output=True, text=True)

    r = compile_many2(main_sources, classes, cp)
    if r.returncode != 0:
        log("ECHEC : compilation du canonique")
        log(r.stderr[-2000:])
        return 3
    r = compile_many2(test_sources, test_classes, f"{cp}:{classes}")
    if r.returncode != 0:
        log("ECHEC : compilation des tests du canonique")
        log(r.stderr[-2000:])
        return 3
    proc = subprocess.run(
        [str(java), f"-Dpickaxe.src.dir={ROOT / 'src' / 'main' / 'java'}",
         "-jar", str(libs / "junit-platform-console-standalone-1.10.2.jar"),
         "--class-path", f"{cp}:{classes}:{test_classes}",
         "--scan-class-path", str(test_classes),
         "--details", "tree", "--disable-ansi-colors", "--disable-banner"],
        capture_output=True, text=True)
    out = proc.stdout + proc.stderr
    for line in out.splitlines():
        if "tests " in line or "Test run" in line:
            log("    " + line.strip())
    code = proc.returncode
    log(f"=== code de retour de la suite canonique : {code} ===")
    if code != 0:
        log("ECHEC : la suite canonique n'est pas VERTE -> la contre-epreuve est invalide")
        resultat_global = 1
    else:
        log("OK : la suite canonique est VERTE.")

    log("")
    log(f"sha256 du canonique APRES : {sha256(canon)} (attendu {sha_avant})")
    if sha256(canon) != sha_avant:
        log("ALERTE : le source canonique a ete modifie")
        resultat_global = 1
    else:
        log("OK : le source canonique est intact.")

    log("")
    if resultat_global == 0:
        log("=== RESULTAT : LES DEUX PREUVES ROUGES SONT VALIDEES ET LE CANONIQUE EST VERT ===")
    else:
        log("=== RESULTAT : PREUVE INVALIDEE ===")
    return resultat_global


if __name__ == "__main__":
    sys.exit(main())
