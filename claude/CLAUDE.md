# Orchestration Guide (for the main agent)

This project has several specialized agents/skills. Route incoming requests to the right one(s) automatically — the user shouldn't have to name an agent explicitly unless they're overriding your routing.

## Available specialists

- **feature-ideator** (`/ideate` skill) — for open-ended "what should we build" questions, or to sanity-check a specific idea before committing to planning it. Researches the actual codebase/stack/recent activity first, then discusses directions and limitations. Upstream of feature-planner — doesn't produce a spec, just a settled direction.
- **feature-planner** (`/plan` skill) — use FIRST for any non-trivial feature request, before any code gets written, once a direction is chosen (either straight from the user, or after an `/ideate` session). Interviews the user, never assumes. Skip only for genuinely trivial, fully-specified one-line changes.
- **feature-builder** (subagent) — implements code once a plan exists at `docs/plans/`, or for a request that's already fully specified. Implementation only — no tests, no lint/build, no commit. Never invoke this on an underspecified request; route to feature-planner instead.
- **code-reviewer** (subagent, opus, read-only) — reviews uncommitted changes against the plan with a fresh context. **Only runs when the user explicitly asks for it** — typically once they're satisfied with a feature and about to commit. Not an automatic step after feature-builder; don't invoke it on your own initiative.
- **test-runner** (subagent) — runs the project's actual existing test/lint/typecheck/build commands and reports pass/fail. Never fixes anything. Same trigger philosophy as code-reviewer: only runs when explicitly asked, not automatically after feature-builder.
- **qa-bug-hunter** (subagent) — tests a page/flow like a QA tester. Defaults to flag-only (frontend + backend). Only pass along a fix instruction if the user explicitly asked for fixes, and even then it only fixes frontend bugs.
- **wireframe-proposer** (subagent) — wireframe/mockup requests. Baseline-only mode with no new requirement, proposal mode (variants) with one.
- **claude-config-auditor** (subagent) — reviews the `.claude/` setup itself (agents, skills, CLAUDE.md) for redundancy, conflicts, and triggering issues.
- **researcher** (subagent) — public-web research (technical/tooling, market/competitor, user/domain, or any topic) that produces a cited report. Web-only: no codebase, no MCP/internal data. Needs a depth (focused or deep) in its prompt — **you must ask the user which depth before invoking it**, defaulting to suggesting focused. Not for codebase questions (feature-ideator / Explore) or for turning findings into a feature spec (feature-planner).

## Standard sequences

Note: some of these arrows are the top-level orchestrator's decision (you); others — feature-ideator's handoff to feature-planner, feature-planner's handoff to feature-builder — are performed by the skill itself (via Task), per its own SKILL.md. This list is a map of what happens, not a second copy of that control flow — if a handoff condition ever needs to change, change it in the skill file; this list just needs to keep describing it accurately.

- **"What should we build" / open-ended feature exploration** → feature-ideator → (direction settles) → feature-planner → feature-builder → (user reviews/tests informally, triggers code-reviewer whenever ready)
- **New feature, non-trivial, direction already clear** → feature-planner → (user approves the plan) → feature-builder → (user reviews/tests informally, triggers code-reviewer whenever ready)
- **"Review this before I commit" / "run the reviewer"** → code-reviewer, on its own, whenever the user asks — regardless of how the changes got there
- **"Test X"** → qa-bug-hunter, flag-only
- **"Test and fix X"** → qa-bug-hunter, with the fix instruction explicitly passed through
- **"Wireframe for X" + a new requirement** → wireframe-proposer (proposal mode). If the requirement itself is vague, prefer running feature-planner first — a fuzzy requirement produces fuzzy variants either way.
- **"Review/clean up my Claude setup"** → claude-config-auditor
- **"Research X" / "compare A vs B" / "what's the market for Y"** (external, web-based) → ask depth (focused/deep) → researcher. For deep research that splits into independent sub-questions, you may run several researcher instances in parallel (one per sub-question, each writing its own report) and synthesize.
- **"Run tests/lint/build on X" / "verify this builds"** → test-runner, on its own, whenever the user asks — not automatic after feature-builder

## Output Folder Protocol (shared by all report-generating agents)

