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

1. Open your checkout or worktree in the terminal, then launch `nvim` there. On Windows, use [WezTerm's project picker](wezterm.md#projects-and-worktrees) to open or return to a workspace and [`gwt`](powershell.md#git-worktrees) to create worktrees. Neovim inherits that directory; **Space ff** finds files and **Space fg** searches its contents.
2. Outline the important interfaces/tests manually; **Space cs** opens document symbols and **Space ao** asks Copilot for a plan.
3. Use the terminal workspace's agent pane for independent work. **Space an** remains available when you want an agent terminal inside the editor; it keeps the directory where it started.
4. **Esc Esc** leaves terminal input mode; **Space ah** hides the agent window. **Space al** lists agent/build terminals in this editor and shows whether their processes are running, exited or failed. A running CLI may be waiting for an approval or prompt.
5. Review with **Space gc** (CodeDiff), run tests with **Space rt**, then make any semantic refactorings with **Space cr** / **Space ca**.

**Editor-hosted jobs survive view changes only while Neovim remains open. Quitting Neovim ends them.** Use the terminal workspace for jobs that should run independently of the editor. Hiding a job is different from stopping it; **Space as** explicitly asks which editor job to stop.

Neovim handles editing and IDE features within the inherited checkout. It does not discover, create or switch projects/worktrees, or save/restore project sessions. Tabs are ordinary editor views: **Space Tab n** opens a view, **Space Tab r** names it, and **Space Tab x** closes it. Buffers remain available across views; closing a view does not create a layout snapshot. Old project/session history in your Neovim data directory is left untouched and is no longer loaded.

Copilot Chat uses the active file as sticky context. Visual selections also work with the AI shortcuts. `#file:path` and `#gitdiff:staged` add explicit context; `#buffer:listed` includes listed editor buffers. Use `:CopilotChatSave NAME` / `:CopilotChatLoad NAME` for named conversations, and **Space aR** to reset before changing topics. Chat and CLI agents are separate sessions. Normal chat requests wait for you to send a prompt.

## Editor layout

The default theme is the Neovim port of Doom Emacs' **Doom One**: charcoal backgrounds, muted chrome, blue keywords, green strings and warm purple/yellow accents. The Berserk dashboard uses a crimson, terminal-native Brand of Sacrifice-inspired emblem and file/search/chat shortcuts. It adapts to shorter windows and has no animation timer or image dependencies.

| Component | Role |
| --- | --- |
| Tabby | Editor views labeled by filename, renamed with Space Tab r |
| Lualine | Mode, working directory, Git branch/diff, path, diagnostics, LSP progress and editor job count |
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
