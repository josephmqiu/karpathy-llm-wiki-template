---
id: karpathy-llm-wiki-gist
title: "LLM Wiki (Karpathy gist)"
type: source
aliases: ["karpathy gist", "llm wiki gist"]
status: stable
source_ref: raw/2026-04-09-karpathy-llm-wiki-gist.md
hash: dc3efe98ae62f23dd08acad13aba2e95287beb20b6bec2f4af0423557fe37401
related: ["[[llm-wiki-pattern]]", "[[andrej-karpathy]]"]
topics: ["llm-wiki"]
created: 2026-04-09
updated: 2026-04-09
last_reviewed: 2026-04-09
superseded_by: null
---

# LLM Wiki (Karpathy gist)

## Summary

Foundational document by [[andrej-karpathy]] proposing the [[llm-wiki-pattern]]: instead of RAG (re-deriving knowledge per query), have an LLM incrementally build and maintain a persistent markdown wiki that compounds over time. The human curates sources, directs analysis, and asks questions; the LLM handles all bookkeeping — summarizing, cross-referencing, filing, and maintenance.

## Key claims

1. **Compounding beats re-derivation.** A persistent wiki accumulates cross-references and synthesis that RAG must reconstruct from scratch every time. The wiki is "a persistent, compounding artifact."
2. **Three-layer architecture.** Raw sources (immutable, human-curated) / wiki (LLM-owned markdown) / schema (CLAUDE.md or AGENTS.md defining structure and workflows). The schema is "the key configuration file."
3. **Three core operations.** Ingest (process a new source into wiki pages, touching 10-15 pages per source at scale), Query (answer questions with citations, optionally filing good answers back as new pages), Lint (health-check for contradictions, orphans, stale claims).
4. **Two navigation files.** `index.md` (content-oriented catalog, read first when answering queries) and `log.md` (chronological operations record, parseable with grep).
5. **Bookkeeping is the value.** "Humans abandon wikis because the maintenance burden grows faster than the value. LLMs don't get bored." The LLM handles what humans won't do.
6. **Historical lineage.** The pattern is "related in spirit to Vannevar Bush's Memex (1945)" — a private, actively curated knowledge store with associative trails. "The part he couldn't solve was who does the maintenance."

## Scope and use cases mentioned

- Personal (goals, health, self-improvement)
- Research (papers, articles over weeks/months)
- Reading a book (chapter-by-chapter companion wiki)
- Business/team (fed by Slack, meeting transcripts, project docs)
- Competitive analysis, due diligence, trip planning, course notes, hobby deep-dives

## Tools mentioned

- **Obsidian** as the IDE (graph view, Dataview plugin, Marp plugin, Web Clipper extension)
- **qmd** (by Tobi Lutke) — local markdown search with hybrid BM25/vector search and MCP server
- Git for version history

## Design philosophy

The document is "intentionally abstract" — it describes the pattern, not a specific implementation. Users share it with their LLM agent and co-evolve a version that fits their domain. "Everything mentioned above is optional and modular."
