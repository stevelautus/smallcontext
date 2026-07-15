#!/bin/bash
# smallcontext: SessionStart hook (all sources, no matcher).
# Two jobs, in order:
#   1. Materialize the bundled checkpoint procedure to the seam path
#      ~/.claude/context-kit/RECYCLING.md — but ONLY if nothing is there already.
#      An existing copy is the user's tweak point and is never overwritten.
#   2. Inject the standing compaction-steering text as additionalContext, so the
#      summarizer knows what to preserve. Plugins cannot ship CLAUDE.md content;
#      SessionStart additionalContext is the documented substitute.
# Registered in this plugin's hooks/hooks.json under hooks.SessionStart.
# Rollback: the "Uninstall / rollback" section of this plugin's README.

PLUGIN_ROOT=$(cd "$(dirname "$0")/.." 2>/dev/null && pwd)
SEAM_DIR="$HOME/.claude/context-kit"
SEAM="$SEAM_DIR/RECYCLING.md"

if [ ! -e "$SEAM" ] && [ -f "$PLUGIN_ROOT/docs/RECYCLING.md" ]; then
  mkdir -p "$SEAM_DIR" 2>/dev/null && cp "$PLUGIN_ROOT/docs/RECYCLING.md" "$SEAM" 2>/dev/null
fi

CTX="Standing compaction guidance (smallcontext plugin): When compacting, always preserve verbatim: (1) the absolute path of the plan/charter/handoff document governing the current task and the current phase/step within it; (2) the list of files created or modified this session; (3) the exact test commands in use and their latest results; (4) any unresolved error text; (5) spend figures against any stated envelope; (6) the next immediate action. Prefer dropping exploratory tool output and dead-end investigations over any of the above. After a compaction, re-read the governing document from disk before continuing work."

jq -n --arg ctx "$CTX" '{hookSpecificOutput:{hookEventName:"SessionStart",additionalContext:$ctx}}'
