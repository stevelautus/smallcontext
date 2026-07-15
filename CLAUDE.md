# Working in this repo

This repo **is** a Claude Code plugin. `hooks/`, `scripts/`, and `docs/RECYCLING.md` are not
documentation about a product — they *are* the product. They execute on, or get copied onto, users'
machines. Editing prose inside `docs/RECYCLING.md` changes live behavior for every install; treat it
with the care you'd give code.

**The seam path is pinned.** The checkpoint procedure materializes to `~/.claude/context-kit/RECYCLING.md`.
That exact path is a cross-plugin contract — the smallplans run skills reference it. Never rename it,
and never move it to match this plugin's name.

**Never overwrite a materialized procedure.** `scripts/session-start.sh` writes
`~/.claude/context-kit/RECYCLING.md` only when it is absent. The installed copy is the user's tuning
point (the 60k threshold lives there); clobbering it silently discards their edits. This guarantee is
load-bearing — do not "improve" it into a sync or a refresh.

**This repo is public.** Keep every shipped file free of personal names, machine paths (`/Users/...`),
private project names, and references to unrelated local tooling. Referring to the smallplans plugin by
name is fine — that seam is real.

**`~/.claude/` is the user's live install, not part of this repo.** The only thing this codebase may
ever write there is the single materialization `session-start.sh` performs. Nothing in your development
loop should touch it.

**Testing.** There is no test suite. Verify the hook scripts by running them with simulated hook stdin
(`{"cwd": "...", ...}`) against a **sandbox `HOME`**, covering every branch: procedure file present and
absent (asserting no overwrite), rolling handoff present and absent. Assert valid JSON on stdout and
silence on stderr. Never test against your real `~/.claude/` — check its `RECYCLING.md` checksum before
and after if there's any doubt.
