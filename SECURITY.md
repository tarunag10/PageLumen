# Security Policy

## Reporting a Vulnerability

Please do not open public issues for vulnerabilities involving document privacy, local file handling, sandboxing, export integrity, or other security-sensitive behavior.

Use the repository's [private vulnerability report form](https://github.com/tarunag10/PageLumen/security/advisories/new). This is the primary security contact channel and supports encrypted, maintainer-only coordination through GitHub. If the form is unavailable, open a minimal public issue asking the maintainer to enable private reporting; do not include document contents, credentials, or exploit details. Include the following only through a private channel:

- A short description of the issue
- Steps to reproduce
- Impact and affected versions or commits
- Any suggested mitigation

### Handling process

- We aim to acknowledge a report within 5 business days.
- We will triage severity, affected versions, exploitability, and whether user documents or credentials could be exposed.
- We will coordinate a fix, regression tests, and a release or mitigation with the reporter before public disclosure whenever practical.
- We target an initial remediation plan within 14 calendar days. Complex issues may take longer; the private report will remain the source of truth for status updates.
- We will credit reporters only with their permission and will not disclose document contents, personal data, or identifying details.
- Please allow a reasonable coordination period before public disclosure. We may request a CVE or other identifier when an issue affects a released distribution.

### In scope

Reports are welcome for vulnerabilities in the PageLumen application, bundled extensions, build/release configuration, document parsing and export paths, privacy/retention controls, and documented integrations that can affect a PageLumen user.

Third-party services or dependencies should also be reported when PageLumen's integration introduces a distinct security impact; otherwise, please report the underlying issue to that project's security channel as well.

### Out of scope

Please do not include ordinary bugs, feature requests, unsupported operating-system configurations, or generated documents containing real personal information. Do not attempt denial-of-service testing against maintainers' infrastructure or access data that does not belong to you.

## Privacy-Sensitive Areas

PageLumen handles user documents that may be private, legal, academic, medical, or workplace-sensitive. Please treat the following areas carefully:

- File import and temporary files
- Screenshot capture
- OCR and document processing
- Export generation
- Future network-assisted processing
- Logs and diagnostics

Avoid adding telemetry, network calls, or document-content logging without explicit user control and documentation.
