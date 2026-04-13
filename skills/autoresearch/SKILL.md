---
id: autoresearch
name: autoresearch
title: "Autoresearch: iterative web research loop with human approval before filing"
version: 1
status: draft
log_op: research
inputs:
  - name: topic
    required: true
    description: "The research topic or question, passed by User in the trigger phrase"
  - name: scope_hint
    required: false
    description: "Optional scope constraints from User (preferred angles, known sources, depth)"
related_skills: [ingest, query, lint, migrate]
created: 2026-04-13
updated: 2026-04-13
---

# Autoresearch

## Purpose

Run an iterative web research loop on a topic, capture every fetched source into the `raw/` staging layer with hash-based dedupe, present the captured bundle to User for approval, and — on approval — file the wiki pages by handing each raw file off to the normal `ingest` pipeline plus one direct synthesis page. Autoresearch is the mechanism for *growing* the wiki from the outside world instead of waiting for User to drop files into `raw/`.

Three non-negotiable design constraints shape this skill:

1. **Human checkpoint between research and filing.** The loop runs autonomously, but one explicit approval gate sits between "research complete" and "wiki pages written." This preserves CLAUDE.md §4 rule 9 ("discuss takeaways with User before writing pages") without forcing User to babysit every round.
2. **Raw/ staging via normal ingest.** Every fetched URL lands in `raw/YYYY-MM-DD-autoresearch-<slug>-<n>.md` and is filed via the `ingest` skill, not written directly to `wiki/`. All hard rules (immutable raw, hash dedupe via `raw/.manifest.json`, atomic ingest commit) apply unchanged.
3. **Soft topic scoping.** Claude proposes which existing domain(s) (CLAUDE.md §1) the research maps to before running any searches. If no existing domain fits, Claude asks User whether to declare a new domain *before* the loop runs — never mid-loop, never post-hoc.

## When to invoke

- **Explicit:** User says `/autoresearch`, `autoresearch X`, `research X`, `deep dive into X`, `investigate X`, `find everything about X`, `go research X`, or `build a wiki on X`. Triggers are eager — if any of these phrases appear with a topic, load this skill.
- **Implicit:** never. Autoresearch is always user-initiated. It does not offer itself from inside `query` or `ingest`.
- **Never:** without reading `references/program.md` first; without completing the checkpoint approval; as a substitute for targeted `query` when the wiki likely already has the answer.

## Inputs

- **`topic`** (required) — the research topic, extracted from the trigger phrase. Keep it as User wrote it; that preserves intent.
- **`scope_hint`** (optional) — any constraints User offered alongside the trigger (e.g., "only arXiv sources", "focus on 2024 papers", "skip the business angle").

## Preconditions

- `skills/autoresearch/references/program.md` exists and is readable. Load it in full before decomposing the topic.
- `raw/.manifest.json` is readable and writable.
- WebSearch and WebFetch are available in the current harness. If either is unavailable, abort and tell User — autoresearch cannot run without them.
- User is available interactively for the checkpoint in step 6. If no human is available, abort.
- Placement rule (CLAUDE.md §5) and hard rules (CLAUDE.md §4) apply to all pages created downstream. Re-read them if uncertain.

## Steps

### Phase A — Plan (before any searches)

1. **Load the program.** Read `skills/autoresearch/references/program.md` in full. It defines source prefs, caps (rounds, pages, sources per round), the confidence rubric, domain notes, and exclusions. The caps are hard — do not exceed them.

2. **Propose domain fit.** Map the topic to existing domains declared in CLAUDE.md §1. Present to User:

   ```
   Topic: <topic>
   Proposed domain(s): <list>  (or: none of the existing domains fit)
   Reasoning: <one sentence>
   ```

   If the topic fits ≥1 existing domain → proceed. If *no* existing domain fits → ask User whether to declare a new domain or refuse the research. Do not proceed until User answers.

3. **Propose search angles.** Decompose the topic into 3–5 distinct search angles. State each angle in one line plus the 2–3 WebSearch queries you plan to run for it. Include any `scope_hint` constraints. Present to User. User may trim, add, or approve as-is. Wait for approval before running any searches. This is a planning step, not a free-for-all — it sets the scope of the loop.

### Phase B — Research loop (caps from `program.md`)

