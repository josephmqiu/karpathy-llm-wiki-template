---
id: llm-wiki-moc
title: LLM Wiki MOC
type: moc
topics: ["llm-wiki"]
status: draft
created: 2026-04-09
updated: 2026-04-09
last_reviewed: 2026-04-09
superseded_by: null
---

# LLM Wiki

Map of Content for the LLM wiki / agentic knowledge management topic. Curated entry points into entities, concepts, sources, and syntheses related to using LLMs to maintain personal knowledge bases (Karpathy's pattern, reference implementations, PKM adaptations, pitfalls, and lessons learned).

## Key sources

- [[karpathy-llm-wiki-gist]] — foundational gist by Karpathy proposing the LLM Wiki pattern (April 2026)
- [[llm-wiki-research-synthesis]] — community survey of implementations, PKM adaptations, and pitfalls

## Entities

- [[andrej-karpathy]] — author of the LLM Wiki pattern

## Concepts

- [[llm-wiki-pattern]] — the core pattern: LLM incrementally builds a persistent wiki instead of RAG

## Syntheses

*(none yet)*

## Open questions for this domain

- What's the right kill-switch threshold once topics 2 and 3 are added?
- When does a manual `hot.md` become useful enough to add as derived-from-log?
- Does the `inbox/` + `triage` workflow stick as a habit, or get abandoned?
- How does the wiki perform past 50 sources? Past 200?
