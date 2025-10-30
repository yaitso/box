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
      claude-code
      claude-code-router
      direnv
      duckdb
      fd
      gemini-cli
      gh
      helix
      htop
      hyperfine
      jq
      nix-direnv
      nixd
      nixfmt
      nodejs_22
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
        $"($env.HOME)/.nix-profile/bin"
        "/nix/var/nix/profiles/default/bin"
      ])

      $env.EDITOR = "hx"
      $env.DIRENV_LOG_FORMAT = ""
      $env.BOX_ROOT = ($env.BOX_ROOT? | default $env.PWD)
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
  '';

  home.activation.setupPython = config.lib.dag.entryAfter [ "writeBoundary" ] ''
    PATH="${pkgs.uv}/bin:$PATH"
    ${pkgs.uv}/bin/uv python install 3.14 graalpy-3.12 --quiet || true
    ${pkgs.uv}/bin/uv python pin --global 3.14 --quiet || true
  '';
}
