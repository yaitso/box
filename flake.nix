{
  description = "box — system config management";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";

    nix-darwin.url = "github:LnL7/nix-darwin";
    nix-darwin.inputs.nixpkgs.follows = "nixpkgs";

    home-manager.url = "github:nix-community/home-manager";
    home-manager.inputs.nixpkgs.follows = "nixpkgs";
  };

  outputs =
    {
      self,
      nixpkgs,
      nix-darwin,
      home-manager,
    }:
    let
      env = import ./env.nix;
    in
    {
      darwinConfigurations.macos = nix-darwin.lib.darwinSystem {
        system = "aarch64-darwin";
        modules = [
          ./macos.nix
          home-manager.darwinModules.home-manager
          {
            nixpkgs.config.allowUnfree = true;
            nixpkgs.overlays = [
              (final: prev: {
                fish = prev.runCommand "fish-stub" { } ''
                  mkdir -p $out/bin
                  echo '#!/bin/sh' > $out/bin/fish
                  echo 'echo "fish stub"' >> $out/bin/fish
                  chmod +x $out/bin/fish
                '';
              })
            ];
            home-manager.useGlobalPkgs = true;
            home-manager.useUserPackages = false;
            home-manager.users.${env.username} = ./shared.nix;
            home-manager.extraSpecialArgs = {
              inherit env;
            };
          }
        ];
        specialArgs = { inherit env; };
      };

      homeConfigurations.linux = home-manager.lib.homeManagerConfiguration {
        pkgs = nixpkgs.legacyPackages.aarch64-linux;
        modules = [ ./linux.nix ];
        extraSpecialArgs = {
          inherit env;
        };
      };
    };
}
