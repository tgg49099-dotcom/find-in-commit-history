// Pickaxe — build script.
//
// Slot 5 (JetBrains Marketplace). Produit : rechercher dans l'historique Git
// les commits qui AJOUTENT ou SUPPRIMENT une chaine (equivalent de
// `git log -S`) ou dont le DIFF matche une expression (equivalent de
// `git log -G`).
//
// Demande d'origine : YouTrack IJPL-84839 « Wanted: Same functionality as
// git log -S / git log -G available in "Find Commit" » (205 votes, ouvert
// depuis le 26/06/2013).
//
// Meme pile que les plugins deja publies par ce slot (IntelliJ Platform
// Gradle Plugin 2.7.2 + JDK 21), donc la recette est deja validee.
//
// ---------------------------------------------------------------------------
// JGit : OU EST-IL ?
// ---------------------------------------------------------------------------
// La consigne du 05/11/2026 disait « JGit, fourni par l'IDE : org.jetbrains.jgit,
// ne pas embarquer de dependance lourde ». MESURE (05/11/2026, PyCharm
// 2026.2.4 = build 262.11879.98) :
//
//   * `org.jetbrains.jgit` : 0 classe dans les 1 378 jars de l'IDE ;
//   * `org.eclipse.jgit`   : 1 597 classes, mais dans UN SEUL jar —
//     `lib/intellij.settingsSync.core.jar` — c'est-a-dire le jar du plugin
//     « com.intellij.settingsSync », PAS le classpath de la plateforme
//     (`bootClassPathJarNames` = 263 entrees, aucune ne contient
//     « settingsSync ») ;
//   * le plugin Git de l'IDE (`vcs-git`, id `Git4Idea`) ne reference
//     AUCUNE classe `org/eclipse/jgit` (0 occurrence sur 4 500 classes) :
//     il a ete reecrit en Rust.
//
// Consequence : un plugin tiers NE VOIT PAS JGit, sauf a declarer une
// dependance sur « com.intellij.settingsSync » — c'est-a-dire a rendre
// obligatoire un plugin que l'utilisateur peut desactiver, sans rapport avec
// la gestion de version. On embarque donc JGit (3,2 Mo), dans la version
// EXACTE que l'IDE utilise lui-meme (6.10.1) : c'est le seul moyen d'avoir
// un plugin autonome qui marche partout. Le rapport du cycle mesure le poids
// reel du ZIP.
//
// `org.slf4j` (API) est fourni par la plateforme (`util-8.jar`) : il n'est
// donc PAS embarque. `commons-codec` est egalement fourni par la plateforme
// (`intellij.libraries.commons.codec.jar`). JavaEWAH, lui, n'y est pas :
// il est embarque (64 Ko).
// ---------------------------------------------------------------------------

plugins {
    java
    id("org.jetbrains.intellij.platform") version "2.7.2"
}

group = "com.tgglabs.pickaxe"
version = (project.findProperty("pluginVersion") as String?) ?: "0.0.1"

repositories {
    mavenCentral()
    intellijPlatform {
        defaultRepositories()
    }
}