Any agent/skill that saves standalone files (plans, research notes, reports, wireframes, audits) follows this exact procedure — defined once here so individual agent files don't need to repeat it.

**Config file:** `.claude/agent-output-config.json` in the project root. One key per agent, e.g. `{ "plansDir": "docs/plans", "qaReportsDir": "docs/qa-reports" }`.

**Procedure:**

1. Check the config file for this agent's key. If present, use it — don't ask again.
2. If absent, **there is no default, ever.** Get an explicit path from the user before creating anything:
   - If you have AskUserQuestion (Skills): ask directly, offering a couple of neutral path examples with no option marked as default, plus free text.
   - If you don't (subagents): stop your turn, state the question in plain text, and wait to be re-invoked with an explicit answer.
3. Once you have an explicit path: read the config file if it exists (so you don't clobber other agents' keys), set this key, write it back. If the file doesn't exist yet, create it with just this key.

**Keys in use:** `wireframesDir` (wireframe-proposer), `plansDir` (feature-planner), `researchDir` (feature-ideator), `qaReportsDir` (qa-bug-hunter), `reviewsDir` (code-reviewer), `auditDir` (claude-config-auditor), `testReportsDir` (test-runner), `researchReportsDir` (researcher). A new agent that saves files just needs a new key name added to this list and a one-line reference in its own file — not a copy of this whole section.

## Coordination rules

- Don't run feature-builder and qa-bug-hunter on the same files at the same time — sequence them (build, then test), don't parallelize.
- Never auto-invoke code-reviewer as part of a feature-building chain — it's a deliberate, user-triggered pre-commit step, not a pipeline stage you add on your own. (If/when the opt-in autonomous build pipeline drafted in `notes/autonomous-agent-setup.md` is actually built, it gets an explicit carve-out here — that pipeline's own invocation is itself the user's deliberate trigger. Until it's built, this rule has no exceptions.)
- Independent, non-overlapping work (e.g., a wireframe for feature A while qa-bug-hunter tests feature B) can run in parallel.
- If a request could plausibly map to more than one specialist, default to feature-planner as the tie-breaker — it surfaces the ambiguity to the user directly instead of you guessing.
- Never skip feature-planner to "save a step" on something that sounds simple but touches data model, API contracts, or has real edge cases — those are exactly the underspecified-requirement cases feature-planner exists for.

## Known gaps (not yet built)

These are known-missing specialists, flagged deliberately rather than built speculatively — each needs its own requirements interview (feature-planner-style) before being built, since inventing their scope now would just be guessing:

- **Dependency-update / vulnerability-triage specialist.** Routine lockfile bumps or `npm audit`-style findings don't map to any current agent.
- **Incident-response / production-debugging specialist.** qa-bug-hunter explicitly refuses staging/production, and code-reviewer only looks at uncommitted diffs — "prod is broken, help me debug" has no home yet.

<!-- agentwatch:correlation-start -->

## Agent & Skill Evolution Loop

Specialized agents/skills can't learn from weight updates — the only real lever is editing their `.md` definition. Treat improvement as a deliberate feedback → retro → eval loop, not something automatic:

- **Tag feedback per-specialist.** When a correction or confirmation is specifically about how one specialist performed (not a general user preference), save it as a `feedback`-type memory with `metadata.agent: <name>` set to its canonical name (`feature-ideator`, `feature-planner`, `feature-builder`, `code-reviewer`, `test-runner`, `qa-bug-hunter`, `wireframe-proposer`, `claude-config-auditor`, `researcher`). This is what lets a retro find everything relevant to one specialist later, across every project's memory folder — feedback about a global specialist doesn't belong to just the project it happened in.
- **Run retros deliberately.** Use the `agent-retro` skill (`/agent-retro`) to fold accumulated feedback for one specialist into its definition file. Never edit an agent/skill `.md` file based on feedback outside this flow — same reasoning as code-reviewer: it's a user-triggered step, not a pipeline stage you add on your own initiative.
- **Eval before trusting an edit.** `/agent-retro` checks `~/.claude/evals/<name>/` for that specialist's eval cases and runs them before and after a proposed edit, so "improved" is measured, not assumed. See `~/.claude/evals/README.md` for the case/result format.
