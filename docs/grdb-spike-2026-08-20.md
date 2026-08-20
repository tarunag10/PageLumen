# GRDB.swift spike — 2026-08-20

## Decision

Do not add GRDB.swift to the shipping target in this phase. PageLumen already
has a `DocumentRepository` boundary backed by the existing persistence adapter,
and the current product requirement is metadata recents plus explicitly
consented searchable local copies. Adding GRDB now would create a second
repository implementation without a demonstrated migration or scale need.

This is a defer decision, not a claim that GRDB or SQLCipher has been rejected
permanently.

## Spike scope

The spike evaluates the smallest production-relevant seam:

- `LocalDocumentRepository` implements `DocumentRepository` without exposing
  the underlying persistence technology.
- Metadata reads do not require page/block payloads at the call site.
- Search returns no results unless `keepSearchableLocalCopies` is enabled.
- Enabled search is bounded by a caller-provided result limit and returns
  deterministic page/block citations and snippets.
- The existing clear-recents path remains the deletion boundary; no duplicate
  index or tombstone store is introduced.

The evidence is the focused `LocalLibraryTests` suite and the repository
implementation in `Sources/PageLumenCore/LocalLibrary.swift`. The suite covers
consent-off search, consent-on matching, metadata projection, limits, and the
protocol-typed repository boundary.

## Adoption trigger

Re-open this spike only if one of these becomes true:

1. measured library/search latency or memory exceeds the documented product
   budget;
2. users explicitly opt into durable full-text search that needs FTS5;
3. a migration requires transactional relational queries that the current
   adapter cannot provide; or
4. encryption-at-rest requirements are approved with a Keychain recovery plan.

If reopened, GRDB must replace the current repository implementation behind
the same protocol. SwiftData and GRDB must not become competing production
truths, and FTS/index deletion and rebuild behavior must be designed before any
searchable-copy migration.

## Verification boundary

This document proves the source-level spike and current decision only. It does
not claim GRDB performance, SQLCipher compatibility, encryption-at-rest, or a
production migration. Those require a separately approved prototype and
device-scale measurements.
