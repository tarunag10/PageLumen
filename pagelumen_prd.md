# Sightline Reader PRD

**Suggested app name:** Sightline Reader  
**Product concept:** Accessible PDF and Screenshot Reader  
**Product type:** Mac-native App Store app  
**Primary platform:** macOS  
**Document version:** v0.1  
**Status:** Draft PRD  

---

## 1. Executive Summary

Sightline Reader is a Mac-native app that turns inaccessible visual documents into readable, structured, audio-friendly, and exportable content.

Users can import a PDF, screenshot, scan, slide, or image. The app extracts text, preserves likely reading order, generates headings, explains tables and charts, creates audio-friendly summaries, and exports the result as Markdown, TXT, HTML, or an accessible PDF.

The MVP should focus on speed, trust, and usefulness rather than perfect document remediation. Users should always be able to compare extracted content against the original page, correct output, and export a cleaner version.

The product can begin as a paid Mac App Store app for individual users and later expand into workplace, education, legal, and research licensing.

---

## 2. Creator Details

### 2.1 Creator Profile

This product is designed for a creator or small founding team that wants to build a practical accessibility-first reading tool for people who regularly encounter information locked inside PDFs, scans, screenshots, slides, and images.

The ideal creator profile:

- Strong interest in accessibility, education, productivity, and local-first AI.
- Able to ship polished Mac software using SwiftUI.
- Comfortable prototyping AI and OCR pipelines before productionizing them.
- Willing to sell to both individuals and institutions.
- Wants a product that can start as a narrow Mac utility and grow into a broader document accessibility platform.

### 2.2 Founder Narrative

The product should be positioned around a simple belief:

> Important information should not become unusable just because it is trapped in a scanned PDF, screenshot, chart, or poorly tagged document.

The creator should communicate three themes consistently:

1. **Access:** Make inaccessible visual documents readable, searchable, and listenable.
2. **Trust:** Preserve the original document, expose confidence levels, and let users verify extracted content.
3. **Privacy:** Prefer local processing where practical, especially for legal, academic, workplace, and personal documents.

### 2.3 Creator Responsibilities

The creator or founding team owns:

- Product vision and roadmap.
- Accessibility quality bar.
- Model and OCR evaluation standards.
- App Store packaging and monetization.
- User research with students, lawyers, educators, researchers, and workplace accessibility teams.
- Partnerships with accessibility consultants, universities, legal aid groups, and assistive technology communities.

### 2.4 Recommended Founding Roles

#### Product and Design Lead

Owns workflows, onboarding, accessibility UX, pricing, and user research.

#### Mac Engineer

Owns SwiftUI app architecture, document viewer, OCR pipeline integration, exports, permissions, and App Store readiness.

#### ML/OCR Engineer

Owns OCR evaluation, reading order reconstruction, layout analysis, table/chart explanation, local model experimentation, and model routing.

#### Accessibility Advisor

Reviews VoiceOver behavior, keyboard navigation, PDF/UA direction, WCAG-informed outputs, and user testing with disabled users.

#### QA and Automation Engineer

Owns document corpus, regression tests, extraction accuracy checks, export validation, and performance benchmarks.

---

## 3. Problem Statement

A large amount of information is functionally inaccessible because it is embedded in visual or poorly structured formats:

- Scanned PDFs with no selectable text.
- Screenshots of conversations, receipts, charts, documents, or webpages.
- Slides exported as flat images.
- Legal filings with poor OCR or irregular layout.
- Research papers with complex figures and tables.
- Classroom handouts and old scanned readings.
- Workplace documents without semantic headings, tags, or reading order.

Existing tools often solve only part of the problem. OCR tools extract text but lose structure. PDF readers display documents but do not explain charts. AI tools summarize content but may ignore reading order, hallucinate details, or require uploading sensitive documents to a server. Accessibility remediation tools can be powerful but are often too complex for everyday users.

This product should close the gap between raw visual content and practical accessible reading.

---

## 4. Product Vision

Create the fastest Mac-native way to make visual documents readable, navigable, listenable, and exportable.

The long-term vision is a local-first accessibility layer for any document or screenshot on a user’s Mac.

The product should eventually answer:

- What text is on this page?
- What should I read first?
- What are the headings and sections?
- What does this table say?
- What does this chart show?
- Can I listen to this as clean audio?
- Can I export this in a format my screen reader, note app, LMS, legal workflow, or workplace system can use?

---

## 5. Target Users

### 5.1 Students

Students receive scanned readings, image-based PDFs, slides, screenshots, and worksheets. They need fast conversion into readable notes, summaries, and audio.

Key needs:

- Extract text from readings and screenshots.
- Convert dense materials into study-friendly summaries.
- Preserve equations, tables, footnotes, and references when possible.
- Export to Markdown, TXT, HTML, or accessible PDF.
- Listen while commuting or reviewing.

### 5.2 Lawyers and Legal Professionals

Legal users handle scanned filings, exhibits, contracts, discovery materials, court PDFs, and screenshots.

Key needs:

- Privacy-preserving local processing.
- High trust and source traceability.
- Batch extraction.
- Page-level citations and references.
- Searchable output.
- Minimal hallucination.
- Clear confidence indicators.

### 5.3 Educators

