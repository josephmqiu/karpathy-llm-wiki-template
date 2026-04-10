# First-Time Setup

Get up and running with the LLM Wiki pattern in under 10 minutes.

This template implements [Andrej Karpathy's LLM Wiki pattern](https://gist.github.com/karpathy/442a6bf555914893e9891c11519de94f) — using an LLM to incrementally build and maintain a persistent markdown wiki instead of RAG.

---

## Prerequisites

### 1. Claude Code (required)

The wiki is operated through [Claude Code](https://claude.ai/code), Anthropic's CLI agent. It reads `CLAUDE.md` on startup and follows the workflows defined there.

Install via npm:

```sh
npm install -g @anthropic-ai/claude-code
```

Or via Homebrew:

```sh
brew install claude-code
```

You need an Anthropic API key or a Claude Pro/Max subscription. See the [Claude Code docs](https://docs.anthropic.com/en/docs/claude-code) for setup details.

### 2. Git (required)

Each ingest is an atomic git commit. The vault should be a git repository.

```sh
git --version   # confirm git is installed
```

### 3. Obsidian (recommended)

[Obsidian](https://obsidian.md/) is the recommended IDE for browsing the wiki. It renders wikilinks, graph view, and Dataview queries natively. You can use any markdown editor, but Obsidian gives the best experience.

Download: https://obsidian.md/download

### 4. Python 3 (required for verify script)

The `scripts/verify-v1.sh` integrity checker uses Python 3 (stdlib only) for JSON parsing. Most systems have this already.

```sh
python3 --version   # confirm python3 is available
```

---

## Obsidian Plugins

After opening the vault in Obsidian, install these community plugins via **Settings > Community plugins > Browse**:

| Plugin | Why | Required? |
|---|---|---|
| **Dataview** | Powers the dashboard queries in `wiki/meta/dashboard.md` — recent ingests, all entities, pages needing review, etc. | Recommended |
| **Git** (Vinzent03) | Commit/push from within Obsidian without switching to the terminal. Useful for quick raw source additions. | Optional |

### Enabling Dataview

1. Open Settings > Community plugins
2. Turn off "Restricted mode" if prompted
3. Click Browse, search for "Dataview"
4. Install, then Enable
5. Open `wiki/meta/dashboard.md` to verify the tables render

---

## Setup Steps

### 1. Clone or copy this template

```sh
git clone https://github.com/<your-username>/karpathy-llm-wiki-template.git my-wiki
cd my-wiki
```

Or download the ZIP and extract it.

### 2. Personalize CLAUDE.md

Open `CLAUDE.md` and replace `User` with your name throughout. This makes the LLM's prompts feel natural:

```sh
# macOS/Linux
sed -i '' 's/User/YourName/g' CLAUDE.md
```

Review the file. The key sections to customize:

- **Section 1 (Identity)**: change the starting topic from `llm-wiki` to your domain if desired
- **Section 9-12 (Workflows)**: the ingest/query/lint/triage workflows work as-is for any topic
- **Notes about this vault**: update to reflect your setup

### 3. Initialize git (if not already)

```sh
git init
git add -A
git commit -m "init: LLM Wiki from Karpathy template"
```

### 4. Open in Obsidian

1. Open Obsidian
2. Click "Open folder as vault"
3. Select the cloned directory
4. Install the Dataview plugin (see above)
5. Open `wiki/index.md` to orient yourself

### 5. Start Claude Code

```sh
cd my-wiki
claude
```

Claude reads `CLAUDE.md` automatically. You can immediately:

- Drop a source file into `raw/` and say `ingest raw/your-file.md`
- Ask questions: `what does the wiki say about X?`
- Run `lint` to check vault health

### 6. Add your first source

```sh
# Save an article, paper, or notes as a raw source
cp ~/Downloads/interesting-article.md raw/2026-04-15-interesting-article.md
```

Then tell Claude:

```text
ingest raw/2026-04-15-interesting-article.md
```

Claude will read it, discuss takeaways with you, then create wiki pages with your approval.

---

## Folder Structure

```
LLM-Wiki/
├── CLAUDE.md          ← system instructions (the schema)
├── raw/               ← immutable source documents
├── wiki/              ← LLM-maintained knowledge base
│   ├── index.md       ← master catalog
│   ├── log.md         ← operations log
│   ├── shared/        ← cross-domain content (default)
│   ├── domains/       ← topic-specific content
│   ├── synthesis/     ← filed query answers
│   └── meta/          ← dashboard, system docs
├── inbox/             ← quick capture (triage later)
└── scripts/           ← verify-v1.sh integrity checker
```

---

## Included Example Content

This template ships with two pre-ingested sources to demonstrate the pattern in action:

1. **Karpathy's original gist** (`raw/2026-04-09-karpathy-llm-wiki-gist.md`) — the foundational document
2. **Research synthesis** (`raw/2026-04-09-llm-wiki-research-synthesis.md`) — community survey of implementations and pitfalls

These produced:
- 2 source summary pages
- 1 entity page (Andrej Karpathy)
- 1 concept page (LLM Wiki Pattern)
- 1 Map of Content (llm-wiki)

You can keep these as reference or clear them out and start fresh with your own topic.

### Starting fresh

To clear the example content and start with an empty wiki:

```sh
rm -rf wiki/shared/sources/* wiki/shared/entities/* wiki/shared/concepts/*
rm -rf wiki/domains/llm-wiki/
rm raw/2026-04-09-*.md
echo '[]' > raw/.manifest.json
```

Then edit `wiki/index.md`, `wiki/log.md`, and create your own topic MOC under `wiki/domains/<your-topic>/`.

---

## Further Reading

- [Karpathy's LLM Wiki gist](https://gist.github.com/karpathy/442a6bf555914893e9891c11519de94f) — the original pattern description
- [Claude Code documentation](https://docs.anthropic.com/en/docs/claude-code) — how to install and use Claude Code
- [Obsidian documentation](https://help.obsidian.md/) — getting started with Obsidian
- [Dataview plugin docs](https://blacksmithgu.github.io/obsidian-dataview/) — query your vault like a database

---

*This template was built from a working LLM Wiki vault. The CLAUDE.md, workflows, and verify script are battle-tested.*
