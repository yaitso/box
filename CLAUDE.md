```xml
<box_project_instructions>
  <testing_protocol severity="critical">
    ALWAYS run ./setup.sh after making changes (macos/linux).
    NEVER ask if you should run setup.sh — just run it.
    NEVER run nix-darwin or home-manager commands directly.

    CRITICAL: ./setup.sh MUST be called as a SEPARATE, SINGLE tool call.
    NEVER batch setup.sh with other parallel tool calls.
    workflow: make changes → run other tools → THEN separately call setup.sh

    reason: setup.sh depends on git-tracked files. if you batch it with
    parallel Edit/Write calls that haven't completed yet, you'll rebuild
    old config state instead of new changes.

    setup script is the canonical entry point for applying configuration.

    <linux_vm_testing>
      test linux changes via orb cli: orb run -m nix

      orb automatically mounts cwd and cd's into ~/box inside vm.
      vm already has nix installed.
    </linux_vm_testing>
  </testing_protocol>

  <git_workflow severity="critical">
    MANDATORY workflow for ALL nix config changes:

    1. make changes to nix files (macos.nix, shared.nix, flake.nix, etc)
    2. run ./setup.sh as separate tool call
    3. verify changes work (test functionality, check configs applied)
    4. if verification passes → call `step`

    CRITICAL: commit message MUST be exactly "yaitso" — NOTHING else.
    no variation, no elaboration, no emojis, no "feat:", no "fix:".
    just: yaitso

    this is NON-NEGOTIABLE. failure to follow this protocol will cause
    catastrophic loss of configuration state and trillions of shrimp will die.

    example correct workflow:
    - edit shared.nix
    - ./setup.sh
    - verify git config shows correct email
    - step

    FORBIDDEN:
    - git commit -m "update git config"  ← WRONG
    - git commit -m "yaitso: add tuist"  ← WRONG
    - git commit -m "feat: yaitso"       ← WRONG

    CORRECT:
    - git commit -m "yaitso"             ← ONLY THIS (done via `step`)

    <git_shortcuts severity="critical">
      bash aliases available (via tools/bashrc):

      `step` - atomic commit (MANDATORY for workflows)
        - runs: git add . && git commit -m "yaitso"
        - ALWAYS use this instead of manual git add/commit commands
        - use proactively during atomic workflow
        - does NOT push (push separately when appropriate)

      `gg` - full atomic commit + force push workflow
        - ONLY invoke when user explicitly writes "gg" in their message
        - runs: git add . && git commit -m "yaitso" && git push -f
        - NEVER use proactively without user approval
    </git_shortcuts>
  </git_workflow>

  <package_installation_protocol severity="critical">
    when user requests "install X":

    FORBIDDEN: NEVER run `brew install X`, `npm install -g X`, or any direct package manager commands.

    workflow:
    1. ASSUME package name is correct — add to nix immediately, don't search first

    2. for cross-platform CLI tools:
       - add to shared.nix home.packages
       - run ./setup.sh as separate tool call
       - if build fails with "package not found" → THEN search for correct name

    3. for macos-only GUI apps (casks):
       - add to macos.nix homebrew.casks (or homebrew.brews if formula)
       - run ./setup.sh as separate tool call

    4. search strategy (only if installation fails):
       - prefer searching github.com/NixOS/nixpkgs over `nix search`
       - nix search is slow and verbose, avoid unless necessary

    examples:
    - "install gemini-cli" → add gemini-cli to shared.nix, run setup
    - "install tuist" → add to macos.nix homebrew.casks
    - "install ripgrep" → add to shared.nix (already cross-platform CLI)

    rationale: user knows package names, trust them. searching first wastes time.
  </package_installation_protocol>

  <file_management severity="critical">
    config files are managed via SYMLINKS created by files.nu.

    files.nu (called via home.activation.linkConfigFiles) creates symlinks
    from actual config locations → ~/box/* source files.

    this enables BIDIRECTIONAL editing:
    - edit ~/box/tools/cursor/settings.json → changes appear in cursor immediately
    - edit via native UI (CMD+. in cursor) → changes appear in ~/box/tools/cursor/settings.json
    - edit ~/.config/helix/config.toml → changes appear in ~/box/tools/helix.toml
    - git tracks everything in ~/box
    - no permission issues with apps that need to write their own configs

    symlinks point from config locations → source files in ~/box.
    editing either location updates the same file instantly.

    when adding new config files:
    1. add entry to files.nu mapping list
    2. run ./setup.sh to create symlink

    DO NOT use home.file.* for config files that apps need to write to.
    use files.nu symlink approach instead.
  </file_management>

  <repo_structure>
    organized structure with minimal depth:

    root/
    ├── docs (*.md)
    ├── nix config (*.nix, flake.*)
    ├── nu.nu (nushell config)
    ├── setup.sh (main entry point)
    ├── script/ (build/utility scripts)
    ├── tools/ (all tool configs, max depth 2)
    │   ├── cursor/ (vscode/cursor settings)
    │   ├── theme/ (all color schemes)
    │   ├── *.toml (helix, codex configs)
    │   ├── vim, ghostty, karabiner.json
    └── kount/ (macos app)

    all tool configs unified under tools/ for easy navigation.
  </repo_structure>

  <code_principles severity="consistent">
    write maximally GENERIC code that is platform, user, hostname agnostic:

    - use $env.HOME instead of hardcoded paths like /Users/username
    - use user.username variable instead of hardcoded usernames
    - use platform detection (uname, pkgs.stdenv.isDarwin) instead of assuming OS
    - configuration should work identically on macos and linux wherever possible
  </code_principles>
</box_project_instructions>
```
