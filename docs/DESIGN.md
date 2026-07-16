# smallcontext — design notes

Rationale, forensics, and known limitations. The [README](../README.md) covers what the plugin does and
how to install it; this file explains *why* it is shaped the way it is. Read it if you want to tune the
thresholds, understand the auto-compact trigger, or judge whether the approach fits your workflow.

## Why demote compaction instead of fighting it

The obvious reactions to auto-compact are to avoid it (keep sessions short) or to beat it (cram
everything important into the summary). Both fail on long autonomous runs.

Avoiding it means ending runs early, which is the exact thing you were trying not to do. Beating it is
worse, because it misunderstands the failure. The summary is not bad — it is *lossy in a way you cannot
predict*. It is produced by a prompt you do not control, at a moment you do not choose, from a context
you have already stopped being able to inspect. Any strategy whose correctness depends on the summary
containing a specific fact is a strategy that fails silently, later, in a way that looks like the model
"forgetting."

So this plugin makes the summary structurally uncritical. Continuity lives on disk, in a rolling handoff
refreshed cheaply at checkpoints. Immediately after any compaction, a hook injects an instruction to
re-read that file and trust it over the summary. The summary's job shrinks from *carry the run* to
*don't actively poison it* — a much weaker requirement, and one it reliably meets.

The consequence worth internalizing: **compaction stops being an event you avoid and becomes a flush you
survive.** Approaching the trigger is not a reason to wind down a run. That inversion is the whole point;
the bundled procedure states it explicitly so that long-running sessions don't quietly treat context
pressure as an exit condition.

## The trigger, and why two env vars

`CLAUDE_AUTOCOMPACT_PCT_OVERRIDE` sets the percentage of context capacity used that triggers
auto-compaction. It defaults to roughly 95; values above the default have no effect, and it applies to
subagents too. Lowering it makes compaction happen earlier and more predictably, which is what you want
when you have a disk-based continuity story: frequent, cheap, survivable flushes beat one catastrophic
one at 95%.

Setting that variable alone is not enough on large-window models, and the reason is the interesting part.

**Observed:** with the percentage override set, a run on a 1M-window model sailed past 500k tokens with
no compaction at all. The override was simply inert.

**Investigated:** the variable *was* being delivered (the settings `env` block does reach the process
environment, and it even hot-reloads into already-running sessions). Auto-compact was enabled. The
threshold function itself — roughly `min(floor(capacity × pct / 100), capacity − reserve)` — would have
produced a trigger far below where the run actually got.

**Diagnosed** (moderate confidence, read from minified code): on a model with a large window and no
*explicitly configured* auto-compact window, the window source resolves to `auto`, and that path bypasses
the percentage-aware threshold calculation entirely. The effective trigger stays at the default, up
around 90%+ of the window. This matches public reports of the override being ignored specifically on
1M-window models.

**Fix:** set `CLAUDE_CODE_AUTO_COMPACT_WINDOW` alongside it. An explicitly configured window flips the
source from `auto` to `env`, which activates the percentage path. That is why the README asks for two
variables rather than one: the second exists solely to make the first take effect.

### Worked numbers, and the tuning invariant

With the percentage at 38, the trigger lands around **~76k tokens on a 200k window** and **~356k on a 1M
window**. The bundled procedure's refresh threshold of **60k** sits below both — which is the entire
point of those particular numbers.

> **Tuning invariant:** the refresh threshold must stay comfortably below the auto-compact trigger for
> the *smallest* window you run. Otherwise compaction can strike before any rolling handoff exists, and
> the plugin has nothing to re-orient you from.

**Treat those two figures as approximations, and do not size your margin from them.** The trigger
depends on how capacity is derived for a given model — in particular how much of the window is reserved
before the percentage is applied — and independent readings of that arithmetic disagree, putting the
200k-window trigger anywhere from the high 60ks to ~76k. Every candidate leaves 60k below the trigger,
so the invariant holds either way; what varies is how *much* headroom you actually have, and on a 200k
window the honest answer is "less than the round numbers suggest — possibly under 10k."

That matters, because the procedure only refreshes at checkpoints. If your checkpoints are far apart, a
200k-window session can grow past the trigger between two of them and compact with no handoff on disk.
If you run 200k-window sessions and care about this, don't trust the arithmetic — watch your status
line's context-usage reading, checkpoint more often, or drop the refresh threshold well below 60k. The
ordering is the contract; the specific numbers are not.

If you lower the percentage (say to 20, moving a 1M trigger to roughly 187k), re-check that ordering.
Change both numbers together or neither.

Sessions on a large-window model will cross the 60k refresh threshold early and spend most of the run
above it. That is harmless by design: past the threshold the procedure re-refreshes only every ~20k
tokens of growth or at the next phase boundary, not at every checkpoint.

## Slug keying

The rolling handoff lives at `~/.claude/handoffs/<slug>/ROLLING-HANDOFF.xml`, and two independent actors
must derive the *same* `<slug>`: the compact-reorient hook (which reads the handoff after a compaction)
and the session that wrote it (following the checkpoint procedure). Whatever keys the slug has to be
computable by both, from what each can see.

The original key is the git top-level path: `<toplevel-basename>-<hash of the toplevel path>`. That is
one silo per repository — correct until two sessions share a repository, and one very common workflow
does exactly that.

