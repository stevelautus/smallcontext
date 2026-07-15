# smallcontext

Long Claude Code sessions degrade when auto-compact replaces your conversation history with a lossy
summary — at a moment you don't control, produced by a prompt you can't change. **smallcontext demotes
compaction from an event you avoid into a flush you survive.** Continuity lives on disk in a rolling
handoff, and the instant a compaction lands, a hook tells the session to re-read that file and trust it
over the summary. The summary stops having to carry your run; it only has to not poison it.

## What you get

**No slash commands. No skills.** Nothing to invoke, nothing to remember. smallcontext is pure
infrastructure — two hooks and a procedure file.

| Component | When it runs | What it does |
|---|---|---|
| **Session-start hook** | Every session start | Injects standing compaction steering into context; on first run only, writes the checkpoint procedure to `~/.claude/context-kit/RECYCLING.md`. |
| **Post-compaction hook** | After every compaction — manual `/compact` or automatic | Injects an instruction to re-orient from this worktree's rolling handoff instead of trusting the summary. |
| **Checkpoint procedure** | Read by any session told to follow it | The measure-and-refresh discipline that keeps the rolling handoff current. Your single tweak point. |

## What changes automatically once enabled

All of the following happens without you asking. This list is exhaustive.

**At every session start** — including the session that resumes after a compaction — this text is
injected into your context:

> Standing compaction guidance (smallcontext plugin): When compacting, always preserve verbatim: (1) the
> absolute path of the plan/charter/handoff document governing the current task and the current
> phase/step within it; (2) the list of files created or modified this session; (3) the exact test
> commands in use and their latest results; (4) any unresolved error text; (5) spend figures against any
> stated envelope; (6) the next immediate action. Prefer dropping exploratory tool output and dead-end
> investigations over any of the above. After a compaction, re-read the governing document from disk
> before continuing work.

**Whenever it is absent** — so: your first session, and again any time you delete it —
`~/.claude/context-kit/RECYCLING.md` is created from the bundled copy. An existing file is left alone,
always. It's yours to edit.

**After every compaction**, a second instruction is injected *in addition to* the steering above (a
compaction is itself a session start, so both hooks fire). It tells the session to re-read this
worktree's rolling handoff — naming its path and age — to follow its orientation pointers governing-plan
first, to resume the in-flight task, to trust the file over the summary where they disagree, and not to
delete it. If no handoff exists, it instead says to re-read the durable documents governing the task:
the plan document if one exists, project `CLAUDE.md` pointers, and recent `git log`.

### Complete footprint

Exactly two paths are ever **written**:

| Path | Written when |
|---|---|
| `~/.claude/context-kit/RECYCLING.md` | Once, if absent. **Never overwritten** afterwards. |
| `~/.claude/handoffs/<slug>/ROLLING-HANDOFF.xml` | **Only when a session actually follows the checkpoint procedure.** The plugin never writes this on its own. |

And these are **read**:

| Path | Read when |
|---|---|
| `~/.claude/handoffs/<slug>/` | After a compaction, to find the rolling handoff. |
| Your repo's git top-level | After a compaction, to derive `<slug>` (`git rev-parse`). |
| `~/.claude/projects/<cwd-slug>/*.jsonl` | **Only when a session follows the checkpoint procedure**, to measure its own context usage. These are your session transcripts; they are read, never written or transmitted. |

`<slug>` is `<git-toplevel-basename>-<hash-of-path>` — falling back to the working directory when it
isn't a repo — giving each worktree its own silo. Nothing outside these paths is touched, and nothing
leaves your machine.

## Install

**Requirements:** `jq` and `git` on your `PATH` — both hooks shell out to them, and without `jq` they
produce no output and the plugin silently does nothing. macOS is the tested platform; on Linux
everything works except the handoff *age* in the re-orient text, which always reads `0 min ago` (the
script uses BSD `stat` syntax — see [DESIGN.md](docs/DESIGN.md)).

```bash
claude plugin marketplace add stevelautus/smallcontext
claude plugin install smallcontext@smallcontext
```

Hooks are snapshotted at session start, so **start a new session** for it to take effect.

**Enablement scope.** Both commands take a scope and both default to `user`. For user-wide install —
every project, including ones you clone tomorrow — the two commands above are all you need. To limit it
to select repos, scope *both* commands, or collaborators are left with a dangling
`smallcontext@smallcontext` reference:

