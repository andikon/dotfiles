# Java and agent workflow

Use Neovim 0.12 or newer. The PDF reference is [here](../cheatsheets/neovim-workflow-cheatsheet.pdf).
Press **Space**, pause, and WhichKey shows the available groups. **Space ?** shows buffer shortcuts.

## First launch

- Install Git, curl 8+, ripgrep and the JDK required by your project. A Nerd Font is recommended for icons.
- Run the [repository installer](../../README.md) and select Neovim. The source is `config/nvim/common`; the installer resolves Windows, macOS, Linux, and custom XDG destinations.
- Open Neovim and let Lazy install the plugins. `:Lazy restore` installs the exact revisions in the lockfile.
- The IntelliJ plugin downloads a separate server bundle. Review its consent screens, then use **Space jl** (`:IntellijLspLicense`) for the trial or your eligible Ultimate license. Set `JAVA_HOME` if the project JDK is not detected. `INTELLIJ_LSP_SERVER` can point to an existing server launcher.
- **Space aa** opens Copilot Chat and its GitHub authentication flow. Your account needs access to Copilot IDE chat. No model is hardcoded; **Space am** chooses an available one.
- Install and authenticate your preferred CLI agent separately. **Space an** detects `codex`, `claude`, `copilot` and `opencode`, and also accepts a custom command.
- **Space uH** (`:checkhealth dotfiles`) checks prerequisites. Mason installs Terraform, Lua, JSON, YAML, Bash and the existing web/C++ language servers. Node-based servers require Node.js on PATH.

IntelliJ's Neovim client is pre-alpha. Its server still imports/indexes Java projects and needs a trial or eligible Ultimate license. There is no Eclipse/JDT LS fallback running alongside it.

## Working on a change

1. **Space pp** opens or returns to a project. **Space pd** opens an arbitrary directory. Each project uses a separate tab and tab-local working directory.
2. Outline the important interfaces/tests manually; **Space cs** opens document symbols and **Space ao** asks Copilot for a plan.
3. For independent agent work, **Space wn** creates a branch/worktree and opens it as a project; **Space an** starts an agent there. The agent terminal keeps that directory even after you switch projects.
4. **Esc Esc** leaves terminal input mode; **Space ah** hides the agent window. **Space al** lists agent/build terminals across projects and shows whether their processes are running, exited or failed. A running CLI may be waiting for an approval or prompt.
5. Review with **Space gc** (CodeDiff), run tests with **Space rt**, then make any semantic refactorings with **Space cr** / **Space ca**.

**Background jobs survive project and tab changes only while Neovim remains open. Quitting Neovim ends them.** Use a separate persistent terminal/session manager for jobs that must outlive the editor. Hiding a job is different from stopping it; **Space as** explicitly asks which job to stop.

Open projects retain live buffers, unsaved changes, split layouts and language servers. This trades memory for fast return visits. IntelliJ can use substantial memory per project; avoid opening many large Java projects at once. Layout snapshots store file paths, splits and cursors in Neovim's data directory; **Space Tab x** saves before closing, and **Space ps** saves explicitly. Jobs and unsaved file contents are never serialized. Existing `.vim` project-session files are retained but the new file-only JSON snapshots start fresh.

Copilot Chat uses the active file as sticky context. Visual selections also work with the AI shortcuts. `#file:path` and `#gitdiff:staged` add explicit context; `#buffer:listed` can span projects. Use `:CopilotChatSave NAME` / `:CopilotChatLoad NAME` for named conversations, and **Space aR** to reset before changing topics/projects. Chat and CLI agents are separate sessions. Normal chat requests wait for you to send a prompt; project switching never submits one automatically.

## Editor layout

The default theme is the Neovim port of Doom Emacs' **Doom One**: charcoal backgrounds, muted chrome, blue keywords, green strings and warm purple/yellow accents. The Berserk dashboard uses a crimson, terminal-native Brand of Sacrifice-inspired emblem and project/agent shortcuts. It adapts to shorter windows and has no animation timer or image dependencies.

| Component | Role |
| --- | --- |
| Tabby | Project and view tabs, renamed with Space Tab r |
| Lualine | Mode, project, Git branch/diff, path, diagnostics, LSP progress and running job count |
| Incline | Compact file labels on splits, modified/read-only state |
| Heirline | Native diagnostic signs, line numbers and fold column |
| hlchunk | Current brace scope and scope line numbers; no parser required |
| Snacks | Explorer, search, pickers, notifications, shell terminals and subtle indent guides |
| render-markdown | Markdown headings, code, lists and checkboxes |

Java/Kotlin use IntelliJ's native completion integration: **Ctrl+Space** requests completion, **Ctrl+n/p** selects, **Enter** accepts. Other languages use Blink. The bare breakpoint shortcut from upstream is removed so **Space b** remains the buffer group; use **Space db** for breakpoints.

The live config had tiny-inline-diagnostic disabled because it was unreliable; that preference is preserved. Native signs and floating diagnostic views remain available, and **Space ud** toggles Neovim's current-line diagnostic messages.

## Parsers and maintenance

Neovim's bundled Markdown/Lua parsers are sufficient for Markdown rendering. Extra Java, Kotlin and configuration-language syntax parsers are optional: install a C compiler and `tree-sitter` CLI >= 0.26.1, then run `:ParsersInstall`. `:TSUpdate` refreshes installed parsers. Missing optional parsers fall back to ordinary syntax/LSP highlighting; startup does not try to compile parsers.

Use `:Lazy restore` for reproducible installation and `:Lazy update` only when you want to update and review the lockfile. **Space jo** opens Java import output; **Space jr** reloads build configuration. Use `:IntellijLspClearCache` only for a broken index, since it forces reindexing.

## Shortcut reference

The [PDF cheatsheet](../cheatsheets/neovim-workflow-cheatsheet.pdf) covers the configured leader shortcuts and supporting commands. Press **Space** and pause for the interactive shortcut menu.

Upstream: [IntelliJ LSP](https://github.com/JetBrains/intellij-lsp.nvim), [CopilotChat](https://github.com/CopilotC-Nvim/CopilotChat.nvim), [Treesitter](https://github.com/nvim-treesitter/nvim-treesitter), [hlchunk](https://github.com/shellRaining/hlchunk.nvim), [Tabby](https://github.com/nanozuki/tabby.nvim), [Heirline](https://github.com/rebelot/heirline.nvim), [Incline](https://github.com/b0o/incline.nvim), [Markdown](https://github.com/MeanderingProgrammer/render-markdown.nvim).
