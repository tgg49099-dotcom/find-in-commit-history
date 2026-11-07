# Rapport de relecture hostile — Fonctions Pro (Slot 5 / Pickaxe)

**Produit :** Pickaxe (Find in Commit History) — Fonctions Pro (`com.tgglabs.pickaxe.pro`)
**Cadre :** Relecture hostile demandée par la holding Tgg.
**Consigne stricte :** Vérifier que les 4 fonctions Pro (P1 recherche dans les messages, P2 export, P3 recherches enregistrées, P4 multi-dépôts) sont TOUTES derrière la garde `estPro()` du `FournisseurLicence` injectable, qu'aucun chemin ne retourne le résultat Pro sans licence, qu'aucune ne lève une exception brute au lieu du message exact « fonction Pro — licence requise », et qu'aucune ne fait d'appel réseau ou d'écriture disque. Rédiger le verdict ligne par ligne, sans patch.

---

## Synthèse d'audit

| # | Fonction Pro | Point d'entrée | Garde `estPro()` | Retour sans licence possible ? | Exception & Message | Réseau / Écriture disque | Statut |
|---|-------------|----------------|------------------|--------------------------------|---------------------|--------------------------|--------|
| **P1** | Recherche messages | `FonctionsPro.rechercherParMessages` | Ligne 87 (`exigerPro("P1")`) | **NON** (bloqué à l. 87) | `FonctionProRefuseeException` : « fonction Pro — licence requise » | **AUCUN** | **CONFORME** |
| **P1** | Recherche messages + diffs | `FonctionsPro.rechercherParMessagesEtDiffs` | Ligne 102 (`exigerPro("P1")`) | **NON** (bloqué à l. 102) | `FonctionProRefuseeException` : « fonction Pro — licence requise » | **AUCUN** | **CONFORME** |
| **P2** | Export résultats | `FonctionsPro.exporter` | Ligne 115 (`exigerPro("P2")`) | **NON** (bloqué à l. 115) | `FonctionProRefuseeException` : « fonction Pro — licence requise » | **AUCUN** | **CONFORME** |
| **P3** | Sauvegarde recherche | `FonctionsPro.sauvegarderRecherche` | Ligne 129 (`exigerPro("P3")`) | **NON** (bloqué à l. 129) | `FonctionProRefuseeException` : « fonction Pro — licence requise » | **AUCUN** | **CONFORME** |
| **P3** | Liste recherches sauvées | `FonctionsPro.recherchesSauvegardees` | Ligne 141 (`exigerPro("P3")`) | **NON** (bloqué à l. 141) | `FonctionProRefuseeException` : « fonction Pro — licence requise » | **AUCUN** | **CONFORME** |
| **P4** | Recherche multi-dépôts | `FonctionsPro.rechercherDansTousLesDepots` | Ligne 158 (`exigerPro("P4")`) | **NON** (bloqué à l. 158) | `FonctionProRefuseeException` : « fonction Pro — licence requise » | **AUCUN** | **CONFORME** |

---

## Verdict ligne par ligne

### 1. `FonctionsPro.java`

- **Ligne 48-68 (`constructeur`)** :
  - L. 51-59 : Validation défensive des injections (`licence == null`, `recherches == null`, `depots == null`) levant des `IllegalArgumentException`.
  - L. 60-62 : Affectation des instances injectées (`this.licence`, `this.recherches`, `this.depots`).
  - *Verdict :* L'état de licence `licence` est injecté au constructeur, assurant la testabilité et l'absence de couplage dur.

- **Ligne 72-74 (`estPro`)** :
  - L. 73 : `return licence.estPro();`
  - *Verdict :* Délégation directe à l'instance injectable `LicenceEtat.estPro()`.

- **Ligne 85-89 (`rechercherParMessages` — P1)** :
  - L. 87 : `exigerPro("P1");` — première instruction exécutée impérativement.
  - L. 88 : Appel moteur uniquement atteint si `estPro()` est vrai.
  - *Verdict :* Garde active, aucun chemin d'exécution ne contourne la vérification.

- **Ligne 100-104 (`rechercherParMessagesEtDiffs` — P1)** :
  - L. 102 : `exigerPro("P1");` — première instruction exécutée impérativement.
  - L. 103 : Appel moteur uniquement atteint si `estPro()` est vrai.
  - *Verdict :* Garde active, aucun chemin d'exécution ne contourne la vérification.

- **Ligne 114-117 (`exporter` — P2)** :
  - L. 115 : `exigerPro("P2");` — première instruction exécutée impérativement.
  - L. 116 : Appel à `ExportResultats.formater(hits, format)` uniquement atteint si `estPro()` est vrai.
  - *Verdict :* Garde active, aucun chemin d'exécution ne contourne la vérification.

- **Ligne 127-131 (`sauvegarderRecherche` — P3)** :
  - L. 129 : `exigerPro("P3");` — première instruction exécutée impérativement.
  - L. 130 : Délégation à `recherches.sauvegarder(...)` conditionnée par la garde.
  - *Verdict :* Garde active, aucun chemin d'exécution ne contourne la vérification.

- **Ligne 139-143 (`recherchesSauvegardees` — P3)** :
  - L. 141 : `exigerPro("P3");` — première instruction exécutée impérativement.
  - L. 142 : Délégation à `recherches.parDepot(depot)` conditionnée par la garde.
  - *Verdict :* Garde active, aucun chemin d'exécution ne contourne la vérification.

