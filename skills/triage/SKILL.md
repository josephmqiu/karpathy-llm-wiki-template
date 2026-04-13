---
id: triage
name: triage
title: "Triage: process inbox items into sources, extensions, or discards"
version: 1
status: stable
log_op: triage
inputs: []
related_skills: [ingest, migrate]
created: 2026-04-13
updated: 2026-04-13
---

# Triage

## Purpose

Process items in `inbox/` to convert low-friction captures (clippings, half-formed thoughts, article dumps) into one of three outcomes: a proper raw source that flows into the `ingest` skill, a small inline extension to an existing wiki page, or a discard. Triage is the gate between User's quick-capture workflow and the wiki's durable content.

## When to invoke

- **Explicit:** User says `triage`, `triage the inbox`, `process inbox`, or similar.
- **Implicit:** at the start of any session where `inbox/` contains anything beyond `.gitkeep`.
- **Chained:** after User drops a new clipping or note into `inbox/` and wants it processed immediately.

## Inputs

None. Reads from `inbox/` at the repo root.

## Preconditions

- `inbox/` directory exists at repo root.
- User is available interactively to decide promote / extend / discard per item. This skill does **not** auto-classify — human in the loop is mandatory (see CLAUDE.md §4 rule 9).
- If any item will be promoted, the `ingest` skill must be available to chain into.

## Steps

1. **List all files in `inbox/`** (skip `.gitkeep`).
2. **For each item**, present it to User with three options:
   - **Promote to source** — move the file to `raw/`, run the `ingest` skill on it.
   - **Extend an existing page** — small additions inline, no full ingest. The inbox file is deleted after the extension lands.
   - **Discard** — delete the inbox file.
3. **For each "promote" decision**: rename the file to `raw/YYYY-MM-DD-<slug>.md` where the date is **today**, not the file's mtime. Then immediately run the `ingest` skill on the new `raw/` path.
4. **For each "extend" decision**: identify the target wiki page, append the new info, update `updated` and bump `last_reviewed` in the frontmatter, and log the extension.
5. **After processing, the inbox should be empty** — only `.gitkeep` remains.
6. **Append to `wiki/log.md`** using the [Log entry format](#log-entry-format) below.
7. **Git commit** using the [Git commit format](#git-commit-format) below.

## Log entry format

```markdown
## [YYYY-MM-DD] triage | <count> items processed

- Promoted: [[a]], [[b]]
- Extended: [[c]]
- Discarded: 2
```

If a field has zero items, write `none` rather than omitting the line — it makes the log greppable for per-outcome counts.

## Git commit format

```
triage: <count> items
```

Promoted items that trigger `ingest` get their own separate `ingest: <source title>` commits per the `ingest` skill. A triage commit records only the triage outcome, not the downstream ingests.

## Anti-patterns

- **Auto-classifying items without asking User.** Per CLAUDE.md §4 rule 9, triage is interactive. Even if an item looks like an obvious promote, present it and wait for confirmation.
- **Leaving files in the inbox after triage.** The inbox must be empty of everything except `.gitkeep` when the skill finishes. If an item can't be decided on, leave the whole triage unfinished and surface the question — do not silently defer it.
- **Using the file's mtime for the `raw/` rename.** Use today's date. The inbox is a staging area; the date in `raw/` should reflect when the item entered the durable record, not when it was captured.
- **Forgetting to chain `ingest` after a promote.** A promoted file is still unprocessed until `ingest` runs on it. Completing triage without running the chained ingests leaves the wiki in a half-done state.
- **Batching promotes into one big ingest.** Each source gets its own atomic ingest (see CLAUDE.md §4 rule 8). If User promotes three items in one triage, that's three `ingest` commits after the one `triage` commit.

## Worked example

**Scenario:** User runs triage on `inbox/`, which contains three items:

- `inbox/2026-04-12-rag-vs-wiki-post.md` — a clipped blog post comparing RAG systems to LLM-maintained wikis
- `inbox/embedding-note.md` — a two-sentence note reminding himself that cosine similarity isn't the only distance metric for retrieval
- `inbox/random-tweet.md` — a screenshot dump of a tweet that turned out to be unrelated to anything in the wiki

**Steps:**

1. List inbox: three files found (ignoring `.gitkeep`).
2. Present each to User:
   - **`rag-vs-wiki-post.md`** — "This is a substantive article. Promote?" User: yes, promote.
   - **`embedding-note.md`** — "Two sentences about distance metrics. Promote as a source, or extend [[embeddings]]?" User: extend — it's a margin note, not a source.
   - **`random-tweet.md`** — "This doesn't match any topic in the vault. Discard?" User: yes, discard.
3. Promote `rag-vs-wiki-post.md`:
   - `mv inbox/2026-04-12-rag-vs-wiki-post.md raw/2026-04-13-rag-vs-wiki-post.md` (today's date, not the file's date)
   - Immediately invoke the `ingest` skill with `source_path = raw/2026-04-13-rag-vs-wiki-post.md`. Ingest writes its own source summary + entities + concepts + MOC update + log entry + manifest entry + commit.
4. Extend `[[embeddings]]`:
   - Read `wiki/shared/concepts/embeddings.md`.
   - Append the distance-metric note inline under an appropriate section (e.g., "Distance metrics" or "Related").
   - Bump `updated` and `last_reviewed` to `2026-04-13`.
   - Delete `inbox/embedding-note.md`.
5. Discard `random-tweet.md`: `rm inbox/random-tweet.md`.
6. Verify `inbox/` contains only `.gitkeep`.
7. Append to `wiki/log.md`:
   ```markdown
   ## [2026-04-13] triage | 3 items processed

   - Promoted: [[rag-vs-wiki-post]]
   - Extended: [[embeddings]]
   - Discarded: 1
   ```
8. `git add inbox/ raw/2026-04-13-rag-vs-wiki-post.md wiki/shared/concepts/embeddings.md wiki/log.md`
9. `git commit -m "triage: 3 items"`

The subsequent `ingest` commit for the RAG source is a separate atomic commit, not part of this triage commit.

## Related skills

- **[ingest](../ingest/SKILL.md)** — chained after every promote decision to process the new `raw/` file into wiki pages.
- **[migrate](../migrate/SKILL.md)** — if an extension requires renaming or merging a page, hand off to migrate rather than doing structural surgery inline.
- **[go](../go/SKILL.md)** — the session-start skill checks the inbox state and surfaces a triage prompt if the inbox is non-empty.
