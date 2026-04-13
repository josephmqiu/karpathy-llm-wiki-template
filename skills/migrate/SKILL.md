---
id: migrate
name: migrate
title: "Migrate: rename, merge, or disambiguate wiki pages"
version: 1
status: stable
log_op: migrate
inputs:
  - name: mode
    required: true
    description: "One of: merge | rename | disambiguate"
  - name: from
    required: true
    description: "Source page(s). One path for rename/disambiguate, two paths for merge."
  - name: to
    required: true
    description: "Target page(s). One path for merge/rename, 2+ paths for disambiguate."
related_skills: [lint, ingest, query]
created: 2026-04-13
updated: 2026-04-13
---

# Migrate

## Purpose

Migrate handles the three page-identity operations on wiki content: **merge** (combine two pages into one — duplicates), **rename** (change a page's canonical name or filename), and **disambiguate** (split one page into two or more when a single name covers multiple distinct concepts). These operations share a mechanical substrate — update files, rewrite backlinks, update the index, preserve the graph — and differ only in the fan-in / fan-out shape.

Migrate is the only skill authorized to change which pages exist at which paths. Ingest, query, and lint can all **trigger** a migrate (when they find a duplicate, collision, or rename need), but they must hand off rather than doing the structural surgery themselves.

## When to invoke

- **Explicit:** User says `merge X and Y`, `rename X to Y`, `disambiguate X into Y and Z`, `X and Y are the same thing`, or similar.
- **Implicit (from lint):** the Tier 2 semantic lint finds an alias collision, duplicate entity, or a disambiguation candidate; lint reports the finding, User approves the fix, and migrate runs.
- **Implicit (from ingest):** ingest discovers that a page it's about to create already exists under a different name. Ingest must **abort its page creation** and hand off to migrate rather than silently renaming or merging mid-ingest. After migrate lands, ingest can resume.

Migrate is **never done silently inside another skill**. This is a governance rule: page identity changes are structural events worth surfacing and logging in their own right.

## Inputs

- **`mode`** (required) — one of `merge`, `rename`, `disambiguate`.
- **`from`** — source page path(s). One path for rename/disambiguate, two paths for merge.
- **`to`** — target page path(s). One path for merge/rename, 2+ paths for disambiguate.

## Preconditions

- The `from` page(s) exist and are readable.
- User has approved the target shape: canonical name (merge/rename), alias list to apply, split points (disambiguate).
- For merge: the canonical page and the page being absorbed are both decided before any file operation begins.
- For disambiguate: the content of the original page has been classified into the target pages (each line of original content has a destination).
- The worktree is clean enough that the migrate commit won't bundle unrelated changes.

## Steps

Migrate has three modes. Pick the mode first, then follow the corresponding sub-procedure. All three modes share steps 7–9 (log, commit, verify).

### Mode: merge

Use when two pages describe the same entity/concept. Fan-in 2→1.

1. **Pick the canonical name.** Per CLAUDE.md §7 naming conventions, prefer the canonical full name (e.g., `andrej-karpathy` over `karpathy`).
2. **Read both files.** Merge any unique content from the non-canonical page into the canonical page. Bump `updated` and `last_reviewed` on the canonical page.
3. **Add the non-canonical name to the `aliases:` array** of the canonical page so future searches find it.
4. **Find all backlinks** to the non-canonical page:
   ```sh
   grep -rn '\[\[<non-canonical>\]\]' wiki/
   grep -rn '\[\[<non-canonical>|' wiki/
   ```
5. **Rewrite each backlink** to point at the canonical page. Use `[[canonical]]` or `[[canonical|display-text]]` if the display text matters.
6. **Delete the non-canonical file**: `rm wiki/.../<non-canonical>.md`.

### Mode: rename

Use when a page needs a new filename (wrong canonical name, kebab-case fix, id change). Fan-in 1→1.

1. **Confirm the new canonical name** against CLAUDE.md §7 naming conventions.
2. **Rename the file**: `mv wiki/.../<old-id>.md wiki/.../<new-id>.md`.
3. **Update the frontmatter**: set `id: <new-id>` to match the new filename. Bump `updated` and `last_reviewed`.
4. **Add the old name to `aliases:`** if it was in common use — preserves searchability.
5. **Find and rewrite all backlinks**, same as merge step 4–5.

### Mode: disambiguate

Use when one name covers multiple distinct concepts and needs to split. Fan-out 1→N.

1. **Don't pick a winner.** Every target concept is valid; the original name is ambiguous.
2. **Create the disambiguated pages** with suffixed names:
   - e.g., `wiki/shared/concepts/attention-ml.md` (id: `attention-ml`, title: "Attention (ML)")
   - e.g., `wiki/shared/concepts/attention-cognition.md` (id: `attention-cognition`, title: "Attention (cognition)")
3. **Set aliases on each target page** so they match the original ambiguous name:
   - `attention-ml.md`: `aliases: ["attention", "transformer attention", "self-attention"]`
   - `attention-cognition.md`: `aliases: ["attention", "attentional focus"]`
4. **Optionally create a disambiguation page** at the original filename that links to all targets. This is recommended when the original name is likely to be queried directly:
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
5. **Find existing backlinks** to the ambiguous name (`[[attention]]`) and classify each one: does it mean ML-attention or cognitive-attention? Rewrite to the specific target. **Do NOT leave backlinks pointing at the disambiguation page** unless the referring page legitimately means "attention in general".
6. **When ingesting future sources that mention the ambiguous name**, link to the specific disambiguated page, not the disambiguation page itself.

### Common steps (all modes)

7. **Update `wiki/index.md`** — remove deleted pages, add new pages, update the entities / concepts / sources sections as the structure changed.
8. **Append to `wiki/log.md`** using the [Log entry format](#log-entry-format) below.
9. **Git commit** using the [Git commit format](#git-commit-format) below. Stage only the intended files — do not rely on `git commit -am` in a dirty worktree.

## Log entry format

Merge:
```markdown
## [YYYY-MM-DD] migrate | merged <from> → <to>

- Reason: <why the merge is being done>
- Canonical: [[<canonical>]]
- Aliases added: "<alias>", ...
- Backlinks updated: N
- Deleted: wiki/.../<non-canonical>.md
```

Rename:
```markdown
## [YYYY-MM-DD] migrate | renamed <old-id> → <new-id>

- Reason: <why the rename is being done>
- Aliases added: "<old-id>"
- Backlinks updated: N
```

Disambiguate:
```markdown
## [YYYY-MM-DD] migrate | disambiguated <ambiguous-name>

- Created: [[<target-1>]], [[<target-2>]], [[<ambiguous-name>]] (disambiguation)
- Aliases set on targets
- Backlinks reclassified: N
```

## Git commit format

```
migrate: <mode> <summary>
```

Examples: `migrate: merge karpathy → andrej-karpathy`, `migrate: rename foo-bar → foo-bar-system`, `migrate: disambiguate attention`.

## Anti-patterns

- **Merging inside another skill.** If ingest, query, or lint discovers a duplicate, they must surface it and hand off to this skill. Page identity is migrate's responsibility.
- **Deleting a page before its backlinks are rewritten.** That leaves the graph with dead wikilinks, which poisons verify-v1.sh's check 3 and hurts navigation.
- **Picking a disambiguation winner.** If two concepts genuinely share a name, both deserve pages. Picking one silently is a knowledge-layer decision the skill has no authority to make.
- **Silently merging contradictions as "rename".** If two pages disagree about facts, that's a `## Disputed` section in the `lint` skill's worked example — not a merge. Supersession and disagreement are not identity operations.
- **Forgetting `aliases:` on the canonical page after a merge.** The non-canonical name must still resolve in search; aliases are how.
- **`git commit -am` in a dirty worktree.** Stage specific files. Migrate often touches many pages (file moves plus backlink rewrites plus index plus log); auto-committing everything bundles unrelated changes.
- **Doing rename-only changes without running a backlink sweep.** Even if the file moves cleanly, the backlinks break. Backlink rewrites are non-optional.

## Worked examples

### Example: merge

**Scenario:** During lint, you find both `wiki/shared/entities/karpathy.md` and `wiki/shared/entities/andrej-karpathy.md`. They're the same person.

1. **Pick the canonical name.** Per CLAUDE.md §7 naming convention: `andrej-karpathy.md` (full name). Keep this one.
2. **Read both files.** Merge any unique content from `karpathy.md` into `andrej-karpathy.md`. Bump `updated` and `last_reviewed`.
3. **Add `karpathy` to the `aliases:` array** of `andrej-karpathy.md` so future searches find it.
4. **Find all backlinks to `[[karpathy]]`** in the vault:
   ```sh
   grep -rn '\[\[karpathy\]\]' wiki/
   grep -rn '\[\[karpathy|' wiki/
   ```
5. **Rewrite each backlink** to `[[andrej-karpathy]]` (or `[[andrej-karpathy|karpathy]]` if the display text matters).
6. **Delete `karpathy.md`**: `rm wiki/shared/entities/karpathy.md`.
7. **Update `wiki/index.md`** — remove `karpathy` from the entities list.
8. **Append to `wiki/log.md`**:
   ```markdown
   ## [2026-04-12] migrate | merged karpathy → andrej-karpathy

   - Reason: duplicate entity, same person
   - Canonical: [[andrej-karpathy]]
   - Aliases added: "karpathy"
   - Backlinks updated: 7
   - Deleted: wiki/shared/entities/karpathy.md
   ```
9. Stage specific files and commit:
   ```
   git add wiki/shared/entities/andrej-karpathy.md wiki/index.md wiki/log.md \
           wiki/shared/concepts/<touched>.md <any other backlink-rewritten files>
   git rm wiki/shared/entities/karpathy.md
   git commit -m "migrate: merge karpathy → andrej-karpathy"
   ```

### Example: disambiguate

**Scenario:** Two pages both want to be `attention.md`. One is the ML concept (transformer attention mechanism), one is the cognitive psychology concept (focused awareness).

1. **Don't pick a winner.** Both are valid concepts.
2. **Disambiguate with suffixes:**
   - `wiki/shared/concepts/attention-ml.md` (id: `attention-ml`, title: "Attention (ML)")
   - `wiki/shared/concepts/attention-cognition.md` (id: `attention-cognition`, title: "Attention (cognition)")
3. **Add aliases:**
   - `attention-ml.md`: `aliases: ["attention", "transformer attention", "self-attention"]`
   - `attention-cognition.md`: `aliases: ["attention", "attentional focus"]`
4. **Create a disambiguation page** `wiki/shared/concepts/attention.md` per the template in step 4 of the disambiguate mode above.
5. **When ingesting future sources that mention "attention"**, link to the specific disambiguated page, not the disambiguation page itself.
6. **Append to `wiki/log.md`**:
   ```markdown
   ## [2026-04-12] migrate | disambiguated attention.md

   - Created: [[attention-ml]], [[attention-cognition]], [[attention]] (disambiguation)
   - Aliases set on targets
   - Backlinks reclassified: 4
   ```
7. Stage specific files and commit:
   ```
   git add wiki/shared/concepts/attention-ml.md \
           wiki/shared/concepts/attention-cognition.md \
           wiki/shared/concepts/attention.md \
           wiki/index.md wiki/log.md \
           <any other backlink-rewritten files>
   git commit -m "migrate: disambiguate attention"
   ```

## Related skills

- **[lint](../lint/SKILL.md)** — upstream. Surfaces duplicates (alias/title collisions, duplicate entities) that trigger migrate.
- **[ingest](../ingest/SKILL.md)** — upstream. When ingest discovers it's about to create a duplicate, it aborts and hands to migrate.
- **[query](../query/SKILL.md)** — downstream. After migrate, queries should find the canonical page via aliases. If they don't, the aliases are wrong.
- **[go](../go/SKILL.md)** — peer. The session-start skill will notice migrate commits in recent log entries and may prompt to run `lint` to check for residual graph damage.
