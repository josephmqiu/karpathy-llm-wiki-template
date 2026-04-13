---
id: ingest
name: ingest
title: "Ingest: process one raw source into wiki pages"
version: 1
status: stable
log_op: ingest
inputs:
  - name: source_path
    required: true
    description: "Path under raw/ to the file being ingested"
related_skills: [triage, query, lint, migrate]
created: 2026-04-13
updated: 2026-04-13
---

# Ingest

## Purpose

Process a single raw source into durable wiki pages: a source summary, any new or extended entities and concepts it touches, MOC updates, an index entry, a log entry, and a manifest entry. Ingest is the primary mechanism for growing the wiki. Each ingest is atomic — one source, one commit.

## When to invoke

- **Explicit:** User says `ingest this source`, `process raw/...`, `add this to the wiki`, or drops a file into `raw/` and asks what to do next.
- **Implicit (chained):** after the `triage` skill promotes an inbox item to `raw/`, ingest runs immediately on the new `raw/` path.
- **Never:** without discussing takeaways with User first (see CLAUDE.md §4 rule 9).

## Inputs

- **`source_path`** (required) — path under `raw/` to the file being ingested, e.g., `raw/2026-04-12-zettelkasten-llm-tools.md`.

## Preconditions

- The file exists at `source_path` and is immutable per CLAUDE.md §4 rule 1. Never modify files in `raw/` — if User asks you to, push back and add a corrective wiki page instead.
- `raw/.manifest.json` is readable and writable.
- User is available interactively for the takeaways discussion in step 4. If no human is available, abort.
- **Ripple budget:** for the first 10 ingests, target **4–8** page touches total per source. Scale up to 10–15 only after the wiki has substance to ripple to. This is CLAUDE.md §4 rule 10.

## Steps

1. **Compute hash.** `shasum -a 256 raw/<filename>` → record the hex digest.
2. **Check `raw/.manifest.json`** for that hash:
   - If found with `status: ingested` → **abort**. Tell User "already ingested as [[<source-page>]]" and stop.
   - If found with `status: deferred` → proceed (and update the entry to `ingested` at the end).
   - If not found → proceed (and add a new entry at the end).
3. **Read the source in full.** For long sources, split into chapter-level or section-level files **before** ingesting whenever practical. This is the default for books, long transcripts, and multi-section reports. Naive whole-document ingests produce slop.
4. **Discuss takeaways with User.** What's the source about? What entities does it mention? What concepts? What's worth keeping? Get explicit sign-off before writing any pages.
5. **Decide placement of the source summary**: `wiki/shared/sources/` (default) or `wiki/domains/<topic>/sources/` (single-domain only). Placement rule per CLAUDE.md §5: when in doubt, `shared/`.
6. **Write the source summary page** with full frontmatter including `source_ref` and `hash`. Apply provenance labels and coverage tags per CLAUDE.md §6A: `[extracted]` / `[inferred]` / `[ambiguous]` / `[disputed]` inline, and `## Section [coverage: high|medium|low]` on major headings.
7. **Identify affected entities and concepts.** For each:
   - Does an existing page cover this? → **extend** it. Bump `updated`, add the new source path to `sources:`, add or refine relevant content.
   - Or is this new? → **create** a new page in `shared/` (default) or `domains/<topic>/` (only if confidently single-domain).
