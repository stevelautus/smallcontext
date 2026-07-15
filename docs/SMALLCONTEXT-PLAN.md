# smallcontext — Plugin Packaging Plan

**Status:** see §11 (ratification block).
**Audience:** first Steve (review + ratification), then a fresh `/implement-plan` session.
**Branch:** `main` @ 3d1ccb7 (repo: `git@github.com:stevelautus/smallcontext.git`).
**Parent doc (requirements source):**
`/Users/ssmall/personal_code/occupal/docs/2026-07-15-claude-tooling-plugin-research.md` — "the research
doc" below. §2 inventories the source system, §5 the verified plugin mechanics, §6 this plugin's target
shape and the **pinned seam contract**, §7 the decision backlog (resolved here), §8 the ground rules and
source manifest. Where the research doc, this plan, and the live source files disagree, **live files
win** — flag the discrepancy, don't silently follow either document.

---

## 0. How to use this document

1. Read this file end to end, then skim the research doc's §5–§6 and §8 (mechanics, shape, ground rules).
2. All decisions are RESOLVED (§3). The implementing session does not relitigate.
3. Source files under `~/.claude/` are **read-only inputs** (§7 pre-auth 3). Porting copies content into
   this repo. The machine-level cutover is a separate attended operation — described in Appendix A,
   never executed autonomously.
4. Bootstrap note: this session itself runs on the user-level originals of the sibling system
   (`/implement-plan` is a `~/.claude/skills/` skill). Originals stay installed until both plugins
   (this one and `smallplans`) are built and verified. Nothing in this plan removes them.
5. Cost: expected app-level LLM spend is $0; envelope in §6.
6. Resume anchor: the §5 phase checkboxes plus the commit trail.

---

## 1. Goal and scope

**Ships:** an installable, open-source Claude Code plugin repo packaging the context kit (research doc
System 2 — compaction continuity). Concretely:

```
<repo root>/
├── .claude-plugin/
│   ├── plugin.json          # name "smallcontext", version 0.1.0
│   └── marketplace.json     # single-plugin repo doubling as its own marketplace
├── hooks/hooks.json         # two SessionStart entries (see §4.1)
├── scripts/
│   ├── session-start.sh     # NEW: materialize RECYCLING.md if missing + inject compaction steering
│   └── compact-reorient.sh  # ported, with retirement edits (see §4.2)
├── docs/
│   ├── RECYCLING.md         # bundled master of the checkpoint procedure (see §4.3)
│   ├── DESIGN.md            # rationale, forensics, limitations (mined from kit README — see §4.5)
│   └── SMALLCONTEXT-PLAN.md # this file
├── CLAUDE.md                # minimal, for this repo's own development (see §4.6)
├── LICENSE                  # Apache-2.0, already committed
└── README.md                # the flagship deliverable (see §4.4)
```

The plugin ships **no user-invocable skills** — it is pure infrastructure: two hooks, the bundled
checkpoint procedure, and documentation.

