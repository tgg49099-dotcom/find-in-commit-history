// Nom du projet Gradle = nom du ZIP produit par `buildPlugin` (mesure du
// 05/11/2026 : le ZIP s'appelle `<rootProject.name>-<version>.zip`).
// On y met le nom public du plugin, sans espace ni ponctuation, comme sur le
// Marketplace : « Find in Commit History » -> FindinCommitHistory-0.0.1.zip.
// C'est ce qui rend coherents les 4 identifiants : <name> de plugin.xml,
// xmlId, nom du ZIP et nom de l'action.
rootProject.name = "FindinCommitHistory"
