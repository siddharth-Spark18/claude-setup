# Eval cases for specialist agents/skills

Used by `/agent-retro` to check whether an edit to an agent/skill's definition actually improved its behavior, rather than just changed it. `claude plugin eval` would be the natural fit for this but is early-access/gated (needs enablement from Anthropic) — this is a plain, ungated equivalent that works the same way for both agents and skills.

## Layout

```
~/.claude/evals/<specialist-name>/
  cases/
    <case-slug>.md       # one test scenario
  results/
    <ISO-date>.md        # one log entry per retro run
```

`<specialist-name>` is the canonical name used everywhere else (e.g. `feature-builder`, `code-reviewer`), not necessarily the skill directory name.

## Case file format

```markdown
---
name: <short label>
tags: [optional, grouping]
---

## Prompt
<the exact user message/scenario to give the specialist>

## Passing behavior
<what a correct response does/contains/avoids — specific enough to judge pass/fail from the transcript>
```

## Results log format

Each retro run appends one entry to `results/<ISO-date>.md`:

```markdown
## <ISO date> — <what changed>
Feedback applied: <memory name(s)>

| Case | Before | After |
|---|---|---|
| <slug> | pass/fail + note | pass/fail + note |
```

Cases start empty for every specialist — `/agent-retro` drafts the first 1-2 cases itself, from real accumulated feedback, the first time it runs against a specialist that doesn't have any yet. Don't hand-write speculative cases with no feedback behind them; that defeats the point of measuring against a real observed failure.
