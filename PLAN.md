## MarkdownPipeline Package Build Plan

### Goal

Create a Swift Package `MarkdownPipeline` that:

* Parses Markdown using **Apple’s Swift Markdown (`Markdown`)** framework as the internal representation (AST).
* Supports **Front Matter** (YAML) extraction.
* Emits **full HTML documents** using your `template.html` plus CSS resources.
* Performs code block highlighting **as a transform stage** (JavaScriptCore + bundled `highlight.min.js`) so the WKWebView and QuickLook only render HTML.

### Existing reusable resources

Re-use sources from the current project if they are helpful:

* `Shared/WebResources/markdown-style.css`
* `Shared/WebResources/stackoverflow-dark.min.css`
* `Shared/WebResources/stackoverflow-light.min.css`
* `Shared/WebResources/highlight.min.js`

Also you might reuse concepts and logic from:

* `Shared/MarkdownParser.swift` (HTML emission, escaping, sanitization, tables, lists, etc.)
* `Shared/Bundle-Extension.swift` (resource loading patterns)
* `Shared/TemplateBuilder.swift` (HTML template filling)

Full HTML template currently used to highlight-code "when on screen": Can be used for inspiration.
* `Shared/WebResources/template.html`

---

## Milestone 1 — Create the Swift Package skeleton

### Tasks

1. Create package:

   ```bash
   mkdir MarkdownPipeline
   cd MarkdownPipeline
   swift package init --type library
   ```

2. Update `Package.swift`:

   * Add dependency on Apple’s `swift-markdown` if not already available via `import Markdown` in your environment.
   * Add resources processing for WebResources.
   * Add platform constraints (iOS/macOS).

   **Target structure** (high-level):

   * Target: `MarkdownPipeline` (library)
   * Test target: `MarkdownPipelineTests`
   * Resources: `Resources/WebResources/*`

3. Copy resources into the package:

   ```
   MarkdownPipeline/
     Sources/MarkdownPipeline/Resources/WebResources/
       markdown-style.css
       stackoverflow-dark.min.css
       stackoverflow-light.min.css
       highlight.min.js
   ```

**Acceptance:** `swift build` succeeds; resources are bundled (via `Bundle.module`).

---

## Milestone 2 — Define the core data structures

### Public API types (minimal but extensible)

Create these files:

1. `MarkdownInput.swift`

   * `enum MarkdownInput { case string(String); case data(Data,...); case file(URL,...) }`

2. `PipelineContext.swift`

   * title, baseURL, theme selection, auto-detect language subset, etc.

3. `PipelineResult.swift`

   * `struct HTMLDocument { let html: String; let title: String?; let baseURL: URL?; }`
   * add helper `write(to:)` and `writeToTemporaryFile()` for QuickLook.

4. `MarkdownPipeline.swift`

   * Owns stages: parse → transforms → emit.

**Acceptance:** You can instantiate `MarkdownPipeline` and call `render(input:context:)` even before internals are implemented (stub returns).

---

## Milestone 3 — Front Matter extraction (YAML)

### Behavior

If the Markdown starts with:

```markdown
---
title: Something
theme: dark
---
# Content
```

Then:

* Extract the YAML block into a `FrontMatter` object
* Remove it from the Markdown that is fed to `Document(parsing:)`
* Store extracted values into `PipelineContext` (or return alongside result)

### Tasks

1. Implement `FrontMatterExtractor.swift`:

   * Detect leading `---\n ... \n---\n`
   * Return `(frontMatter: String, bodyMarkdown: String)`
   * Keep it strict: only at the very beginning of the document.

2. Implement simple YAML parsing strategy:

   * **Phase 1 (fast):** parse only “flat” `key: value` lines (enough for `title`, `theme`, toggles)
   * **Phase 2 (optional later):** integrate a YAML lib if you really need nested structures.

**Acceptance:** Unit tests for:

* no front matter → unchanged
* valid front matter → extracted + body returned
* malformed front matter → treat as normal markdown (don’t crash)

---

## Milestone 4 — Parser stage using Swift Markdown AST

### Tasks

1. Create `SwiftMarkdownParser.swift`:

   * Input: `String`
   * Output: `Document` (from `Markdown` package)

2. Keep `Document` internal to the module (not exposed in public API) if possible.

**Acceptance:** A simple Markdown string parses into a `Document` and can be walked.

---

## Milestone 5 — HTML emitter (baseline, no highlighting yet)

You already have an emitter in `Shared/MarkdownParser.swift` that implements `MarkupVisitor` and returns HTML. Use it as the baseline emitter logic. 

### Tasks

1. Copy/adapt the visitor into the package as `HTMLVisitor.swift`:

   * Keep:

     * HTML escaping helpers (`encodedHTMLEntities`, `encodedHTMLAttribute`)
     * link/image sanitization (schemes)
     * raw HTML sanitization (disallowed tags)
     * table rendering
     * list handling and checkbox rendering
     * paragraph skip logic

2. Adjust code block output to be “pipeline-friendly”:

   * Instead of directly emitting `<pre><code class="lang-...">escaped</code></pre>`,
   * emit a placeholder structure or annotation (see next milestone), OR keep as-is for now.

3. Implement `HTMLEmitter.swift`:

   * Loads `template.html` from resources
   * Injects:

     * computed body HTML
     * CSS (inline or link style)
     * title (from front matter or context)
   * Reuse your TemplateBuilder concepts (string replacement tokens).