```bash
# this repo, shared with collaborators (committed to .claude/settings.json)
claude plugin marketplace add stevelautus/smallcontext --scope project
claude plugin install smallcontext@smallcontext -s project

# this repo, only you (.claude/settings.local.json)
claude plugin marketplace add stevelautus/smallcontext --scope local
claude plugin install smallcontext@smallcontext -s local
```

**Developing against a local checkout** — point the marketplace at the directory instead. The checkout
registers under the same marketplace name (`smallcontext`), so remove the published one first:

```bash
claude plugin marketplace remove smallcontext
claude plugin marketplace add ./path/to/smallcontext
claude plugin install smallcontext@smallcontext
```

## Per-project setup: none

There isn't any. No bindings document, no project config, no `CLAUDE.md` edits, no per-repo
registration. Enable it once at user scope and every project is covered — including repos you clone
tomorrow. This is deliberate, and it's stated here so you don't go looking for the step you missed.

## Manual setup: two environment variables

This is the only manual step. Plugins cannot ship settings `env` variables, so these go in your
`~/.claude/settings.json` yourself:

```json
{
  "env": {
    "CLAUDE_AUTOCOMPACT_PCT_OVERRIDE": "38",
    "CLAUDE_CODE_AUTO_COMPACT_WINDOW": "1000000"
  }
}
```

The first sets the percentage of context capacity used that triggers auto-compaction — lowering it from
its ~95 default buys frequent, survivable flushes instead of one catastrophic one. The second exists
only to make the first work: on large-window models the percentage override is silently inert unless a
window is explicitly configured (via this variable or the `autoCompactWindow` setting).

`1000000` is the maximum accepted value and is clamped down to your model's real window, so the same
setting is correct whether you run a 200k or a 1M model — you are not inflating anything.

> **Tuning invariant:** keep the procedure's refresh threshold (60k, in `RECYCLING.md`) comfortably
> **below** the auto-compact trigger for the smallest window you run — otherwise compaction can strike
> before a rolling handoff exists, and there is nothing to re-orient from. The values above satisfy it.
> If you lower the percentage, re-check that ordering; move both numbers or neither.

Worked numbers, their caveats, and the forensics behind that second variable are in
[docs/DESIGN.md](docs/DESIGN.md).

## Using it

**With the smallplans plugin:** nothing to do. Its run skills already consult the procedure at every
checkpoint.

**Standalone:** tell any long-running session to follow `~/.claude/context-kit/RECYCLING.md` at its
checkpoints — for example, *"follow ~/.claude/context-kit/RECYCLING.md at every commit and phase
boundary."* The post-compaction hook works regardless, but it can only point at a handoff that a session
actually wrote.

## Test your install

Two minutes, and it needs a **new** session (hooks snapshot at session start):

1. Open a session in any repo and exchange a couple of messages.
2. Run `/compact`.
3. Ask: *"Did a hook just inject instructions? Quote them."*

You should see the re-orient text quoted back. In a repo with no rolling handoff yet — which is the
normal case on a fresh install — that's the generic fallback naming the durable docs, and it is the
correct result. To check the session-start half, ask a fresh session to quote its standing compaction
guidance, and confirm `~/.claude/context-kit/RECYCLING.md` now exists.

## Tuning & maintenance

- **Change the threshold** by editing `~/.claude/context-kit/RECYCLING.md` in place. The plugin never
  overwrites it, so your edit survives every update. Mind the tuning invariant above.
- **Pick up a new bundled version** after a plugin update by deleting that file; the next session
  re-materializes it. (Save your edits first — that's the trade for never being overwritten.)

## Uninstall / rollback

```bash
claude plugin uninstall smallcontext@smallcontext
claude plugin marketplace remove smallcontext
```

Pass the same `-s` you installed with (`uninstall` defaults to `-s user`); `claude plugin list` shows
each plugin's scope if you've forgotten.

Hooks deactivate with the plugin. Two leftovers are inert and removable at your leisure:
`~/.claude/context-kit/RECYCLING.md` and any rolling handoffs under `~/.claude/handoffs/`.

**The env vars are not inert — remove them too.** Left set, they keep forcing early compaction while the
re-orient hook is gone and nothing is maintaining a handoff, which is strictly worse than stock. They are
the one leftover that isn't safe to leave lying around.

## Design notes

[docs/DESIGN.md](docs/DESIGN.md) — why compaction is demoted rather than fought, the auto-compact trigger
math, the 1M-window inertness forensics, known limitations, and verification history.

## License

Apache-2.0