Educators need to make handouts, readings, slides, and archived materials more accessible for students.

Key needs:

- Simple workflow for converting old materials.
- Heading generation and alt-text-like explanations.
- Export accessible HTML or PDF.
- Shareable summaries.
- Low setup burden.

### 5.4 Researchers

Researchers handle papers, figures, charts, tables, scanned books, datasets, and screenshots from archives.

Key needs:

- Accurate extraction from papers.
- Figure and table summaries.
- Metadata and references.
- Markdown export for note-taking.
- Document comparison and quote capture.

### 5.5 Workplaces

Companies need to make internal PDFs, screenshots, forms, slide exports, and process docs more accessible.

Key needs:

- Local-first or enterprise-safe processing.
- Team licensing.
- Export formats for documentation systems.
- Accessibility compliance support.
- Repeatable workflows.

### 5.6 Accessibility-Centered Users

The product should directly support users with:

- Blindness or low vision.
- Dyslexia and other reading differences.
- ADHD or cognitive overload.
- Motor limitations that make manual copying difficult.
- Temporary impairments.
- Language or comprehension barriers.

The product should not treat accessibility as a secondary feature. Accessibility is the core product value.

---

## 6. Jobs To Be Done

### 6.1 Core Jobs

1. When I receive a scanned PDF, I want to extract clean text so I can read it with my preferred tools.
2. When I capture a screenshot, I want to understand its content without manually zooming, copying, or retyping.
3. When a document has multiple columns, headers, footers, and figures, I want the app to preserve the correct reading order.
4. When a page has a chart or table, I want a plain-language explanation of what it says.
5. When I am tired or multitasking, I want a clean audio-friendly summary I can listen to.
6. When I need to share or archive the result, I want to export it in accessible formats.

### 6.2 Emotional Jobs

- Feel less blocked by inaccessible documents.
- Trust that the app is not inventing content.
- Avoid exposing private documents unnecessarily.
- Save time during study, legal review, teaching, or research.
- Feel confident sharing more accessible material with others.

---

## 7. Goals and Non-Goals

### 7.1 MVP Goals

- Import screenshots, images, and PDFs.
- Extract text with page-level structure.
- Preserve likely reading order across common layouts.
- Generate headings and section labels.
- Explain simple tables and common chart types.
- Produce audio-friendly summaries.
- Export Markdown, TXT, HTML, and basic accessible PDF.
- Provide side-by-side original and extracted views.
- Run core OCR locally on Mac.
- Clearly communicate confidence and limitations.

### 7.2 Business Goals

- Launch a useful paid Mac app with a clear accessibility and productivity value proposition.
- Convert free/trial users into paid individual plans.
- Validate willingness to pay among students, lawyers, educators, researchers, and workplace teams.
- Build a corpus and feedback loop for improving extraction quality.
- Establish trust around privacy and local processing.

### 7.3 Non-Goals for MVP

- Full enterprise document management.
- Perfect PDF/UA compliance for every exported PDF.
- Complete mathematical OCR for all formulas.
- Full handwriting recognition beyond basic support if available through OCR.
- Full slide editing or PDF editing.
- Replacing professional accessibility remediation workflows.
- Real-time screen reader replacement.
- Cloud-based batch processing at enterprise scale.

---

## 8. MVP Feature Set

### 8.1 Import Sources

#### P0

- Drag and drop PDF, PNG, JPEG, TIFF, HEIC.
- Open from Finder.
- Paste image from clipboard.
- Use macOS Share Sheet where possible.
- Recent files list.

#### P1

- Capture selected screen region.
- Capture current window.
- Batch import multiple PDFs or images.

#### P2

- Monitor a folder for new screenshots.
- Browser extension import.
- Import from scanner.

### 8.2 OCR and Text Extraction

#### P0

- Extract text from image-based pages and screenshots.
- Detect existing selectable PDF text when present.
- Merge native PDF text and OCR output when useful.
- Preserve page numbers.
- Store bounding boxes for recognized text blocks.
- Show confidence where available.

#### P1

- Allow user correction of OCR text.
- Language detection.
- Multi-language OCR routing.
- Batch OCR.

#### P2

- Handwriting support where feasible.
- Mathematical formula recognition.
- Domain-tuned OCR profiles for legal, academic, receipts, and slides.

### 8.3 Reading Order Preservation

#### P0

- Reconstruct likely reading order for common layouts:
  - Single-column pages.
  - Two-column academic PDFs.
  - Slide layouts.
  - Forms with labels and values.
  - Screenshot UI layouts.
- Remove repeated headers and footers when confidence is high.
- Keep page boundaries visible in output.

#### P1

- Reading order editor with drag-and-drop blocks.
- Toggle between original order, detected order, and user-corrected order.
- Detect sidebars, captions, footnotes, and references.

#### P2

- Train or customize layout models using user-corrected examples.
- Domain-specific layout templates.

### 8.4 Heading Generation

#### P0

- Detect visible headings using font size, position, capitalization, spacing, numbering, and semantic cues.
- Generate missing headings for sections using local or optional AI processing.
- Create a document outline.
- Export heading hierarchy to Markdown and HTML.

#### P1

- User can rename, merge, split, promote, or demote headings.
- Auto-generate short section titles for unlabeled blocks.

