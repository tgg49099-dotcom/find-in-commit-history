// Find in Commit History — build script.
//
// A plugin that searches the Git history for the commits that ADD or REMOVE a
// string (the equivalent of `git log -S`) or whose DIFF matches a regular
// expression (the equivalent of `git log -G`).
//
// ---------------------------------------------------------------------------
// Why is JGit bundled?
// ---------------------------------------------------------------------------
// Measured on the jars of PyCharm 2026.2.4 (build 262.11879.98):
//
//   * `org.jetbrains.jgit`: 0 class in the 1,378 jars of the IDE;
//   * `org.eclipse.jgit`  : present, but only inside `lib/intellij.settingsSync.core.jar`
//     — the jar of the "Settings Sync" plugin, NOT the platform classpath
//     (`bootClassPathJarNames` = 263 entries, none of them "settingsSync");
//   * the IDE's own Git plugin (`Git4Idea`) references no `org/eclipse/jgit`
//     class at all (it has been rewritten in Rust).
//
// A third-party plugin therefore does not see JGit, unless it declares a
// dependency on "com.intellij.settingsSync" — i.e. it would make a plugin the
// user can disable mandatory, which has nothing to do with version control.
// JGit is therefore bundled, in the exact version the IDE itself uses (6.10.1).
//
// `org.slf4j` (API) and `commons-codec` are provided by the platform
// (`util-8.jar`, `intellij.libraries.commons.codec.jar`), so they are NOT
// bundled. JavaEWAH is not: it is bundled (~170 KB).
// ---------------------------------------------------------------------------

import org.gradle.api.tasks.bundling.AbstractArchiveTask

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
        // The IDE to compile against, two ways:
        //
        //  - `-PplatformLocalPath=/path/to/ide` : compile AGAINST a local IDE
        //    installation. Nothing is downloaded, and `since-build` is then the
        //    exact build number of the IDE that was compiled against.
        //  - otherwise: `create("PY", platformVersion)` downloads the IDE from
        //    the JetBrains CDN (requires the network).
        //
        // The first form is what an offline build uses.
        val localIdePath = (project.findProperty("platformLocalPath") as String?)?.trim()
        if (!localIdePath.isNullOrEmpty()) {
            local(file(localIdePath))
        } else {
            create("PY", (project.findProperty("platformVersion") as String?) ?: "2026.2.4")
        }

        // JetBrains Plugin Verifier (the `verifyPlugin` task).
        // The `verifier-cli` artifact is not in every local Gradle cache: in
        // `--offline` mode that task fails with "No cached version of
        // org.jetbrains.intellij.plugins:verifier-cli ... available for offline
        // mode". The declaration is kept here because it does not weigh on
        // `buildPlugin` (it is resolved only by `verifyPlugin`) and because it
        // makes the task usable as soon as a network is available.
        pluginVerifier()
    }

    // JGit — bundled (see the header of this file).
    // 6.10.1.202505221210-r is EXACTLY the version used by the IDE 2026.2.4
    // (1,594 common classes out of 1,597).
    implementation("org.eclipse.jgit:org.eclipse.jgit:6.10.1.202505221210-r") {
        // These two are TRANSITIVE dependencies of JGit, and both are provided
        // by the platform:
        //   - slf4j-api         -> forbidden by JetBrains (the platform ships
        //                          org.slf4j in util-8.jar);
        //   - commons-codec     -> provided by the platform
        //                          (intellij.libraries.commons.codec.jar).
        // Bundling them would make the plugin distribution rejected.
        exclude(group = "org.slf4j", module = "slf4j-api")
        exclude(group = "commons-codec", module = "commons-codec")
    }
    implementation("com.googlecode.javaewah:JavaEWAH:1.1.12")

    // slf4j-api is no longer resolved through the JGit dependency (excluded
    // above): it has to be brought back explicitly for the TEST classpath,
    // otherwise JGit cannot find org.slf4j.LoggerFactory at test runtime.
    // `testImplementation` is NEVER bundled in the distribution ZIP.
    testImplementation("org.slf4j:slf4j-api:2.0.13")
    testImplementation("org.junit.jupiter:junit-jupiter:5.10.2")
    testRuntimeOnly("org.junit.jupiter:junit-jupiter-engine:5.10.2")
    testRuntimeOnly("org.junit.platform:junit-platform-launcher")
}

