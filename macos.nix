{ pkgs, user, ... }:

{
  system.stateVersion = 5;
  system.primaryUser = user.username;

  networking.hostName = "macos";
  networking.computerName = "macos";

  users.users.${user.username} = {
    home = "/Users/${user.username}";
    shell = pkgs.nushell;
  };

  environment.shells = [ pkgs.nushell ];
  environment.systemPackages = [ pkgs.nushell ];

  nix.settings.experimental-features = [
    "nix-command"
    "flakes"
  ];

  nixpkgs.config.allowUnfree = true;

  homebrew = {
    enable = true;
    casks = [
      "karabiner-elements"
      "ghostty"
      "cursor"
      "zoom"
      "notion-calendar"
      "hiddenbar"
      "tuist"
      "codex"
    ];
  };

  system.activationScripts.macosDefaults.text = ''
    if command -v nu &>/dev/null; then
      nu ${./macos.nu} || true
      nu ${./files.nu} || true
    fi

    if [ -x ${./kount/kount.sh} ]; then
      cd ${./kount} && ${./kount/kount.sh} || true
    fi
  '';
}
