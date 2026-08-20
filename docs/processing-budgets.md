# Processing budgets

PageLumen estimates import cost before a large PDF enters OCR. The estimate is
deterministic: each PDF point is converted to the normal two-pixel OCR target,
then adjusted for the selected quality. The peak working-memory estimate is
three 8-bit buffers for the largest selected page. The estimate is a safety
signal, not a measurement of resident memory.

When an import exceeds the page, pixel, or estimated working-memory boundary,
the app pauses and offers a balanced-quality import or the first 100 pages.
Cancellation remains available at page boundaries. A selected page range keeps
the original PDF page numbers in citations and review navigation.

The physical-device acceptance gate still needs a representative scanned PDF
run on supported macOS hardware. That run must record peak resident memory,
wall time, cancellation latency, and whether the quality choice preserves
acceptable OCR accuracy. No local estimate should be presented as that
measurement.