#### P2

- Create study guide, legal brief outline, or teaching outline from headings.

### 8.5 Table Explanation

#### P0

- Detect simple tables.
- Extract rows and columns where possible.
- Generate plain-language explanation.
- Export as Markdown table and HTML table.
- Warn when table structure is uncertain.

#### P1

- Table editor for correcting rows, columns, and headers.
- CSV export.
- Support merged cells and multi-page tables.

#### P2

- Spreadsheet export.
- Advanced table reasoning and cross-table comparison.

### 8.6 Chart Explanation

#### P0

- Detect likely chart regions.
- Identify broad chart type when possible:
  - Bar chart.
  - Line chart.
  - Pie chart.
  - Scatter plot.
  - Flowchart or diagram.
- Generate a careful plain-language description:
  - What the chart appears to show.
  - Axes and labels if readable.
  - Key trend or comparison if clear.
  - Uncertainty statement when values are hard to read.

#### P1

- Let users select a chart region manually.
- Generate alt-text-style descriptions.
- Extract visible data labels.

#### P2

- Approximate data extraction from charts.
- Multi-chart comparison.
- Domain-specific chart explanation modes.

### 8.7 Audio-Friendly Summaries

#### P0

- Generate a concise summary optimized for listening.
- Avoid dense citations and visual references unless needed.
- Include page references.
- Offer lengths:
  - 30-second summary.
  - 2-minute summary.
  - Detailed walkthrough.
- Use text-to-speech playback.

#### P1

- Export audio file.
- Voice and speed controls.
- Queue multiple documents.
- “Read extracted text” and “Read summary” modes.

#### P2

- Podcast-style study mode.
- Q&A mode over document content.
- Smart chapters.

### 8.8 Exports

#### P0

- Markdown.
- TXT.
- HTML.
- Basic accessible PDF.

#### P1

- DOCX.
- CSV for tables.
- Audio file.
- JSON with OCR blocks and metadata.

#### P2

- EPUB.
- LMS package.
- Notion, Obsidian, or Readwise integrations.

### 8.9 Accessible PDF Export

MVP expectation: produce a more accessible PDF than the original, not guaranteed full remediation.

P0 output should include:

- Recognized text layer.
- Logical heading structure where possible.
- Reading order metadata where supported.
- Alt-text-like summaries for charts and images where generated.
- Basic document title and language metadata.

P1 output should include:

- Better tagged PDF structure.
- Table tags where reliable.
- User-editable alt text.
- Validation warnings.

P2 output should include:

- Stronger PDF/UA-oriented workflow.
- Compliance report.
- Enterprise remediation review mode.

---

## 9. User Experience

### 9.1 Main Workflow

1. User opens the app.
2. User drags in a PDF or screenshot.
3. App shows import preview.
4. App detects document type and starts extraction.
5. User sees progress by page.
6. App displays side-by-side view:
   - Left: original page.
   - Right: structured extracted content.
7. User reviews outline, text, tables, charts, and summary.
8. User optionally edits headings, reading order, or OCR text.
9. User listens to summary or full text.
10. User exports Markdown, TXT, HTML, or accessible PDF.

### 9.2 Key Screens

#### Home Screen

Purpose: Get users into extraction quickly.

Elements:

- Drop zone.
- Paste from clipboard button.
- Capture screenshot button.
- Recent documents.
- Privacy note: local processing where available.
- Trial or usage status.

#### Processing Screen

Purpose: Make extraction feel transparent and trustworthy.

Elements:

- Page thumbnails.
- Processing status per page.
- OCR confidence indicator.
- Detected layout type.
- Cancel button.

#### Review Screen

Purpose: Compare original and extracted result.

Elements:

- Original document pane.
- Structured output pane.
- Outline sidebar.
- Page selector.
- Reading order overlay toggle.
- Confidence warnings.
- Edit mode.

#### Summary Screen

Purpose: Turn document into listenable content.

Elements:

- Summary length selector.
- Audio-friendly toggle.
- Playback controls.
- Page references.
- Copy and export summary buttons.

#### Export Screen

Purpose: Export clean output without confusion.

Elements:

- Format selector.
- Include options:
  - Headings.
  - Tables.
  - Chart explanations.
  - Page references.
  - Confidence notes.
- Accessibility warning if accessible PDF is partial.
- Save location.

### 9.3 VoiceOver and Keyboard Expectations

- Every major control must have clear labels.
- Entire app must be navigable by keyboard.
- Extracted content pane should be readable as structured text.
- Outline should expose heading levels.
- Tables should expose row and column context in HTML output.
- Playback controls should be easy to operate without visual precision.
- Warnings should not rely on color alone.

---

## 10. Functional Requirements

### 10.1 Import and Document Handling

| ID | Requirement | Priority | Acceptance Criteria |
|---|---|---:|---|
| FR-001 | Import PDF files | P0 | User can drag or open a PDF and see page thumbnails. |
| FR-002 | Import images | P0 | User can import PNG, JPEG, TIFF, HEIC where macOS supports decoding. |
| FR-003 | Paste screenshot | P0 | User can paste an image from clipboard and start extraction. |
| FR-004 | Preserve original file | P0 | App never modifies original source unless user explicitly exports over it. |
| FR-005 | Batch import | P1 | User can process multiple files in one queue. |

