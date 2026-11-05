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
        // IDE de compilation, deux facons (mesurees le 05/11/2026) :
        //
        //  - `-PplatformLocalPath=/work/ide/pycharm-2026.2.4` : compile
        //    CONTRE l'IDE deja installe dans le conteneur. ZERO
        //    telechargement, et le `since-build` 262 est alors l'EXACT
        //    numero de build de l'IDE compile (262.11879.98).
        //  - sinon : `create("PY", platformVersion)` telecharge l'IDE
        //    depuis le CDN JetBrains (necessite le reseau).
        //
        // La premiere forme est celle du build hors ligne : elle garantit
        // que le ZIP livre est compile contre la MEME plateforme que
        // celle annoncee dans `since-build`.
        val localIdePath = (project.findProperty("platformLocalPath") as String?)?.trim()
        if (!localIdePath.isNullOrEmpty()) {
            local(file(localIdePath))
        } else {
            create("PY", (project.findProperty("platformVersion") as String?) ?: "2026.2.4")
        }
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
    // Instrumentation du bytecode par JetBrains : DESACTIVEE, et c'est une
    // decision mesuree.
    //
    // MESURE du 05/11/2026 : la tache `:instrumentCode` resout
    // `com.jetbrains.intellij.java:java-compiler-ant-tasks:262.11879.98`
    // depuis Maven. En mode `--offline` (conteneur sans acces au CDN
    // JetBrains) cet artefact N'EST PAS dans le cache (seule la version
    // 243.21565.199 y est) -> le build echoue :
    //   No cached version of com.jetbrains.intellij.java:java-compiler-ant-tasks:262.11879.98
    //   available for offline mode.
    //
    // Consequence de la desactivation : le jar du plugin ne contient pas
    // les assertions `@NotNull` injectees par l'instrumentation. Elles ne
    // servent qu'a detecter des violations de contrat en developpement ;
    // le comportement du plugin a l'execution est identique.
    instrumentCode = false

    pluginConfiguration {
        id = "com.tgglabs.pickaxe"
        name = (project.findProperty("pluginName") as String?) ?: "Find in Commit History"
        version = project.version.toString()
        ideaVersion {
            sinceBuild = (project.findProperty("pluginSinceBuild") as String?) ?: "262"
            // `until-build` : on ne l'ecrit QUE si la propriete existe ET
            // n'est pas vide. Le champ `pluginUntilBuild` a ete SUPPRIME de
            // `gradle.properties` le 05/11/2026 : le XML genere ne doit donc
            // contenir AUCUN attribut `until-build`
            // (verifie dans le ZIP livre, pas dans le source).
            val configuredUntilBuild = (project.findProperty("pluginUntilBuild") as String?)?.trim()
            if (!configuredUntilBuild.isNullOrEmpty()) {
                untilBuild = configuredUntilBuild
            }
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

// Bytecode Java 21.
//
// MESURES du 05/11/2026 (elles CHANGENT la conclusion du cycle 116) :
//   * `product-info.json` de PyCharm 2026.2.4 (build 262.11879.98) dit
//     « minRequiredJavaVersion » = 25 : un plugin dont le `since-build` est
//     262 ne peut donc JAMAIS tourner sur un JVM 17 ;
//   * les plugins embarques dans cet IDE sont compiles majoritairement en
//     major 65 = Java 21 (1 530 classes mesurees), major 69 = Java 25
//     (1 120 classes) : Java 21 est le niveau de reference de la plateforme.
// Le refus du cycle 116 (« 17 est le format demande pour since-build 243 »)
// n'a donc plus de fondement : le `since-build` est passe a 262.
// C'est pourquoi le hunk de Jules (tache 15597185981936027315) est
// APPLIQUE ici, et non refuse.
// Compilateur : Java 25 minimum, OUTREMENT que le bytecode produit.
//
// MESURE du 05/11/2026 : les classes de la plateforme 2026.2.4 sont en
// « major version 69 » (Java 25) — par exemple
// `lib/intellij.platform.ide.jar(/com/intellij/openapi/ui/DialogWrapper.class)`.
// Un `javac` 21 refuse de les lire :
//   bad class file: .../DialogWrapper.class
//   class file has wrong version 69.0, should be 65.0
// -> 38 erreurs de compilation. Le compilateur DOIT donc etre un JDK 25.
//
// Ce n'est PAS le JDK 25 de la machine : c'est le JBR (JetBrains Runtime)
// deja installe DANS l'IDE de reference, que Gradle detecte comme
// toolchain via :
//   -Porg.gradle.java.installations.paths=/work/ide/pycharm-2026.2.4/jbr
// (Gradle 8.10.2, lui, ne peut PAS tourner sur un JVM 25 : mesure,
// « Unsupported class file major version 69 » — le daemon reste donc sur
// le JDK 21.)
//
// Le BYTECODE produit reste en Java 21 (`sourceCompatibility`/`targetCompatibility`),
// comme le demande la plateforme pour un plugin `since-build 262`.
java {
    toolchain {
        languageVersion.set(
            JavaLanguageVersion.of((project.findProperty("javaToolchainVersion") as String?) ?: "25")
        )
    }
}

tasks.withType<JavaCompile>().configureEach {
    sourceCompatibility = "21"
    targetCompatibility = "21"
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
