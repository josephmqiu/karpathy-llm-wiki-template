---
id: query
name: query
title: "Query: answer a question against the wiki, log it, optionally file as synthesis"
version: 1
status: stable
log_op: query
inputs:
  - name: question
    required: true
    description: "The question to answer, in User's words"
related_skills: [ingest, lint, migrate, go]
created: 2026-04-13
updated: 2026-04-13
---

# Query

## Purpose

Answer a domain question by reading the wiki first, synthesizing an answer with inline citations to wiki pages, and deciding whether the answer is worth filing as a durable synthesis page. Query is the read-side of the wiki and the primary mechanism for converting latent knowledge in the graph into explicit knowledge in `wiki/synthesis/`.

Every query operation gets logged, whether or not a synthesis page is filed. The log trail is how future sessions reconstruct what was asked, what was read, and what was decided — that's the "bookkeeping is the value" principle from CLAUDE.md §2.

## When to invoke

- **Explicit:** User says "what does the wiki say about X", "compare A and B", "what do we know about Y".
- **Implicit (the common case):** User asks any domain question that could be answered, even partially, from existing wiki content. User does **not** need to say "run a query" — the skill activates on any question the wiki plausibly covers.
- **Not for:** questions about session mechanics, tool usage, or things unrelated to the wiki's topics. Those should be answered without burning tokens on the wiki.

Default behavior: **read the wiki first, cite wiki pages in the answer, then decide whether to file.** Even if the answer is not filed, read-first discipline is what makes the wiki useful.

## Inputs

- **`question`** (required) — the question to answer, in User's words. Preserve the exact phrasing for the log entry and, if filed, the synthesis page's `question:` frontmatter field.

## Preconditions

- `wiki/index.md` and the relevant MOC(s) exist and are readable.
- If filing is likely, the target directory `wiki/synthesis/` exists.
- For interactive sessions, User is available to confirm the filing decision or override with `save that` / `file it` / `skip`.
- In non-interactive runs (e.g., subagent validation), the decision rule below is applied autonomously.

## Steps

1. **Read in order**: `wiki/index.md` → relevant `<topic>-moc.md` → specific pages. Follow the read order in CLAUDE.md §8. Skipping the index/MOC means you'll miss existing pages and may create duplicates.
2. **Synthesize an answer with inline citations** to specific wiki pages, e.g.:
   > [[andrej-karpathy]] proposed the LLM wiki pattern in his April 2026 gist [[karpathy-llm-wiki-gist]].
3. **State your filing decision.** After answering, add one line at the end of your response:
   ```
   **Filing decision:** [yes/no] — [reason]
   ```
   This is not a request for permission; it is a forcing function to actually evaluate the rule below. User can override with `save that`, `file it`, or `skip`.
4. **Apply the decision rule.** The decision can come from User interactively OR from the originating instruction (e.g., `file it` in a subagent run). When no interactive human is available, apply the rule below autonomously:

   | File? | Test |
   |---|---|
   | **Yes** | Answer cites 2+ wiki pages and adds reasoning not present on any single page |
   | **Yes** | User says `save that`, `file it`, or similar |
   | **Yes** | The question matches or extends an open question from a MOC |
   | **Probably yes** | The answer would save future-you from re-reading 3+ pages to reconstruct |
   | **No** | The answer restates a single existing page without adding synthesis |
   | **No** | The answer is about session mechanics rather than domain knowledge |

   When in doubt and the answer cites ≥2 wiki pages → file.

   **Quick save:** If User says `save that` or `file it` after any answer, file the immediately preceding answer as a synthesis. Do not re-ask the question or re-derive the answer unless User asks for a rewrite.

5. **If filing, write `wiki/synthesis/<slug>.md`** with full frontmatter per CLAUDE.md §6 — all required fields, plus `type: synthesis` and the mandatory `question:` field (the original question verbatim). Include the original question as a blockquote near the top of the page body:
   ```markdown
   > **Question:** <question text>
   ```
   so the synthesis is discoverable both structurally and in prose. Apply provenance labels and coverage tags per CLAUDE.md §6A.

6. **Update `wiki/index.md`** — add the new page under the "Synthesis" section.

7. **Update the relevant MOC(s).** Add the synthesis to the MOC's "Syntheses" section. If it answers or partially answers an open question, annotate that question with `answered by [[<synthesis-page>]]` or remove it if fully resolved.

