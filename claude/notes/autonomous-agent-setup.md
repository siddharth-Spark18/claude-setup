# Autonomous agent-driven dev setup — research & design notes

Status: **not yet built**. This is a saved design draft from a research session on 2026-09-07, to pick back up later.

Goal (from user): a global (with project-level override) Claude Code setup where a big task gets planned, decomposed into chunks, executed in parallel by subagents where possible, then reviewed from a fresh point of view, with structured feedback looping back to the main/coordinating agent for revision.

## Scope decisions made so far

- **Global vs project**: setup should live in `~/.claude` (agents/skills) as the default, with the ability to override/extend per project via project-level `.claude/` config (project config already takes precedence over user-level in Claude Code, so this falls out naturally).
- **Merge/commit autonomy**: after parallel subagents finish in separate git worktrees, **auto-merge into an integration branch, but never auto-commit** — user reviews the diff and commits themselves. Matches the standing rule that commits/pushes always need explicit go-ahead.
- **Trigger mechanism for the pipeline**: **not yet decided.** Options considered were (a) a new dedicated skill/slash command (e.g. `/autobuild`) as an explicit opt-in per big task — recommended, purely additive, leaves the existing manual plan→build→(user-triggered)review flow untouched; (b) extending `feature-planner` with an autonomy toggle; (c) making it the automatic default for any non-trivial build request. Need to pick one before implementing.

## Key conflict to resolve before building

The existing global `~/.claude/CLAUDE.md` orchestration guide has an explicit rule: *"Never auto-invoke code-reviewer as part of a feature-building chain — it's a deliberate, user-triggered pre-commit step, not a pipeline stage you add on your own."* The new autonomous pipeline directly wants an automatic review→feedback loop, which conflicts with this. Recommended resolution: don't change that rule for the default/manual flow — add the automatic loop as a **separate, deliberately-invoked path** (its own skill/command) that the user opts into per task, rather than changing what happens by default when using feature-planner/feature-builder normally.

## Research findings