4. **Round 1 — broad search.**
   - For each approved angle: run 2–3 WebSearch queries.
   - For the top 2–3 results per angle: run WebFetch and capture the cleaned content.
   - For each fetched URL:
     - Compute a filename: `raw/YYYY-MM-DD-autoresearch-<topic-slug>-<n>.md` (n is a monotonic counter across the session, not per angle).
     - Write the file with a header block:
       ```markdown
       <!-- source_url: <url> -->
       <!-- fetched_at: <ISO timestamp> -->
       <!-- autoresearch_topic: <topic> -->
       <!-- round: 1 -->
       ```
       followed by the cleaned WebFetch output.
     - Compute SHA256 (`shasum -a 256 raw/<filename>`).
     - Check `raw/.manifest.json`:
       - If hash already present with `status: ingested` → delete the new raw file (it's a dupe) and cite the existing source page in the synthesis.
       - If hash not present → add a new manifest entry with `status: deferred`, `captured_via: autoresearch`, the topic slug, and the round number.
   - Extract key claims, entities, concepts, and open questions into a scratch buffer (in-memory, not filed yet).

5. **Round 2 — gap fill.** Identify what Round 1 missed or contradicted. Run up to 5 targeted searches, fetch the top result for each, repeat the raw-capture procedure (step 4's raw-file substeps) with `round: 2` in the header. Stop when gaps are addressed *or* when page cap is reached.

6. **Round 3 — optional synthesis pass.** Only if major contradictions or load-bearing gaps remain. One more targeted pass, same raw-capture procedure with `round: 3`. Do not run Round 3 just to fill time.

   **Loop termination.** Stop when any of:
   - All planned angles are addressed and no major gaps remain.
   - `max_rounds` (default 3 from `program.md`) is reached.
   - `max_pages` (default 15) is reached across raw captures. Document what was skipped in the checkpoint report.
   - `max_sources_per_round` (default 5) would be exceeded. Stop the current round and move on.

### Phase C — Checkpoint (mandatory human approval)

7. **Present the bundle.** After the loop exits, do NOT write any wiki pages yet. Produce a checkpoint report for User containing:

   ```
   Autoresearch checkpoint: <topic>

   Rounds run: N/3
   Sources captured (raw/): N
   Dedupe hits (already in manifest): N

   Raw files created:
     - raw/YYYY-MM-DD-autoresearch-<slug>-1.md  (url: ..., round: 1)
     - raw/YYYY-MM-DD-autoresearch-<slug>-2.md  (url: ..., round: 1)
     - ...

   Proposed wiki output:
     - source summaries (N pages, via ingest):
       - [[candidate-source-1]]
       - ...
     - concept pages (create: N, extend: N):
       - create [[candidate-concept-1]]
       - extend [[existing-concept-x]] with a new section
       - ...
     - entity pages (create: N, extend: N):
       - create [[candidate-entity-1]]
       - ...
     - synthesis page:
       - wiki/synthesis/research-<slug>.md

   Total projected page touches: N
     (adaptive ripple budget from CLAUDE.md §4 rule 10)

   Key findings (from scratch buffer):
     - [finding] (support: [[candidate-source-1]], [[candidate-source-2]])
     - ...

   Contradictions:
     - <source A> says X; <source B> says Y. Note on which is more credible and why.
     - (or: none)

   Open questions still unanswered:
     - ...
   ```

8. **Wait for User's decision.** User picks one of:
   - **Approve all.** Proceed to Phase D filing.
   - **Approve with edits.** User trims the proposed page list. Revise and re-present, or proceed if edits are clear.
   - **Reject / rework.** User asks for another round, different angles, or cancels. Honor the request. If canceled: leave the raw files in place as `status: deferred` in the manifest (User can ingest them later manually or promote them via `triage`), log the run as `research | <topic> (canceled)`, and stop.

   Do not proceed to filing without an explicit approve. Silence is not approval.

### Phase D — Filing (only after approval)

9. **Hand off each raw file to ingest.** For each approved raw file:
   - Follow `skills/ingest/SKILL.md` steps 1–13 as if User had dropped the file manually.
   - The takeaways discussion in ingest step 4 is *already* covered by the checkpoint — state this explicitly in the ingest log entry for each file and proceed to step 5 without a second approval.
   - Each ingest is its own atomic commit with message `ingest: <source title>`. This means autoresearch produces N+1 commits on a typical run (N ingest commits + one research commit).

10. **Write the synthesis page directly.** Create `wiki/synthesis/research-<topic-slug>.md`:

    ```yaml
    ---
    id: research-<topic-slug>
    title: "Research: <Topic>"
    type: synthesis
    aliases: []
    status: draft
    question: "<the topic, phrased as the question that triggered the research>"
    sources: ["raw/...autoresearch...1.md", "raw/...autoresearch...2.md", ...]
    related: ["[[candidate-source-1]]", "[[candidate-concept-1]]", ...]
    topics: [<proposed-domain(s) from step 2>]
    created: YYYY-MM-DD
    updated: YYYY-MM-DD
    last_reviewed: YYYY-MM-DD
    superseded_by: null
    ---

    # Research: <Topic>

    ## Overview [coverage: high|medium|low]
    Two to three sentences stating what the research found. Apply provenance labels per CLAUDE.md §6A.

    ## Key findings [coverage: ...]
    - Finding 1 [extracted]. (Source: [[source-page]])
    - Finding 2 [inferred]. (Synthesizes: [[source-a]] + [[source-b]])
    - ...

    ## Entities [coverage: ...]
    - [[entity-name]] — role / significance in one line

    ## Concepts [coverage: ...]
    - [[concept-name]] — one-line definition

    ## Contradictions [coverage: ...]
    > [!warning] Conflicting claims
    > [[source-a]] says X [extracted]. [[source-b]] says Y [extracted]. [brief note on credibility]

    ## Open questions [coverage: low]
    > [!gap] Unverified claim
    > Claim that still needs a primary source.

    - Question the loop didn't fully resolve
    - Gap that would need more sources

    ## Sources
    - [[source-1]] — author, date, domain
    - [[source-2]] — ...
    ```

    The synthesis page starts as `status: draft`. User flips it to `stable` after reviewing.

11. **Update `wiki/index.md`** with all new pages under their appropriate sections.

12. **Append one `research` log entry** using the [Log entry format](#log-entry-format) below. The per-ingest log entries land automatically from each ingest hand-off — the `research` entry is the summary over all of them.

13. **Git commit the synthesis + log + index** as the final `research:` commit. The ingest commits from step 9 are already on the branch.

## Log entry format

Appended to the **bottom** of `wiki/log.md` (never the top — CLAUDE.md §10).

```markdown
## [YYYY-MM-DD] research | <topic>

- Trigger: "<exact trigger phrase User used>"
- Domain(s): <list>
- Rounds: N/3 | Sources captured: N | Dedupe hits: N | Pages touched: N
- Raw files:
  - raw/YYYY-MM-DD-autoresearch-<slug>-1.md
  - raw/YYYY-MM-DD-autoresearch-<slug>-2.md
  - ...
- Ingest commits: <list of commit short-hashes or source titles>
- Synthesis: [[research-<slug>]]
- Status: approved | canceled | partial
- Key findings (one-liners):
  - ...
- Open questions: N filed in synthesis
- Executed by: User interactive + autoresearch
```

Omit empty bullets (don't write `Dedupe hits: 0` if there were none).

## Git commit format

Autoresearch produces multiple commits per run:

1. **N `ingest:` commits** — one per raw file handed off in Phase D step 9. Normal ingest commit format (`ingest: <source title>`).
2. **One `research:` commit** at the end — contains the synthesis page, the `wiki/log.md` `research` entry, and the `wiki/index.md` update. Message: `research: <topic>`.

If the run is canceled at the checkpoint: zero commits. The raw files remain on disk with `status: deferred` in the manifest but are never committed. If User wants to keep them on the branch for later triage, he can commit them manually.

## Anti-patterns

- **Skipping the checkpoint.** The Phase C approval gate is the entire reason this skill exists in its current form. Never file a wiki page before User approves the bundle.
- **Writing directly to `wiki/sources/`, `wiki/concepts/`, or `wiki/entities/` during the loop.** All source content flows through `raw/` → `ingest`. The only direct wiki write is the synthesis page in Phase D step 10.
- **Running a loop without reading `references/program.md`.** The caps and source rules are the whole safety mechanism. Reading them is not optional.
- **Exceeding caps to "finish the job".** If the page cap is hit mid-loop, stop and note what was skipped in the checkpoint report's "Open questions" section. Do not file 20 pages when the cap is 15.
- **Auto-declaring a new domain.** If no existing domain fits, ask User in Phase A step 2 before running any searches. Do not write `topics: ["new-topic-i-invented"]` on a page without explicit approval.
- **Treating the scratch buffer as authoritative.** The scratch buffer (extracted claims between rounds) is in-memory scratchwork. Every claim that ends up in a wiki page must be re-derived from a raw file with a citation. No "I remember reading" claims.
- **Proactive offering from `query` or `ingest`.** Autoresearch is user-initiated only. Do not surface "want me to research this gap?" from other skills. (User considered this design and rejected it.)
- **Committing raw files before the checkpoint.** Raw files written during the loop live on disk but are not committed until their ingest hand-off in Phase D. If the run is canceled, they stay uncommitted.
- **Filing the synthesis as `stable`.** Always `draft`. User flips to stable after review.
- **Inventing a parallel confidence system on page bodies.** This vault uses provenance labels (`[extracted]`/`[inferred]`/`[ambiguous]`/`[disputed]`) and section-level `[coverage: ...]` per CLAUDE.md §6A. Do not introduce `high|medium|low` confidence annotations as a separate axis — map any such signal onto `[coverage: ...]`.
- **Writing to `wiki/hot.md`.** This vault does not have a `hot.md` (see CLAUDE.md notes section). Do not create one.

## Worked example

**Scenario:** User says: `research the failure modes of LLM-maintained wikis`.

**Phase A — Plan:**

1. Load `references/program.md`. Caps: 3 rounds, 15 pages, 5 sources/round. Source prefs: named-author blog posts, primary gists, reference implementations.
2. Domain fit: `llm-wiki` (primary — the seed topic of this template). Present to User. User confirms.
3. Angles (4): (a) Karpathy's original pattern + critiques, (b) community reference implementations and post-mortems, (c) known failure modes (cognitive offloading, markdown-as-database limits, context rot), (d) how maintenance rituals compare across projects. 2 queries per angle. User approves.

**Phase B — Loop:**

4. Round 1: 8 WebSearches across 4 angles, 10 WebFetches. 10 raw files captured as `raw/2026-04-13-autoresearch-llm-wiki-failure-modes-1.md` through `-10.md`.
5. Round 2: gap — no coverage of long-term maintenance data. 3 targeted searches, 3 fetches, 3 more raw files. Page count: 13/15.
6. Round 3: skipped. No major contradictions or gaps.

**Phase C — Checkpoint:**

7. Present bundle: 13 raw files, proposed 6 source pages (some similar Round 1 results merge under one), create 3 concepts, extend 1 existing concept, create 2 entities, write 1 synthesis page `research-llm-wiki-failure-modes.md`. Total touches: 13.
8. User approves, asks to drop two low-quality sources. Revised: 11 ingest hand-offs + 1 synthesis.

**Phase D — Filing:**

9. 11 `ingest:` commits, one per raw file, via normal ingest pipeline. Each notes "takeaways already covered by autoresearch checkpoint 2026-04-13" in its log entry.
10. Write `wiki/synthesis/research-llm-wiki-failure-modes.md` as `status: draft`, `topics: ["llm-wiki"]`.
11. Update `wiki/index.md`.
12. Append one `research | failure modes of LLM-maintained wikis` entry to `wiki/log.md`.
13. Final `research: llm-wiki failure modes` commit.

## Related skills

- **[ingest](../ingest/SKILL.md)** — downstream. Every raw file captured by autoresearch is filed via the normal ingest pipeline, producing N atomic commits.
- **[query](../query/SKILL.md)** — adjacent. Use `query` first when the wiki likely has the answer. Use `autoresearch` when it doesn't and you want to go find it.
- **[lint](../lint/SKILL.md)** — downstream. An autoresearch run that produces 12+ pages will likely cross the 5-ingest threshold and trigger a lint cycle.
- **[migrate](../migrate/SKILL.md)** — peer. If the checkpoint surfaces a duplicate entity or a placement Claude wants to change on an existing page, hand off to migrate rather than silently fixing it during filing.
- **[triage](../triage/SKILL.md)** — alternative on cancellation. If User cancels autoresearch but wants to keep the captured raw files, he can promote them later via the normal inbox/triage path; the manifest entries are already set to `deferred`.
