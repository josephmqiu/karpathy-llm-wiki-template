---
id: lint
name: lint
title: "Lint: audit the wiki for structural and semantic problems"
version: 1
status: stable
log_op: lint
inputs: []
related_skills: [ingest, query, migrate]
created: 2026-04-13
updated: 2026-04-13
---

# Lint

## Purpose

Audit the wiki for problems. Lint has two tiers: a deterministic structural tier run by `scripts/verify-v1.sh`, and a semantic tier run by the model applying judgment to page content. The structural tier finds schema violations, dead links, log inconsistencies, and naming collisions mechanically. The semantic tier finds contradictions, concept gaps, missing cross-references, coverage gaps, and supersession candidates — things only a reader can see.

Lint **never auto-fixes**. It reports findings, User reviews, User approves, then the skill applies fixes. This is CLAUDE.md §4 rule 11.

## When to invoke

- **Cadence:** after every 5th ingest since the last lint, run a full health check.
- **Session preflight:** at session start, if the last `lint |` entry in `wiki/log.md` is more than 14 days old. This is the §8 preflight.
- **Explicit:** User says `lint`, `health check`, `run lint`, or similar.
- **Implicit:** after a large migration, batch of ingests, or structural change where drift is plausible.

At current scale, a full lint is cheap. Do not skip it just to save time.

## Inputs

None. Lint operates on the entire wiki.

## Preconditions

- `scripts/verify-v1.sh` exists and is executable.
- `wiki/index.md`, `wiki/log.md`, and `raw/.manifest.json` are readable.
- User is available interactively to review findings and approve fixes. Semantic lint without User just produces a report.

## Steps

### Tier 1: Structural (scripted)

1. **Run `scripts/verify-v1.sh`** — folder structure, frontmatter/schema (including the `question:` field on synthesis pages), dead wikilinks, manifest reconciliation, log reconciliation, log ordering, naming conventions, kill-switch metric, and the deterministic health checks (orphans, stub-rot, stale review dates, alias/title collisions, query/synthesis health). If verify-v1.sh fails, structural problems must be addressed before semantic lint begins — an inconsistent structural base will poison semantic findings.

### Tier 2: Semantic (LLM-powered)

Read wiki pages and apply judgment. Report findings; **never auto-fix**.

2. **Contradiction detection.** Scan pages that share sources or have direct backlink relationships for claims that conflict. Use shared `sources:` entries or mutual `[[wikilinks]]` as the first-pass scope. `topics:` alone is too broad — too many false positives on unrelated pages that happen to share a domain tag.
3. **Concept gaps.** Find meaningful named concepts, techniques, people, or tools that appear repeatedly across pages but have no page or alias of their own. Candidates for a stub or a full new page on the next ingest.
4. **Missing cross-references.** Find page pairs that are probably related but disconnected in the graph. Exclude broad survey sources when using shared-source overlap as evidence — surveys cite everything.
5. **Source coverage gaps.** Inspect MOC open questions and suggest concrete searches for questions with weak source coverage. A question with zero supporting sources is a hole in the wiki, not a knowledge claim.
6. **Supersession candidates.** Judge whether newer source-backed content actually supersedes older claims, not just whether the dates are old. An old page that's still correct is not a supersession candidate. Disagreement ≠ supersession (see Example below).

### Reporting and fixes

7. **Report findings to User** as one structured report. Group by tier and severity. **Do NOT auto-fix anything.**
8. **If User approves fixes**, apply them, then re-run `verify-v1.sh` to confirm the fixes didn't introduce new structural problems.

### Logging

9. **Append to `wiki/log.md`** using the [Log entry format](#log-entry-format) below.
10. **Git commit** if fixes were applied, using the [Git commit format](#git-commit-format) below. Stage only the intended files.

## Log entry format

```markdown
## [YYYY-MM-DD] lint | <summary>

- verify-v1.sh: PASS / FAIL
- Orphans: N (structural)
- Stub-rot: N (structural)
- Stale pages: N (structural)
- Alias collisions: N (structural)
- Contradictions: N (semantic)
- Concept gaps: N (semantic)
- Missing cross-refs: N (semantic)
- Coverage gaps: N (informational)
- Supersession candidates: N (semantic)
- Kill-switch metric: <X>%
- Fixes applied: [[a]], [[b]]  (or: "none — clean")
```

## Git commit format

```
lint: <summary>
```

Only if fixes were applied. A lint run with zero findings or findings-but-no-approved-fixes logs only, no commit.

## Anti-patterns

- **Auto-fixing lint findings.** Report → ask → fix. Never silently mutate the wiki. This is CLAUDE.md §4 rule 11.
- **Skipping Tier 1 before Tier 2.** A wiki with structural issues poisons semantic lint (e.g., dead wikilinks pollute the "missing cross-refs" check). Run verify-v1.sh first.
- **Using `topics:` alone as the contradiction scope.** Too broad — surfaces unrelated pages that happen to share a domain tag. Use shared `sources:` or mutual backlinks.
- **Marking a page as superseded just because it's old.** Age ≠ wrong. Supersession requires that new info actually replaces the old claim. Old-and-still-correct is fine; old-and-contradicted is a `## Disputed` section, not a supersession (see Example below).
- **Silently merging contradictions.** If two sources disagree, flag both, don't pick a side. The wiki's job is to preserve the record, not resolve every debate.
- **`git commit -am` in a dirty worktree.** Stage specific files. Lint often touches multiple pages; auto-committing everything bundles unrelated changes.
- **Treating "coverage gaps" as failures.** Coverage gaps are informational — they tell you what to ingest next, not what's broken.

## Worked example

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
3. **Bump `updated` and `last_reviewed`** on `hot-cache-pattern.md`.
4. **Optionally write a synthesis page** `wiki/synthesis/hot-cache-pattern-debate.md` that addresses both views and, if applicable, presents the current working understanding. Include the `question:` field (the question that prompted it).
5. **Mark neither source as superseded** unless one is clearly factually wrong. Disagreement ≠ supersession. Supersession is for "this newer info actually replaces the older claim" (e.g., a fact that turned out to be wrong).
6. **Append to `wiki/log.md`**:
   ```markdown
   ## [2026-04-12] lint | contradiction flagged

   - Pages updated: [[hot-cache-pattern]] (added Disputed section)
   - Synthesis: [[hot-cache-pattern-debate]]
   - Sources cited on each side: [[xyz-blog-post]], [[codex-review-of-llm-wiki-plan]]
   ```
7. Stage specific files and commit:
   ```
   git add wiki/shared/concepts/hot-cache-pattern.md wiki/synthesis/hot-cache-pattern-debate.md wiki/log.md
   git commit -m "lint: flag hot.md cache contradiction"
   ```

The key move: disagreement between two sources is a `## Disputed` section on the affected page (plus an optional synthesis), not a silent merge or a supersession. Preserve the record.

## Related skills

- **[ingest](../ingest/SKILL.md)** — upstream. Every 5 ingests triggers a lint. Ingest writes the log entries lint reads to compute cadence.
- **[query](../query/SKILL.md)** — peer. Lint's Tier 2 semantic checks often surface "this question has no sources" gaps that `query` can answer by re-reading, or that `ingest` can fix with a new source.
- **[migrate](../migrate/SKILL.md)** — downstream. Lint findings like "duplicate entity" or "alias collision" hand off to migrate for the actual rename/merge.
- **CLAUDE.md §8 (session-start preflight)** — upstream. The preflight checks the last lint date and ingests-since-last-lint and prompts to run this skill when either threshold fires.