### From Anthropic's own published patterns
- **"Building Effective Agents"** (anthropic.com/engineering/building-effective-agents) names 5 composable workflow patterns, not a framework: prompt chaining, routing, parallelization (sectioning vs. voting), **orchestrator-workers** (explicitly recommended for coding tasks where files/changes can't be predicted upfront — this is our use case), and **evaluator-optimizer** (generator + separate critic loop — this is the "review → feedback → revise" pattern we want). Core caveat: start with a single well-optimized prompt; add agentic complexity only when that falls short.
- **"How We Built Our Multi-Agent Research System"** (anthropic.com/engineering/multi-agent-research-system, June 2025): lead agent plans, decomposes into subtasks with explicit objective/output-format/tool guidance/boundaries, spawns 3–5 subagents in parallel, synthesizes. Each subagent gets a clean/isolated context window. **Failure modes they hit**: vague instructions → subagents duplicated work; early versions over-spawned (50 subagents for a simple query) or searched endlessly. Fix was explicit scaling rules baked into prompts (simple query = 1 agent, complex = 10+ with divided labor) and very specific per-agent task boundaries. Cost: multi-agent runs ~15x the tokens of a single chat — only justified when task value is high.
- **Claude Code subagent mechanics** (code.claude.com/docs): subagents defined via YAML frontmatter (`tools`/`disallowedTools`, `model`, `isolation: worktree`, `maxTurns`, `effort`); fresh context by default (not the parent's conversation — forks are the exception). `isolation: worktree` gives a subagent its own git worktree, **enforced at the tool layer** (blocks Edit/Write/Bash cwd/git redirects into the main checkout), not just convention. No auto-merge — worktrees with no changes auto-delete, worktrees with changes persist until a periodic sweep; merging back is left to the user/coordinator.
- No single official doc names the full "plan → parallel build → fresh review → revise" loop as one feature, but it's fully composable from these primitives, and Claude Code's `Workflow` tool (pipeline/parallel/phase primitives, loop-until-dry patterns) is purpose-built for exactly this shape.

### From industry practice (Devin, Cursor, multi-agent frameworks)
- **Cognition/Devin**: "Managed Devins" (shipped ~Mar 2026) — one coordinator Devin decomposes a large task, spawns child sessions each in its own isolated VM, monitors, resolves conflicts, compiles results. "Playbooks" = reusable system-prompt templates for recurring task types.
- **Cursor**: Composer 2.0's "Plan Mode" produces a numbered file-by-file plan and waits for approval before executing. Cursor 3 (~Apr 2026) added a "Parallelize" button that splits a task, giving each subagent its own isolated git worktree; outputs land as PRs. Cursor reports 35% of their own merged PRs now come from background agents.
- **Frameworks**: LangGraph's supervisor pattern (orchestrator + cheaper-model workers + a separate critic that can loop work back) is the closest match to the full loop; CrewAI favors role-based crews with parallel execution but weaker branching control; AutoGen is strongest for multi-party debate. **No framework documents a rigorous fix for reviewer self-agreement bias** beyond "critic is a separate agent/role with its own prompt" — genuine adversarial N-way voting appears in research papers, not in shipped framework defaults.
- **Worktree isolation** is the dominant industry mechanism for parallel coding agents (Claude Code shipped native worktree support ~Feb 2026). Common reported failure modes: agents silently overwriting each other's work when file scopes overlap even without a compile/test failure; context pollution from unrelated agents' noise; DB/port collisions. Fix pattern: scope each worktree to a directory with its own CLAUDE.md restricting edits to that scope.
- **When parallelizing backfires** (important guardrail): a Google Research agent-scaling study found +81% improvement on genuinely parallelizable tasks but **-70% degradation on sequential/tightly-coupled tasks** when forced into a multi-agent shape, with diminishing returns beyond ~5 agents. A UIUC study found multi-agent setups burn **4–220x more tokens** than single-agent. Repeated practical rule across sources: only parallelize when subtasks are independent/disjoint in file scope and governed by written specs; keep bug fixes, tightly-coupled codebases, and ambiguous-requirement work strictly serial — "parallel agents multiply conflict surface area, not throughput."

## Proposed design (draft, not yet built)

A new global skill (`~/.claude/skills/`, project-overridable) as the explicit entry point for "build this end-to-end autonomously" on a non-trivial task. When invoked, it authors and runs a `Workflow` script:

1. **Plan** — decompose into chunks with explicit file/module boundaries. The plan agent must certify whether chunks are truly independent (disjoint file scope); only then does it parallelize. Tightly-coupled work runs serially instead (per the Google Research finding above) — this is the complexity/parallelization gate.
2. **Execute** — independent chunks run in parallel via `agent()` with `agentType: 'feature-builder'` (reusing the existing agent, not reinventing it) and `isolation: 'worktree'` each; coupled work runs as an ordered pipeline instead.
3. **Merge** — worktrees don't auto-merge in Claude Code, so this is an explicit step: merge each worktree branch into one integration branch automatically, surface conflicts to the user rather than silently resolving them, and stop short of committing (per the merge-safety decision above).
4. **Review** — a fresh `code-reviewer` agent (already read-only, already fresh-context by default) reviews the merged result against the plan, returns structured findings.
5. **Feedback loop** — findings go back to the coordinator, which re-invokes `feature-builder` scoped only to flagged files, then re-reviews — capped at a couple of iterations, never auto-commits/pushes.

Other implementation notes:
- Reuse existing specialized agents (`feature-planner`, `feature-builder`, `code-reviewer`) as workflow steps via `agentType` rather than creating redundant new agent definitions.
- Guard against over-spawning (Anthropic's own failure mode): cap default parallel fan-out (e.g. 3–6 chunks) and iteration count (e.g. 2 review/fix rounds), configurable per project.
- Project-level override: extend the existing `.claude/agent-output-config.json` convention with a new key (e.g. `autobuild: { maxParallelAgents, reviewIterations, useWorktrees }`) so a project can tune or disable parts of this without touching the global skill.
- Update the CLAUDE.md orchestration guide's "Standard sequences" to add this as a new, distinct entry once the trigger mechanism (see open decision above) is settled — do not fold it into the existing manual chain's default behavior.

## Guardrails hardened (2026-09-07, from config audit)

The config audit flagged that the guardrails below existed only as soft proposals with no concrete mechanism or fallback behavior. Resolved as follows, to carry over when this is actually built:

1. **Iteration/cost cap — concrete, with defined fallback.** Hard cap: 2 review/fix rounds, not "a couple" left vague. If must-fix findings are still open when the cap is hit: **stop, don't loop again, don't silently give up either** — surface a summary to the user of what's still open and that the cap (not a clean pass) is why the loop ended, then hand back control. Never keep going past the cap and never end silently.
2. **Fan-out ceiling — concrete default, batched overflow.** Hard default cap: 5 parallel chunks (matches the Anthropic finding above that returns diminish past ~5 agents). If planning produces more independent chunks than the cap, run them in batches of ≤5 rather than spawning all at once. Configurable *down* (not up) per project via `autobuild.maxParallelAgents` in `.claude/agent-output-config.json`.
3. **Parallelization gate — no longer prompt-only.** The plan agent's independence certification must now come with an explicit list of file paths/globs each chunk owns. Before parallel execution starts, the orchestrating script (not the model's say-so) mechanically checks those lists for overlap. Any overlap found → those chunks downgrade to serial automatically; fail safe toward serial, never toward "trust the model and parallelize anyway."
4. **Worktree cleanup — explicit, not dependent on the periodic sweep.** The merge step's last action deletes/prunes the per-chunk worktrees and branches used for that run, immediately after a successful merge — doesn't wait for Claude Code's periodic sweep, so repeated runs don't accumulate unbounded worktrees between sweeps.

## Next steps when resuming
1. Decide the trigger mechanism (see open decision above).
2. Write the new skill (SKILL.md) and, if needed, its Workflow script template.
3. Add/extend the `agent-output-config.json` key for project-level tuning.
4. Update CLAUDE.md's "Standard sequences" section to reference the new flow.
5. Dry-run on one real non-trivial task before trusting it on anything larger.
