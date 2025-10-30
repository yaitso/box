{
  pkgs,
  config,
  user,
  fenix-pkgs,
  ...
}:

{
  home.stateVersion = "24.11";

  home.packages =
    (with pkgs; [
      ast-grep
      bun
      claude-code
      claude-code-router
      codex
      direnv
      duckdb
      fd
      gemini-cli
      gh
      helix
      htop
      hyperfine
      jj
      jq
      nix-direnv
      nixd
      nixfmt
      nodejs_22
      opentofu
      ripgrep
      ruff
      shellcheck
      shfmt
      tldr
      tokei
      tree
      uv
    ])
    ++ [ fenix-pkgs.complete.toolchain ]
    ++ (
      if pkgs.stdenv.isDarwin then
        [
          pkgs.asitop
          pkgs.swiftformat
        ]
      else
        [ ]
    );

  programs.nushell = {
    enable = true;

    envFile.text = ''
      $env.PATH = ($env.PATH | split row (char esep) | prepend [
        $"($env.HOME)/.local/bin"
        $"($env.HOME)/.nix-profile/bin"
        "/nix/var/nix/profiles/default/bin"
        "/usr/local/bin"
      ])

      $env.EDITOR = "hx"
      $env.DIRENV_LOG_FORMAT = ""
    '';

    configFile.source = ./script/shell.nu;
  };

  programs.direnv = {
    enable = true;
    nix-direnv.enable = true;
  };

  programs.git = {
    enable = true;
    settings = {
      user.name = user.fullname;
      user.email = user.email;
      init.defaultBranch = "master";
      push.default = "simple";
      pull.rebase = false;
      rerere.enabled = true;
      core.editor = "hx";
      commit.gpgsign = false;
      rebase.autoStash = true;
      credential.helper = if pkgs.stdenv.isDarwin then "osxkeychain" else "store";
    }
    // (
      if pkgs.stdenv.isLinux then
        {
          url."git@github.com:".insteadOf = "https://github.com/";
        }
      else
        { }
    );
  };

  programs.helix = {
    enable = true;
    defaultEditor = true;
  };

  programs.ssh = {
    enable = true;
    enableDefaultConfig = false;
    matchBlocks."*" = {
      addKeysToAgent = "yes";
      extraOptions = {
        UseKeychain = "yes";
      };
    };
    matchBlocks."yaitso" = {
      identityFile = "~/.ssh/yaitso";
    };
  };

  home.file.".ssh/config".force = true;

  home.activation.linkConfigFiles = config.lib.dag.entryAfter [ "writeBoundary" ] ''
    ${pkgs.nushell}/bin/nu ${./script/files.nu}
    ${pkgs.nushell}/bin/nu ${./script/mcp.nu}
  '';

  home.activation.setupPython = config.lib.dag.entryAfter [ "writeBoundary" ] ''
    PATH="${pkgs.uv}/bin:$PATH"
    ${pkgs.uv}/bin/uv python install 3.14 graalpy-3.12 --quiet || true
    ${pkgs.uv}/bin/uv python pin --global 3.14 --quiet || true
  '';

  home.file.".local/bin/brave-9228" = {
    executable = true;
    text = ''
      #!/usr/bin/env bash
      set -euo pipefail

      APP1="$HOME/Applications/Brave Browser.app/Contents/MacOS/Brave Browser"
      APP2="/Applications/Brave Browser.app/Contents/MacOS/Brave Browser"

      if [ -x "$APP1.real" ]; then
        BIN="$APP1.real"
      elif [ -x "$APP2.real" ]; then
        BIN="$APP2.real"
      elif [ -x "$APP1" ]; then
        BIN="$APP1"
      else
        BIN="$APP2"
      fi

      exec "$BIN" --remote-debugging-port=9228 "$@"
    '';
  };

  home.activation.bravePatch = config.lib.dag.entryAfter [ "writeBoundary" ] ''
    set -e

    WRAPPER="$HOME/.local/bin/brave-9228"

    patch_one() {
      local APP="$1"
      local BIN="$APP/Contents/MacOS/Brave Browser"
      [ -e "$BIN" ] || return 0

      if [ -L "$BIN" ]; then
        local TARGET
        TARGET="$(readlink "$BIN" || true)"
        if [ "$TARGET" != "$WRAPPER" ]; then
          ln -sf "$WRAPPER" "$BIN"
        fi
      else
        if [ -e "$BIN" ] && [ -e "$BIN.real" ]; then
          mv -f "$BIN" "$BIN.real"
        elif [ -e "$BIN" ] && [ ! -e "$BIN.real" ]; then
          mv "$BIN" "$BIN.real"
        fi
        ln -sf "$WRAPPER" "$BIN"
      fi
    }

    patch_one "$HOME/Applications/Brave Browser.app"
    patch_one "/Applications/Brave Browser.app"
  '';
}
