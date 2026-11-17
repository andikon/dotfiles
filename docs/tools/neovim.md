# Java and agent workflow

Use Neovim 0.12 or newer.
Press **Space**, pause, and WhichKey shows the available groups. **Space ?** shows buffer shortcuts.

## First launch

- Install Git, curl 8+, ripgrep and the JDK required by your project. A Nerd Font is recommended for icons.
- Run the [repository installer](../../README.md) and select Neovim. The source is `config/nvim/common`; the installer resolves Windows, macOS, Linux, and custom XDG destinations.
- Open Neovim and let Lazy install the plugins. `:Lazy restore` installs the exact revisions in the lockfile.
- For Java, install Python 3.9+ and a JDK supported by your JDT LS release (JDK 21+ for JDT LS 1.63). Mason installs `jdtls` automatically. Check `:Mason` and reopen the Java file if you opened it before installation finished. Set `JDTLS_JAVA_HOME` to run the server on a separate JDK while keeping your build's `JAVA_HOME`.
- To run and debug Java main classes, use `:MasonInstall java-debug-adapter`, then reopen Neovim. **Space rr** runs and **Space rd** debugs a selected main class. **Space dv** opens the debug console.
- **Space aa** opens Copilot Chat and its GitHub authentication flow. Your account needs access to Copilot IDE chat. No model is hardcoded; **Space am** chooses an available one.
- Install and authenticate your preferred CLI agent separately. **Space an** detects `codex`, `claude`, `copilot` and `opencode`, and also accepts a custom command.
- **Space uH** (`:checkhealth dotfiles`) checks prerequisites. Mason installs Terraform, Lua, JSON, YAML, Bash and the existing web/C++ language servers. Node-based servers require Node.js on PATH.

## Large Maven projects

JDT LS starts when you open a Java file. It looks for the Maven wrapper or `.mvn` above that file. In a wrapperless reactor, it uses the outermost ancestor POM up to the nearest Git checkout boundary. The result is independent of which module you open first and which directory you launch Neovim from.