### 10.2 OCR

| ID | Requirement | Priority | Acceptance Criteria |
|---|---|---:|---|
| FR-010 | Run OCR on image pages | P0 | App extracts recognized text from screenshots and scanned pages. |
| FR-011 | Detect native PDF text | P0 | App uses embedded text when present and avoids unnecessary OCR unless requested. |
| FR-012 | Store bounding boxes | P0 | Each recognized block has page, bounding region, and text metadata. |
| FR-013 | Show OCR confidence | P1 | App displays low-confidence warnings at page or block level. |
| FR-014 | Edit OCR output | P1 | User can correct extracted text and export corrected version. |

### 10.3 Reading Order and Structure

| ID | Requirement | Priority | Acceptance Criteria |
|---|---|---:|---|
| FR-020 | Generate reading order | P0 | App outputs blocks in likely human reading order for common single and two-column pages. |
| FR-021 | Generate outline | P0 | App produces heading hierarchy when headings are visible or inferable. |
| FR-022 | Detect repeated headers and footers | P1 | App marks likely repeated headers/footers and lets users include or exclude them. |
| FR-023 | Manual order editing | P1 | User can reorder blocks and export corrected order. |

### 10.4 Tables and Charts

| ID | Requirement | Priority | Acceptance Criteria |
|---|---|---:|---|
| FR-030 | Detect simple tables | P0 | App identifies likely table regions and attempts row/column extraction. |
| FR-031 | Explain tables | P0 | App creates a plain-language explanation of table contents with uncertainty when needed. |
| FR-032 | Export tables | P0 | Tables export as Markdown and HTML tables when reliable. |
| FR-033 | Detect charts | P0 | App identifies likely chart or figure regions. |
| FR-034 | Explain charts | P0 | App creates a careful description of chart type, labels, trend, and uncertainty. |

### 10.5 Summaries and Audio

| ID | Requirement | Priority | Acceptance Criteria |
|---|---|---:|---|
| FR-040 | Generate audio-friendly summaries | P0 | User can generate a listening-optimized summary from extracted content. |
| FR-041 | Play summary aloud | P0 | User can play generated summary using system speech. |
| FR-042 | Read full extracted text aloud | P1 | User can listen to the full extracted document. |
| FR-043 | Export audio | P1 | User can export summary as audio file. |

### 10.6 Export

| ID | Requirement | Priority | Acceptance Criteria |
|---|---|---:|---|
| FR-050 | Export Markdown | P0 | Output includes headings, paragraphs, tables, page breaks, and chart explanations. |
| FR-051 | Export TXT | P0 | Output is clean plain text with page markers. |
| FR-052 | Export HTML | P0 | Output uses semantic headings, paragraphs, lists, and tables. |
| FR-053 | Export accessible PDF | P0 | Output includes readable text, basic structure, metadata, and generated descriptions where available. |
| FR-054 | Export settings | P1 | User can choose what to include in export. |

---

## 11. Non-Functional Requirements

### 11.1 Performance

Initial MVP targets:

- Open common PDFs under 100 pages without freezing the UI.
- Process a single screenshot in under 5 seconds on a modern Apple silicon Mac for OCR-only extraction.
- Process a 10-page scanned PDF in under 60 seconds for OCR and basic structure on a modern Apple silicon Mac.
- Keep the UI responsive during processing.
- Allow cancellation.

Performance should be benchmarked across:

- M1 MacBook Air baseline.
- M2/M3/M4 MacBook Air or Pro.
- Intel Mac support only if product strategy requires it.

### 11.2 Reliability

- Never overwrite original files by default.
- Recover gracefully from corrupt PDFs.
- Allow partial output when some pages fail.
- Log processing errors locally.
- Make low-confidence outputs visible.

### 11.3 Privacy

- Default to local OCR and local document processing where possible.
- Do not upload documents without explicit user consent.
- Make cloud features opt-in and clearly labeled.
- Provide a privacy mode that disables all network calls.
- Store only necessary local metadata.
- Give users a clear way to delete local cache and processing history.

### 11.4 Security

- Use macOS sandboxing for App Store distribution.
- Request only necessary permissions.
- Treat PDFs and images as untrusted inputs.
- Avoid executing embedded PDF content.
- Keep temporary files in protected app storage.
- Remove temporary extraction artifacts when no longer needed.

### 11.5 Accessibility

- App UI should target WCAG-informed design where applicable.
- VoiceOver support is required for core workflows.
- Keyboard-only use is required for core workflows.
- Exports should use semantic structure where possible.
- Do not rely on color alone to communicate confidence or errors.
- Support Dynamic Type-equivalent scaling where practical on macOS.
- Provide high contrast and reduced motion behavior where possible.

---

## 12. Technical Stack

### 12.1 App Layer

**Recommended:** SwiftUI

SwiftUI should power the main Mac app interface because it enables a native app experience, system accessibility integration, fast iteration, and App Store-friendly packaging.

Use SwiftUI for:

- Main document window.
- Import flow.
- Side-by-side review pane.
- Outline and block editor.
- Summary and playback screens.
- Export settings.
- Preferences.

Supporting Apple frameworks:

