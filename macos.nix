{ pkgs, env, ... }:

{
  system.stateVersion = 5;
  system.primaryUser = env.username;

  networking.hostName = "macos";
  networking.computerName = "macos";

  users.users.${env.username} = {
    home = "/Users/${env.username}";
    shell = pkgs.nushell;
  };

  environment.shells = [ pkgs.nushell ];
  environment.systemPackages = [ pkgs.nushell ];

  nix.settings = {
    experimental-features = [
      "nix-command"
      "flakes"
    ];
    substituters = [
      "https://cache.nixos.org"
      "https://nix-community.cachix.org"
    ];
    trusted-public-keys = [
      "cache.nixos.org-1:6NCHdD59X431o0gWypbMrAURkbJ16ZPMQFGspcDShjY="
      "nix-community.cachix.org-1:mB9FSh9qf2dCimDSUo8Zy7bkq5CX+/rkCWyvRCYg3Fs="
    ];
    max-jobs = "auto";
    cores = 0;
  };

  nixpkgs.config.allowUnfree = true;

  homebrew = {
    enable = true;
    onActivation.autoUpdate = false;
    onActivation.upgrade = false;
    casks = [
      "karabiner-elements"
      "ghostty"
      "cursor"
      "zoom"
      "notion-calendar"
      "hiddenbar"
      "brave-browser"
      "google-chrome"
      "helium-browser"
      "tuist"
      "lm-studio"
    ];
  };

  system.activationScripts.macosDefaults.text = ''
    if command -v nu &>/dev/null; then
      nu ${./script/macos.nu} || true
      nu ${./script/files.nu} || true
      nu ${./kount/kount.nu} || true
    fi
  '';
}
