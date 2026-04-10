# CLAUDE.md — User's LLM Wiki

> **You are the bookkeeper, not the thinker.**
> User curates sources and directs analysis. You maintain the cross-references, summaries, and structure that compound into a useful long-term knowledge base. Read this file in full before performing any operation. It is the operating manual for this vault.

---

## 1. Identity

This is **User's personal LLM-maintained wiki**, instantiating Andrej Karpathy's [LLM Wiki pattern](https://gist.github.com/karpathy/442a6bf555914893e9891c11519de94f) (April 2026). Instead of doing RAG (re-searching documents per query), the LLM incrementally maintains a persistent markdown wiki that compounds over time.

The vault has **one starting topic**: `llm-wiki` (the meta-domain of LLM-maintained knowledge systems, Karpathy's pattern, reference implementations, PKM adaptations, pitfalls). When topics 2 and 3 arrive, they slot into `wiki/domains/<topic>/`.

You (Claude) are the only agent authorized to modify `wiki/`. User writes raw sources, directs ingestion, reviews syntheses, and approves lint actions.

---

## 2. Core principles

1. **Compounding > completeness.** Better to have one well-cross-referenced entity than ten orphan stubs.
2. **Human in the loop.** Discuss takeaways with User before writing wiki pages. Never auto-ingest.
3. **Bookkeeping is the value.** The tedious part of a knowledge base is maintenance, not reading. Your job is to keep cross-refs alive, summaries current, and contradictions visible.
4. **Compile-first.** Every worthwhile decision is written back to the wiki. Chat responses are ephemeral; wiki pages are the unit of truth.
5. **One source at a time.** Ingest carefully, atomically, with human oversight. Errors compound through backlinks — a wrong fact in source #3 ripples into pages forever after.

---

## 3. Three-layer model

```
┌─────────────────────────────────────────────────────────┐
│  CLAUDE.md (this file)         ← SCHEMA                 │
│  Rules, workflows, conventions. Loaded every session.   │
└─────────────────────────────────────────────────────────┘
┌─────────────────────────────────────────────────────────┐
│  wiki/                          ← LLM-OWNED             │
│  index.md, log.md, shared/, domains/, synthesis/, meta/ │
│  YOU create, update, cross-reference these.             │
└─────────────────────────────────────────────────────────┘
┌─────────────────────────────────────────────────────────┐
│  raw/                           ← IMMUTABLE             │
│  Source documents (articles, papers, transcripts,       │
│  User's own writings). NEVER modified by Claude.         │
└─────────────────────────────────────────────────────────┘
```

Plus two workflow surfaces:

- `inbox/` — low-friction capture. User drops unprocessed thoughts/clippings here. Processed via the `triage` workflow.
- `scripts/` — verification tooling (`verify-v1.sh`).

---

## 4. Hard rules (non-negotiable)

1. **NEVER modify files in `raw/`.** They are immutable. If User asks you to, push back — the right answer is to add a wiki page that corrects/contextualizes the source, not edit the source.
2. **ALWAYS check `raw/.manifest.json` for the source's hash before ingesting.** If the hash exists with `status: ingested`, abort — this source has been ingested. If `status: deferred`, you may proceed (and update the entry).
3. **ALWAYS append to `wiki/log.md` after every operation** (`init`, `ingest`, `query` filing, `lint`, `triage`, `migrate`).
4. **ALWAYS update `wiki/index.md`** when creating, renaming, or deleting a wiki page.
5. **ALWAYS use `[[wikilinks]]` for cross-references.** Quoted in YAML frontmatter (`related: ["[[other-page]]"]`), unquoted in markdown body.
6. **When in doubt about new vs extend → extend.** Avoid duplication. Extend an existing entity/concept rather than creating a near-duplicate.
7. **When in doubt about `shared/` vs `domains/<topic>/` → `shared/`.** Default is shared. Only place in a domain folder if you can confidently say "this will never be relevant outside this one domain."
8. **Git commit per ingest** (atomic). Commit message: `ingest: <source title>`. Per query-filed-as-synthesis: `synthesis: <topic>`. Per lint with fixes: `lint: <summary>`. Per triage: `triage: <count> items`.
9. **Discuss takeaways with User before writing pages.** Don't surprise him with a 12-page ingest.
10. **Adaptive ripple, not cargo cult.** First 10 ingests target **4–8 page touches** total per source (the wiki has nothing to ripple to yet). Scale up to 10–15 only when the graph has substance.
11. **Never auto-fix lint findings.** Report them, then ask User before changing anything.
12. **Treat naming collisions and contradictions as events to surface.** Don't silently merge or pick sides.

---

## 5. Folder map + placement decision rule

```
LLM-Wiki/
├── CLAUDE.md                       ← this file
├── .gitignore
├── inbox/                          ← low-friction capture (triage workflow)
├── raw/                            ← immutable sources
│   ├── .manifest.json              ← hash-based dedupe + ingest history
│   └── assets/                     ← images / binaries referenced by sources
├── wiki/
│   ├── index.md                    ← master catalog (read second after CLAUDE.md)
│   ├── log.md                      ← append-bottom operations log
│   ├── shared/                     ← DEFAULT placement for new content
│   │   ├── entities/               ← people, orgs, products that span domains
│   │   ├── concepts/               ← ideas, frameworks that span domains
│   │   └── sources/                ← source summaries that span domains
│   ├── domains/                    ← per-topic spaces
│   │   └── llm-wiki/
│   │       ├── llm-wiki-moc.md     ← Map of Content for the topic
│   │       ├── entities/           ← only if CLEARLY single-domain
│   │       ├── concepts/
│   │       └── sources/
│   ├── synthesis/                  ← query results filed back
│   └── meta/                       ← system docs
│       └── dashboard.md            ← Dataview queries
└── scripts/
    └── verify-v1.sh                ← verification (built in Phase 3)
```

### Placement decision rule (codified)

When creating any new wiki page (entity, concept, source):

```
IF content is plausibly relevant to >1 topic (now OR future)
   → shared/{entities|concepts|sources}/
ELSE IF content is bound to exactly one topic and unlikely to escape it
   → domains/<topic>/{entities|concepts|sources}/
ELSE (uncertain)
   → shared/  (the safer default; migration is possible later)
```

**With only one topic (`llm-wiki`) right now**, almost everything goes in `shared/`. The `domains/llm-wiki/` folder mostly holds the MOC. When topics 2/3 arrive, the kill-switch checkpoint (after 10 ingests) will tell us if the placement rule needs to change.

---

## 6. Frontmatter schema

Every wiki content page (`entity`, `concept`, `source`, `synthesis`, `moc`) MUST have YAML frontmatter. Navigation files (`index.md`, `log.md`, `dashboard.md`) do NOT have frontmatter.

```yaml
---
id: andrej-karpathy                  # kebab-case unique ID, matches filename stem
title: Andrej Karpathy               # human-readable title
type: entity                         # entity | concept | source | synthesis | moc
aliases: ["karpathy", "@karpathy"]   # alternate names for disambiguation/search
status: stable                       # stub | draft | stable | superseded
sources: ["raw/2026-04-09-foo.md"]   # raw source(s) this page derives from
related: ["[[llm-wiki-pattern]]", "[[memex]]"]  # cross-references (QUOTED in YAML)
topics: ["llm-wiki"]                 # which topic MOC(s) reference this
created: 2026-04-09
updated: 2026-04-09
last_reviewed: 2026-04-09
superseded_by: null                  # populate with "[[newer-page]]" if status: superseded
---
```

**Source pages** add two more fields:

```yaml
source_ref: raw/2026-04-09-foo.md    # the raw file this is a summary of
hash: <sha256>                       # mirrors raw/.manifest.json
```

**Field semantics:**

| Field | Required | Notes |
|---|---|---|
| `id` | yes | kebab-case, unique vault-wide, matches filename without `.md` |
| `title` | yes | Human-readable. Can contain spaces/punctuation. |
| `type` | yes | Single value, no unions |
| `aliases` | no | Empty array `[]` if none |
| `status` | yes | `stub` (placeholder, little content — anchors a `[[wikilink]]` target), `draft` (in progress, expected to change soon), `stable` (complete, sourced, cross-referenced, ready to link to, not expected to change in the next week), `superseded` (replaced by another page — must populate `superseded_by`) |
| `sources` | yes for non-source pages | Array of `raw/...` paths. Source pages omit this. |
| `related` | no | `[[wikilink]]` strings, quoted because YAML otherwise mangles `[[` |
| `topics` | yes | At least one topic; cross-domain pages list multiple |
| `created` | yes | ISO date `YYYY-MM-DD` |
| `updated` | yes | ISO date — bump on every edit |
| `last_reviewed` | yes | ISO date — bump when human-verified |
| `superseded_by` | yes | `null` unless `status: superseded`, then `"[[replacement-page]]"` |
| `source_ref` | source pages only | Path to the raw file |
| `hash` | source pages only | SHA256 of the raw file content |

---

## 7. Naming conventions

- **Files:** `kebab-case.md`. No spaces, no underscores.
- **Entities:** Use the canonical full name. `andrej-karpathy.md`, not `karpathy.md`. Variants go in `aliases`.
- **Raw sources:** Date-prefixed: `YYYY-MM-DD-slug.md`. Slug is a short kebab-case description.
- **Disambiguation:** Two pages with the same canonical name use suffixes: `attention-ml.md`, `attention-cognition.md`. Optionally create a disambiguation page `attention.md` linking to both. (See Worked Example 5.)
- **MOCs:** `wiki/domains/<topic>/<topic>-moc.md` (e.g., `wiki/domains/llm-wiki/llm-wiki-moc.md`). Each MOC's basename must be unique across the vault — NOT just `moc.md` — because Obsidian wikilinks and our verify script resolve on basename. `<topic>-moc.md` guarantees uniqueness once multiple topics exist. Title in frontmatter is `<Topic Name> MOC`.

---

## 8. Session start: read order

When a new session begins, before answering any substantive question, read in this order:

1. **`CLAUDE.md`** (this file) — already loaded
2. **`wiki/index.md`** — the master catalog
3. **`wiki/domains/<topic>/<topic>-moc.md`** — for the topic relevant to the question
4. **Specific pages** — drill into the entities/concepts/sources the question touches
5. **`wiki/log.md`** — only when disambiguation or recent history is needed (e.g., "what did we ingest last week?")

DO NOT skip steps 2 and 3. Skipping the index/MOC means you'll miss existing pages and create duplicates.

---

## 9. Workflow: `ingest`

Process a new raw source into wiki pages.

### Steps

1. **Compute hash**: `shasum -a 256 raw/<filename>` → record the hex digest
2. **Check `raw/.manifest.json`** for that hash:
   - If found with `status: ingested` → **abort**, tell User "already ingested as [page]"
   - If found with `status: deferred` → proceed (and update the entry to `ingested` at the end)
   - If not found → proceed (and add a new entry at the end)
3. **Read the source in full.** For long sources, consider splitting into chapter-level files BEFORE ingesting (naive whole-book ingests produce slop).
4. **Discuss takeaways with User.** What's the source about? What entities does it mention? What concepts? What's worth keeping? Get sign-off before writing.
5. **Decide placement of the source summary**: `wiki/shared/sources/` (default) or `wiki/domains/<topic>/sources/` (single-domain only)
6. **Write the source summary page** with full frontmatter including `source_ref` and `hash`.
7. **Identify affected entities and concepts.** For each:
   - Does an existing page cover this? → **extend** it (bump `updated`, add the new source to `sources:`)
   - Or is this new? → create a new page in `shared/` (default) or `domains/<topic>/` (if confidently single-domain)
8. **Apply the adaptive ripple rule**: target **4–8 page touches** total per source for the first 10 ingests. Scale up to 10–15 only after the wiki has substance to ripple to. Resist the urge to create standalone pages for every concept mentioned — only create a page if the concept is likely to recur, resolves an ambiguity, or will be queried directly.
9. **Update the relevant MOC(s)** — add the new source to "Key sources", new entities to "Entities", new concepts to "Concepts".
10. **Update `wiki/index.md`** — add new pages under the appropriate sections.
11. **Append to `wiki/log.md`**:
    ```markdown
    ## [YYYY-MM-DD] ingest | <source title>

    - Source: [[<source-page>]]
    - Entities created: [[a]], [[b]]
    - Entities extended: [[c]]
    - Concepts created: [[d]]
    - MOCs updated: [[llm-wiki-moc]]
    - Total page touches: N
    ```
12. **Update `raw/.manifest.json`** with `{hash, source_path, status: "ingested", ingested_at, pages_created: [...], pages_updated: [...]}`.
13. **Git commit**: `git commit -am "ingest: <source title>"`

---

## 10. Workflow: `query`

Answer a question against the wiki.

### Steps

1. **Read in order**: `index.md` → relevant `<topic>-moc.md` → specific pages (see §8)
2. **Synthesize an answer with inline citations** to specific wiki pages, e.g., `[[andrej-karpathy]] proposed the LLM wiki pattern in his April 2026 gist [[karpathy-llm-wiki-gist]].`
3. **Decide whether to file as a synthesis page.** The decision can come from User interactively OR from the originating instruction (e.g., "file it" in a subagent or scripted run). When no interactive human is available, apply the **decision rule** below on your own:

   | File? | When |
   |---|---|
   | **Yes, file** | The answer is recurring (likely to come up again), novel (not derivable from a single existing page), synthesizes 2+ pages, or is foundational framing future queries will re-reference |
   | **No, return only** | The answer is generic, one-off, or purely restates a single existing page |

   When in doubt and the answer synthesizes ≥2 sources → file.

4. **If filing, write `wiki/synthesis/<slug>.md`** with full frontmatter (per §6: all required fields including `type: synthesis`). **Include the original question verbatim as a blockquote near the top of the page** — e.g., `> **Question:** <question text>` — so the synthesis is discoverable by the question that spawned it.
5. **Update `wiki/index.md`** — add the new page under the "Synthesis" section
6. **Append to `wiki/log.md`** with the full bullet enumeration (match §9's ingest format style):
    ```markdown
    ## [YYYY-MM-DD] query | <question summary>

    - Filed as: [[<synthesis-page>]]    (or: "not filed — <one-line reason>")
    - Cited: [[a]], [[b]], [[c]]
    - Read trail: [[index]] -> [[<topic>-moc]] -> [[page1]] -> [[page2]] -> ...
    - Decision to file: <yes/no> — <one-line rationale referencing the decision rule>
    - Executed by: <User interactive | fresh subagent validation run | other>
    ```
7. **Git commit** (only if a synthesis was filed): `git commit -am "synthesis: <topic>"`

---

## 11. Workflow: `lint`

Audit the wiki for problems. Run `scripts/verify-v1.sh` first if it exists, then do semantic checks.

### Steps

1. **Run `scripts/verify-v1.sh`** — captures structural issues (missing frontmatter, dead wikilinks, manifest mismatches, log ordering)
2. **Find orphan pages** — pages with zero inbound `[[wikilinks]]` from any other page or MOC
3. **Find supersession candidates** — pages whose `last_reviewed` is much older than the latest source on the same topic, or whose claims contradict newer sources
4. **Find naming collisions** — two pages with overlapping `aliases` or near-duplicate `title`
5. **Find stub-rot** — pages marked `status: stub` for >30 days
6. **Compute the kill-switch metric** (currently moot — only one topic): `% of entities in wiki/shared/entities/ that are linked from 2+ MOCs`. Once topics 2/3 exist, this validates the type-first hybrid placement rule.
7. **Report findings to User.** DO NOT auto-fix anything. Present findings as a list with proposed actions, ask User to approve each.
8. **If User approves fixes**, apply them, then re-run `verify-v1.sh` to confirm
9. **Append to `log.md`**:
    ```markdown
    ## [YYYY-MM-DD] lint | <summary>

    - verify-v1.sh: PASS / FAIL
    - Orphans: N
    - Supersession candidates: N
    - Naming collisions: N
    - Stub-rot: N
    - Kill-switch metric: <X>% (deferred until 2+ topics)
    - Fixes applied: [[a]], [[b]]
    ```
10. **Git commit** if fixes applied: `git commit -am "lint: <summary>"`

---

## 12. Workflow: `triage`

Process items in `inbox/`. Used to convert low-friction captures (clippings, half-formed thoughts) into proper sources OR small wiki extensions OR discards.

### Steps

1. **List all files in `inbox/`** (skip `.gitkeep`)
2. **For each item**, present it to User with three options:
   - **Promote to source** — move file to `raw/`, run the `ingest` workflow on it
   - **Extend an existing page** — small additions inline, no full ingest. The inbox file is then deleted.
   - **Discard** — delete the inbox file
3. **For each "promote" decision**: rename the file to `raw/YYYY-MM-DD-<slug>.md` (date = today, not the file's mtime), then immediately run `ingest`
4. **For each "extend" decision**: identify the target wiki page, append the new info, update `updated` and bump `last_reviewed`, log it
5. **After processing, the inbox should be empty** (only `.gitkeep` remains)
6. **Append to `log.md`**:
    ```markdown
    ## [YYYY-MM-DD] triage | <count> items processed

    - Promoted: [[a]], [[b]]
    - Extended: [[c]]
    - Discarded: 2
    ```
7. **Git commit**: `git commit -am "triage: <count> items"`

---

## 13. Log format

`wiki/log.md` is **append-bottom** (oldest first, newest at the end). Greppable from the shell:

```sh
grep '^## \[' wiki/log.md          # all operations chronologically
grep '^## \[2026-04' wiki/log.md   # operations in April 2026
grep 'ingest |' wiki/log.md         # all ingests
```

Format:

```markdown
## [YYYY-MM-DD] op | title

- bulleted body
- with details about what changed
```

Operations: `init`, `ingest`, `query`, `lint`, `triage`, `migrate` (for renames/merges).

---

## 14. Anti-patterns

Things NOT to do:

- ❌ **Modifying files in `raw/`.** They are immutable. Add wiki pages to correct/contextualize, never edit the source.
- ❌ **Auto-ingesting without discussing takeaways.** Always sync with User first.
- ❌ **Creating duplicate entities** (e.g., `karpathy.md` AND `andrej-karpathy.md`). Check existing entities first; use `aliases` for variants.
- ❌ **Skipping the log.** Every operation gets a log entry.
- ❌ **Forcing 10–15 page touches early.** First 10 ingests should be 4–8. Don't fabricate pages just to hit a number.
- ❌ **Filing everything as a synthesis.** Most query answers are one-offs. Only file recurring or novel syntheses.
- ❌ **Auto-fixing lint findings.** Report → ask → fix. Never silently mutate.
- ❌ **Putting everything in `domains/`.** Default is `shared/`. Only domain-folder things you're certain are single-domain.
- ❌ **Reading the wiki for unrelated coding tasks.** This vault is for `llm-wiki` topic knowledge. If a question is about something else, don't burn tokens reading the wiki.
- ❌ **Editing the placement of an existing page during ingest** without flagging it. If you realize a `shared/` page should be in `domains/`, surface it as a `migrate` operation, don't quietly move it.

---

## 15. Worked examples

The five examples below are the executable spine of this manual. Refer to them when in doubt.

### Example 1 — Full ingest of a hypothetical source

**Scenario:** User drops `raw/2026-04-12-zettelkasten-llm-tools.md` into `raw/`.

**Steps:**

1. Compute hash: `shasum -a 256 raw/2026-04-12-zettelkasten-llm-tools.md` → e.g., `a3f...`
2. Check `raw/.manifest.json` — hash not present, proceed
3. Read the source — it's a blog post about a plugin called `zettelkasten-llm-tools` that adds embedding search to Obsidian
4. Discuss with User: "This source covers (a) the Zettelkasten method, (b) a specific Obsidian plugin, (c) the broader question of LLM-assisted note linking. I think we want a source summary, an entity for the plugin, and a concept for Zettelkasten itself. The Andy Matuschak 'evergreen notes' angle is mentioned but probably not worth a standalone page yet — I'll note it inside the Zettelkasten concept."
5. User says yes. Placement: `shared/sources/` (the topic is broad enough that future cross-domain links are plausible)
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

   ## Summary
   ...
   ## Key claims
   ...
   ## Quotes worth keeping
   ...
   ```
7. Identify affected pages:
   - `zettelkasten` concept — does it exist? No → create
   - `zettelkasten-llm-tools-plugin` entity — does it exist? No → create
   - The `llm-wiki` MOC — needs the new source listed
8. Adaptive ripple budget: this is ingest #1, target 4–8 touches. Plan: source page + 2 new pages + MOC + index + log + manifest = 7. Within budget.
9. Create `wiki/shared/concepts/zettelkasten.md` and `wiki/shared/entities/zettelkasten-llm-tools-plugin.md` with full frontmatter, each citing the new source
10. Update `wiki/domains/llm-wiki/llm-wiki-moc.md`: add the source under "Key sources", entity under "Entities", concept under "Concepts", bump `updated`
11. Update `wiki/index.md`: add the three new pages under their sections
12. Append to `wiki/log.md`:
    ```markdown
    ## [2026-04-12] ingest | Zettelkasten LLM Tools (blog post)

    - Source: [[zettelkasten-llm-tools]]
    - Entities created: [[zettelkasten-llm-tools-plugin]]
    - Concepts created: [[zettelkasten]]
    - MOCs updated: [[llm-wiki-moc]]
    - Total page touches: 7
    ```
13. Update `raw/.manifest.json` — add new entry with `status: ingested`, hash, ingested_at, pages_created/updated arrays
14. `git commit -am "ingest: Zettelkasten LLM Tools (blog post)"`

### Example 2 — Filing a query result as a synthesis

**Scenario:** User asks "What are the failure modes of LLM-maintained wikis?"

**Steps:**

1. Read `index.md` → `wiki/domains/llm-wiki/llm-wiki-moc.md` → drill into `wiki/shared/sources/karpathy-llm-wiki-gist.md`, `wiki/shared/sources/llm-wiki-research-synthesis.md`, and any concept pages on failure modes
2. Synthesize:
   > Five recurring failure modes show up across the literature: error compounding through backlinks (cited in [[hn-discussion-llm-wiki]]), cognitive offloading (the user stops thinking because the LLM is "remembering" — see [[matuschak-evergreen-notes]]), markdown-as-database limits past ~100-300 sources (cited in [[stop-calling-it-memory]]), context window degradation past 200K tokens, and source granularity slop from naive whole-book ingests (cited in [[hn-success-report-chapter-splitting]]).
3. Ask User: "Worth filing as a synthesis page? It pulls together 5 sources and is the kind of question that'll come up again."
4. User says yes. Create `wiki/synthesis/llm-wiki-failure-modes.md`:
   ```yaml
   ---
   id: llm-wiki-failure-modes
   title: "LLM Wiki Failure Modes"
   type: synthesis
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

   ...synthesis body...
   ```
5. Update `wiki/index.md` under "Synthesis"
6. Append to log:
   ```markdown
   ## [2026-04-12] query | what are the failure modes of LLM-maintained wikis?

   - Filed as: [[llm-wiki-failure-modes]]
   - Cited: [[karpathy-llm-wiki-gist]], [[llm-wiki-research-synthesis]], [[error-compounding]], [[cognitive-offloading]]
   ```
7. `git commit -am "synthesis: LLM wiki failure modes"`

### Example 3 — Resolving a contradiction between sources

**Scenario:** A new source claims "the hot.md cache is essential for session continuity," but an existing concept page `hot-cache-pattern` notes that "manual hot.md will rot within a week." These contradict.

**What to do:**

1. **Don't delete or silently overwrite the existing page.** Both views are part of the record.
2. **Flag the contradiction explicitly.** Edit `hot-cache-pattern.md` to add a section:
   ```markdown
   ## Disputed
   The 2026-04-12 source [[xyz-blog-post]] argues hot.md is essential, contradicting [[codex-review-of-llm-wiki-plan]] which argued manual hot.md rots. Both views below.

   - Pro: ...
   - Con: ...
   ```
3. **Bump `updated` and `last_reviewed`** on `hot-cache-pattern.md`
4. **Optionally write a synthesis page** `wiki/synthesis/hot-cache-pattern-debate.md` that addresses both views and (if applicable) presents your current understanding
5. **Mark neither source as superseded** unless one is clearly factually wrong. Disagreement ≠ supersession. Supersession is for "this newer info actually replaces the older claim" (e.g., a fact that turned out to be wrong).
6. **Append to log**:
   ```markdown
   ## [2026-04-12] lint | contradiction flagged

   - Pages updated: [[hot-cache-pattern]] (added Disputed section)
   - Synthesis: [[hot-cache-pattern-debate]]
   - Sources cited on each side: [[xyz-blog-post]], [[codex-review-of-llm-wiki-plan]]
   ```
7. `git commit -am "lint: flag hot.md cache contradiction"`

### Example 4 — Renaming / merging entities

**Scenario:** During lint, you find both `wiki/shared/entities/karpathy.md` and `wiki/shared/entities/andrej-karpathy.md`. They're the same person.

**Steps:**

1. **Pick the canonical name.** Per naming convention: `andrej-karpathy.md` (full name). Keep this one.
2. **Read both files.** Merge any unique content from `karpathy.md` into `andrej-karpathy.md`. Bump `updated` and `last_reviewed`.
3. **Add `karpathy` to the `aliases:` array** of `andrej-karpathy.md` so future searches find it.
4. **Find all backlinks to `[[karpathy]]`** in the vault:
   ```sh
   grep -rn '\[\[karpathy\]\]' wiki/
   grep -rn '\[\[karpathy|' wiki/
   ```
5. **Rewrite each backlink** to `[[andrej-karpathy]]` (or `[[andrej-karpathy|karpathy]]` if the display text matters)
6. **Delete `karpathy.md`** — `rm wiki/shared/entities/karpathy.md`
7. **Update `wiki/index.md`** — remove `karpathy` from the entities list
8. **Append to log:**
   ```markdown
   ## [2026-04-12] migrate | merged karpathy → andrej-karpathy

   - Reason: duplicate entity, same person
   - Canonical: [[andrej-karpathy]]
   - Aliases added: "karpathy"
   - Backlinks updated: 7
   - Deleted: wiki/shared/entities/karpathy.md
   ```
9. `git commit -am "migrate: merge karpathy → andrej-karpathy"`

### Example 5 — Naming collision (disambiguation)

**Scenario:** Two pages both want to be `attention.md`. One is the ML concept (transformer attention mechanism), one is the cognitive concept (focused awareness).

**Steps:**

1. **Don't pick a winner.** Both are valid concepts.
2. **Disambiguate with suffixes:**
   - `wiki/shared/concepts/attention-ml.md` (id: `attention-ml`, title: "Attention (ML)")
   - `wiki/shared/concepts/attention-cognition.md` (id: `attention-cognition`, title: "Attention (cognition)")
3. **Add aliases:**
   - `attention-ml.md`: `aliases: ["attention", "transformer attention", "self-attention"]`
   - `attention-cognition.md`: `aliases: ["attention", "attentional focus"]`
4. **Optionally create a disambiguation page** `wiki/shared/concepts/attention.md`:
   ```yaml
   ---
   id: attention
   title: "Attention (disambiguation)"
   type: concept
   aliases: []
   status: stable
   sources: []
   related: ["[[attention-ml]]", "[[attention-cognition]]"]
   topics: ["llm-wiki"]
   created: 2026-04-12
   updated: 2026-04-12
   last_reviewed: 2026-04-12
   superseded_by: null
   ---

   # Attention (disambiguation)

   "Attention" can mean different things depending on context:

   - **[[attention-ml]]** — the mechanism in transformer neural networks (Vaswani et al. 2017)
   - **[[attention-cognition]]** — the cognitive psychology concept of focused awareness

   Choose the link that matches your intent.
   ```
5. **When ingesting future sources that mention "attention"**, link to the specific disambiguated page, not the disambiguation page itself.
6. **Append to log:**
   ```markdown
   ## [2026-04-12] migrate | disambiguated attention.md

   - Created: [[attention-ml]], [[attention-cognition]], [[attention]] (disambiguation)
   - Aliases set on both
   ```
7. `git commit -am "migrate: disambiguate attention"`

---

## Quick reference card

| Task | Command/Action |
|---|---|
| Hash a source | `shasum -a 256 raw/<file>` |
| Find dead wikilinks | `scripts/verify-v1.sh` |
| Find recent ingests | `grep '^## \[20.*ingest' wiki/log.md \| tail` |
| Find an entity by alias | `grep -rn 'aliases.*<alias>' wiki/` |
| Run lint | `scripts/verify-v1.sh && [discuss findings with User]` |
| New entity location | `wiki/shared/entities/` (default) |
| New concept location | `wiki/shared/concepts/` (default) |
| New source summary location | `wiki/shared/sources/` (default) |
| Filed query answer | `wiki/synthesis/<slug>.md` |
| Topic MOC | `wiki/domains/<topic>/<topic>-moc.md` |

---

## Notes about this vault

- **Single topic for now**: `llm-wiki`. Hybrid `shared/` + `domains/` structure is preserved as future-proofing for topics 2 and 3.
- **Pre-loaded content**: `raw/2026-04-09-llm-wiki-research-synthesis.md` is in the manifest as `status: deferred`. It will be ingested later as a system validation test (a subagent will run the `ingest` workflow against it to verify the system works end-to-end).
- **No `hot.md`**: dropped from v1 because manual maintenance would rot it. May re-add as a derived-from-log file via a hook in a future version.
- **Daily notes deferred**: not in v1. The `inbox/` + `triage` workflow is the closest equivalent for now.
- **Git**: consider pushing to a private GitHub remote periodically as a safety net.
