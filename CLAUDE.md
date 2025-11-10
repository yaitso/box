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