intellijPlatform {
    // JetBrains bytecode instrumentation: DISABLED, and this is a measured
    // decision.
    //
    // The `:instrumentCode` task resolves
    // `com.jetbrains.intellij.java:java-compiler-ant-tasks:<version>` from
    // Maven. In `--offline` mode that artifact is usually not in the local
    // cache, and the build fails. Disabling it means the plugin jar does not
    // contain the injected `@NotNull` assertions: they only matter to catch
    // contract violations during development, the runtime behaviour of the
    // plugin is identical.
    instrumentCode = false

    // Plugin Verifier: it is given the LOCAL IDE, so that nothing is
    // downloaded. The task checks the ZIP against the code of that IDE.
    pluginVerification {
        ides {
            val localIdePath = (project.findProperty("platformLocalPath") as String?)?.trim()
            if (!localIdePath.isNullOrEmpty()) {
                local(file(localIdePath))
            }
        }
    }

    pluginConfiguration {
        id = "com.tgglabs.pickaxe"
        name = (project.findProperty("pluginName") as String?) ?: "Find in Commit History"
        version = project.version.toString()
        ideaVersion {
            sinceBuild = (project.findProperty("pluginSinceBuild") as String?) ?: "262"
            // `until-build` is written ONLY if the property exists AND is not
            // empty: the plugin declares no upper bound.
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
    // No publication from this build: the token is not even read here.
    // `publishPlugin` / `uploadPlugin` must NEVER be run without the explicit
    // agreement of the repository owner.
    publishing {
        token = System.getenv("JETBRAINS_MARKETPLACE_TOKEN")
    }
}

// ---------------------------------------------------------------------------
// Java toolchain
// ---------------------------------------------------------------------------
// The IDE 2026.2.4 classes are in "class file 69" (Java 25) — for example
// `lib/intellij.platform.ide.jar(/com/intellij/openapi/ui/DialogWrapper.class)`.
// A `javac` 21 refuses to read them:
//   bad class file: .../DialogWrapper.class
//   class file has wrong version 69.0, should be 65.0
// -> the compiler MUST be a JDK 25.
//
// It is not a JDK 25 installed on the machine: it is the JetBrains Runtime
// (JBR) that ships INSIDE the IDE, which Gradle picks up as a toolchain via
//   -Porg.gradle.java.installations.paths=/path/to/ide/jbr
// (Gradle 8.10.2 itself cannot run on a JVM 25: "Unsupported class file major
// version 69" — the daemon stays on JDK 21.)
//
// The PRODUCED bytecode stays at Java 21 (`sourceCompatibility` /
// `targetCompatibility` = 21), which is the reference level of the platform
// for a plugin with `since-build 262`.
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

// The tests are pure engine tests (JGit): they need no class of the platform.
tasks.withType<Test>().configureEach {
    useJUnitPlatform()
    systemProperty("java.awt.headless", "true")
    maxHeapSize = "512m"
    testLogging {
        events("passed", "failed", "skipped")
        showStandardStreams = false
    }
}

// `buildSearchableOptions` starts a full IDE in the background to index the
// SETTINGS pages. This plugin has NO settings page: the index would be empty.
// The task is disabled: it brings nothing here.
tasks.matching { it.name == "buildSearchableOptions" }.configureEach {
    enabled = false
}

// ---------------------------------------------------------------------------
// REPRODUCIBLE ZIP
// ---------------------------------------------------------------------------
// The SHA-256 of the released ZIP is published in `SHA256.txt`. By default
// Gradle writes the TIMESTAMP of every entry of the ZIP: the hash then changes
// at every build, and the documented hash becomes stale after the first
// rebuild.
//
// These two options remove the timestamps and sort the entries: two builds of
// the same sources then produce the SAME ZIP, byte for byte.
tasks.withType<AbstractArchiveTask>().configureEach {
    isPreserveFileTimestamps = false
    isReproducibleFileOrder = true
}