The first import builds the index. Later launches of Neovim start a fresh JVM and reuse the index and import state in `stdpath("data")/jdtls/<root-hash>/workspace`. Each checkout or worktree has its own workspace. Use one Neovim instance per checkout while editing Java because Eclipse locks the workspace. Keeping that instance open in WezTerm also keeps the Java process warm. [nvim-jdtls workspace configuration](https://github.com/mfussenegger/nvim-jdtls#data-directory-configuration)

Maven dependency resolution stays enabled, and eager downloading of dependency sources is disabled. If the server runs low on memory during import, try `JDTLS_JVM_ARGS=-Xmx4g` before launching Neovim, provided your machine has enough free RAM. Compare the first import with the next launch from the same checkout after JDT LS reports readiness. [Eclipse launcher options](https://github.com/eclipse-jdtls/eclipse.jdt.ls#running-from-command-line-with-wrapper-script)

## Working on a change

1. Open your checkout or worktree in the terminal, then launch `nvim` there. On Windows, use [WezTerm's project picker](wezterm.md#projects-and-worktrees) to open or return to a workspace and [`gwt`](powershell.md#git-worktrees) to create worktrees. Neovim inherits that directory; **Space ff** finds files and **Space fg** searches its contents.
2. Outline the important interfaces/tests manually; **Space cs** opens document symbols and **Space ao** asks Copilot for a plan.
3. Use the terminal workspace's agent pane for independent work. **Space an** remains available when you want an agent terminal inside the editor; it keeps the directory where it started.
4. **Esc Esc** leaves terminal input mode; **Space ah** hides the agent window. **Space al** lists agent/build terminals in this editor and shows whether their processes are running, exited or failed. A running CLI may be waiting for an approval or prompt.
5. Review with **Space gc** (CodeDiff), run tests with **Space rt**, then make any semantic refactorings with **Space cr** / **Space ca**.

To create a Java class, open a Java source file in the target package and press **Space jn** after JDT LS attaches. Enter a class name such as `OrderService`. Neovim uses the module's source roots from JDT LS to fill in the package declaration and opens the class body for editing. Save with **Space fs** or `:write`.

**Editor-hosted jobs survive view changes only while Neovim remains open. Quitting Neovim ends them.** Use the terminal workspace for jobs that should run independently of the editor. Hiding a job is different from stopping it; **Space as** explicitly asks which editor job to stop.

Neovim handles editing and IDE features within the inherited checkout. It does not discover, create or switch projects/worktrees, or save/restore project sessions. **Space Tab n** opens a view, **Space Tab r** names it in the statusline, and **Space Tab x** closes it. **Space Tab [** and **Space Tab ]** switch views. Buffers remain available across views. Old project/session history in your Neovim data directory is left untouched and is no longer loaded.

Copilot Chat uses the active file as sticky context. Visual selections also work with the AI shortcuts. `#file:path` and `#gitdiff:staged` add explicit context; `#buffer:listed` includes listed editor buffers. Use `:CopilotChatSave NAME` / `:CopilotChatLoad NAME` for named conversations, and **Space aR** to reset before changing topics. Chat and CLI agents are separate sessions. Normal chat requests wait for you to send a prompt.

## Editor layout

Neovim starts with **Gruvbox Material** in dark mode. The Berserk dashboard uses a terminal-native Brand of Sacrifice-inspired emblem and file/search/chat shortcuts. It adapts to shorter windows and has no animation timer or image dependencies.

Neovide adds one pixel between rows. In a terminal, the host controls row height. The bundled Windows WezTerm config uses a line height of 1.16.

| Component | Role |
| --- | --- |
| Lualine | Slanted statusline with the file path, unsaved buffer count, errors and warnings. Wider windows show Git, search, LSP and working-directory details. |
| Incline | Compact file labels on splits, modified/read-only state |
| Heirline | Native diagnostic signs, line numbers and fold column |
| hlchunk | Current brace scope and scope line numbers; no parser required |
| Snacks | Explorer, search, pickers, notifications, shell terminals and subtle indent guides |
| render-markdown | Markdown headings, code, lists and checkboxes |

Use Blink's **Ctrl+Space** to request completion and **Enter** to accept. Use **Space db** for breakpoints.

The live config had tiny-inline-diagnostic disabled because it was unreliable; that preference is preserved. Native signs and floating diagnostic views remain available, and **Space ud** toggles Neovim's current-line diagnostic messages.

## Parsers and maintenance

Neovim's bundled Markdown/Lua parsers are sufficient for Markdown rendering. Extra Java, Kotlin and configuration-language syntax parsers are optional: install a C compiler and `tree-sitter` CLI >= 0.26.1, then run `:ParsersInstall`. `:TSUpdate` refreshes installed parsers. Missing optional parsers fall back to ordinary syntax/LSP highlighting; startup does not try to compile parsers.

Use `:Lazy restore` for reproducible installation. In a Java buffer, **Space jo** opens the logs, **Space jr** refreshes the project's build configuration after POM changes, and **Space ja** organizes imports. **Space jR** restarts JDT LS with the existing workspace. Reserve `:JdtWipeDataAndRestart` for a broken workspace because the next import rebuilds its index.

## Shortcut reference

Press **Space** and pause for the current shortcuts. The [PDF cheatsheet](../cheatsheets/neovim-workflow-cheatsheet.pdf) predates the JDT LS migration.

Upstream documentation for [nvim-jdtls](https://github.com/mfussenegger/nvim-jdtls), [CopilotChat](https://github.com/CopilotC-Nvim/CopilotChat.nvim), [Treesitter](https://github.com/nvim-treesitter/nvim-treesitter), [hlchunk](https://github.com/shellRaining/hlchunk.nvim), [Heirline](https://github.com/rebelot/heirline.nvim), [Incline](https://github.com/b0o/incline.nvim), and [Markdown](https://github.com/MeanderingProgrammer/render-markdown.nvim).