- **PDFKit** for PDF viewing, thumbnails, and page operations.
- **Vision** for OCR and layout-oriented image analysis.
- **AVFoundation** for speech synthesis, audio playback, and potential media export.
- **Speech framework** for speech recognition if voice commands, dictation, or spoken annotations become part of the product.
- **Accessibility APIs** for app/window context and assistive workflows.

### 12.2 OCR and Image Preprocessing

**Recommended:** Apple Vision

Use Apple Vision as the first OCR engine for MVP because it is native, optimized for Apple platforms, and avoids sending user documents to cloud services for baseline OCR.

OCR pipeline:

1. Load PDF page or image.
2. Render page to image at appropriate resolution.
3. Preprocess image:
   - Deskew where possible.
   - Improve contrast.
   - Normalize orientation.
   - Crop margins if needed.
4. Run OCR.
5. Store recognized text blocks with bounding boxes and confidence.
6. Group words and lines into blocks.
7. Pass blocks to layout reconstruction.

### 12.3 Local Inference

**Recommended:** MLX Swift

Use MLX Swift for on-device model inference experiments and production features that can run locally on Apple silicon.

Candidate local model tasks:

- Heading classification.
- Block type classification.
- Reading order refinement.
- Summary generation with small local language models.
- Chart/table region classification.
- Alt-text-style figure description if a suitable local vision-language model is practical.

Important product caveat: treat MLX Swift usage as a capability to validate carefully. Local model quality, memory usage, startup time, and App Store packaging size will decide which features are shipped locally versus made optional.

### 12.4 Model Experimentation

**Recommended:** Python MLX

Use Python MLX for research and prototyping before porting successful approaches into the Mac app.

Use Python MLX for:

- Testing local LLMs and vision-language models.
- Evaluating summarization quality.
- Running document layout experiments.
- Benchmarking model size, speed, and memory.
- Creating synthetic evaluation sets.

### 12.5 Audio and Speech

**Recommended:** AVFoundation and Apple Speech

Use AVFoundation for:

- Text-to-speech playback.
- Audio session management.
- Exporting generated audio in future versions.
- Audio/video capture if screenshot narration or recording workflows are added.

Use Apple Speech for:

- Future voice notes.
- Spoken corrections.
- Voice-driven commands.
- Dictated annotations.

MVP should prioritize text-to-speech playback over speech recognition unless voice input is central to the first release.

### 12.6 Accessibility APIs

Use macOS Accessibility APIs for future context-aware capture and workflows, such as:

- Understanding the active app or window.
- Capturing the frontmost window with user permission.
- Supporting assistive workflows around screenshots.
- Providing better labels and focus behavior inside the app.

MVP should avoid overreaching with system-wide permissions. Ask only when a feature truly needs access.

### 12.7 AI Coding and Development Workflow

**Recommended:** Codex CLI

Use Codex CLI as an engineering accelerator, not as a runtime dependency.

Good uses:

- Refactoring Swift code.
- Generating unit tests.
- Writing PDF fixture tests.
- Creating CLI utilities for evaluation.
- Explaining unfamiliar code.
- Drafting migration plans.
- Reproducing bugs locally.

Guardrails:

- Require human review for all generated code.
- Keep golden test fixtures for OCR and export behavior.
- Do not paste sensitive user documents into coding-agent prompts.
- Use local redacted fixtures for development.

---

## 13. Proposed Architecture

### 13.1 High-Level Architecture

```text
Input Layer
  PDF / Image / Screenshot / Clipboard
        ↓
Document Normalization
  PDF rendering, image decoding, orientation, preprocessing
        ↓
Extraction Layer
  Native PDF text extraction + OCR fallback
        ↓
Layout Layer
  Blocks, bounding boxes, reading order, headings, tables, figures
        ↓
Understanding Layer
  Table explanation, chart explanation, summaries, alt-text-like descriptions
        ↓
Review Layer
  Side-by-side UI, outline, editor, confidence warnings
        ↓
Export Layer
  Markdown, TXT, HTML, accessible PDF, future audio/DOCX/CSV
```

### 13.2 Core Modules

#### DocumentImporter

Responsibilities:

- Accept files, clipboard images, and screenshots.
- Validate file type.
- Create internal document record.
- Generate thumbnails.
- Preserve original source path and copy rules.

#### PageRenderer

Responsibilities:

- Render PDF pages to images for OCR.
- Normalize image resolution.
- Manage memory for large documents.
- Provide page image to Vision and UI.

#### OCRService

Responsibilities:

- Run Apple Vision OCR.
- Extract embedded PDF text where available.
- Merge or choose best text source.
- Return recognized lines, words, bounding boxes, and confidence.

#### LayoutAnalyzer

Responsibilities:

- Group OCR results into text blocks.
- Detect columns.
- Infer reading order.
- Detect headings, captions, tables, figures, footnotes, and repeated headers/footers.

#### StructureGenerator

Responsibilities:

- Build document outline.
- Generate missing headings.
- Create semantic document tree.
- Prepare export-ready structure.

#### ExplanationEngine

Responsibilities:

- Explain tables.
- Explain charts and figures.
- Create summaries.
- Add uncertainty statements.
- Avoid unsupported claims.

#### AudioEngine

Responsibilities:

- Convert summary or extracted text to speech.
- Manage playback controls.
- Future: export audio.

#### ExportEngine

Responsibilities:

- Export Markdown.
- Export TXT.
- Export HTML.
- Export accessible PDF.
- Future: DOCX, EPUB, CSV, JSON.

#### EvaluationHarness

Responsibilities:

- Run extraction tests against fixture documents.
- Compare OCR output to ground truth.
- Score reading order.
- Validate exports.
- Track regression over time.

---

## 14. Data Model

### 14.1 Document

```json
{
  "id": "uuid",
  "title": "string",
  "sourceType": "pdf|image|screenshot|clipboard",
  "sourceURL": "optional string",
  "createdAt": "datetime",
  "pageCount": 0,
  "language": "optional string",
  "processingStatus": "pending|processing|complete|partial|failed",
  "pages": []
}
```

### 14.2 Page

```json
{
  "id": "uuid",
  "pageNumber": 1,
  "width": 0,
  "height": 0,
  "thumbnailURL": "string",
  "ocrStatus": "pending|complete|failed",
  "layoutType": "singleColumn|multiColumn|slide|form|mixed|unknown",
  "blocks": []
}
```

### 14.3 Block

```json
{
  "id": "uuid",
  "pageNumber": 1,
  "type": "heading|paragraph|list|table|figure|caption|footer|header|unknown",
  "text": "string",
  "bounds": {
    "x": 0,
    "y": 0,
    "width": 0,
    "height": 0
  },
  "confidence": 0.0,
  "readingOrderIndex": 0,
  "children": [],
  "metadata": {}
}
```

### 14.4 Table

```json
{
  "id": "uuid",
  "pageNumber": 1,
  "bounds": {},
  "rows": [],
  "columns": [],
  "markdown": "string",
  "html": "string",
  "explanation": "string",
  "confidence": 0.0
}
```

### 14.5 Figure or Chart

```json
{
  "id": "uuid",
  "pageNumber": 1,
  "bounds": {},
  "figureType": "chart|diagram|photo|illustration|unknown",
  "chartType": "bar|line|pie|scatter|unknown",
  "visibleText": "string",
  "description": "string",
  "confidence": 0.0,
  "uncertaintyNotes": []
}
```

---

## 15. Reading Order Strategy

### 15.1 MVP Approach

Use a hybrid layout algorithm:

1. OCR returns lines and bounding boxes.
2. Lines are grouped into blocks by proximity, alignment, and spacing.
3. Page is classified into likely layout type.
4. Columns are detected using x-coordinate clusters and vertical whitespace.
5. Blocks are sorted by detected column and y-position.
6. Captions, footnotes, headers, and footers are marked separately.
7. User-facing output is generated with page markers and confidence notes.

### 15.2 Common Layout Rules

**Single-column document:** sort top-to-bottom, left-to-right.

**Two-column paper:** identify column boundary, read left column top-to-bottom, then right column top-to-bottom, while handling full-width title and abstract blocks.

**Slides:** prioritize title, subtitle, main bullets, chart/figure descriptions, footer notes.

**Forms:** pair labels and values based on spatial proximity.

**Screenshots:** group by UI regions, then read top-to-bottom while preserving obvious conversation/message sequence.

### 15.3 Confidence Handling

Low-confidence reading order should trigger:

- “Reading order may need review” warning.
- Visual overlay showing block order.
- Option to export with page-position notes.
- Future manual reorder editor.

---

## 16. AI Behavior and Safety Rules

### 16.1 Grounding Rules

The app should separate extracted content from generated content.

Extracted content:

- Comes from OCR or embedded PDF text.
- Should be shown as source text.
- Should keep page references.

Generated content:

- Headings, summaries, table explanations, and chart explanations.
- Should be labeled as generated.
- Should include uncertainty where appropriate.

### 16.2 Hallucination Prevention

The explanation engine must:

- Avoid adding facts not visible in the document.
- Say when text, axis labels, legends, or values are unreadable.
- Prefer “appears to show” for uncertain chart analysis.
- Keep page references attached to claims where possible.
- Let users inspect source page next to explanation.

### 16.3 Sensitive Documents

For legal, medical, workplace, or personal documents:

- Default local processing should be emphasized.
- Cloud processing, if offered, should require explicit consent.
- The app should provide a privacy mode with network-disabled processing.
- Logs should avoid storing document text unless the user opts in.

---

## 17. Accessibility and Compliance Direction

### 17.1 Standards Direction

The product should be informed by:

- WCAG 2.2 principles for accessible digital content.
- PDF/UA concepts for tagged, semantically structured PDFs.
- Apple Human Interface Guidelines and macOS accessibility patterns.

MVP should not claim universal compliance unless validated. The correct claim is:

> Exports are designed to be more accessible and screen-reader-friendly. Full compliance depends on document complexity and should be reviewed for formal requirements.

### 17.2 Export Accessibility Checklist

#### Markdown

- Use heading levels.
- Preserve lists.
- Represent tables cleanly.
- Add figure descriptions.
- Include page markers.

#### HTML

- Use semantic headings.
- Use paragraph tags.
- Use table elements for reliable tables.
- Include alt-text-like descriptions for figures.
- Include document language where known.

#### Accessible PDF