**Non-goals:** no behavior changes to the ported system beyond the decisions in §3 (port faithfully);
no `${CLAUDE_PLUGIN_DATA}` migration and no seam-path rename (both explicitly out of scope per the
research doc §6); no cutover execution (Appendix A is descriptive only); no touching the `smallplans`
repo or any file under `~/.claude/`; no marketplace publication steps beyond pushing this public repo
(installing from GitHub is the reader's act, documented in the README).

**The pinned seam contract (research doc §6, binding, not renegotiable here):** the checkpoint procedure
lives at `~/.claude/context-kit/RECYCLING.md`. This plugin's SessionStart hook materializes it there from
the bundled `docs/RECYCLING.md`; the `smallplans` run skills reference that exact path with their
existing fail-soft clause. The path keeps its pre-plugin directory name deliberately. Do not rename it.

## 2. Current state (verified against disk 2026-07-15)

**This repo:** nearly empty — `LICENSE` (Apache-2.0) and a one-line stub `README.md`; clean tree;
`main` pushed to `origin` (`stevelautus/smallcontext`). `/implement-plan`'s fresh-start gate needs this
plan committed and pushed, nothing else.

**Source material (all read-only, all verified to match the research doc's descriptions):**

| Source | Verified state |
|---|---|
| `~/.claude/context-kit/compact-reorient.sh` | 31 lines; matches research doc §2. Contains the two retirement targets: the `HANDOFF-*.xml` fallback glob (line 19) and the `/resume-handoff` aside in the injected text (line 26). |
| `~/.claude/context-kit/RECYCLING.md` | 67 lines; threshold **60000 tokens**; contains the retirement targets: "derived exactly as the `/handoff` skill derives it" (slug), "the `/handoff` skill's document structure" (content spec), the `/resume-handoff` deletion-rule aside (post-compaction §2), a `HANDOFF-*.xml` mention (post-compaction §1), and references to the smallplans skills and to a README "beside this file". |
| `~/.claude/context-kit/README.md` | 96 lines; mining source for README/DESIGN.md: rationale, 1M-window forensics, live-test recipes, rollback, tuning invariant. **Known drift:** its component table says "80k-token threshold" — stale; RECYCLING.md's 60k is authoritative (the README's own later prose documents the 80k→60k change). Do not port the stale number. |
| `~/.claude/settings.json` | Confirmed: `env` block carries `CLAUDE_AUTOCOMPACT_PCT_OVERRIDE=38` and `CLAUDE_CODE_AUTO_COMPACT_WINDOW=1000000`; `hooks.SessionStart` carries the matcher-`"compact"` entry pointing at the kit script (plus an unrelated GSD entry — never touch it). |
| `## Compaction (context-kit)` section of `~/.claude/CLAUDE.md` | Present; content embedded verbatim in the research doc §8 ("the content is settled"). |

No other discrepancies found between the research doc and disk.

## 3. Decisions (all resolved; none open)

| # | Decision | Source |
|---|---|---|
| D1 | Repo shape per research doc §6; single-plugin repo doubling as its own marketplace. | Research doc (locked 2026-07-15) |
| D2 | Seam contract pinned as quoted in §1. | Research doc §6 |
| D3 | **Compaction steering ships as hook injection**, not a CLAUDE.md snippet: `session-start.sh` injects the settled steering text as `additionalContext` at every session start. Rationale: zero-manual-step install for the public audience; the manual-setup section shrinks to the two env vars. The README documents the injected text; users wanting custom steering use their own CLAUDE.md (duplication is harmless). | Steve, 2026-07-15 interview (§7.4 of research doc) |
| D4 | **Drop the legacy `HANDOFF-*.xml` fallback glob** from the shipped `compact-reorient.sh` — reads only `ROLLING-HANDOFF.xml`. The retired handoff pair isn't shipped, so fresh installs can never produce timestamped files; Steve's user-level hook keeps the glob until cutover. | Steve, 2026-07-15 interview (retirement edit c) |
| D5 | **Materialize-if-missing**: `session-start.sh` creates `~/.claude/context-kit/RECYCLING.md` from the bundled master only when absent; it never overwrites an existing copy. Preserves the file's "single tweak point" property (user edits the 60k threshold in place) and guarantees verification on this machine cannot touch the live kit's copy. Picking up a newer bundled version = delete the file, start a session. README documents this. | Steve, 2026-07-15 interview |
| D6 | Marketplace name `smallcontext`; enable key `smallcontext@smallcontext`. | Steve, 2026-07-15 interview |
| D7 | LICENSE: Apache-2.0 (already committed at repo root before planning began). | Steve, via repo setup |
| D8 | `plugin.json` version `0.1.0`; public repo → deliberate version pinning per research doc §5. | Assumption presented 2026-07-15, unvetoed |
| D9 | `hooks/hooks.json` registers **two** SessionStart entries: matcher-less (`session-start.sh` — materialize + steering, fires on every source including `compact`) and matcher `"compact"` (`compact-reorient.sh` — re-orient injection). Rationale: the compact matcher alone would never materialize RECYCLING.md before a first compaction, but run-skill checkpoints need it from session one. | Assumption presented 2026-07-15, unvetoed |
| D10 | README stays lean; design rationale, 1M-window forensics, and known limitations go to `docs/DESIGN.md`. Rationale: Steve's brief — don't drown the vital content. | This plan (fits the brief) |
| D11 | After live verification passes, the run **removes** its marketplace registration + enable additions — the machine returns to its exact pre-run state. The attended cutover re-enables later. | Steve, 2026-07-15 interview |
| D12 | Spend envelope $2 nominal (§6). | Steve, 2026-07-15 interview |

## 4. Shipped-content specifications

### 4.1 `hooks/hooks.json`

Same event format as settings hooks (research doc §5), script paths via `${CLAUDE_PLUGIN_ROOT}`:

```json
{
  "hooks": {
    "SessionStart": [
      {
        "hooks": [
          { "type": "command", "command": "${CLAUDE_PLUGIN_ROOT}/scripts/session-start.sh" }
        ]
      },
      {
        "matcher": "compact",
        "hooks": [
          { "type": "command", "command": "${CLAUDE_PLUGIN_ROOT}/scripts/compact-reorient.sh" }
        ]
      }
    ]
  }
}
```

Verify the exact top-level wrapping (`hooks` key present or not) against current docs at build time —
whichever form the docs specify, keep both entries and the matcher semantics above. Multiple hooks'
`additionalContext` outputs concatenate (verified live 2026-06-10 coexisting with other SessionStart
hooks); post-compaction the session legitimately receives both injections (steering + re-orient).

### 4.2 `scripts/compact-reorient.sh` (ported, 3 edits)

Port `~/.claude/context-kit/compact-reorient.sh` verbatim except:

1. **Header comment block**: registration is now `hooks/hooks.json` in this plugin (not
   `~/.claude/settings.json`); rollback pointer → the plugin README's uninstall section.
2. **Glob (D4)**: the newest-handoff lookup becomes
   `NEWEST=$(ls -t "$DIR"/ROLLING-HANDOFF.xml 2>/dev/null | head -1)` — drop `HANDOFF-*.xml`.
3. **Injected text (retirement edit b)**: in the handoff-found branch, replace the trailing
   "Do NOT delete the handoff file — the one-shot /resume-handoff deletion rule does not apply to a
   post-compaction re-read." with "Do NOT delete the rolling handoff file — it is reusable." The rule
   survives; the retired-skill citation does not.

Everything else — slug derivation, macOS `stat -f %m`, the no-handoff fallback branch, the jq output
shape — ports unchanged.

### 4.3 `docs/RECYCLING.md` (ported, retirement edit a + reference scrub)

Port `~/.claude/context-kit/RECYCLING.md` with these edits, preserving the 60k threshold, the tuning
invariant, and all procedure semantics:

1. **Inline the handoff document structure** (retirement edit a). Replace "Content: the `/handoff`
   skill's document structure, sized small" with the structure itself: a rolling handoff is an XML doc
   with sections `metadata` / `orientation` / `reference_documents` / `memory_context` /
   `files_in_play` / `project_state` / `session_work_log` / `next_session_brief` / `gotchas` /
   `decisions_carryover` — sized small (running snapshot, not a session epitaph), must-haves being
   `metadata` with a crisp `next_immediate_action`, `orientation` whose first pointer is the governing
   plan/charter document, `files_in_play`, `project_state`, `gotchas`, `decisions_carryover`.
   Point, don't copy.
2. **Slug derivation stands alone**: drop "derived exactly as the `/handoff` skill derives it" — the
   bash block already in the file is the definition.
3. **Post-compaction section**: drop the `HANDOFF-*.xml` mention (re-read target is
   `ROLLING-HANDOFF.xml`, matching D4) and replace the `/resume-handoff` deletion-rule sentence with
   the bare rule: "Do NOT delete the rolling handoff. It is reusable."
4. **Header re-aim**: "Referenced by the `stream-work`, `implement-plan`, and `plan-feature` skills"
   becomes a sentence true for the public audience — referenced by the smallplans run skills when that
   plugin is installed; any long session can be asked to follow this procedure directly. "Design
   rationale and rollback: README.md beside this file" → point at the smallcontext plugin repo (the
   materialized copy sits alone in `~/.claude/context-kit/`).
