# Skill Registry — perfinance

Generated: 2026-05-09 | Stack: Flutter/Dart | Store: engram

## User Skills

| Trigger | Skill | Path |
|---------|-------|------|
| Creating a pull request, opening a PR, preparing changes for review | branch-pr | ~/.claude/skills/branch-pr/SKILL.md |
| Creating a GitHub issue, reporting a bug, requesting a feature | issue-creation | ~/.claude/skills/issue-creation/SKILL.md |
| "judgment day", "dual review", "juzgar", "que lo juzguen" | judgment-day | ~/.claude/skills/judgment-day/SKILL.md |
| Creating a new skill, add agent instructions, document patterns for AI | skill-creator | ~/.claude/skills/skill-creator/SKILL.md |

## Project Conventions

No project-level CLAUDE.md or AGENTS.md found. Global ~/.claude/CLAUDE.md applies.

Key conventions from global config:
- Package manager: pnpm (N/A — this is a Flutter/Dart project, use `flutter pub` / `dart pub`)
- Never build after changes
- Never add AI attribution to commits
- Use conventional commits only
- Match user language (Rioplatense Spanish voseo in this project)

## Compact Rules

### branch-pr
- Every PR MUST link an approved issue — no exceptions
- Every PR MUST have exactly one `type:*` label
- Automated checks must pass before merge
- Blank PRs without issue linkage will be blocked by CI

### issue-creation
- Blank issues are disabled — MUST use bug report or feature request template
- Every issue gets `status:needs-review` automatically on creation
- A maintainer MUST add `status:approved` before any PR can be opened
- Questions go to Discussions, not issues

### judgment-day
- Launch two independent blind judge sub-agents simultaneously (parallel)
- Resolve skills from registry before launching judges
- Synthesize findings and apply fixes; re-judge until both pass or escalate after 2 iterations
- Judges are blind — do NOT share context between them

### skill-creator
- Create skills for repeated patterns that differ from generic best practices
- Use SKILL.md frontmatter: name, description (with Trigger:), license, metadata
- Include: Purpose, When to Use, Critical Patterns/Rules, Step-by-step workflow
- Don't create skills for trivial or one-off tasks
