# Security and privacy

Beacon is a personal native Mac app backed by Apple Reminders and EventKit. It has no third-party package dependencies, backend server, API keys, or analytics integration. Google/iCloud account authentication and calendar sync are handled by macOS.

## Review before public source publication — 2026-09-08

- Gitleaks 8.30.1 scanned all existing Git history and the publication file set with redacted output: no secrets detected.
- Reviewed external URL handling, Calendar permissions/read paths, reminder write paths, Siri capture, native dictation, local storage, build/signing scripts, and repository contents.
- Corrected the development signing helper: removed the `security import -A` option that trusted all applications, retaining only `/usr/bin/codesign`, and set restrictive permissions on temporary signing files. This changes future setup runs; it does not retroactively alter an existing keychain item's access controls. Existing installations can review the Beacon Dev private key's Access Control in Keychain Access.
- Added Git exclusions for environment secrets, private keys, signing bundles, provisioning profiles, and personal Xcode settings.
- All 104 automated tests passed. Tests include rejecting insecure HTTP and lookalike meeting hosts. Calendar events are read only; meeting links are limited to HTTPS on supported meeting domains.

## Limits and trust model

This is a source review and automated scan, not a penetration test or a guarantee that no vulnerabilities exist. macOS builds currently run without App Sandbox or Hardened Runtime and are locally signed, not notarized distribution builds. Only run builds you trust.

Apple's permission prompts govern Reminders and Calendar access. Reminder titles can appear in notifications according to macOS notification settings. Local preferences and scheduling metadata are stored in the user's profile; they are not separately encrypted by Beacon. Calendar and reminder data must not be committed to Git.

The optional end-to-end scripts operate on real Apple Reminders and delete scratch reminders with the `beacon-e2e-` prefix. They were not run for this review. Use a test environment for them. No signing identity was created or modified during the review.

Do not include secrets or private reminders in public issues. Report suspected security problems through GitHub private vulnerability reporting if enabled.