**The collision.** Start a session at a repo's root, then have it create a git worktree and work inside
the worktree. The session's cwd stays the main checkout, so `git rev-parse --show-toplevel` returns the
main repo's path — for that session and for every other session started the same way. They all hash to
one slug and overwrite each other's `ROLLING-HANDOFF.xml`. Two concurrent worktree streams silently
share, and clobber, a single handoff. (The usage-measurement race in *Known limitations* below is a
documented limitation that only mistimes a refresh; this collision was undocumented and loses data.)

**Why the session id is the right key.** Weigh the candidates against the "both actors must compute it
independently" constraint:

- *Repo-path hash* — today's key. Collides, as above.
- *Worktree or branch* — the ideal semantic key, but the hook cannot derive it. After a compaction the
  hook reliably sees only the session's cwd (the main checkout) plus its hook-input JSON; it has no way
  to know which worktree the session subsequently created. Making it work would need the session to drop
  a pointer file the hook then reads — more moving parts, and a new thing to go stale.
- *Session id* — unique per concurrent session, stable across a compaction (a compaction keeps the same
  `session_id`), and derivable by *both* sides: the hook reads `.session_id` from its input JSON
  (falling back to the basename of `.transcript_path`), and the writing session knows its own id from
  its transcript / scratchpad path. It is the only collision-free key both actors can compute without
  coordinating.

So `session` mode keys on `<repo-basename>-<first 8 of the session id>`. The repo basename comes from
the git *common* dir (`git rev-parse --path-format=absolute --git-common-dir`), not the top-level, so a
main checkout and its linked worktrees still resolve to one name — only the session-id suffix separates
the silos. (`--path-format=absolute` needs git ≥ 2.31; on older git the derivation degrades cleanly to
the session's working-directory basename instead of emitting an error.)

**The trade-off.** A `session`-mode handoff is per-session: a *different* session on the same worktree
later cannot resume from it. That is acceptable because the handoff's only job is intra-session
compaction survival — surviving the flush *within* one run. Cross-session continuity is a separate
concern, already carried by in-repo plan / progress / charter docs any session can pick up.

**Why the default stays `repo`.** Switching keys would change every existing install's slug, orphaning
handoffs mid-run. So the new behavior is opt-in: unset or `SMALLCONTEXT_SLUG_MODE=repo` reproduces the
original slug byte-for-byte, and only `SMALLCONTEXT_SLUG_MODE=session` selects the new keying. Anyone who
never launches multiple sessions from one repo root never has to think about it.

## Known limitations

- **The summarizer's prompt is not ours.** The injected steering biases what the summary preserves; it
  cannot replace the summarization prompt. Steering is a nudge, not a contract — which is precisely why
  the design refuses to depend on it.
- **The usage measurement races.** The measurement one-liner picks the newest *non-agent* transcript in
  the project's directory by modification time. A second session in the *same* working directory can win
  that race. The consequence is an early or late handoff refresh — never data loss — so it is accepted
  rather than solved.
- **Injection timing after a mid-turn auto-compact** (does the session act on the injection immediately,
  or on the next loop iteration?) is believed immediate per the documentation, but is the hardest thing
  here to observe directly.
- **`stat(1)` is BSD/macOS syntax.** The re-orient hook reports the handoff's age using `stat -f %m`. On
  GNU/Linux that call fails and the script falls back to treating the file as freshly written, so the
  injection reports an age of 0 minutes. Everything else — finding the handoff, naming its path,
  instructing the re-read — works unchanged. The age is cosmetic; the fallback is deliberate.
- **The steering text is injected, not editable in place.** It ships inside the session-start hook. If
  you want different steering, put your own in a `CLAUDE.md`; both will be in context before compaction,
  and the duplication is harmless.

## Verification history

The mechanism has been exercised end to end rather than assumed:

- Both hook scripts were run against simulated hook input covering every branch — handoff present and
  absent, procedure file present and absent — asserting valid JSON output and, critically, that an
  existing procedure file is never overwritten.
- Installed as a plugin from a marketplace, a fresh session quoted the session-start steering back
  verbatim, confirming the injection arrives intact and carries its attribution prefix.
- A scratch session with a manual `/compact` confirmed the re-orient injection arrives in the rebuilt
  context, and that it coexists with other SessionStart hooks rather than displacing them — multiple
  hooks' `additionalContext` outputs concatenate, and a plugin-registered `compact` matcher is honored
  exactly like a settings-registered one.
- The never-overwrite guarantee was confirmed against a machine that already had a procedure file in
  place: installing and running the plugin left that file byte-for-byte unchanged, verified by checksum
  and by the file still carrying its local edits afterwards.
- The usage measurement one-liner was validated against a live session transcript.
- The 1M-window inertness described above was found *because* a real run failed to compact when it
  should have; the two-variable fix was confirmed against a subsequent run.
- **`SMALLCONTEXT_SLUG_MODE`** was exercised by running the compact-reorient hook against simulated
  hook input under a sandbox `HOME`, over disposable git fixtures (a main repo plus a linked worktree):
  repo mode (env unset) produced output byte-for-byte identical to the pre-change script and still
  resolved a handoff placed at the original path-hash slug; `session` mode with `session_id` present
  keyed on its first 8 chars, and with `session_id` absent fell back to the `transcript_path` basename;
  and a run whose cwd was the *linked worktree* resolved the repo basename from the git common dir — so
  it keyed on the main-repo name rather than leaking the worktree directory name. Every case asserted
  valid JSON on stdout and empty stderr. The session-start hook was run separately to confirm its
  no-overwrite guarantee still held by checksum.

The case that remains hardest to observe deliberately is a mid-turn *automatic* compaction interrupting
a long autonomous run — it self-confirms the first time a run crosses the line, which on a tuned setup
is a routine occurrence rather than a special event.
