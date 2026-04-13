# Skills

Operational procedures for this LLM Wiki, extracted from `CLAUDE.md`. Each skill is a self-contained markdown file at `skills/<name>/SKILL.md` that encodes one workflow — what to do, when to do it, how to log it, how to commit it.

Skills are **harness-agnostic**: plain markdown + YAML, no vendor-specific frontmatter. They can be executed by Claude Code today or any future AI agent that reads markdown and follows numbered steps.

## Catalog

Session start (read order + preflight checks for lint cadence and inbox state) is handled inline by CLAUDE.md §8, not as a skill.

| Skill | When it activates | File |
|---|---|---|
| **ingest** | New file in `raw/`; User says "ingest", "process this source" | [`ingest/SKILL.md`](ingest/SKILL.md) |
| **query** | Any domain question answerable from wiki content (implicit) | [`query/SKILL.md`](query/SKILL.md) |
| **lint** | Every 5 ingests or 14 days; User says "lint", "health check" | [`lint/SKILL.md`](lint/SKILL.md) |
| **triage** | Non-empty `inbox/`; User says "triage" | [`triage/SKILL.md`](triage/SKILL.md) |
| **migrate** | Rename, merge, disambiguate, or move a wiki page | [`migrate/SKILL.md`](migrate/SKILL.md) |
| **autoresearch** | User says "research X", "investigate X", "deep dive into X", "build a wiki on X" | [`autoresearch/SKILL.md`](autoresearch/SKILL.md) |

## File template

Every `SKILL.md` has the same shape so any agent can parse it by section heading.

### Frontmatter

```yaml
---
id: <name>                    # kebab-case, matches directory name
name: <name>                  # harness-friendly alias
title: "..."                  # human-readable one-liner
version: 1                    # bump on breaking changes
status: stable                # draft | stable | deprecated
log_op: <op>                  # matches wiki/log.md op tokens
inputs:
  - name: <param>
    required: true
    description: "..."
related_skills: [<name>, ...]
created: YYYY-MM-DD
updated: YYYY-MM-DD
---
```

### Body sections (in order)

1. **Purpose** — what this skill does, one paragraph
2. **When to invoke** — explicit ("User says X") and implicit ("new file in raw/") triggers
3. **Inputs** — parameters with types and defaults
4. **Preconditions** — hard rules that must hold before executing
5. **Steps** — numbered, executable, same granularity as the schema rules in CLAUDE.md
6. **Log entry format** — exact markdown template appended to `wiki/log.md`
7. **Git commit format** — commit-message convention for this op
8. **Anti-patterns** — scoped subset of CLAUDE.md §11
9. **Worked example** — one end-to-end run
10. **Related skills** — links to sibling skills that chain with this one

The template is the contract. Load a skill file in full before executing its steps.

## Architecture

These skills are the **fat skills** layer of a three-layer model:

- **Harness** — Claude Code (or any LLM agent) — runs the model, provides Read/Edit/Bash/Grep, manages context. Knows nothing about this wiki.
- **Skills** — this directory — parameterized procedures that encode the wiki's workflows.
- **Application** — `scripts/verify-v1.sh` + `raw/` + wiki frontmatter — deterministic, domain-specific, pure.

`CLAUDE.md` at the repo root stays thin: identity, core principles, hard rules, folder map, frontmatter schema, naming conventions, log format, anti-patterns, and a skill catalog that mirrors this README. No procedural bodies.

## Adding a new skill

1. Create `skills/<name>/SKILL.md` following the template above.
2. Add a row to the catalog in this README.
3. Add a matching row to the catalog in `CLAUDE.md §9`.
4. If the skill introduces a new log operation, document it in `CLAUDE.md §10` (log format).
5. Run `scripts/verify-v1.sh` to confirm the skill catalog stays in sync.

## `references/` subfolder convention

A skill that needs a user-editable config layer places it under `skills/<name>/references/<file>.md`. The `references/` subfolder holds files the skill loads at runtime but User tunes by hand — not content pages, not schema. `autoresearch` is the first skill to use this convention (see `skills/autoresearch/references/program.md`, which configures caps, source preferences, and domain notes for the research loop). Files under `references/` have no frontmatter requirements and are not scanned by the verify script's content-page checks.