dependencies {
    intellijPlatform {
        // PyCharm Professional 2024.3 : deja dans le cache Gradle du
        // conteneur, le build ne telecharge rien de gros.
        create("PY", (project.findProperty("platformVersion") as String?) ?: "2024.3")
    }

    // JGit : embarque (voir le bloc de commentaire ci-dessus).
    // 6.10.1.202505221210-r est EXACTEMENT la version presente dans
    // l'IDE 2026.2.4 (compare classe par classe : 1 594 classes communes
    // sur 1 597).
    implementation("org.eclipse.jgit:org.eclipse.jgit:6.10.1.202505221210-r") {
        // MESURE du 05/11/2026 (build Gradle officiel, `unzip -l` du ZIP
        // produit SANS ces exclusions) : le ZIP embarquait 5 jars, dont
        //   - slf4j-api-1.7.36.jar  -> INTERDIT par JetBrains (la plateforme
        //     fournit org.slf4j dans util-8.jar) ;
        //   - commons-codec-1.17.0.jar -> fourni par la plateforme
        //     (intellij.libraries.commons.codec.jar).
        // Ces deux-la sont donc des dependances TRANSITIVES de JGit a
        // exclure : c'est ce que fait le script hors reseau du cycle 115.
        exclude(group = "org.slf4j", module = "slf4j-api")
        exclude(group = "commons-codec", module = "commons-codec")
    }
    implementation("com.googlecode.javaewah:JavaEWAH:1.1.12")

    // slf4j-api n'est plus resolu par la dependance JGit (exclu ci-dessus) :
    // il faut le remettre explicitement pour la CLASSE DE TEST, sinon JGit
    // ne trouve pas org.slf4j.LoggerFactory au runtime des tests.
    // `testImplementation` n'est JAMAIS embarque dans le ZIP.
    testImplementation("org.slf4j:slf4j-api:2.0.13")
    testImplementation("org.junit.jupiter:junit-jupiter:5.10.2")
    testRuntimeOnly("org.junit.jupiter:junit-jupiter-engine:5.10.2")
    testRuntimeOnly("org.junit.platform:junit-platform-launcher")
}

intellijPlatform {
    pluginConfiguration {
        id = "com.tgglabs.pickaxe"
        name = (project.findProperty("pluginName") as String?) ?: "Find in Commit History"
        version = project.version.toString()
        ideaVersion {
            sinceBuild = (project.findProperty("pluginSinceBuild") as String?) ?: "243"
            untilBuild = (project.findProperty("pluginUntilBuild") as String?) ?: "263.*"
        }
        vendor {
            name = (project.findProperty("pluginVendorName") as String?) ?: "Tgg Labs"
            email = (project.findProperty("pluginVendorEmail") as String?) ?: "tgg.apps.support@gmail.com"
            url = (project.findProperty("pluginVendorUrl") as String?) ?: "https://plugins.jetbrains.com/vendor/tgg-labs"
        }
    }
    // Aucune publication depuis ce build : le jeton n'est meme pas lu ici.
    // `publishPlugin` / `uploadPlugin` ne doivent JAMAIS etre lances sans
    // l'accord du proprietaire (cf. NOTES.md).
    publishing {
        token = System.getenv("JETBRAINS_MARKETPLACE_TOKEN")
    }
}

// Bytecode Java 17 : format impose par la plateforme (build 243+).
// MESURE du 05/11/2026 : le jar produit par le build Gradle officiel est en
// « major version 61 » = Java 17, exactement comme le ZIP construit a la main
// du cycle 115. Une proposition de Jules (tache 15597185981936027315) faisait
// passer le bytecode en Java 21 : REFUSEE, parce qu'elle aurait rendu les deux
// ZIP non identiques (class file 65 au lieu de 61) alors qu'aucune mesure ne
// l'exige, et que 17 est le format demande par la plateforme pour un plugin
// `since-build 243`.
tasks.withType<JavaCompile>().configureEach {
    sourceCompatibility = "17"
    targetCompatibility = "17"
    options.encoding = "UTF-8"
}

// Les tests sont des tests de moteur pur (JGit), pas des tests d'IDE :
// ils n'ont besoin d'aucune classe de la plateforme.
tasks.withType<Test>().configureEach {
    useJUnitPlatform()
    systemProperty("java.awt.headless", "true")
    maxHeapSize = "512m"
    testLogging {
        events("passed", "failed", "skipped")
        showStandardStreams = false
    }
}

// `buildSearchableOptions` lance un IDE complet en arriere-plan pour indexer
// les pages de REGLAGES. Ce plugin n'a AUCUNE page de reglages : l'index
// serait vide. La tache a deja TUE un build dans ce conteneur (exit 137 =
// SIGKILL de l'OOM, conteneur plafonne a 1 572 864 000 octets). On la
// desactive : elle n'apporte rien ici.
tasks.matching { it.name == "buildSearchableOptions" }.configureEach {
    enabled = false
}
