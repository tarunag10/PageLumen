# Search and encryption decision record

Updated 20 August 2026.

## Searchable copies

PageLumen does not currently persist an FTS index. Search is implemented behind
`DocumentRepository` and returns no results unless the person enables “Keep
searchable local copies.” The current implementation scans retained local
documents, applies a caller limit, and returns page/block citations. This is a
deliberate bounded fallback while GRDB remains unevaluated for production.

If FTS5 is later introduced, it must index only the approved local searchable
copy, delete rows transactionally with the source document, rebuild after a
schema/version change, and expose an explicit rebuild/clear result. Disabling
the setting or clearing recents must remove the searchable copy and index; no
hidden cache may survive the retention boundary.

## Encryption at rest

PageLumen makes no encryption-at-rest claim for the current JSON persistence
store. It does not generate, persist, or recover an encryption key. This keeps
the privacy statement accurate rather than implying protection that has not
been validated.

Before adopting SQLCipher or another encrypted store, a separate design review
must specify Keychain accessibility, backup/migration behavior, key loss and
recovery, document deletion, offline operation, and test evidence on supported
macOS versions. A user-visible “encrypted” label must wait for that review and
an approved migration plan.