5. **Env-var mention made conditional**: "`CLAUDE_AUTOCOMPACT_PCT_OVERRIDE=38` is set globally" becomes
   "if set per the plugin README" phrasing — a fresh install may not have set it yet; the invariant
   sentence (refresh threshold stays below the smallest-window trigger) ports verbatim.

### 4.4 `scripts/session-start.sh` (new, small)

Responsibilities, in order:

1. **Materialize (D5):** if `~/.claude/context-kit/RECYCLING.md` does not exist, `mkdir -p` the
   directory and copy the bundled master into place. Never overwrite. Resolve the bundled master
   `$0`-relative (`"$(cd "$(dirname "$0")/.." && pwd)/docs/RECYCLING.md"`) — robust regardless of env;
   if the docs confirm `CLAUDE_PLUGIN_ROOT` is exported to hook processes, either form is fine.
2. **Inject steering (D3):** emit the settled compaction-steering text as SessionStart
   `additionalContext` (same jq output shape as `compact-reorient.sh`). Content — port verbatim from
   the research doc §8 blockquote (== the live `~/.claude/CLAUDE.md` section body, sans heading):

   > When compacting, always preserve verbatim: (1) the absolute path of the plan/charter/handoff
   > document governing the current task and the current phase/step within it; (2) the list of files
   > created or modified this session; (3) the exact test commands in use and their latest results;
   > (4) any unresolved error text; (5) spend figures against any stated envelope; (6) the next
   > immediate action. Prefer dropping exploratory tool output and dead-end investigations over any of
   > the above. After a compaction, re-read the governing document from disk before continuing work.

   Prefix it with one orienting clause (e.g. "Standing compaction guidance (smallcontext plugin): …")
   so a user quoting their injected context can attribute it.