- Add text layer.
- Include title and metadata.
- Preserve logical structure where possible.
- Include generated figure descriptions where practical.
- Avoid claiming full remediation without validation.

---

## 18. Monetization

### 18.1 App Store Model

Recommended launch model:

#### Free Trial

- Process limited number of pages per month.
- Export TXT and Markdown with limits.
- Watermark accessible PDF exports or limit page count.

#### Individual Pro Subscription

- Unlimited or high-limit OCR.
- Full export formats.
- Table/chart explanations.
- Audio-friendly summaries.
- Batch processing.

#### Student Plan

- Discounted annual subscription.
- Same core features as Pro.
- Optional verification later.

#### One-Time Purchase Option

- Consider only if subscription resistance is high.
- Could include local OCR and basic exports, with AI features as subscription.

#### Workplace Plan

- Seat-based licensing.
- Privacy mode.
- Admin controls.
- Batch processing.
- Priority support.
- Accessibility review features.

### 18.2 Packaging Recommendation

Start simple:

- **Free:** 10 pages/month, Markdown/TXT export.
- **Pro:** full individual usage.
- **Teams:** contact sales or license key distribution.

Avoid too many limits in the MVP. The value should be obvious after the first successful conversion.

### 18.3 Willingness-To-Pay Hypotheses

Students pay for study productivity and audio summaries.

Lawyers pay for privacy, searchability, and time savings.

Educators pay when it helps meet accessibility requirements faster.

Researchers pay for structured extraction from papers and figures.

Workplaces pay for compliance support, privacy, and repeatability.

---

## 19. Success Metrics

### 19.1 Activation Metrics

- First document imported.
- First successful extraction.
- First export.
- First audio playback.
- Time from app open to first usable output.

### 19.2 Quality Metrics

- OCR accuracy against fixture corpus.
- Reading order accuracy.
- Heading detection precision and recall.
- Table extraction success rate.
- Chart explanation usefulness rating.
- Export validation pass rate.

### 19.3 Business Metrics

- Trial-to-paid conversion.
- Monthly recurring revenue.
- Student discount conversion.
- Pro retention after 30/90 days.
- Workplace inbound leads.
- Refund rate.

### 19.4 User Trust Metrics

- Percentage of outputs edited before export.
- Low-confidence warning rate.
- User-reported hallucination rate.
- Privacy mode usage.
- Support tickets about incorrect extraction.

---

## 20. Evaluation Plan

### 20.1 Test Corpus

Build a fixture library with:

- Scanned textbook pages.
- Two-column research papers.
- Legal PDFs.
- Receipts and forms.
- Slides exported as PDFs.
- Screenshots of webpages.
- Screenshots of chats or emails.
- Tables with simple and complex structure.
- Bar, line, pie, and scatter charts.
- Low-resolution scans.
- Rotated and skewed pages.

### 20.2 Ground Truth

For each fixture, store:

- Correct text.
- Correct reading order.
- Expected headings.
- Expected table structure.
- Expected chart description.
- Expected export snapshot.

### 20.3 Automated Tests

- OCR text similarity.
- Reading order sequence score.
- Heading hierarchy comparison.
- Markdown snapshot test.
- HTML accessibility lint checks.
- PDF export smoke tests.
- Performance tests by page count and file size.

### 20.4 Human Evaluation

Recruit users from each primary segment and ask them to complete:

- Convert a scanned PDF.
- Convert a screenshot.
- Listen to a summary.
- Export Markdown or accessible PDF.
- Correct a table or heading.
- Rate trust and usefulness.

---

## 21. Roadmap

### 21.1 Phase 0: Research and Prototype

Estimated duration: 2 to 4 weeks

Deliverables:

- SwiftUI shell app.
- PDF/image import prototype.
- Apple Vision OCR proof of concept.
- Reading order prototype in Python or Swift.
- Export Markdown/TXT prototype.
- 25-document test corpus.
- Initial user interviews.

### 21.2 Phase 1: MVP Build

Estimated duration: 8 to 12 weeks

Deliverables:

- Native Mac app.
- PDF/image/screenshot import.
- OCR pipeline.
- Reading order reconstruction.
- Heading generation.
- Side-by-side review.
- Markdown, TXT, HTML export.
- Basic accessible PDF export.
- Audio-friendly summary playback.
- App Store-ready privacy and onboarding.

### 21.3 Phase 2: Private Beta

Estimated duration: 4 to 6 weeks

Deliverables:

- 50 to 100 beta users.
- Feedback capture.
- Reliability improvements.
- Table/chart explanation refinements.
- Export fixes.
- Pricing test.
- Accessibility audit pass.

### 21.4 Phase 3: Public Launch

Estimated duration: 2 to 4 weeks

Deliverables:

- App Store listing.
- Website landing page.
- Demo videos.
- Student/legal/educator use-case pages.
- Documentation.
- Support workflow.
- Launch analytics.

### 21.5 Phase 4: Expansion

Potential features:

- Batch mode.
- Folder watch.
- DOCX, CSV, EPUB, audio exports.
- Advanced PDF/UA workflow.
- Team licensing.
- Browser extension.
- iPad app.
- Cloud processing option for larger models.

---

## 22. Risks and Mitigations

