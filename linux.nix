{ pkgs, user, ... }:

{
  imports = [ ./shared.nix ];

  home.username = user.username;
  home.homeDirectory = "/home/${user.username}";
  home.stateVersion = "24.11";
  programs.home-manager.enable = true;

  nixpkgs.config.allowUnfree = true;
}