Keep it fast (runs every session start) and silent on stderr.

### 4.5 `docs/DESIGN.md` (mined from `~/.claude/context-kit/README.md`)

Carries what the README deliberately omits (D10): why compaction is demoted rather than fought
(rationale), the auto-compact trigger math and the 1M-window inertness forensics (why
`CLAUDE_CODE_AUTO_COMPACT_WINDOW` must accompany the pct override), the tuning invariant with worked
numbers (38% → ~76k trigger on 200k, ~356k on 1M; 60k refresh sits under both), known limitations
(summarizer prompt not replaceable, mtime race on the usage one-liner, mid-turn injection timing), and
verification history recast generically. Sanitize per §4.7: no names, no machine paths, no references
to unrelated local tooling (GSD, claude-mem), no Max-plan cost anecdotes; use the corrected 60k number.

### 4.6 `README.md` — the flagship deliverable

Steve's brief verbatim: the README must contain everything a user needs to understand what
commands/functionality is available, how to access it, and what parts cause automatic/ongoing behavior
changes; optimize for maximum user-friendliness — structured layout, succinct, no drowning of vital
content. **Acceptance criteria — the README must contain, in roughly this order:**

1. **One-paragraph pitch.** Long Claude Code sessions degrade when auto-compact replaces history with a
   lossy summary; smallcontext demotes compaction to a survivable flush — continuity lives on disk.
2. **"What you get" table** — explicit up front that there are **no slash commands or skills**; the
   plugin is pure infrastructure. Three rows: session-start hook / post-compaction hook / bundled
   checkpoint procedure — each with *when it runs* and *what it does* in one line.