- **Ligne 155-168 (`rechercherDansTousLesDepots` — P4)** :
  - L. 158 : `exigerPro("P4");` — première instruction exécutée impérativement.
  - L. 159-167 : Récupération des dépôts et exécution de la recherche multi-dépôts.
  - *Verdict :* Garde active, aucun chemin d'exécution ne contourne la vérification.

- **Ligne 182-186 (`exigerPro`)** :
  - L. 183 : `if (!licence.estPro()) {`
  - L. 184 : `throw new FonctionProRefuseeException(fonction);`
  - L. 185 : `}`
  - *Verdict :* Condition stricte et univoque : si `estPro()` renvoie faux, l'exception contrôlée dédiée est levée immédiatement.

- **Ligne 171-179 (`rechercherDans`)** :
  - L. 172-178 : Lecture locale via `PickaxeRepository.open(cible.getCheminPath())` dans un try-with-resources.
  - *Verdict :* Lecture locale en mémoire/Git pur, aucun appel réseau, aucune écriture disque.

---

### 2. `LicenceEtat.java` et `FournisseurLicence.java`

- **`FournisseurLicence.java` : Ligne 13-24** :
  - Interface pure sans dépendances externes.
  - Méthode `Boolean licenceProActive();`.
  - *Verdict :* L'abstraction est totalement découplée et injectable.

- **`LicenceEtat.java` : Ligne 34-42 (`constructeur`)** :
  - Injection obligatoire du `FournisseurLicence` (`if (fournisseur == null) throw new IllegalArgumentException(...)`).
  - *Verdict :* Injection stricte et testable hors IDE.

- **`LicenceEtat.java` : Ligne 48-50 (`estPro`)** :
  - `return Boolean.TRUE.equals(lire());`
  - *Verdict :* Si `lire()` retourne `null` (état inconnu) ou `false`, `estPro()` vaut strictement `false`.

- **`LicenceEtat.java` : Ligne 60-70 (`lire`)** :
  - L. 61 : `try { return fournisseur.licenceProActive(); }`
  - L. 63-69 : `catch (RuntimeException | LinkageError e) { return Boolean.FALSE; }`
  - *Verdict :* Toute anomalie ou absence de classe plateforme est absorbée sans jamais faire fuiter d'exception brute vers l'appelant.

- **`LicenceEtat.java` : Ligne 32 (`MESSAGE_LICENCE_REQUISE`)** :
  - `public static final String MESSAGE_LICENCE_REQUISE = "fonction Pro — licence requise";`
  - *Verdict :* Formulation strictement conforme au message exigé.

---

### 3. `FonctionProRefuseeException.java`

- **Ligne 18 (`MESSAGE`)** :
  - `public static final String MESSAGE = "fonction Pro — licence requise";`
  - *Verdict :* Constante publique exacte.

- **Ligne 24-27 (`constructeur`)** :
  - `super(MESSAGE);`
  - `this.fonction = fonction == null ? "" : fonction;`
  - *Verdict :* Exception contrôlée propre, message utilisateur non-technique, aucune exception brute remontée.

---

### 4. `ExportResultats.java` (P2)

- **Lignes 39-55 (`formater`)**, **57-70 (`enCsv`)**, **72-83 (`enMarkdown`)**, **85-92 (`listePatchs`)** :
  - Mise en forme pure en mémoire via des `StringBuilder`.
  - *Verdict :* Renvoie une `String`. Aucune ouverture de socket réseau, aucun flux d'écriture sur le système de fichiers (`FileWriter`, etc.).

---

### 5. `RecherchesSauvegardees.java` et `StockageRecherches.java` (P3)

- **`StockageRecherches.java` : Ligne 13-30** :
  - Interface avec méthodes en mémoire `charger(String depot)` et `enregistrer(String depot, List<RechercheSauvee> recherches)`.
- **`RecherchesSauvegardees.java` : Lignes 39-55, 62-71** :
  - Manipulation de listes en mémoire (`ArrayList`, `Collections.unmodifiableList`).
  - *Verdict :* La classe métier ne fait ni I/O disque directe ni appel réseau ; le stockage sous-jacent est injecté.

---

### 6. `DepotsDuProjet.java` et `DepotCible.java` (P4)

- **`DepotsDuProjet.java` : Lignes 37-52, 60-84, 86-90** :
  - Exploration arborescente locale en lecture seule via `Files.isDirectory`, `Files.list`, `Files.isRegularFile`.
  - Aucune modification du système de fichiers (`Files.write`, `Files.delete`, `Files.createDirectory`, etc. sont absents).
  - Aucun appel réseau.
  - *Verdict :* Lecture locale stricte, aucune écriture disque, aucun appel réseau.

---

## Conclusion et verdict final

- **Garde `estPro()`** : **CONFORME** (les 4 fonctions P1, P2, P3, P4 vérifient `estPro()` immédiatement à l'entrée).
- **FournisseurLicence injectable** : **CONFORME** (`LicenceEtat` reçoit `FournisseurLicence` et est injecté dans `FonctionsPro`).
- **Aucun retour Pro sans licence** : **CONFORME** (l'exception interrompt tout flux d'exécution).
- **Message d'exception** : **CONFORME** (strictement « fonction Pro — licence requise », aucune exception brute non gérée).
- **Absence d'appels réseau / écritures disque** : **CONFORME** (100% pur en mémoire et lecture locale).
- **Code source produit** : **INTACT** (aucun patch appliqué sur le code Java canonique).