8. **Append to `wiki/log.md`** using the [Log entry format](#log-entry-format) below. **Every query operation gets a log entry, whether or not a synthesis was filed.**

9. **Git commit** only if a synthesis was filed or another durable wiki page changed materially. Stage only the intended files — do **not** rely on `git commit -am` in a dirty worktree. Unfiled queries normally log only.

## Log entry format

```markdown
## [YYYY-MM-DD] query | <question summary>

- Filed as: [[<synthesis-page>]]    (or: "not filed — <one-line reason>")
- Cited: [[a]], [[b]], [[c]]
- Read trail: [[index]] -> [[<topic>-moc]] -> [[page1]] -> [[page2]] -> ...
- Decision to file: <yes/no> — <one-line rationale referencing the decision rule>
- Executed by: <User interactive | fresh subagent validation run | other>
```

Even unfiled queries get a full log entry — the read trail and citations are the primary value even without a synthesis page.

## Git commit format

```
synthesis: <topic>
```

Only when a synthesis is filed. Unfiled queries don't get commits; the log entry rides along on the next commit that does land.

## Anti-patterns

- **Answering domain questions without reading the wiki first.** If User asks about a topic with existing wiki pages, read them first. The query workflow activates implicitly — don't wait to be told.
- **Filing everything as a synthesis.** Most query answers are one-offs. Only file recurring, novel, or multi-page syntheses.
- **Restating a single page as a "synthesis".** If the answer just summarizes one existing page, don't create a new file. Point at the page.
- **Skipping the log entry on unfiled queries.** Every query gets logged, not just filed ones. The read trail is valuable even when the answer itself isn't.
- **`git commit -am` in a dirty worktree.** Stage specific files. The wiki often has in-flight work on unrelated files; auto-committing everything bundles unrelated changes into synthesis commits.
- **Re-deriving an answer when User says `save that`.** Quick-save files the answer you already gave. Don't re-synthesize unless User explicitly asks for a rewrite.
- **Writing a synthesis without the `question:` frontmatter field.** Synthesis pages require it per CLAUDE.md §6. The verifier's structural check will fail without it.

## Worked example

**Scenario:** User asks "What are the failure modes of LLM-maintained wikis?"

**Steps:**

1. Read `wiki/index.md` → `wiki/domains/llm-wiki/llm-wiki-moc.md` → drill into `wiki/shared/sources/karpathy-llm-wiki-gist.md`, `wiki/shared/sources/llm-wiki-research-synthesis.md`, and any concept pages on failure modes.
2. Synthesize:
   > Five recurring failure modes show up across the literature: error compounding through backlinks (cited in [[hn-discussion-llm-wiki]]), cognitive offloading (the user stops thinking because the LLM is "remembering" — see [[matuschak-evergreen-notes]]), markdown-as-database limits past ~100–300 sources (cited in [[stop-calling-it-memory]]), context window degradation past 200K tokens, and source granularity slop from naive whole-book ingests (cited in [[hn-success-report-chapter-splitting]]).
3. State the filing decision: `**Filing decision:** yes — cites 5 wiki pages and adds a recurring-failure framing not present on any single page`.
4. User confirms: "save that".
5. Create `wiki/synthesis/llm-wiki-failure-modes.md`:
   ```yaml
   ---
   id: llm-wiki-failure-modes
   title: "LLM Wiki Failure Modes"
   type: synthesis
   question: "What are the failure modes of LLM-maintained wikis?"
   aliases: ["wiki failure modes", "llm wiki pitfalls"]
   status: stable
   sources:
     - "raw/2026-04-09-karpathy-llm-wiki-gist.md"
     - "raw/2026-04-09-llm-wiki-research-synthesis.md"
   related: ["[[error-compounding]]", "[[cognitive-offloading]]", "[[markdown-as-database-limits]]"]
   topics: ["llm-wiki"]
   created: 2026-04-12
   updated: 2026-04-12
   last_reviewed: 2026-04-12
   superseded_by: null
   ---

   # LLM Wiki Failure Modes

   > **Question:** What are the failure modes of LLM-maintained wikis?

   ...synthesis body with [extracted] / [inferred] labels and section-level [coverage: ...] tags...
   ```
6. Update `wiki/index.md` under "Synthesis".
7. Update `wiki/domains/llm-wiki/llm-wiki-moc.md` — add the new synthesis under "Syntheses", strike any now-answered open question.
8. Append to `wiki/log.md`:
   ```markdown
   ## [2026-04-12] query | what are the failure modes of LLM-maintained wikis?

   - Filed as: [[llm-wiki-failure-modes]]
   - Cited: [[karpathy-llm-wiki-gist]], [[llm-wiki-research-synthesis]], [[error-compounding]], [[cognitive-offloading]]
   - Read trail: [[index]] -> [[llm-wiki-moc]] -> [[karpathy-llm-wiki-gist]] -> [[llm-wiki-research-synthesis]]
   - Decision to file: yes — cites 5 wiki pages and synthesizes a recurring failure framing
   - Executed by: User interactive
   ```
9. Stage only the synthesis page, the MOC, the index, and the log:
   ```
   git add wiki/synthesis/llm-wiki-failure-modes.md wiki/index.md wiki/domains/llm-wiki/llm-wiki-moc.md wiki/log.md
   git commit -m "synthesis: LLM wiki failure modes"
   ```

## Related skills

- **[ingest](../ingest/SKILL.md)** — upstream. Creates the pages that query reads from. An unanswerable query often surfaces a missing-source gap that `ingest` should fill.
- **[lint](../lint/SKILL.md)** — downstream. The query/synthesis health check (Check 13) watches for filing decisions that point at missing synthesis pages; lint surfaces those as structural failures.
- **[migrate](../migrate/SKILL.md)** — peer. If query discovers a duplicate or a disambiguation need while reading the graph, hand off to migrate.
- **[go](../go/SKILL.md)** — upstream. The session-start skill loads the index and relevant MOC, which primes the read order this skill depends on.