3. **"What changes automatically once enabled"** — the section the brief demands, prominent, exhaustive
   and honest: (a) every session start: the steering text is injected into context (shown or linked
   verbatim) and, first time only, `~/.claude/context-kit/RECYCLING.md` is created; (b) after every
   compaction (manual or auto): a re-orient instruction is injected pointing at this worktree's rolling
   handoff if one exists. Plus the complete on-disk footprint: the one materialized file, and
   `~/.claude/handoffs/<slug>/ROLLING-HANDOFF.xml` — written **only** when a session actually follows
   the checkpoint procedure, not by the plugin autonomously. Nothing else is read or written.
4. **Install** — marketplace add (GitHub form) + enable, and the local-checkout directory form for
   development; exact commands.
5. **Manual setup (the only one): the two env vars** — the `env` block snippet
   (`CLAUDE_AUTOCOMPACT_PCT_OVERRIDE`, `CLAUDE_CODE_AUTO_COMPACT_WINDOW`) with two sentences on what
   they do and the **tuning invariant** (keep RECYCLING.md's refresh threshold below the auto-compact
   trigger for the smallest window in use). Deeper math → DESIGN.md link.
6. **Using it** — for smallplans users: automatic at checkpoints. Standalone: tell any long-running
   session to follow `~/.claude/context-kit/RECYCLING.md` at its checkpoints.
7. **Test your install** — the 2-minute recipe: NEW session (hooks snapshot at session start), exchange
   messages, `/compact`, ask the session to quote what was just injected.
8. **Tuning & maintenance** — edit the threshold in the materialized file (the plugin never overwrites
   it); delete the file to re-materialize the bundled version after a plugin update.
9. **Uninstall / rollback** — disable the plugin (hooks deactivate with it); leftovers are inert and
   removable at leisure: the materialized RECYCLING.md, rolling handoffs under `~/.claude/handoffs/`,
   the manually-set env vars.
10. **Link to DESIGN.md** for rationale and forensics.

Length discipline: if a section can't be skimmed in ~15 seconds, its detail belongs in DESIGN.md.

### 4.7 Sanitization sweep (research doc §7.10) — applies to every shipped file

Grep checklist over all shipped content (scripts, docs, README, manifests):
`Steve`, `ssmall`, `/Users/`, `occupal`, `smallplans`-machine-specifics, `GSD`, `claude-mem`,
`Max` (plan-cost anecdotes), `py3_bootstrap_venv`. Personal/machine specifics recast as generic
illustrations; references to Steve's other local tooling dropped. `stevelautus` in install examples is
fine (it's the public repo path). The smallplans *plugin* may be referenced by name (the seam is real);
Steve's machine state may not.

### 4.8 Repo `CLAUDE.md` (minimal, ~15 lines)

For future development sessions in this repo: this is a Claude Code plugin — the shipped files ARE the
product, so prose edits change live behavior of installs; sources under `~/.claude/` were read-only
porting inputs, not part of this repo; the seam contract (§1) is pinned; sanitization rule §4.7 applies
to every shipped file; test commands are the §5 Phase-2 checks; plan doc at `docs/SMALLCONTEXT-PLAN.md`.

## 5. Phase plan

Each phase ends at a natural safe point with an atomic green commit; checkboxes are the resume anchor.

### Phase 1 — Scaffold & manifests
- [ ] `.claude-plugin/plugin.json`: `name: "smallcontext"`, `version: "0.1.0"`, one-line description
      (+ author/repo fields as current docs support).
- [ ] `.claude-plugin/marketplace.json`: `name: "smallcontext"`, `owner`, one plugin entry with
      `"source": "./"`.
- [ ] Verify: both files `jq`-valid; field names checked against current plugin-reference docs
      (claude-code-guide agent or official docs — do not trust training data).
- [ ] Commit.

*Note: the `"source": "./"` form gets its live test in Phase 5; if registration rejects it, nesting
under `plugins/smallcontext/` is the documented-safe fallback (pre-authorized deviation — record it
under §9 follow-ups and update marketplace.json + paths accordingly).*

### Phase 2 — Port scripts, procedure, hooks
- [ ] `scripts/compact-reorient.sh` per §4.2.
- [ ] `scripts/session-start.sh` per §4.4.
- [ ] `docs/RECYCLING.md` per §4.3.
- [ ] `hooks/hooks.json` per §4.1 (wrapping form verified against current docs).
- [ ] Verify: `bash -n` both scripts; execute both with simulated hook stdin
      (`{"cwd": "<scratch>", ...}`) covering all branches — compact-reorient with and without a rolling
      handoff present; session-start against a **sandbox `HOME`** (`HOME=<scratchdir> script`) proving
      (a) materialization when the file is absent, (b) **no overwrite** when a sentinel-modified copy
      exists, (c) valid jq `additionalContext` output both times. No real machine state touched.
- [ ] Commit.

### Phase 3 — Sanitization sweep
- [ ] Run the §4.7 grep checklist over every shipped file; fix all hits (or record a justified
      exception under §9).
- [ ] Verify: checklist greps return clean; re-run Phase 2's script checks (edits must not break
      behavior).
