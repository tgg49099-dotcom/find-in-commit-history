# Publication du plugin « Find in Commit History » (JetBrains Marketplace)

## Ce que contient ce dossier

- `FindinCommitHistory-0.0.1.zip` — **le plugin à téléverser**.
  md5 `25d82c71a9782c0798cbd2c27c0be242` · sha256 `8e657c0c2e8b36034cb83767ed9fe53be32abd2d5d564bac4be4326ba66720a1` · 3 133 459 octets.
  Construit le 06/11/2026 à 02:52:16 CET (`scripts/build_zip.sh`, 0 téléchargement, 0 $).
  **Ne pas le décompresser, le renommer ni le recompresser.**
- `captures/01-resultats.png`, `captures/02-hash-copie.png`, `captures/03-filtre-chemin.png` — les **3 captures** à joindre (1200 × 780 px).
- `MISE-VENTE-TGG.md` — **le formulaire, champ par champ** : les 20 champs, les valeurs exactes, les 2 blocs de texte à coller tels quels, et la marche à suivre complète.

## Les gestes, dans l'ordre (≈ 10 min)

1. Se connecter sur **https://plugins.jetbrains.com/plugin/add** (compte JetBrains de Tgg).
2. **Vendor** : sélectionner « Tgg Labs » (id 21195) s'il est proposé ; sinon accepter le Marketplace Developer Agreement et créer le profil vendor, nom public `Tgg Labs`, e-mail `tgg.apps.support@gmail.com`. **Ne pas créer un 2ᵉ vendor.**
3. Si le formulaire demande le **statut de commerçant** : c'est un acte juridique réservé à Tgg → **arrêter là et me le dire** (ne rien cocher à ma place, ne rien inventer).
4. Remplir les 20 champs avec les valeurs de `MISE-VENTE-TGG.md` § 1. Les blocs « description » et « change notes » se **collent tels quels**, sans retouche.
5. Prix **Free** (0 $) · canal par défaut · **hidden décoché** · pas de publicité · since-build **262** · catégorie **VCS** · mots-clés `git pickaxe search history log`.
6. Déposer le ZIP ci-dessus, puis joindre les **3 captures**. Soumettre (« Submit »).
7. **Le geste qui met la fiche en ligne** : après le Submit, ouvrir la page du plugin → onglet **Sales Info** → bouton **« Add to Marketplace »** → prix Free. (L'upload seul ne publie rien.)

## Contrôle avant de cliquer

```
md5sum FindinCommitHistory-0.0.1.zip
# attendu : 25d82c71a9782c0798cbd2c27c0be242
```

Un md5 différent ⇒ le fichier reçu n'est pas celui annoncé : **ne pas téléverser**, dis-le-moi.

## Lien de code source (obligatoire dans le formulaire)

https://github.com/tgg49099-dotcom/find-in-commit-history — dépôt public, commit du code `d5da657`.

En cas d'erreur du formulaire : **copie le message exact** et envoie-le-moi. 0 $.
