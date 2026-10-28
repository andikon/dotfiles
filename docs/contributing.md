# Maintaining these dotfiles

## Layout

- `config/<tool>/common` contains portable application files. Platform directories contain the actual platform-specific config when it differs. Installed files must work after the temporary repository snapshot is removed.
- `catalog/tools.tsv` defines tool IDs, labels, supported platforms, detection commands, required/optional dependencies, and grouping.
- `catalog/requirements.tsv` defines minimum executable versions. Both installers read it.
- `catalog/targets.tsv` declares file, directory, or `absent` targets. `absent` means back up and remove a conflicting config file.
- `catalog/packages.tsv` maps tools/dependencies to package identifiers. `-` means manual installation. Homebrew entries may start with `--cask`.
- `installer/` contains native PowerShell and Bash implementations with matching behavior.
- `docs/tools/` describes how to use each setup; `tests/` validates installation and the Windows workspace workflow.
- `windows_stuff/install.ps1` is a compatibility entry point for old commands.

Catalog files use UTF-8, LF, literal tabs, a header row, and `-` instead of empty fields. Values are data, never executable shell expressions. Multi-value fields use commas. Keep tools grouped by what they configure, rather than by the machine that first used them.

## Add a tool

1. Put its config in `config/<tool>/common` or a platform folder. Include dotfiles; exclude machine state, credentials, caches, and generated histories.
2. Add its tool entry, dependency IDs, and package mappings. Version checks belong in `requirements.tsv`; a package manager providing an older version must not mark it compatible.
3. Add target rows using supported destination variables. A dedicated directory can be owned as a whole; a shared application directory must use individual files or named modules. Keep a tool's target paths disjoint so staging and restoration do not overlap.
4. If detection or destination discovery needs application knowledge, implement it in the applicable installer and cover that behavior with a temporary-home test. Use fixed command arguments; catalog values are never evaluated as code.
5. Document first-launch setup and any required user authentication, then run the relevant checks below.

For a new dependency, add a package row even if every package manager is manual. `vscode-extensions` is an intentional special handler because its items are extension IDs rather than system packages. Windows portable WezTerm is another explicit handler: it expands the config into named file/directory targets without owning its application directory.

## Validate changes

No check should install software or modify your active configuration. Integration tests create temporary home directories and substitute package managers and downloads.

```sh
python tests/installer/validate_catalog.py
bash tests/installer/test-bash.sh
```

On Windows:

```powershell
python tests/installer/validate_catalog.py
powershell -NoProfile -File tests/installer/Test-Installer.ps1
pwsh -NoProfile -File tests/installer/Test-Installer.ps1
pwsh -NoProfile -File tests/wezterm/Verify-WezTerm.ps1
```

The Bash suite covers Linux/WSL and macOS path behavior, replacement, restoration, cancellation, minimum versions, simulated package installs, and clone-free download behavior. CI runs it natively on Linux and macOS, with `/bin/bash` used to cover macOS's bundled Bash. The Windows suite covers Windows PowerShell 5.1 and PowerShell 7, directory junctions, portable WezTerm, rollback, and shared-directory ownership.

The WezTerm suite also loads the installed WezTerm configuration and checks Lua behavior when those programs are available. `-Runtime` explicitly starts disposable native mux panes for deeper workspace checks; it requires local WezTerm and PowerShell 7.

## Review and publication

Review moves alongside edits so existing customizations and tests survive restructuring. Keep the tracked Neovim `lazy-lock.json`; update it deliberately when upgrading plugins. Use LF for scripts and catalog data, enforced by `.gitattributes`.

Run previews before applying changes to your own machine. Publishing the root entry scripts to GitHub makes the README bootstrap commands available; creating a local change does not update the remote installer. A named release tag or commit can pin a known configuration across machines.
