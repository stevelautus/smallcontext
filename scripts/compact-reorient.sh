#!/bin/bash
# smallcontext: SessionStart(compact) hook.
# After any compaction (auto or manual), inject instructions to re-orient from disk
# (this worktree's rolling handoff) instead of trusting the lossy compaction summary.
# Registered in this plugin's hooks/hooks.json under hooks.SessionStart, matcher
# "compact". macOS stat(1) syntax.
# Rollback: the "Uninstall / rollback" section of this plugin's README.

INPUT=$(cat)
CWD=$(printf '%s' "$INPUT" | jq -r '.cwd // empty' 2>/dev/null)
[ -z "$CWD" ] && CWD="$PWD"

ROOT=$(git -C "$CWD" rev-parse --show-toplevel 2>/dev/null || printf '%s' "$CWD")
SLUG="$(basename "$ROOT")-$(printf '%s' "$ROOT" | shasum | cut -c1-8)"
DIR="$HOME/.claude/handoffs/$SLUG"

NEWEST=""
if [ -d "$DIR" ]; then
  NEWEST=$(ls -t "$DIR"/ROLLING-HANDOFF.xml 2>/dev/null | head -1)
fi

if [ -n "$NEWEST" ]; then
  NOW=$(date +%s)
  MTIME=$(stat -f %m "$NEWEST" 2>/dev/null || echo "$NOW")
  AGE_MIN=$(( (NOW - MTIME) / 60 ))
  CTX="Context was just compacted; the summary is lossy. Re-orient from disk before continuing: (1) read $NEWEST (written ${AGE_MIN} min ago); (2) follow its orientation pointers, governing plan/charter document first; (3) resume the in-flight task. Trust the disk state over the compaction summary wherever they disagree. Do NOT delete the rolling handoff file — it is reusable."
else
  CTX="Context was just compacted; the summary is lossy. Before continuing, re-read from disk the durable documents governing the current task (the plan/charter doc if one exists, project CLAUDE.md pointers, recent git log), then resume the in-flight task. Trust the disk state over the compaction summary wherever they disagree."
fi

jq -n --arg ctx "$CTX" '{hookSpecificOutput:{hookEventName:"SessionStart",additionalContext:$ctx}}'
