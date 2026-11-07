#!/usr/bin/env python3
"""
Test de relecture hostile des 4 fonctions Pro (Slot 5 - Pickaxe).
Vérifie :
1. P1, P2, P3, P4 sont toutes derrière la garde estPro() du FournisseurLicence injectable.
2. Aucun chemin ne retourne le résultat Pro sans licence.
3. Aucune ne lève une exception brute au lieu du message exact « fonction Pro — licence requise ».
4. Aucune ne fait d'appel réseau ou d'écriture disque.
"""

import glob
import os
import re
import unittest

class TestRelectureHostileFonctionsPro(unittest.TestCase):

    def setUp(self):
        with open("FonctionsPro.java", "r", encoding="utf-8") as f:
            self.fonctions_pro = f.read()
        with open("LicenceEtat.java", "r", encoding="utf-8") as f:
            self.licence_etat = f.read()
        with open("FonctionProRefuseeException.java", "r", encoding="utf-8") as f:
            self.exception_pro = f.read()
        with open("FournisseurLicence.java", "r", encoding="utf-8") as f:
            self.fournisseur_licence = f.read()

    def test_fournisseur_licence_injectable_et_licence_etat(self):
        """FournisseurLicence est une interface injectable et LicenceEtat l'utilise."""
        self.assertIn("public interface FournisseurLicence", self.fournisseur_licence)
        self.assertIn("Boolean licenceProActive();", self.fournisseur_licence)

        # LicenceEtat prend FournisseurLicence par injection
        self.assertIn("public LicenceEtat(FournisseurLicence fournisseur)", self.licence_etat)
        self.assertIn("this.fournisseur = fournisseur;", self.licence_etat)

        # FonctionsPro prend LicenceEtat par injection
        self.assertIn("public FonctionsPro(LicenceEtat licence,", self.fonctions_pro)
        self.assertIn("this.licence = licence;", self.fonctions_pro)

        # FonctionsPro expose estPro() délégué à licence.estPro()
        self.assertIn("public boolean estPro() {\n        return licence.estPro();\n    }", self.fonctions_pro)

    def test_garde_exiger_pro_systematique_pour_p1_p2_p3_p4(self):
        """Chacune des méthodes Pro P1, P2, P3, P4 appelle exigerPro() dès la première ligne."""
        methodes_pro = {
            "P1_messages": (r"rechercherParMessages\([^)]*\)[^{]*\{(\s*exigerPro\(\"P1\"\);)", "P1"),
            "P1_messages_diffs": (r"rechercherParMessagesEtDiffs\([^)]*\)[^{]*\{(\s*exigerPro\(\"P1\"\);)", "P1"),
            "P2_export": (r"exporter\([^)]*\)[^{]*\{(\s*exigerPro\(\"P2\"\);)", "P2"),
            "P3_sauvegarde": (r"sauvegarderRecherche\([^)]*\)[^{]*\{(\s*exigerPro\(\"P3\"\);)", "P3"),
            "P3_liste": (r"recherchesSauvegardees\([^)]*\)[^{]*\{(\s*exigerPro\(\"P3\"\);)", "P3"),
            "P4_multi_depots": (r"rechercherDansTousLesDepots\([^)]*\)[^{]*\{(\s*exigerPro\(\"P4\"\);)", "P4"),
        }

        for nom, (pattern, code_pro) in methodes_pro.items():
            match = re.search(pattern, self.fonctions_pro)
            self.assertIsNotNone(match, f"La méthode {nom} doit commencer immédiatement par exigerPro(\"{code_pro}\");")

    def test_aucun_chemin_ne_retourne_de_resultat_sans_licence(self):
        """exigerPro vérifie licence.estPro() et lève immédiatement FonctionProRefuseeException."""
        garde_regex = re.compile(
            r"private\s+void\s+exigerPro\(String\s+fonction\)\s+throws\s+FonctionProRefuseeException\s*\{"
            r"\s*if\s*\(!licence\.estPro\(\)\)\s*\{"
            r"\s*throw\s+new\s+FonctionProRefuseeException\(fonction\);"
            r"\s*\}"
            r"\s*\}"
        )
        self.assertIsNotNone(garde_regex.search(self.fonctions_pro), "Garde exigerPro() non trouvée ou incorrecte")

    def test_message_exact_licence_requise_et_pas_d_exception_brute(self):
        """Le message exact est 'fonction Pro — licence requise' et aucune exception brute n'est levée."""
        message_attendu = "fonction Pro — licence requise"

        self.assertIn(f'public static final String MESSAGE_LICENCE_REQUISE = "{message_attendu}";', self.licence_etat)
        self.assertIn(f'public static final String MESSAGE = "{message_attendu}";', self.exception_pro)

        # Dans FonctionProRefuseeException
        self.assertIn("super(MESSAGE);", self.exception_pro)

        # Dans LicenceEtat.lire(), capture RuntimeException et LinkageError sans propager d'exception brute
        self.assertIn("catch (RuntimeException | LinkageError e)", self.licence_etat)
        self.assertIn("return Boolean.FALSE;", self.licence_etat)

    def test_aucune_fonction_ne_fait_d_appel_reseau_ou_ecriture_disque(self):
        """Aucun appel réseau et aucune écriture disque dans tous les fichiers Java."""
        reseau_tokens = [
            "java.net.Socket", "java.net.ServerSocket", "java.net.URL", "java.net.URI",
            "java.net.HttpURLConnection", "java.net.http.HttpClient", "HttpRequest",
            "SocketChannel", "URLConnection", "InetAddress"
        ]
        disque_ecriture_tokens = [
            "FileWriter", "FileOutputStream", "Files.write", "Files.newBufferedWriter",
            "Files.newOutputStream", "Files.createFile", "Files.createDirectory",
            "Files.delete", "Files.move", "Files.copy", "RandomAccessFile", "PrintWriter"
        ]

        fichiers_java = glob.glob("*.java")
        self.assertGreaterEqual(len(fichiers_java), 13, "Tous les fichiers Java doivent être audités")

        for f_path in fichiers_java:
            with open(f_path, "r", encoding="utf-8") as f:
                content = f.read()

            for tok in reseau_tokens:
                self.assertNotIn(tok, content, f"Appel réseau suspect ({tok}) détecté dans {f_path}")

            for tok in disque_ecriture_tokens:
                self.assertNotIn(tok, content, f"Écriture disque suspecte ({tok}) détectée dans {f_path}")

if __name__ == "__main__":
    unittest.main()
