# PageLumen persistence migration and recovery contract

## Current stores

PageLumen has two persistence adapters behind `DocumentPersisting`:

- `SwiftDataPersisting` stores recent-document metadata plus a Codable
  `ReaderDocument` payload in the app-support `recents.store` container on
  macOS 14 and later.
- `FilePersisting` is the recoverable local JSON fallback. Its envelope is
  explicitly versioned with `schemaVersion = 1`; the legacy top-level array
  format is read as version 0 and upgraded on the next successful write.

The fallback store is not a second source of truth during normal operation. It
is a safety boundary used when SwiftData cannot open or save. The active
document remains in memory and the UI reports degraded recents storage.

## Rules for the next schema change

1. Add a new `VersionedSchema` type and migration plan before changing
   `PersistedDocument` fields. Do not rely on implicit SwiftData inference for
   a release that changes the model.
2. Keep the previous schema type in the migration source. A migration must be
   additive or provide an explicit transformation for every removed/renamed
   field.
3. Open the candidate container in a temporary directory first, run migration
   and read-back checks, and only then make it the active store.
4. Before replacing an existing store, create a timestamped backup of the
   store files. Never delete the old store because migration failed.
5. If migration or read-back fails, restore the old store, switch the session
   to `FilePersisting`, and surface a recovery action in Settings.
6. Keep `ReaderDocument` JSON decoding additive. New fields must have
   `decodeIfPresent` defaults so documents from the fallback store remain
   readable after an app update.

## Required release tests

The migration test fixture must cover: a previous-version store with recents,
an empty store, a corrupt store, a read-only directory, insufficient-space or
write-failure simulation, interrupted migration, successful rollback, and
fallback import/review/export while SwiftData is unavailable. The old store and
its backup must remain inspectable after every failure case.

This document is a design contract, not proof that a SwiftData schema migration
has been exercised on a physical release build. That gate remains open until a
versioned schema and macOS 14/current-macOS migration run are added.
