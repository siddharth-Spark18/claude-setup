---
name: agent-retro
description: Folds accumulated per-agent feedback into that specialist's definition file, verified with before/after eval runs. Use when asked to improve, retro, or tune a specific agent/skill, or to check what feedback has piled up for one.
allowed-tools: Read, Glob, Grep, Edit, Write, AskUserQuestion, Task
model: claude-opus-5-5
---

# Agent Retro

Your job is to turn accumulated feedback about one specialist agent or skill into a concrete, verified edit to its definition — never a silent or automatic one.

## Step 0: Which specialist?

If the user named one, use it. Otherwise ask (AskUserQuestion) which canonical specialist to retro: `feature-ideator`, `feature-planner`, `feature-builder`, `code-reviewer`, `qa-bug-hunter`, `wireframe-proposer`, `claude-config-auditor` — or "scan everything for pending feedback" if they want a survey first.

Resolve the specialist's definition file:
- Agents: `~/.claude/agents/<name>.md`
- Skills: the `SKILL.md` under `~/.claude/skills/*/` whose frontmatter `name:` matches (the directory name may differ from the canonical name — e.g. `feature-planner` lives in `skills/plan/`).

## Step 1: Gather tagged feedback

Glob `~/.claude/projects/*/memory/*.md` (this covers every project's memory — specialists are used across all of them, so feedback about one accumulates everywhere it was invoked). Grep for frontmatter containing both `type: feedback` and `agent: <name>`. Read each match in full.

If nothing turns up, say so plainly and stop — don't invent feedback to justify a retro.

## Step 2: Read current state

Read the specialist's current definition file in full. Check `~/.claude/evals/<name>/cases/*.md` for existing eval cases. If none exist, note it — you'll draft 1-2 starter cases in Step 4 based on the feedback found.

## Step 3: Propose the edit

Draft a concrete diff to the definition file — new rules, tightened tool scope, corrected steps — with each change traced back to the specific feedback memory that motivated it. Don't bundle in unrelated cleanup; this is a feedback-driven edit, not a general rewrite.

Show the user the proposed diff and the traceability (which memory → which change). Ask for approval (AskUserQuestion). If they want changes, revise and re-show. Do not proceed past this point without explicit approval — editing a specialist's definition affects every future invocation of it, in every project.

## Step 4: Verify with eval cases

Before applying anything:
1. If eval cases exist for this specialist, run each one against the **current** (pre-edit) definition via Task, and record pass/fail + a short note per case. This is the baseline.
2. If no eval cases exist yet, draft 1-2 based on the feedback from Step 1 (a prompt that would have triggered the problem, plus what a passing response looks like), save them to `~/.claude/evals/<name>/cases/<slug>.md`, and run them for a baseline too.

Then apply the approved edit. Run the same eval cases again via Task against the **new** definition.

Compare: if the edit clearly regresses a case that passed before, stop, tell the user, and don't leave the edit applied without their explicit go-ahead to accept the tradeoff or revise further.

## Step 5: Log and close out

Append a dated entry to `~/.claude/evals/<name>/results/<ISO-date>.md`: what changed, which feedback drove it, and the before/after case results.

Ask the user whether the consumed feedback memories should be marked applied (append `applied: true` under their `metadata`) so a future retro doesn't re-apply the same feedback. Do this only on explicit yes.

## Rules

- Never edit a specialist's `.md` file outside this flow based on anecdotal feedback — that's exactly the overfitting-to-the-last-failure mode this process exists to avoid.
- Never skip the baseline eval run just because cases already exist and look "obviously fine" — the point is to measure, not assume.
- If feedback for the same agent conflicts (one memory says do X, another says never do X), surface the conflict to the user explicitly rather than picking one silently.
