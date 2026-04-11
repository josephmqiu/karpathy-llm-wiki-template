# Karpathy LLM Wiki Template

A ready-to-use implementation of [Andrej Karpathy's LLM Wiki pattern](https://gist.github.com/karpathy/442a6bf555914893e9891c11519de94f) — where an LLM incrementally builds and maintains a persistent markdown wiki that compounds over time, instead of re-deriving knowledge from raw documents on every query (RAG).

## What this is

You collect sources (articles, papers, notes). You point your LLM at them one at a time. The LLM reads each source, discusses what's worth keeping, then writes and cross-references wiki pages — summaries, entity profiles, concept explanations, synthesis pages. Over time the wiki becomes a compounding knowledge base with backlinks, citations, and structure that no human would maintain by hand.

The LLM is the bookkeeper. You are the thinker.

## What's included

| Component | Purpose |
|---|---|
| [`CLAUDE.md`](CLAUDE.md) | The full schema — rules, workflows, conventions. Claude reads this every session. |
| [`SETUP.md`](SETUP.md) | First-time setup guide — software, Obsidian plugins, getting started steps. |
| `wiki/` | The LLM-maintained knowledge base (index, log, shared content, topic domains, synthesis) |
| `raw/` | Immutable source documents — the LLM reads but never modifies these |
| `inbox/` | Low-friction capture — drop messy notes here, triage later |
| `scripts/verify-v1.sh` | Integrity checker — schema, wikilinks, manifest, naming conventions, and health checks |

The template ships with two pre-ingested example sources (Karpathy's original gist + a community research synthesis) so you can see the pattern in action before adding your own content.

## Four operations

| Operation | What it does |
|---|---|
| **ingest** | Process a raw source into wiki pages. Hash check, read, discuss with you, write pages, update cross-references, commit. |
| **query** | Ask a question against the wiki. The LLM reads the index, drills into relevant pages, synthesizes an answer with citations, states a filing decision, and can file good answers back as synthesis pages. |
| **lint** | Health check — schema drift, orphan pages, naming collisions, stale content, contradictions, and coverage gaps. Reports findings, asks before fixing. |
| **triage** | Process the inbox. Each item gets promoted to a source (then ingested), folded into an existing page, or discarded. |

## Quick start

```sh
git clone https://github.com/josephmqiu/karpathy-llm-wiki-template.git my-wiki
cd my-wiki
claude
```

See [`SETUP.md`](SETUP.md) for full setup instructions including Obsidian plugins and configuration.

---

# User Manual

Plain-English guide to using this vault day to day.

If you want the system rules Claude follows, read [`CLAUDE.md`](CLAUDE.md). This section is the practical version: what goes where, what to ask, and what not to touch.

---

## Start here

If you just opened the vault and want to get oriented:

1. Open [[dashboard]] to see recent activity and summary tables.
2. Open [[llm-wiki-moc|the llm-wiki MOC]] to browse the main topic from the top.
3. Follow a few links: [[llm-wiki-pattern]] -> [[andrej-karpathy]] -> [[karpathy-llm-wiki-gist]].
4. Ask Claude a simple question about the topic.

The goal is not to memorize the structure. The goal is to know the few moves you actually use.

---

## The mental model

This vault has four important pieces:

| Thing | What it is | What you do with it |
|---|---|---|
| `inbox/` | Temporary capture bucket | Drop messy notes, links, or half-formed thoughts here when you're in a hurry |
| `raw/` | Permanent source library | Store source documents here before Claude turns them into wiki knowledge |
| `wiki/` | The actual knowledge base | Read pages here, follow wikilinks, ask questions against it |
| Claude | The bookkeeper | Reads sources, writes and updates wiki pages, keeps the structure coherent |

Short version:

- `inbox/` is for "deal with this later"
- `raw/` is for "keep this source"
- `wiki/` is for "what the vault knows"

Two important rules:

- Files in `raw/` are **not** cleaned up after ingest. They stay there as the source of truth.
- Files in `inbox/` **are** meant to disappear after triage: they get promoted, folded in, or discarded.

---

## Starting Claude

Start Claude from the vault root:

```sh
cd /path/to/LLM-Wiki
claude
```

If the vault moves later, only the `cd` path changes. The important part is that you start in the folder containing `CLAUDE.md`, `raw/`, `wiki/`, and `scripts/`.

Once Claude is open, just talk to it directly:

```text
ingest raw/2026-04-15-your-file.md
triage my inbox
what does the wiki say about the criticisms of the LLM Wiki pattern?
run lint
the memex page gets one point backwards - fix it
```

You do not need to remind Claude how the vault works. That behavior lives in `CLAUDE.md`.

---

## The three things you'll do most

### 1. Save something

If you already know it is a real source you want to keep, put it in `raw/`.

Examples:

- Clip a web article into `raw/`
- Paste notes into `raw/YYYY-MM-DD-slug.md`
- Convert a PDF to text and save it in `raw/`

If you are moving too fast to decide what it is, drop it in `inbox/` and move on.

Rule of thumb:

- Use `raw/` when the item is a source
- Use `inbox/` when the item is just a capture

### 2. Ingest a source

When a file is in `raw/`, ask Claude to ingest it:

```text
ingest raw/2026-04-15-your-file.md
```

Claude will:

1. Check whether that source was already ingested
2. Read it in full
3. Come back with a proposed summary and a proposed set of page updates
4. Wait for your approval before writing
5. Write or update the wiki pages if you approve

This discussion step matters. If Claude proposes too many new pages, says the wrong thing is important, or misses the real point, push back before it writes.

After ingest:

- the file stays in `raw/`
- the manifest records that it was ingested
- the wiki gets updated
- the source summary usually appears in `wiki/shared/sources/`
- in some cases it may go in `wiki/domains/<topic>/sources/` if that source is intentionally topic-specific

### 3. Ask questions

You can ask Claude questions against the wiki in plain English:

```text
what are the main criticisms of the LLM Wiki pattern?
how does the bookkeeping thesis connect to Memex?
compare what the sources say about RAG versus the compiled-wiki approach
```

Claude reads the index, the relevant MOC, and the relevant pages, then answers from the wiki.

This is implicitly the `query` workflow. Every domain question that benefits from existing wiki pages should be answered this way, and every query should get logged in `wiki/log.md`.

After answering, Claude should state a filing decision. Say yes to saving as a synthesis page if:

- you expect to want that answer again
- it combines multiple pages or sources
- it creates a framing you would want Future You to find quickly

Say no if it is just a one-off answer.

If Claude already answered and you decide you want it saved, say:

```text
save that
```

That should file the immediately preceding answer as a synthesis without re-deriving it.

---

## Common tasks

### I found something interesting but do not want to deal with it right now

Put it in `inbox/`.

Example:

```sh
pbpaste > inbox/$(date +%Y-%m-%d)-whatever.md
```

No naming convention matters in `inbox/`. It is the junk drawer on purpose.

Later, ask:

```text
triage my inbox
```

### I want to clean up the inbox

`Triage` means Claude walks through each inbox item and asks what to do with it.

Each item becomes one of three things:

- **Promote**: move it to `raw/`, rename it properly, then ingest it
- **Extend**: fold the useful part into an existing wiki page, then delete the inbox file
- **Discard**: delete it

After triage, `inbox/` should be empty except for `.gitkeep`.

### I want to save a real source directly

Skip `inbox/` and put it straight into `raw/`.

Good candidates:

- articles
- papers
- transcripts
- your own substantial notes or essays

Once it is in `raw/`, ingest it.

### I want to fix something that looks wrong

Tell Claude plainly what is wrong.

Examples:

```text
the summary on the source page misses the main point - rewrite it
the rag page overstates one claim - fix that section
add "Karpathy" as an alias on the Andrej Karpathy page
```

Claude should update the relevant wiki page instead of you having to hunt through backlinks manually.

### I want to check whether the vault is healthy

Use either of these:

```sh
scripts/verify-v1.sh
```

or:

```text
run lint
```

`verify-v1.sh` is the structural checker. It checks the folder shape, frontmatter, schema rules, wikilinks, manifest reconciliation, log consistency, naming, the kill-switch metric, and deterministic health checks like orphans, stub-rot, stale review dates, alias collisions, and query/synthesis health.

`lint` is the broader Claude workflow. It runs the verifier and then looks for semantic issues like contradictions, concept gaps, missing cross-references, supersession candidates, and source coverage gaps. Claude should report findings and ask before fixing anything.

Current expected verifier result in this vault:

- 14 passed
- 1 warning
- 0 failed

The warning is expected right now because there is only one topic MOC.

---

## What you can ask Claude to do

### The four workflows

| Command | What it does |
|---|---|
| **ingest** | Process a raw source into wiki pages. Hash check → read → discuss → write pages → update MOC/index/log/manifest → commit. |
| **query** | Ask a question against the wiki. Reads index → MOC → pages → synthesizes an answer with citations, states a filing decision, logs the query, and can file the answer as a `wiki/synthesis/` page. |
| **lint** | Health check. Runs `verify-v1.sh` + semantic checks (contradictions, concept gaps, missing cross-references, coverage gaps, supersession). Reports findings, asks before fixing. |
| **triage** | Process `inbox/` items. For each: promote to source (→ ingest), extend an existing page, or discard. |

### Structural operations

| Command | What it does |
|---|---|
| **merge** | Combine two duplicate pages into one canonical page. Rewrites backlinks, updates aliases. |
| **rename** | Rename a page. Updates all backlinks vault-wide. |
| **disambiguate** | Split one page into two (e.g., `attention.md` → `attention-ml.md` + `attention-cognition.md`). |
| **fix / correct** | Edit a specific claim or typo in a page. Bumps `updated`, re-verifies. |

You can also just ask things in plain English — *"what does the wiki say about X?"*, *"compare sources A and B"*, *"show me all stub pages"*, *"undo the last ingest"*. For domain questions, that is still the `query` workflow even if you do not use the word "query."

---

## What the main words mean

You do not need the jargon to use the system, but these terms come up a lot:

- **MOC**: "Map of Content." A topic hub page. In this vault the main one is [[llm-wiki-moc]].
- **Ingest**: Turn one raw source into maintained wiki knowledge.
- **Triage**: Process the inbox and decide what each item should become.
- **Synthesis**: A saved answer that combines multiple pages into one reusable explanation.
- **Lint**: Audit the wiki for structural and semantic drift.
- **Manifest**: `raw/.manifest.json`, the record of which raw sources have been ingested.

---

## What you can edit directly

Safe to edit yourself:

- files in `inbox/`
- wording in `wiki/meta/` docs like this one
- small typo fixes in wiki pages, if you really want to do them by hand

Things to be careful with:

- `raw/.manifest.json`
- broad structural changes like renames, merges, or moving pages

Do not edit directly:

- files in `raw/` after they are stored there
- `CLAUDE.md` casually

Why:

- `raw/` is the source-of-truth layer
- `CLAUDE.md` changes system behavior for every future session

When in doubt, ask Claude to make the change.

---

## Troubleshooting

### "I do not understand where something should go"

Use this rule:

- if it is a source, put it in `raw/`
- if it is a maybe-source or a messy capture, put it in `inbox/`
- if it is a knowledge page Claude wrote, it belongs in `wiki/`

### "I ingested something and now I cannot find it"

Look in one of these places:

- `wiki/shared/sources/` for the source summary
- `wiki/domains/<topic>/sources/` if it was intentionally topic-specific
- `wiki/log.md` for the operation log
- `wiki/index.md` for the catalog

### "Claude seems to not know something that should be in the wiki"

Usually one of two things happened:

- the wiki does not actually contain that knowledge yet
- the relevant page exists but is not well linked from the MOC or index

Run `scripts/verify-v1.sh` or ask Claude to run lint.

### "verify-v1.sh failed"

Read the output. It usually points to the exact problem.

Common examples:

- dead wikilink
- missing or malformed frontmatter
- manifest mismatch
- log ordering problem

If you do not want to fix it manually, paste the output to Claude and ask it to fix the issue.

### "I opened Obsidian and things look inconsistent"

If the vault is in iCloud, wait for sync to settle before opening Obsidian on another machine. The dangerous case is editing the same git-backed vault on two devices while sync is still in flight.

If there is a git problem, inspect first:

```sh
git status
git log --oneline | head -5
```

Avoid blanket discard commands unless you are certain you want to lose local changes.

### "I want to undo the last bad operation"

First inspect:

```sh
git log --oneline | head -5
```

If the bad operation is the most recent commit and you are sure you want to throw it away entirely, then:

```sh
git reset --hard HEAD~1
```

That is destructive. Do not use it casually.

If the situation is more complicated than "the last commit was bad," stop and inspect before doing anything more aggressive.

---

## Quick reference

| I want to... | Do this |
|---|---|
| Save a source | Put it in `raw/`, then ingest it |
| Save something for later | Drop it in `inbox/` |
| Clean up captures | `triage my inbox` |
| Ask the wiki a question | Ask Claude in plain English |
| Save a good answer as a page | Tell Claude to file it as a synthesis |
| Check vault health | Run `scripts/verify-v1.sh` or ask Claude to run lint |
| Fix a wrong claim or typo | Tell Claude exactly what is wrong |
| Undo the latest bad commit | Inspect first, then `git reset --hard HEAD~1` only if you really mean it |

---

## Good cadence

You do not need a rigid process, but this is a sane default:

- ingest one source at a time
- triage the inbox at least weekly
- run lint every 5 ingests or when the last lint is older than 14 days
- use the graph and dashboard occasionally to stay oriented

This system gets better from steady use, not from heroic cleanup sessions.

---

## Good pages to know

- [[dashboard]]: the easiest high-level status view
- [[llm-wiki-moc]]: the main topic hub
- [[karpathy-llm-wiki-gist]]: the source that kicked off this vault
- [[llm-wiki-research-synthesis]]: community survey of LLM wiki implementations

---

## Advanced maintenance

You will not use these every day, but they are the main structural operations once the wiki gets bigger.

### Rename a page

Use this when the page exists but the name is wrong or too vague.

Example:

```text
rename the "rag" concept to "retrieval-augmented-generation"
```

Claude should update the page name, fix backlinks, update the index, and log the migration.

### Merge duplicates

Use this when two pages are really the same thing and should become one canonical page.

Example:

```text
merge karpathy.md into andrej-karpathy.md
```

This should be treated as a visible cleanup operation, not a silent merge.

### Disambiguate a collision

Use this when one title is trying to mean two different things.

Example:

```text
disambiguate attention.md into attention-ml and attention-cognition
```

This is better than letting one overloaded page slowly become confusing.

### Ask for structural cleanup

If the wiki starts feeling messy, you do not need to know the exact fix up front. You can just describe the problem.

Examples:

```text
these two concept pages feel redundant - should we merge them?
this page title is overloaded - split it cleanly
find orphan pages
show me stub pages
```

Claude should inspect the structure, explain the likely fix, and then make the changes deliberately instead of improvising blindly.

### Treat these as maintenance, not routine writing

Renames, merges, disambiguations, and larger reorganizations are higher-risk than normal page edits because they affect backlinks, index entries, and the shape of the graph.

That does not mean avoid them. It means do them deliberately.

---

*Last updated: 2026-04-09*
