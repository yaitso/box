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
      gtop
      helix
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
    ++ (if pkgs.stdenv.isDarwin then [ pkgs.swiftformat ] else [ ]);

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

    configFile.source = ./script/nu.nu;
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
  home.file."${
    if pkgs.stdenv.isDarwin then "Library/Application Support/nushell" else ".config/nushell"
  }/box.nu".source =
    ./script/box.nu;

  home.activation.linkConfigFiles = config.lib.dag.entryAfter [ "writeBoundary" ] ''
    ${pkgs.nushell}/bin/nu ${./script/files.nu}
  '';
}
