# Working with coding agents

The [main README](../README.md) is for people installing and using the configuration. [AGENTS.md](../AGENTS.md) is the primary entry point for coding agents changing this repository. Tool behavior, ownership, and catalog conventions are explained in [contributing](contributing.md).

## A normal change

1. Ask the agent to inspect the affected config and propose a concrete change. Review its destination paths and expected effect before approving implementation when you want a planning step.
2. After approval, let it edit the tool's files and catalog together. A new tool should become discoverable, selectable, installable where supported, and documented.
3. Have it run the native temporary-home tests and report which platforms were actually exercised. CI supplies the other operating systems.
4. Review the diff and preview the installer. Apply to your machine explicitly, then publish using your normal Git workflow when ready.

Example request:

> Add a cross-platform Git configuration. Inspect the catalog and ownership rules first, propose its destinations, then wait for my approval. Preserve my current local edits.

For implementation:

> Implement the approved plan. Validate with temporary home directories and tell me which native platforms were tested.

## Instruction files and selectable agents

- Root `AGENTS.md` holds shared repository instructions.
- `.github/copilot-instructions.md` directs Copilot to that guidance.
- `.github/agents/planner.agent.md` is a read-only planner.
- `.github/agents/reviewer.agent.md` reviews behavior, ownership, portability, and test evidence.

Select an agent deliberately in a compatible client. These definitions do not run on their own. They are repository-scoped and the installer does not copy them into global agent settings. The planner and reviewer share the same repository rules rather than maintaining separate copies.

## What to review

For installer work, pay attention to the exact replacement scope, backup/restore behavior, missing dependencies, minimum versions, canceled input, and scripts downloaded from one immutable revision. A valid config file alone does not establish that copying it to a machine is correct.

For application work, preserve the existing workflow unless changing it is part of the request. Authentication, licenses, choice of login shell, starting desktop sessions, and applying settings to a real user profile remain explicit user actions.