**Acceptance:** Markdown renders into a full HTML document using `template.html` and CSS, with no highlighting yet.

---

## Milestone 6 — Code block highlighting as a transform stage (JavaScriptCore)

### Approach

Highlighting should be *just a transform* that enriches code blocks before final HTML output.

Two viable implementation patterns:

#### Pattern A (recommended): AST transform before emitting HTML

* Traverse `Document`
* For each `CodeBlock`, compute `highlightedHTMLSnippet`
* Store it in a side-table keyed by code block identity (e.g., stable path index while walking)
* In the HTML emitter, when encountering a `CodeBlock`, use the highlighted HTML snippet instead of escaped raw code.

#### Pattern B: Emit placeholders then replace

* HTMLVisitor emits placeholder tags like:

  ```html
  <pre data-codeblock-id="42"><code class="hljs language-swift"></code></pre>
  ```
* After emission, do a string replacement of placeholders.
* Simpler to implement, slightly hackier, but effective.

### Tasks

1. Create `HLJSHighlighter.swift`:

   * Holds a single `JSContext`
   * Loads `highlight.min.js` from resources once
   * Methods:

     * `highlight(code: String, language: String?) -> CodeHighlightResult`
     * `highlightAuto(code: String, subset: [String]) -> CodeHighlightResult`

2. Implement language alias normalization:

   * `js→javascript`, `yml→yaml`, `sh/zsh→bash`, `py→python`, etc.

3. Implement caching:

   * `NSCache` keyed by hash(code + language)
   * Prevent repeated work across QuickLook + app loads

4. Add CSS theme selection:

   * Choose between `stackoverflow-dark.min.css` and `stackoverflow-light.min.css`
   * Theme choice can come from:

     * Front matter (`theme: dark`)
     * Pipeline context override
     * System appearance (optional later)

**Acceptance:** A markdown file with fenced code blocks produces HTML containing `<span class="hljs-...">` output and uses the correct theme CSS.

---

## Milestone 7 — Public convenience API for your app + QuickLook

### Tasks

1. Add:

   * `MarkdownPipeline.defaultHTML(theme: ...)`
   * `renderHTML(from input: MarkdownInput, context: PipelineContext) -> HTMLDocument`

2. QuickLook helper:

   * `HTMLDocument.writeToTemporaryFile()` returns `URL`
   * This becomes the single line your QuickLook extension uses.

3. WKWebView helper (optional):

   * Provide `baseURL` so relative links/images can be resolved consistently.

**Acceptance:** Your app and QuickLook extension can replace the current approach with a single call to the package.

---

## Milestone 8 — Replace current implementation in the main project

### Tasks

1. Identify all call sites that currently use:

   * `Shared/MarkdownParser.swift`
   * `Shared/TemplateBuilder.swift`
   * manual resource injection

2. Replace with:

   * `MarkdownPipeline.defaultHTML(...).render(...)`

3. Keep old code temporarily behind a feature flag until validated.

**Acceptance:** App and QuickLook render identical HTML output, but now through `MarkdownPipeline`.

---

## Milestone 9 — Tests & golden fixtures

### Tasks

1. Add fixtures:

   * Markdown with headings/lists/tables/images/raw HTML
   * Markdown with multiple code blocks, with and without language info
   * Markdown with front matter controlling title/theme

2. Golden test strategy:

   * Render HTML
   * Compare against stored expected HTML (normalize whitespace)
   * Or verify key substrings exist (less brittle)

3. Security tests:

   * raw HTML sanitization disallows scripts/iframes etc. (mirrors your existing logic) 
   * URL sanitization rejects non http/https/file schemes 

**Acceptance:** CI tests pass; output doesn’t regress.

---

# Concrete Codex CLI Task List (copy/paste to agent)

Use this as the exact instruction set for your Codex CLI agent:

1. Create Swift package `MarkdownPipeline` (library + tests).
2. Add `Resources/WebResources/` to the target and configure `Bundle.module` resource access.
3. Implement public API types:

   * `MarkdownInput`, `PipelineContext`, `HTMLDocument`, `MarkdownPipeline`.
4. Implement `FrontMatterExtractor`:

   * supports YAML front matter at start of file
   * parse at least `title` and `theme`.
5. Implement parser stage using `Markdown.Document(parsing:)`.
6. Port your `MarkupVisitor` HTML conversion logic from `Shared/MarkdownParser.swift` into `HTMLVisitor` and use it as the baseline HTML emitter. 
7. Implement HTML document assembly using `template.html`:

   * inject body HTML
   * inject CSS (markdown-style + theme css)
   * set `<title>` from front matter/context.
8. Implement `HLJSHighlighter` using JavaScriptCore and `highlight.min.js`.
9. Add code-block highlighting transform:

   * normalize language aliases
   * highlight with explicit language when available, else auto-detect with subset
   * cache results
10. Provide `MarkdownPipeline.defaultHTML(theme:)` factory.
11. Add tests for front matter, sanitization, and code highlighting output.

---

## Notes for the agent (important implementation detail)

Your existing `visitCodeBlock` currently emits `class="lang-..."` and escapes code. 
highlight.js expects something like:

* `class="hljs language-swift"` (or `language-javascript`)
  and highlighted snippet inserted *as HTML* (not escaped again). So the new pipeline needs to adjust the emitter for code blocks (or use placeholders + replace).

