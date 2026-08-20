# Structured intelligence result contract

PageLumen treats an Apple Intelligence response as a review-gated draft, not
as extracted source text. `GroundedSummary` is the typed, Codable contract
shared by the Foundation Models adapter, the review workspace, and export
code. It contains:

- the generated body and optional human-readable `SummaryCitation` excerpts;
- `citedPageBlockIDs`, a source-text-free list of stable page/block locations;
- uncertainty notes and unsupported-claim strings;
- typed `GroundedReviewAction` records with a bounded action kind, reason, and
  optional page/block destination.

The page/block records are deliberately separate from excerpts. An App Intent,
availability message, persistence record, or telemetry-style envelope can use
the IDs without disclosing OCR text. `GroundedIntelligenceResult` is Codable
with explicit `generated`, `unavailable`, and `failed` states. Unavailable
states serialize only the capability state, and failed states serialize a
generic policy message; provider diagnostics are never serialized because
they could contain prompts or source text.

The current Foundation Models adapter still obtains the generated body through
its legacy text response. The surrounding result is normalized into this
structured contract deterministically, including omitted-block and extraction
warning actions. Replacing the body request with Foundation Models `@Generable`
output is a subsequent adapter task; it must preserve this contract and must
validate model-supplied locations against the selected source blocks before
displaying them.

Fallback behavior is deterministic: unsupported or failed model requests keep
the local summary, cite the retained source blocks, add an explicit fallback
uncertainty note, and suggest source verification. No fallback or unavailable
payload includes a source excerpt.

## Validation requirements

The contract is covered by `ExplanationEngineTests` for:

1. typed page/block locations and review actions;
2. Codable round trips, including legacy summaries without the new fields;
3. unavailable and failed serialization without source disclosure.

`IntelligenceContextBuilder` now provides the bounded request boundary. It
resolves an optional set of selected block IDs in reading order, labels each
provided passage with its page/block location and inferred heading section,
and applies both a deterministic block limit and character limit. The
resulting `IntelligenceContextMetadata` records included and omitted page
numbers and section labels, plus counts, without storing omitted passages.
`ExplanationEngine` exposes the same selection scope through grounded and
deterministic fallback summaries. This is deliberately a summary operation;
there is no open-ended chat surface.

Model quality, remaining task-specific modes, and the evaluation corpus remain
separate release gates.
