# Security Policy

## Reporting a Vulnerability

Please do not open public issues for vulnerabilities involving document privacy, local file handling, sandboxing, export integrity, or other security-sensitive behavior.

Instead, report privately through GitHub's private vulnerability reporting if enabled for this repository. If private reporting is not available, contact the maintainer directly and include:

- A short description of the issue
- Steps to reproduce
- Impact and affected versions or commits
- Any suggested mitigation

## Privacy-Sensitive Areas

PageLumen handles user documents that may be private, legal, academic, medical, or workplace-sensitive. Please treat the following areas carefully:

- File import and temporary files
- Screenshot capture
- OCR and document processing
- Export generation
- Future network-assisted processing
- Logs and diagnostics

Avoid adding telemetry, network calls, or document-content logging without explicit user control and documentation.
