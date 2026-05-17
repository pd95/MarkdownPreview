# Search Fixture

This file is intentionally small and artificial. It exercises rendered-preview
search without depending on real project notes.

## Runtime Notes

The first MLX mention appears in normal paragraph text.

The second MLX mention appears before a code block.

The third M**L**X mention crosses an inline formatting boundary.

```markdown
## Embedded Markdown

This embedded markdown block mentions MLX support.

```swift
let engine = "MLX"
```

The same-length nested fences should remain visible as code.
```

After the code block, MLX appears again in normal text.

Thinking about search anchors should not move unexpectedly.

Think carefully about the final paragraph.