| Risk | Impact | Mitigation |
|---|---|---|
| OCR quality is inconsistent | User loses trust | Show confidence, allow correction, benchmark corpus, use native text when available. |
| Reading order fails on complex layouts | Poor accessibility | Show order overlay, support manual reorder, start with common layouts. |
| Chart explanations hallucinate | High trust risk | Use careful wording, cite visible labels, include uncertainty, avoid exact values unless readable. |
| Accessible PDF export is not fully compliant | Legal/reputation risk | Avoid overclaiming, label as basic accessible export, add validation roadmap. |
| Local AI models are too slow or large | Bad UX | Use local models selectively, offer optional downloads, keep MVP lightweight. |
| App Store sandbox limits workflows | Engineering delay | Design around sandbox early, test permissions, use security-scoped bookmarks. |
| Privacy concerns block legal/workplace adoption | Business risk | Local-first architecture, privacy mode, clear consent for cloud features. |
| Market sees it as commodity OCR | Weak monetization | Focus on reading order, accessibility, audio summaries, table/chart explanation, and exports. |

---

## 23. Launch Positioning

### 23.1 Core Tagline Options

- Make inaccessible PDFs readable.
- Turn screenshots and scans into accessible text.
- Read, hear, and export any visual document.
- OCR built for accessibility, not just copying text.

### 23.2 Landing Page Promise

Upload a scanned PDF, screenshot, or image. The app extracts the text, rebuilds the reading order, explains tables and charts, creates an audio-friendly summary, and exports clean accessible formats.

### 23.3 Differentiators

- Mac-native.
- Local-first OCR.
- Accessibility-first output.
- Reading order reconstruction.
- Table and chart explanations.
- Audio-friendly summaries.
- Export to formats users actually need.

---

## 24. Open Questions

1. Should MVP include screenshot capture, or only import/paste screenshots?
2. Should cloud AI be available at launch, or should launch be fully local-first?
3. What level of accessible PDF export is feasible in the first release?
4. Which export format matters most to the first target segment?
5. Should the first wedge be students, legal professionals, or educators?
6. How much manual editing should be included in MVP?
7. Will users pay more for privacy mode and local-only processing?
8. Should app support Intel Macs or require Apple silicon?
9. What document size limits are acceptable for launch?
10. What claims can be made safely after accessibility review?

---

## 25. Recommended MVP Scope Cut

To ship faster, the first public release should include:

- Import PDF/image/clipboard.
- Apple Vision OCR.
- Side-by-side review.
- Reading order for common layouts.
- Heading generation.
- Basic table detection and explanation.
- Basic chart/figure explanation.
- Audio-friendly summary playback.
- Markdown, TXT, HTML export.
- Basic accessible PDF export with cautious labeling.

Defer:

- Full PDF/UA validation.
- Advanced table editor.
- Audio export.
- DOCX/EPUB.
- Folder watch.
- Enterprise admin.
- Browser extension.
- iPad app.

---

## 26. Definition of Done for MVP

MVP is ready when:

- A user can import a scanned PDF and export readable Markdown in under two minutes.
- A user can paste a screenshot and get structured text in seconds.
- A screen reader user can complete the core flow without mouse-only controls.
- Common two-column documents produce acceptable reading order.
- Tables and charts produce useful but appropriately cautious explanations.
- The app never claims certainty where extraction is uncertain.
- Exported HTML uses semantic structure.
- Accessible PDF export improves readability without overclaiming compliance.
- Privacy behavior is clear and trustworthy.
- The app passes internal regression tests across the fixture corpus.

---

## 27. Build Plan Using Codex CLI

Use Codex CLI during development for focused, reviewable tasks.

Suggested task prompts:

- “Refactor the OCRService into protocol-based components and add unit tests.”
- “Create fixtures for PDF import tests and snapshot Markdown export.”
- “Add a ReadingOrderAnalyzer test for two-column academic PDFs.”
- “Review this SwiftUI view for keyboard navigation and VoiceOver labels.”
- “Generate a regression test for table Markdown export.”
- “Find memory leaks or large image retention in the PDF rendering pipeline.”

Development guardrail:

Every Codex-generated change should pass tests, be reviewed by a human, and be checked against accessibility and privacy expectations before merge.

---

## 28. Smallest End-To-End Prototype

Build the smallest end-to-end prototype first:

1. Drag in a screenshot or one-page scanned PDF.
2. Run OCR with Apple Vision.
3. Show original image and extracted text side by side.
4. Generate a simple heading and summary.
5. Export Markdown.

This prototype validates the core promise before investing in advanced PDF export, chart explanation, and subscription packaging.

---

## 29. App Name Recommendation

### Top Pick: Sightline Reader

Why it works:

- It suggests reading order, visual interpretation, and clarity.
- It feels more premium than a generic OCR name.
- It fits students, legal professionals, researchers, and workplace users.
- It can stretch beyond PDFs into screenshots, slides, scans, and future document contexts.
- It sounds appropriate for an accessibility-first tool without being overly clinical.

### Backup Name Ideas

- AccessLens
- ClearRead
- PageVoice
- ReadOrder
- ScanSage
- DocLumen
- Clarity PDF
- ReadBridge
- AltPage
- LumenReader

Before launch, run trademark, domain, and App Store availability checks.
