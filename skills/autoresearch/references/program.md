# Research program

This file configures the `autoresearch` skill. User edits this file to tune what autoresearch does; the skill reads it in full at the start of every run (Phase A step 1).

This is a **config file**, not a content page. It has no YAML frontmatter and is not part of the wiki schema — it lives alongside `skills/autoresearch/SKILL.md` as a peer artifact, following the `references/` subfolder convention. If another skill ever needs its own config layer, it should use the same `skills/<name>/references/` shape.

---

## Search objectives

Default objectives for every research session:

- Find **authoritative sources**. Prefer in this order:
  1. Primary sources — original papers, official documentation, official source code repos, first-hand reports by named authors
  2. Peer-reviewed or edited publications — arXiv (treat as primary for ML/systems topics), journal articles, established technical publications
  3. Secondary-but-credible — .edu pages, reference works, well-cited textbooks
  4. Opinionated but informed — named-author blog posts, conference talks, podcast transcripts with named guests
- **Extract key entities** — people, organizations, products, tools — and propose wiki pages for those that are load-bearing.
- **Extract key concepts and frameworks** — and propose wiki pages for the ones substantive enough to stand alone (not every term mentioned needs a page).
- **Preserve contradictions explicitly.** If two sources disagree on a material claim, note both in the synthesis under `## Contradictions` with a brief credibility note — never silently pick one.
- **Identify open questions** — gaps the loop could not close, which become `> [!gap]` callouts in the synthesis page.
- **Prefer recent sources** for fast-moving topics (last 18–24 months) unless the topic is foundational, in which case older primary sources are preferred.

---

## Coverage rubric

Every major section on a page autoresearch produces gets a `[coverage: ...]` tag per CLAUDE.md §6A. Apply the rubric as follows when filing:

| Coverage | When to use |
|---|---|
| `[coverage: high]` | Multiple independent authoritative sources agree |
| `[coverage: medium]` | Single good source, or sources partially agree |
| `[coverage: low]` | Single informal source, opinion piece, or primarily inferential |

Apply provenance labels per claim within a section:

- `[extracted]` — directly supported by one or more cited sources in the page's `sources:` frontmatter
- `[inferred]` — LLM synthesis across 2+ sources; not stated verbatim in any one
- `[ambiguous]` — source basis is underspecified, incomplete, or unclear
- `[disputed]` — sources conflict; the containing paragraph must preserve both sides

Always note the source date for factual claims whose truth may decay. Mark any claim derived from a source older than 3 years as `[ambiguous]` at minimum, unless the topic is foundational.

---

## Loop constraints (hard caps)

These are hard caps. Autoresearch must not exceed them even if the topic feels incomplete.

- **Max search rounds per topic:** 3
- **Max raw files captured per session:** 15
- **Max WebSearch queries per round:** 10 across all angles
- **Max WebFetch results fetched per round:** 5
- **Max projected wiki pages filed per session:** 15 (ripple budget from CLAUDE.md §4 rule 10 still applies — target 10–15 only after the vault has substance)

If a cap is reached mid-loop, stop that round, do not start the next round, and surface what was skipped in the checkpoint report under `Open questions`. The synthesis page then carries forward those open questions as `> [!gap]` callouts — future autoresearch runs can target them explicitly.

---

## Output style

Applies to the synthesis page and to any content fed back to ingest hand-offs.

- **Declarative, present tense.** Write "The paper shows X" not "The paper would seem to show X".
- **Cite every non-obvious claim.** `(Source: [[page]])` inline, or via `sources:` in frontmatter for whole-page claims.
- **Short pages.** Synthesis page under 200 lines. Concept/entity pages under 150. Split if longer; each sub-page gets its own citations.
- **No hedging language.** Avoid "it seems", "perhaps", "might be". Uncertainty belongs in `> [!gap]` callouts, not in softened prose.
- **Flag uncertainty explicitly.** For any claim that needs verification, use:
  ```markdown
  > [!gap] This claim needs primary-source verification.
  > <the claim>
  ```

---

## Domain notes

Domain-specific rules that autoresearch applies based on which domain the topic maps to in Phase A step 2. The template ships with one seed topic, `llm-wiki`. Add a new `### <domain>` section under this heading whenever a new domain is declared in CLAUDE.md §1.

### `llm-wiki` (LLM-maintained knowledge systems)

- **Prefer:** Karpathy's original gist and subsequent writings, reference implementations (`claude-obsidian`, `obsidian-copilot`, etc.), post-mortems and pitfall reports.
- **Treat as primary:** the Karpathy gist itself, named-author blog posts from people running LLM wikis in production.
- **Flag:** any source that confuses LLM-maintained wikis with RAG systems — this is a common framing error. Note it in `Contradictions`.

### No fitting domain

If Phase A step 2 concluded that the topic does not fit any existing domain and User approved declaring a new domain, the autoresearch run produces pages with the new domain in `topics:`. Creating the new domain folder (`wiki/domains/<new>/`) and MOC is a **follow-up task** for the `migrate` skill, not autoresearch. Autoresearch writes `topics: ["<new-domain>"]` in frontmatter and leaves the folder creation to migrate.

---

## Exclusions

Do **not** cite as high-coverage sources:

- Reddit posts and forums — use only as pointers to the primary sources they cite, never as the primary citation
- Social media posts (X/Twitter, LinkedIn, etc.) — the thread is not the source; the underlying paper or repo it links to is
- Undated web pages — if the page has no publication date, treat as `[coverage: low]` regardless of content
- AI-generated content farms and SEO-optimized explainers that don't link to primary sources
- Marketing pages and press releases — flag as `[coverage: low]` unless corroborated by an independent source
- Old (>3 years) claims about fast-moving topics unless marked as historical context

If a Reddit or social media post is the only available pointer to a claim, cite the *underlying source* it links to. If there is no underlying source, the claim goes under `> [!gap]` in the synthesis.

---

## Tuning this file

Edit this file when:

- The caps need adjustment (vault outgrows 15 pages per session → bump to 20; too many empty runs → lower to 10)
- A new domain is added to CLAUDE.md §1 → add a `### <new-domain>` section under Domain notes
- A source category becomes chronically unreliable → add it to Exclusions
- The confidence → coverage mapping drifts from how coverage is actually used elsewhere in the vault → update the mapping table

Every tuning change should be committed as `research-program: <short summary>` (not a skill commit — this is a config edit) and referenced in the next `research` log entry under a `program edits since last run` line if material.