- [ ] Commit.

### Phase 4 — README, DESIGN.md, repo CLAUDE.md
- [ ] `docs/DESIGN.md` per §4.5.
- [ ] `README.md` per §4.6 — every numbered acceptance criterion present.
- [ ] `CLAUDE.md` per §4.8.
- [ ] Verify: self-review README against the §4.6 list item by item; §4.7 greps clean on all three;
      every path/command in the README is literally correct (install commands, file paths, env keys).
- [ ] Commit.

### Phase 5 — Live verification (research doc §7.9; pre-auths 4–5)
- [ ] Snapshot pre-state: checksum `~/.claude/context-kit/RECYCLING.md`; copy of settings/plugin-config
      state that registration will touch.
- [ ] Register this checkout as a directory-source marketplace; enable `smallcontext@smallcontext`
      (additive only). This is also the live test of `"source": "./"` (see Phase 1 note).
- [ ] NEW scratch session (hooks snapshot at session start — the current session can never see them):
      confirm the session-start steering injection arrives (ask the session to quote it); run
      `/compact`; confirm the plugin's re-orient injection fires. **Expected pre-cutover:** the
      user-level kit hook fires too — two re-orient blocks, distinguishable because the plugin's copy
      lacks the `/resume-handoff` sentence. Duplicates are expected and harmless; only the plugin
      copy's presence and correctness are under test.
- [ ] Confirm the live `~/.claude/context-kit/RECYCLING.md` checksum is **unchanged** (D5 holds).
      Mismatch = hard stop (§8).
- [ ] Remove the marketplace registration + enable entries (D11); diff-confirm settings/plugin state
      matches the pre-state snapshot exactly.
- [ ] Record verification results (what fired, quoted snippets, any deviations) under §9.
- [ ] Commit (doc updates only).

### Phase 6 — Closeout
- [ ] Update this doc: all checkboxes, §9 follow-ups, honest final status.
- [ ] Push branch; open PR into `main` per `/implement-plan` closeout; report the PR URL.
- [ ] Appendix A (cutover) remains untouched and unexecuted.

## 6. Spend envelope

**$2 (Steve, 2026-07-15).** Expected spend: **$0** — this build is file porting, prose, and manifests;
no app exists to make LLM calls, and no metering mechanism (no `LLMCallRecord` analogue) exists in this
repo. Should a step genuinely require an ad-hoc LLM API call, it may proceed within the envelope only
if each call and its estimated cost are logged under §9; the envelope is a hard ceiling. Claude-session
usage itself is plan usage, outside this envelope, as always.

## 7. Pre-authorizations

Runs under this plan may, without asking:

1. Spend to the §6 envelope, with per-call logging under §9.
2. Make minor documented plan deviations (recorded under §9).
3. **Read** (never write) the research doc and the source paths it manifests for smallcontext:
   `~/.claude/context-kit/{compact-reorient.sh,RECYCLING.md,README.md}` and the `env` +
   `hooks.SessionStart` blocks of `~/.claude/settings.json` (Steve's standing grant, research doc §8).
4. **Phase-5 machine-state grant (Steve, 2026-07-15):** register this checkout as a directory-source
   marketplace and enable `smallcontext@smallcontext` — additive changes only, touching nothing else —
   and afterwards remove exactly those additions (D11). Includes launching scratch Claude sessions for
   the hook tests.
5. Fall back to `plugins/smallcontext/` nesting if `"source": "./"` fails registration (Phase 1 note) —
   a documented deviation, not a stop.

Nothing else. No destructive carve-outs exist or are needed; the only deletion permitted anywhere is
pre-auth 4's removal of additions the run itself made.

## 8. Hard-stop additions (beyond /implement-plan's standard set)

- Any prospective modification outside this repo beyond pre-auth 4's exact scope → stop and ask.
- Phase 5 finds the live `~/.claude/context-kit/RECYCLING.md` checksum changed → stop immediately and
  report; do not attempt repair (restoration is attended; the kit's `backups/` exist).
- Plugin mechanics diverge from the research doc §5's verified claims in a way that would require a
  machine-state workaround (e.g. `${CLAUDE_PLUGIN_ROOT}` not substituted, plugin SessionStart matcher
  `"compact"` not honored) → stop and report findings rather than working around.

## 9. Follow-ups / queued

*(empty at ratification; runs append here — deviations, spend log, verification results, discovered
work for later.)*

## 10. Migration expectations

None. No database, no schema, no data migrations of any kind.

---

## 11. Ratification block

**Status: DRAFT — not ratified.**

Ratification covers exactly:

1. Decisions D1–D12 (§3) as written, including the four interview resolutions of 2026-07-15
   (D3 steering-by-injection, D4 drop legacy glob, D5 materialize-if-missing, D6 marketplace name)
   and the two unvetoed assumptions (D8 version 0.1.0, D9 two-hook design).
2. The shipped-content specifications (§4), including the README acceptance criteria (§4.6) and the
   sanitization checklist (§4.7).
3. The six phases and their verification criteria (§5).
4. The $2 spend envelope and its logging rule (§6).
5. Pre-authorizations 1–5 (§7) — notably the Phase-5 machine-state grant and its D11 removal duty.
6. The hard-stop additions (§8).
7. Appendix A as *description only*: the cutover is attended, never autonomous.

Kickoff after ratification: `/implement-plan docs/SMALLCONTEXT-PLAN.md` in a fresh session.

---

## Appendix A — Machine cutover (ATTENDED ONLY; not part of any autonomous run)

For Steve, after BOTH plugins are built and verified, in one sitting (never leave both hook
registrations active across sessions — research doc §7.5):

1. Re-register/enable the plugin (`smallcontext@smallcontext`).
2. Remove from `~/.claude/settings.json` the `hooks.SessionStart` entry with matcher `"compact"`
   (leave the GSD entry and everything else untouched); validate with `jq`.
3. Remove the `## Compaction (context-kit)` section from `~/.claude/CLAUDE.md` (the plugin now injects
   equivalent steering — keeping both is harmless duplication, removing it is cleaner).
4. Keep the two env vars — they remain manual by design.
5. `~/.claude/context-kit/` disposition: the live `RECYCLING.md` there is now the materialized seam
   file (already in place; the plugin will not touch it). The kit's `README.md` and `backups/` are
   historical records — keep or archive at leisure. Do **not** delete `RECYCLING.md` unless the intent
   is to adopt the plugin's bundled version (it re-materializes next session).
6. The retired `/handoff` + `/resume-handoff` skill dirs and `~/.claude/commands/prepnextconvo.md`:
   separate keep-or-delete calls, unrelated to this plugin.
