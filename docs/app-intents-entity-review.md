# App Intents entity review

Updated 20 August 2026. PageLumen uses the current `AppEntity` and
`DisplayRepresentation` APIs available to the macOS 14 deployment target.

The document entity exposes only a bounded title, page count, and unresolved
finding count. The finding entity exposes an opaque identifier, document
identifier/title, page number, kind, severity, and resolved state. Neither
entity has an OCR excerpt, source URL, prompt, response, or arbitrary
document-text property. Titles are normalized and capped at 120 characters.

Newer entity schemas and view annotations were evaluated but deliberately not
adopted: they do not provide a required user outcome here and could widen the
system-discoverable context without improving the bounded actions. Any future
adoption requires a new privacy review and entity-retention tests.
