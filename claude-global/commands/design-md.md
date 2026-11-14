---
description: Use an installed awesome-design-md reference in the current project
argument-hint: [brand/style name]
---

Use the local reference library at:

~/.claude/design-md/awesome-design-md

Task:
Find the closest matching DESIGN.md for "$ARGUMENTS".

Rules:
- Do not copy brand identity blindly.
- Use the selected DESIGN.md as visual reference only.
- Preserve this project's product identity, copy, architecture and business logic.
- Before editing, inspect the current project structure.
- If no DESIGN.md exists for the requested brand/style, list the closest 3 options.
- Ask before copying a DESIGN.md into the project root.
- If asked to apply it, copy only the chosen DESIGN.md into ./DESIGN.md, then propose exact UI files to change.
