#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
contre_epreuve.py — PREUVE ROUGE du moteur pickaxe (version Python).

« Un test qui n'a jamais ete rouge n'est pas un test. »

Principe : on mute une COPIE du moteur (le source canonique n'est JAMAIS
touche), on rejoue la suite de tests, et on EXIGE que la suite echoue. Si la
suite reste verte sur le moteur mute, la preuve est invalide : les tests ne
mordent pas.

La mutation simule l'implementation naive de `git log -S` : au lieu de
comparer le NOMBRE d'occurrences avant / apres, on se contente de demander
« la chaine est-elle presente d'un cote ou de l'autre ? ». C'est exactement
le piege que le produit promet d'eviter : une chaine reecrite a l'identique
ne doit PAS remonter.

Sortie :
  0 = preuve ROUGE validee (la suite a bien echoue sur le moteur mute)
  1 = preuve ROUGE INVALIDEE (la suite est verte sur le moteur mute)
  3 = environnement incomplet (pas de JDK, jar manquant)

Ce fichier est autonome : aucun chemin de conteneur en dur, il ne depend que
de son propre emplacement (le racine du depot = le parent de `scripts/`).

REGLE DE PROPRETE (controle de pre-vol) : les deux chaines de mutation
ci-dessous ne doivent apparaitre dans AUCUN fichier de `src/`. Elles sont
volontairement ecrites ici sous forme de REGEX (parenthesees echappees) et
de chaine complete : la forme « avant » n'est donc pas findable telle quelle
dans les sources, et la forme « apres » ne l'est pas non plus. Le script
verifie lui-meme cette propriete avant de commencer.
"""

import hashlib
import os
import re
import shutil
import subprocess
import sys
from pathlib import Path

# --------------------------------------------------------------------------
# LA MUTATION (les deux seules chaines autorisees)
# --------------------------------------------------------------------------
# Forme « avant » : la comparaison correcte (nombre d'occurrences).
MUTATION_AVANT_REGEX = (
    r"hit = countOccurrences\(oldBytes, needleBytes\) != "
    r"countOccurrences\(newBytes, needleBytes\);"
)
# Forme « apres » : la forme naive, qui remonte les faux positifs.
MUTATION_APRES = (
    "hit = countOccurrences(oldBytes, needleBytes) > 0 || "
    "countOccurrences(newBytes, needleBytes) > 0;"
)

ROOT = Path(__file__).resolve().parent.parent
WORK = ROOT / "build" / "red-proof-py"
ENGINE = "src/main/java/com/tgglabs/pickaxe/engine/PickaxeEngine.java"


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
    return None, None


def main() -> int:
    javac, java = find_jdk()
    if javac is None:
        log("ERREUR : aucun JDK trouve (JAVA_HOME, /usr/lib/jvm/*, ou javac dans le PATH)")
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

    log("=== CONTRE-EPREUVE ROUGE — moteur pickaxe (scripts/contre_epreuve.py) ===")
    log(f"date            : {subprocess.run(['date','-u','+%Y-%m-%dT%H:%M:%SZ'], capture_output=True, text=True).stdout.strip()}")
    log(f"java            : {subprocess.run([str(java),'-version'], capture_output=True, text=True).stderr.splitlines()[0]}")
    log(f"source canonique: {canon}")

    # --- propriete : les mutations ne doivent pas etre dans les sources -----
    src_files = sorted((ROOT / "src").rglob("*.java")) + sorted((ROOT / "src").rglob("*.xml"))
    for lit in (MUTATION_AVANT_REGEX, MUTATION_APRES):
        for f in src_files:
            if lit in f.read_text(encoding="utf-8", errors="replace"):
                log(f"ALERTE : la mutation est presente dans {f} — preuve invalide")
                return 1
    log("OK : aucune mutation n'est presente dans src/ (avant et apres).")

    sha_avant = sha256(canon)
    log(f"sha256 AVANT    : {sha_avant}")

    # --- 1. copie + mutation de la COPIE -----------------------------------
    if WORK.exists():
        shutil.rmtree(WORK)
    WORK.mkdir(parents=True)
    shutil.copytree(ROOT / "src", WORK / "src")
    mut = WORK / ENGINE
    text = mut.read_text(encoding="utf-8")
    new_text, n = re.subn(MUTATION_AVANT_REGEX, MUTATION_APRES.replace("\\", "\\\\"), text, count=1)
    if n != 1:
        log("MUTATION IMPOSSIBLE : le motif attendu est absent du source")
        return 3
    mut.write_text(new_text, encoding="utf-8")
    log("")
    log("=== 1. mutation de la COPIE (le canonique n'est pas touche) ===")
    log(f"sha256 de la copie mutee : {sha256(mut)}")

    # --- 2. compilation de la copie mutee ----------------------------------
    log("")
    log("=== 2. compilation de la copie mutee ===")
    classes = WORK / "classes"
    test_classes = WORK / "test-classes"
    classes.mkdir(parents=True, exist_ok=True)
    test_classes.mkdir(parents=True, exist_ok=True)

    main_sources = sorted((WORK / "src" / "main" / "java" / "com" / "tgglabs" / "pickaxe" / "engine").glob("*.java"))
    test_sources = sorted((WORK / "src" / "test" / "java").rglob("*.java"))

    def compile_many(sources, out, extra_cp):
        args = [str(javac), "-encoding", "UTF-8", "--release", "17", "-nowarn",
                "-cp", extra_cp, "-d", str(out)] + [str(s) for s in sources]
        return subprocess.run(args, capture_output=True, text=True)

    r = compile_many(main_sources, classes, cp)
    if r.returncode != 0:
        log("ECHEC : compilation")
        log(r.stderr[-2000:])
        return 3
    r = compile_many(test_sources, test_classes, f"{cp}:{classes}")
    if r.returncode != 0:
        log("ECHEC : compilation des tests")
        log(r.stderr[-2000:])
        return 3
    log("OK : compilation reussie")

    # --- 3. execution de la suite sur le moteur MUTE ------------------------
    log("")
    log("=== 3. execution de la suite sur le moteur MUTE ===")
    proc = subprocess.run(
        [str(java), "-jar", str(libs / "junit-platform-console-standalone-1.10.2.jar"),
         "--class-path", f"{cp}:{classes}:{test_classes}",
         "--scan-class-path", str(test_classes),
         "--details", "tree", "--disable-ansi-colors", "--disable-banner"],
        capture_output=True, text=True)
    out = proc.stdout + proc.stderr
    for line in out.splitlines():
        if "tests " in line or "Test run" in line or "Failures" in line:
            log("    " + line.strip())
    code = proc.returncode

    # --- 4. controle --------------------------------------------------------
    sha_apres = sha256(canon)
    log("")
    log(f"=== 4. CODE DE RETOUR de la suite mutée : {code} ===")
    log(f"sha256 APRES (canonique) : {sha_apres}")
    if sha_avant != sha_apres:
        log("ALERTE : le source canonique a ete modifie pendant la contre-epreuve")
        return 1
    log("OK : le source canonique est intact (sha256 identique avant / apres).")

    log("")
    if code != 0:
        log("=== RESULTAT : PREUVE ROUGE VALIDEE ===")
        log(f"La suite echoue (code {code}) sur le moteur mute : les tests mordent.")
        return 0
    log("=== RESULTAT : PREUVE ROUGE INVALIDEE ===")
    log("La suite est VERTE sur le moteur mute : la mutation ne mord pas.")
    return 1


if __name__ == "__main__":
    sys.exit(main())