8. **Apply the adaptive ripple rule.** Target **4–8 page touches** for the first 10 ingests; 10–15 only after the wiki has substance. Resist creating standalone pages for every concept mentioned — only create a page if the concept is likely to recur, resolves an ambiguity, or will be queried directly.
9. **Update the relevant MOC(s).** Add the new source to "Key sources", new entities to "Entities", new concepts to "Concepts". Bump the MOC's `updated`.
10. **Update `wiki/index.md`** — add new pages under the appropriate sections.
11. **Append to `wiki/log.md`** using the [Log entry format](#log-entry-format) below.
12. **Update `raw/.manifest.json`** with `{hash, source_path, status: "ingested", ingested_at, pages_created: [...], pages_updated: [...]}`.
13. **Git commit** using the [Git commit format](#git-commit-format) below. Stage only the intended files — do not rely on `git commit -am` in a dirty worktree.

## Log entry format

```markdown
## [YYYY-MM-DD] ingest | <source title>

- Source: [[<source-page>]]
- Entities created: [[a]], [[b]]
- Entities extended: [[c]]
- Concepts created: [[d]]
- MOCs updated: [[llm-wiki-moc]]
- Total page touches: N
```

Omit lines that have no entries (don't write `Entities extended: none`), but always include the total page touches line — it's the count the lint skill watches.

## Git commit format

```
ingest: <source title>
```

One commit per source. If ingest fans out to multiple pages (source + entities + concepts + MOC + index + log + manifest), they all land in the same commit.

## Anti-patterns

- **Modifying files in `raw/`.** They are immutable per CLAUDE.md §4 rule 1. Add a corrective wiki page instead, never edit the source.
- **Skipping the hash check.** Always compute the hash and check `raw/.manifest.json` first. Re-ingesting the same source silently corrupts the wiki.
- **Auto-ingesting without discussing takeaways.** Always sync with User before writing pages. Even obvious sources get the takeaways step.
- **Creating duplicate entities.** Check existing entities by canonical name AND aliases before creating a new page. Use aliases for variants (e.g., `karpathy` → alias of `andrej-karpathy`).
- **Forcing 10–15 page touches early.** First 10 ingests should be 4–8. Don't fabricate pages just to hit a number.
- **Naive whole-document ingest of long sources.** Books, long transcripts, and multi-section reports should usually be split to chapter/section-level first.
- **Putting everything in `domains/`.** Default is `shared/`. Only place in a domain folder if you can confidently say "this will never be relevant outside this one domain."
- **Silently editing the placement of an existing page.** If you realize a `shared/` page should be in a domain folder, surface it as a `migrate` operation — don't quietly move it inside an ingest.
- **Skipping provenance labels.** All new pages and major rewrites get `[extracted]` / `[inferred]` / `[ambiguous]` / `[disputed]` labels and section-level `[coverage: ...]` tags per CLAUDE.md §6A.

## Worked example

**Scenario:** User drops `raw/2026-04-12-zettelkasten-llm-tools.md` into `raw/`.

**Steps:**

1. Compute hash: `shasum -a 256 raw/2026-04-12-zettelkasten-llm-tools.md` → e.g., `a3f...`.
2. Check `raw/.manifest.json` — hash not present, proceed.
3. Read the source — it's a blog post about a plugin called `zettelkasten-llm-tools` that adds embedding search to Obsidian.
4. Discuss with User: "This source covers (a) the Zettelkasten method, (b) a specific Obsidian plugin, (c) the broader question of LLM-assisted note linking. I think we want a source summary, an entity for the plugin, and a concept for Zettelkasten itself. The Andy Matuschak 'evergreen notes' angle is mentioned but probably not worth a standalone page yet — I'll note it inside the Zettelkasten concept."
5. User says yes. Placement: `shared/sources/` (the topic is broad enough that future cross-domain links are plausible).
6. Create `wiki/shared/sources/zettelkasten-llm-tools.md`:
   ```yaml
   ---
   id: zettelkasten-llm-tools
   title: "Zettelkasten LLM Tools (blog post)"
   type: source
   aliases: []
   status: stable
   source_ref: raw/2026-04-12-zettelkasten-llm-tools.md
   hash: a3f...
   related: ["[[zettelkasten]]", "[[zettelkasten-llm-tools-plugin]]"]
   topics: ["llm-wiki"]
   created: 2026-04-12
   updated: 2026-04-12
   last_reviewed: 2026-04-12
   superseded_by: null
   ---

   # Zettelkasten LLM Tools (blog post)

   ## Summary [coverage: high]
   ...
   ## Key claims [coverage: medium]
   ...
   ## Quotes worth keeping [coverage: high]
   ...
   ```
7. Identify affected pages:
   - `zettelkasten` concept — does it exist? No → create.
   - `zettelkasten-llm-tools-plugin` entity — does it exist? No → create.
   - The `llm-wiki` MOC — needs the new source listed.
8. Adaptive ripple budget: this is ingest #1, target 4–8 touches. Plan: source page + 2 new pages + MOC + index + log + manifest = 7. Within budget.
9. Create `wiki/shared/concepts/zettelkasten.md` and `wiki/shared/entities/zettelkasten-llm-tools-plugin.md` with full frontmatter, each citing the new source.
10. Update `wiki/domains/llm-wiki/llm-wiki-moc.md`: add the source under "Key sources", entity under "Entities", concept under "Concepts", bump `updated`.
11. Update `wiki/index.md`: add the three new pages under their sections.
12. Append to `wiki/log.md`:
    ```markdown
    ## [2026-04-12] ingest | Zettelkasten LLM Tools (blog post)

    - Source: [[zettelkasten-llm-tools]]
    - Entities created: [[zettelkasten-llm-tools-plugin]]
    - Concepts created: [[zettelkasten]]
    - MOCs updated: [[llm-wiki-moc]]
    - Total page touches: 7
    ```
13. Update `raw/.manifest.json` — add new entry with `status: ingested`, hash, ingested_at, pages_created/updated arrays.
14. `git add` the specific files touched (source page, two new pages, MOC, index, log, manifest) and `git commit -m "ingest: Zettelkasten LLM Tools (blog post)"`.

## Related skills

- **[triage](../triage/SKILL.md)** — upstream. Promotes inbox items into `raw/` paths that feed this skill.
- **[query](../query/SKILL.md)** — downstream. Answers questions that reference the pages this skill creates.
- **[lint](../lint/SKILL.md)** — downstream. Runs automatically after every 5 ingests since the last lint.
- **[migrate](../migrate/SKILL.md)** — peer. If this skill discovers a duplicate entity or a placement it wants to change on an existing page, hand off to migrate rather than doing the rename inside the ingest.
