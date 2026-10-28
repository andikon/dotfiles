# Repository guidance

This repository ships independent application configurations and native installers for Windows, macOS, Linux, and WSL.

- Read [docs/contributing.md](docs/contributing.md) when adding a tool, changing the catalog, moving configuration files, or modifying installer behavior. It defines ownership and the native validation commands.
- Read [docs/configuration.md](docs/configuration.md) when changing replacement, backups, restore, or migration behavior. Replacement must be exact within an explicitly owned target and reversible from a journal.
- Read the relevant `docs/tools/` guide before changing application behavior. The Windows workspace configuration and tests live under `config/wezterm/windows` and `tests/wezterm`.
- Use the shared TSV catalogs as the source of tool, dependency, version, package, and destination definitions. Keep PowerShell 5.1 and Bash 3.2 compatibility in installer code.
- Exercise installer changes through temporary homes and mocked downloads/package managers. Run the catalog validator and the applicable native installer suite. Report untested native platforms accurately.
- Retain existing local edits during migrations. Installed files must work independently of a checkout. Keep personal paths, credentials, histories, and runtime state outside tracked configuration.
- Preserve the user's requested approval checkpoints. Use preview and temporary-home modes for verification; apply settings to a real user profile or publish changes only when requested.

For the human/agent collaboration workflow and selectable agents, read [docs/agent-workflow.md](docs/agent-workflow.md).
