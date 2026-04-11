# Dashboard

Dataview queries over the wiki. Requires the **Dataview** community plugin.

> If queries below show "Dataview: Query not initialized" or similar, the plugin isn't enabled. Settings → Community plugins → Browse → Dataview → Install + Enable.

## Recent ingests

```dataview
TABLE created, type, status
FROM "wiki/shared/sources" OR "wiki/domains"
WHERE type = "source"
SORT created DESC
LIMIT 10
```

## All entities

```dataview
TABLE topics, status, updated
FROM "wiki/shared/entities" OR "wiki/domains"
WHERE type = "entity"
SORT updated DESC
```

## All concepts

```dataview
TABLE topics, status, updated
FROM "wiki/shared/concepts" OR "wiki/domains"
WHERE type = "concept"
SORT updated DESC
```

## Pages needing review

Pages whose `last_reviewed` is older than 30 days, or marked `status: stub`.

```dataview
TABLE last_reviewed, status, type
FROM "wiki/shared" OR "wiki/domains"
WHERE last_reviewed < date(today) - dur(30 days) OR status = "stub"
SORT last_reviewed ASC
```

## Superseded pages

```dataview
TABLE superseded_by, updated
FROM "wiki/shared" OR "wiki/domains"
WHERE status = "superseded"
```

## All syntheses

```dataview
TABLE question, topics, status, created
FROM "wiki/synthesis"
WHERE type = "synthesis"
SORT created DESC
```

## Lint cadence

Recommended cadence: every 5 ingests or 14 days, whichever comes first.

```dataview
TABLE type, status, last_reviewed
FROM "wiki/shared" OR "wiki/domains"
WHERE last_reviewed < date(today) - dur(60 days)
SORT last_reviewed ASC
```

## Kill-switch metric (deferred until topic 2 exists)

When 2+ MOCs exist, this query shows entities linked from multiple MOCs (cross-domain entities). The metric: `% of shared entities linked from 2+ MOCs`. Used to validate the type-first hybrid placement rule.

```dataview
TABLE length(file.inlinks) AS "incoming links", topics
FROM "wiki/shared/entities"
WHERE type = "entity"
SORT length(file.inlinks) DESC
```
