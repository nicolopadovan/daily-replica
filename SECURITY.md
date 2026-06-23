# Security Policy

Daily Replica is currently a Proof of Concept. It is local-first, but it has not
had a formal security audit or hardening pass.

## Supported Versions

Only the latest released version is supported for security fixes.

## Reporting a Vulnerability

Please open a private security advisory on GitHub if available, or contact the
maintainer before publishing details publicly. Include:

- The affected version or commit
- Steps to reproduce
- Expected and actual behavior
- Any local data or permission impact

## Local Data And Permissions

Daily Replica stores activity data locally in SQLite under the user's
Application Support directory. The app may request macOS Accessibility access
for focused window titles and Automation access for reading the active Chrome
tab URL. If either permission is denied, app-level tracking continues and the
unavailable window or URL detail is left blank.

The app includes local controls to export data as JSON, export activity segments
as CSV, clear activity history, and reset all local data stored by Daily Replica.
