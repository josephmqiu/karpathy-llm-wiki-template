---
id: go
name: go
title: "Go: session start — read order, preflight checks, surface prompts"
version: 1
status: stable
log_op: null
inputs: []
related_skills: [ingest, query, lint, triage, migrate]
created: 2026-04-13
updated: 2026-04-13
---

# Go

## Purpose

Initialize a wiki session. Execute the read order that primes context, run the preflight checks that enforce lint cadence and inbox hygiene, and surface any prompts that require User's attention before substantive work begins.

Go is session-internal — it does **not** write a log entry. Its outputs are the loaded context, the preflight findings, and any prompts it raises. The durable effect of running go is that the session is now ready to run the other skills correctly (with the index, relevant MOC, and recent log history in context).

## When to invoke

- **Session start:** the first substantive action of a new session. User does not need to say `go` — the skill activates implicitly when a new session begins.
- **Explicit:** User says `go`, `begin`, `start session`, `where are we`, or similar.
- **Topic switch:** if User pivots mid-session to a different topic / MOC than the one currently loaded, re-run the read order for the new topic.
- **Resume after long break:** if a session has been idle long enough that recent state is unclear, re-run to refresh the preflight checks.

## Inputs

None. Go operates on the full wiki state.

## Preconditions

- The wiki's core files exist: `CLAUDE.md`, `wiki/index.md`, `wiki/log.md`, `raw/.manifest.json`.
- At least one topic MOC exists under `wiki/domains/`.
- `inbox/` and `scripts/verify-v1.sh` are readable.

## Steps

### Read order (execute every session)

1. **`CLAUDE.md`** — the schema + rules + skill catalog. Usually already loaded by the harness; if not, read it first.
2. **`wiki/index.md`** — the master content catalog. This is non-negotiable: skipping the index means missing existing pages and creating duplicates.
3. **`wiki/domains/<topic>/<topic>-moc.md`** — the Map of Content for the topic relevant to the anticipated question or task. If the topic is unclear at session start, read `wiki/index.md`'s MOC section and wait for a question before drilling in.
4. **Specific pages** — as the question crystallizes, drill into the entities / concepts / sources / syntheses the question touches. Follow wikilinks outward from the MOC.
5. **`wiki/log.md`** — only when disambiguation or recent history is needed (e.g., "what did we ingest last week?", "when was the last lint?"). Preflight checks below use the log.

**Do not skip steps 2 and 3.** Skipping the index/MOC is the most common failure mode and it produces duplicate pages that later require `migrate` to clean up.

### Preflight checks (mandatory)

After the read order primes the context, run these two checks before substantive work. They take seconds. They are the enforcement mechanism for lint cadence and inbox hygiene.

6. **Last lint date.** Find the most recent `lint |` entry in `wiki/log.md`. If the last lint is more than **14 days** old, surface:
   > Lint is overdue (last run: YYYY-MM-DD). Want me to run it before we start?

   Wait for User's answer. If yes, invoke the [lint](../lint/SKILL.md) skill. If no, proceed but note the staleness in the working context.

7. **Ingests since last lint.** Count `ingest |` entries in `wiki/log.md` that appear **after** the most recent `lint |` entry. If that count is 5 or more, surface:
   > We've hit ingest N since the last lint — time for a scheduled health check.

   Wait for User's answer. Same yes/no branching as check 6.

8. **Inbox state.** List `inbox/` (skipping `.gitkeep`). If the inbox has one or more items, surface:
   > Inbox has N item(s) waiting: <filenames>. Want me to triage before we start?

   Wait for User's answer. If yes, invoke the [triage](../triage/SKILL.md) skill. If no, proceed.

### Ready state

9. Return the session to User with a brief "ready" acknowledgment that includes:
   - Which MOC was loaded (or "no topic loaded yet — tell me what you want to work on")
   - Any preflight prompts that were deferred (lint overdue but User said no, inbox non-empty but User said no)
   - Zero ceremony otherwise — if everything is clean, just confirm ready and wait for the next instruction.

## Log entry format

**None.** Go is session-internal. It does not append to `wiki/log.md`.

If the preflight prompts trigger a `lint` or `triage` run, those skills log their own entries. If User invokes go explicitly and nothing happens (clean preflight, no prompts), nothing is written anywhere — that's correct.

## Git commit format

**None.** Go does not commit.

## Anti-patterns

- **Skipping the index and MOC.** Steps 2 and 3 are non-negotiable. The index and MOC are how the model avoids creating duplicate pages; skipping them is the dominant failure mode for wiki drift.
- **Auto-running lint or triage without asking.** The preflight checks **surface prompts**; they do not auto-invoke the downstream skills. User decides.
- **Reading `wiki/log.md` in full at session start.** The log can get long. Read only what the preflight checks need (recent lint entries, recent ingests), not the whole file.
- **Logging the go operation.** Go is session-internal. Adding a `go |` entry to `wiki/log.md` would bloat the log with noise and give verify-v1.sh's query/synthesis health check something irrelevant to parse.
- **Running go every turn.** Go runs at session start (or topic switch, or resume). Running it every turn burns context for no gain.
- **Ignoring the preflight checks when User doesn't say `go`.** Go activates implicitly at session start even without the keyword. The checks must still run.

## Worked example

**Scenario:** User opens a new session in the wiki repo.

**Steps:**

1. Read CLAUDE.md (harness already loaded it).
2. Read `wiki/index.md`. Note the current topic(s): starting template has one seed topic, `llm-wiki`.
3. Topic unclear yet — wait for User's question before reading a specific MOC beyond `llm-wiki-moc`.
4. Preflight check 1 (last lint). Grep `wiki/log.md` for `^## \[.*\] lint \|`. If present, compare age against today; if older than 14 days, surface the prompt. Fresh template has no lint entry yet — no prompt.
5. Preflight check 2 (ingests since last lint). Count `^## \[.*\] ingest \|` entries after the most recent `lint |` entry. Fresh template: 2 pre-ingested sources, 0 lints. Under 5. No prompt.
6. Preflight check 3 (inbox state). `ls inbox/` → just `.gitkeep`. Empty. No prompt.
7. Return: "Ready. `llm-wiki` topic loaded via index. No preflight prompts. What do you want to work on?"

**Variant scenario:** Same session, but several ingests later. Check 2 would find 6 ingests since the last lint and surface:
> We've hit ingest 6 since the last lint — time for a scheduled health check. Want me to run lint before we start?

If User says yes, invoke the [lint](../lint/SKILL.md) skill and proceed only after it completes. If User says no, proceed and note the staleness.

## Related skills

- **[lint](../lint/SKILL.md)** — downstream. Preflight checks 6 and 7 surface prompts to run this skill.
- **[triage](../triage/SKILL.md)** — downstream. Preflight check 8 surfaces a prompt to run this skill when the inbox is non-empty.
- **[ingest](../ingest/SKILL.md)** — downstream. Once go primes the context, `ingest` can run on new `raw/` sources.
- **[query](../query/SKILL.md)** — downstream. Once go primes the context, `query` can answer questions against the wiki with the correct index/MOC/pages already in view.
- **[migrate](../migrate/SKILL.md)** — downstream. Page identity operations benefit from go having loaded the index and relevant MOC first.
