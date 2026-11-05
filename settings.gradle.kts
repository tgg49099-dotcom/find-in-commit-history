// The name of the Gradle project is the name of the ZIP produced by
// `buildPlugin` (measured: the ZIP is called `<rootProject.name>-<version>.zip`).
// It holds the public name of the plugin, without space nor punctuation, as on
// the Marketplace: "Find in Commit History" -> FindinCommitHistory-0.0.1.zip.
// This is what keeps the four identifiers consistent: the <name> of plugin.xml,
// the xmlId, the name of the ZIP and the label of the action.
rootProject.name = "FindinCommitHistory"
