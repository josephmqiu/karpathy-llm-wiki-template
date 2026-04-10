---
id: llm-wiki-pattern
title: LLM Wiki Pattern
type: concept
aliases: ["llm wiki", "karpathy wiki pattern", "agentic wiki"]
status: stable
sources: ["raw/2026-04-09-karpathy-llm-wiki-gist.md", "raw/2026-04-09-llm-wiki-research-synthesis.md"]
related: ["[[andrej-karpathy]]", "[[karpathy-llm-wiki-gist]]", "[[llm-wiki-research-synthesis]]"]
topics: ["llm-wiki"]
created: 2026-04-09
updated: 2026-04-09
last_reviewed: 2026-04-09
superseded_by: null
---

# LLM Wiki Pattern

A knowledge management pattern proposed by [[andrej-karpathy]] in which an LLM incrementally builds and maintains a persistent markdown wiki, rather than re-deriving knowledge from raw documents on every query (as in RAG).

## Core insight

The tedious part of a knowledge base is not reading or thinking — it's bookkeeping: updating cross-references, keeping summaries current, noting contradictions, maintaining consistency across pages. Humans abandon wikis because maintenance burden grows faster than value. LLMs eliminate that cost.

## Architecture

Three layers:

1. **Raw sources** — immutable, human-curated documents (articles, papers, transcripts). The LLM reads but never modifies these.
2. **The wiki** — LLM-owned markdown files (summaries, entity pages, concept pages, syntheses). The LLM creates, updates, and cross-references these.
3. **The schema** — a configuration document (e.g., CLAUDE.md) defining structure, conventions, and workflows. Co-evolved by human and LLM.

## Operations

- **Ingest** — process a new source into wiki pages, updating entities, concepts, and cross-references across the wiki
- **Query** — answer questions with citations to wiki pages; good answers can be filed back as synthesis pages, so explorations compound
- **Lint** — health-check for contradictions, orphan pages, stale claims, missing cross-references

## Key properties

- **Compounding** — each source and query enriches the wiki; cross-references accumulate rather than being re-derived
- **Human-in-the-loop** — the human curates sources, directs analysis, and asks questions; the LLM handles bookkeeping
- **Tooling-agnostic** — the pattern works with any LLM agent and any markdown-based tool (Obsidian, VS Code, etc.)

## Historical lineage

Related in spirit to Vannevar Bush's Memex (1945) — a private, curated knowledge store with associative trails between documents. The Memex envisioned the structure; the LLM Wiki pattern solves the maintenance problem Bush couldn't address.

## Contrast with RAG

RAG re-derives knowledge from raw documents on every query. The LLM Wiki pattern compiles knowledge once and keeps it current. RAG scales retrieval; the wiki scales understanding. An open debate: detractors argue the pattern is "RAG with extra steps" that context window growth will make obsolete; defenders counter that compiled, cross-referenced, deduplicated knowledge is qualitatively different from raw chunk retrieval ([[llm-wiki-research-synthesis]]).

## Community adoption

The gist hit 5,000+ GitHub stars and the HN front page within days of release (April 2026). Notable implementations include MehmetGoekce/llm-wiki (L1/L2 cache architecture), NicholasSpisak/second-brain (Obsidian-first), AgriciDaniel/claude-obsidian (hot cache pattern), and Ss1024sS/LLM-wiki (multi-platform). An LLM Wiki v2 gist by Rohit G. extends the pattern with confidence scoring, supersession tracking, and hybrid search.

Conventions that have converged across implementations: entity/concept/source/synthesis page taxonomy, YAML frontmatter with `type`/`sources`/`related`/`updated`, the 10-15 page ripple rule per ingest, and the compile-first principle (wiki pages are the unit of truth, not chat responses).

## Known pitfalls

- **Error compounding** — mistakes in early ingests propagate through backlinks. Mitigation: ingest one source at a time, stay involved, lint regularly.
- **Source granularity** — naive whole-document ingests produce slop; chapter-level splitting yields dramatically better results.
- **Markdown-as-database limits** — scale ceiling at ~100-300 sources before needing Dataview, SQLite, or a graph DB.
- **Cognitive offloading** — if the LLM writes everything, the human bypasses the mental-model-building that made note-taking useful. The human should remain "the thinker, not just the curator."
- **Context window degradation** — performance degrades around 200-300K tokens even in 1M-context models.
