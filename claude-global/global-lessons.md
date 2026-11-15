# Global Lessons

Lessons learned across all projects. Read this at the start of every session.
These are not project-specific — they apply everywhere.

---

## 2026-04-04 — Visual asset approval and proof discipline

**Origin:** ARCANEX project, D-1 body plate generation (quick task 260404-mkf)
**Trigger:** Approved a generated image as "operational body plate" without rigorous visual inspection. User corrected — the image had missing feet, figure too distant, silhouette diffuse, and was essentially identical to a prior attempt. The approval was wrong.

### Rules — MANDATORY for all visual asset work

1. **NEVER approve a visual asset without explicit visual inspection.** Open the file. Describe factually what you see. Do not trust the prompt, the MCP output text, or abstract criteria.

2. **NEVER trust that a prompt produced what it asked for.** The prompt said "80% of frame" — the result was ~65%. The prompt said "head to feet" — the feet were absent. Always verify output against intent.

3. **ALWAYS verify extremities.** Before any approval, explicitly confirm:
   - Feet present and defined (not glow fading into background)
   - Hands present
   - Head/hair complete
   - No cropping of any body part

4. **ALWAYS verify framing.** Estimate the actual percentage of frame the figure occupies. Do not accept the prompt's target as the result.

5. **ALWAYS verify edges/borders.** For compositing assets, the silhouette edges must be defined enough for edge detection. Diffuse glow that dissolves into the background = not a usable asset.

6. **ALWAYS compare side-by-side with prior attempts.** If there is no visible difference from the previous attempt, there is no progress. Do not declare progress that does not exist visually.

7. **ALWAYS separate "generated" from "approved".** Generation is an operation. Approval is a judgment that requires proof. The correct intermediate label is "candidate" or "generated", not "approved".

8. **Confirmation bias kills accuracy.** After spending time crafting a prompt and waiting for generation, there is a natural bias to see success. Fight it. Look for what is WRONG, not what is right.

9. **If the user has already proved something in the terminal, treat it as strong evidence.** Do not dismiss or reinterpret evidence the user has already demonstrated.

10. **NEVER say "gravei no claude-mem" (or equivalent) if only local files were updated and plugin/indexation is not confirmed.** Distinguish clearly between:
    - Plugin persistence (automatic, unconfirmable in real-time)
    - File persistence (manual, immediately verifiable)

### Approval checklist for visual assets

Before writing "APPROVED" or equivalent, answer ALL of these:

- [ ] Did I open and visually inspect the generated file?
- [ ] Did I compare it side-by-side with the prior attempt?
- [ ] Are feet/hands/head complete and defined?
- [ ] Is the figure's frame occupancy what was requested?
- [ ] Are silhouette edges clean enough for the intended use?
- [ ] Is there a real visual difference from the previous attempt?
- [ ] Does the asset serve the stated purpose (compositing, integration, etc.)?

If ANY answer is "no" or "unclear", the verdict is **CANDIDATE**, not **APPROVED**.

---
