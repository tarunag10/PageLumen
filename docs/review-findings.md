# Review finding priorities

PageLumen exposes a normalized `ReviewFinding` queue for extraction and
accessibility remediation. Each finding has a detection kind and an
action-oriented `ReviewFindingCategory`. The category is persisted in JSON,
but decoding remains backward-compatible with documents written before the
field existed.

The queue uses a stable, deterministic order:

1. unreadable page;
2. missing structure;
3. low confidence;
4. conflicting extraction sources;
5. unresolved table headers;
6. missing image description; and
7. unreviewed AI contribution.

Page number, severity, reading-order index, and the privacy-safe finding ID
are tie-breakers. No source text is copied into the category or priority
metadata. Existing review decisions continue to live on the owning block, so
accepting, rejecting, or resolving one finding does not mutate extracted
text.

The bounded detector currently identifies:

- failed or empty pages as unreadable;
- unknown blocks as missing structure;
- blocks below the selected review preset threshold as low confidence;
- a declared block source that disagrees with typed provenance as a source
  conflict;
- tables without assigned column headers;
- figures without a non-empty description; and
- blocks marked with Apple Intelligence provenance or an explicit AI
  contribution marker.

These are review signals, not conformance claims. A reviewer must still verify
the source page before publishing an export.
