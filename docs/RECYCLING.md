# Context recycling procedure (smallcontext)

Referenced by the smallplans run skills (`stream-work`, `implement-plan`, `plan-feature`) when that
plugin is installed; any long-running session can also be told to follow this procedure directly. This
file is the single tweak point: edit the threshold or the procedure here and every referencing skill
inherits the change. Design rationale and rollback: the smallcontext plugin's README and DESIGN.md.

## Why

Auto-compact replaces conversation history with a lossy summary at a moment you don't control. This kit
demotes it to a mere context flusher: continuity lives on disk, refreshed cheaply at checkpoints, and a
SessionStart hook re-points the session at the disk state immediately after any compaction. The summary
then only has to not-poison; it no longer has to carry the run.

## At every checkpoint (each commit / phase boundary / major doc section)

1. **Measure context usage** (~1s, run from the project root):

   ```bash
   TD="$HOME/.claude/projects/$(printf '%s' "$PWD" | sed 's|[^a-zA-Z0-9]|-|g')"
   T=$(ls -t "$TD"/*.jsonl 2>/dev/null | grep -v '/agent-' | head -1)
   tail -80 "$T" | jq -rs '[.[] | select(.isSidechain != true) | .message.usage // empty
     | (.input_tokens + .cache_creation_input_tokens + .cache_read_input_tokens)] | last // 0'
   ```

   This reads the newest non-agent transcript in this project's directory, which is almost always the
   current session. A concurrent session in the SAME working directory can occasionally win the mtime
   race; the consequence is only an early or late handoff refresh, so accept it.

2. **Threshold: 60000 tokens.** (The number to edit when tuning. Constraint: keep it comfortably BELOW
   the auto-compact trigger in tokens for the smallest window you run, so a rolling handoff always
   exists before compaction can strike. With `CLAUDE_AUTOCOMPACT_PCT_OVERRIDE=38` set per the plugin
   README, the trigger sits at ~76k tokens on a 200k window and ~356k on a 1M window; 60k sits under
   both. Sessions on a 1M-window model hit this early; that is harmless given the re-refresh rule
   below.)

3. **Below threshold** → continue, nothing else to do.

4. **At or above threshold** → refresh the rolling handoff, then continue working:
   - Path: `~/.claude/handoffs/<slug>/ROLLING-HANDOFF.xml`, where `<slug>` is:
     ```bash
     ROOT="$(git rev-parse --show-toplevel 2>/dev/null || pwd)"
     SLUG="$(basename "$ROOT")-$(printf '%s' "$ROOT" | shasum | cut -c1-8)"
     ```
   - Content: an XML document with the sections `metadata`, `orientation`, `reference_documents`,
     `memory_context`, `files_in_play`, `project_state`, `session_work_log`, `next_session_brief`,
     `gotchas`, `decisions_carryover` — sized small: this is a running snapshot, not a session epitaph.
     Must-haves: `metadata` with a crisp `next_immediate_action`, `orientation` whose first pointer is
     the governing plan/charter document, `files_in_play`, `project_state`, `gotchas`,
     `decisions_carryover`. Point, don't copy.
   - **OVERWRITE the file in place** with the Write tool. Never create timestamped copies here and never
     delete anything.
   - Once over threshold, refresh again only after roughly 20k further token growth or at the next phase
     boundary, whichever comes first — not at every commit.

Approaching the compaction trigger is never a reason to stop, wind down, or end a run: refresh the
handoff and keep working straight through the flush. Compaction is a survivable flush, not an exit —
that survivability is this kit's entire purpose.

## After a compaction

You will know a compaction happened because the compact-reorient hook injects instructions (and the
conversation history visibly becomes a summary). Then:

1. **Re-read from disk before continuing**: `ROLLING-HANDOFF.xml` for this worktree, then the governing
   plan/charter document it names, then any files in play it flags.
2. **Do NOT delete the rolling handoff. It is reusable.**
3. **Trust disk over the compaction summary** wherever they disagree.
4. Resume the in-flight task.
