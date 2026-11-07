# Security Policy — Find in Commit History

## Reporting a vulnerability

**Please do not open a public GitHub issue for a security problem.**

Report it by email to **tgg.apps.support@gmail.com** with:

- the plugin version and your IDE build;
- what you did, what you expected, and what happened;
- the steps to reproduce, and any proof-of-concept you are comfortable sharing
  by email.

We acknowledge reports as soon as we can (normally within a few working days)
and keep you informed while we investigate. We will tell you when a fix is
published, and we will credit you in the release notes if you want us to.

Please give us a reasonable window to ship a fix before disclosing publicly.

## What the plugin does

Find in Commit History searches the **local** Git history of the repositories
opened in your project — the `git log -S` and `git log -G` ("pickaxe") search.
The history is read from your own repositories; **nothing is sent anywhere**:
the plugin has no account, no telemetry, no analytics and no advertising.

## What is in scope

- The plugin reading a repository, a file or a setting it should not read, for
  example outside the projects open in the IDE.
- The plugin sending any request to a third party, or making your commit
  messages, diffs, file names or search history leave your machine.
- The plugin exposing data it stores: your saved searches, your settings, or
  the state of the Pro licence.
- Writing or exporting outside the folder you chose: an export (CSV, Markdown,
  or the list of patches) landing in an unexpected place, or overwriting a file
  you did not ask to overwrite.
- Injection or unsafe handling of the content that comes out of Git — a commit
  message, a diff, a file name or a path — that leads to code execution in the
  IDE, or to a command run on your machine.
- A defect in the licence check that opens the Pro features without a licence,
  or that breaks the free search.

## What is out of scope

- Issues that require an attacker to already control your machine or your
  local account.
- Vulnerabilities in the IDE itself, in the JetBrains Marketplace, or in Git
  itself — please report those to their own maintainers (the plugin displays
  what Git returns, it does not validate it).
- Denial of service caused by searching an enormous repository.
- Missing hardening that has no practical impact in the plugin's usage.

## Supported versions

Security fixes are applied to the latest published version. Older versions are
not maintained.

| Version | Supported |
|---|---|
| 0.0.3 (current) | yes |
| ≤ 0.0.2 | no — please update |
