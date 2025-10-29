{
  description = "box — system config management";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";

    nix-darwin.url = "github:LnL7/nix-darwin";
    nix-darwin.inputs.nixpkgs.follows = "nixpkgs";

    home-manager.url = "github:nix-community/home-manager";
    home-manager.inputs.nixpkgs.follows = "nixpkgs";

    fenix.url = "github:nix-community/fenix";
    fenix.inputs.nixpkgs.follows = "nixpkgs";
  };

  outputs =
    {
      self,
      nixpkgs,
      nix-darwin,
      home-manager,
      fenix,
    }:
    let
      mkUser =
        base:
        let
          u = builtins.getEnv "BOX_USERNAME";
          f = builtins.getEnv "BOX_FULLNAME";
          e = builtins.getEnv "BOX_EMAIL";
          overrides =
            if u != "" then
              {
                username = u;
                fullname = if f != "" then f else base.fullname;
                email = if e != "" then e else base.email;
              }
            else
              { };
        in
        base // overrides;

      user = mkUser {
        username = "yaitso";
        fullname = "Yai Tso";
        email = "root@yaitso.com";
      };
    in
    {
      darwinConfigurations.macos = nix-darwin.lib.darwinSystem {
        system = "aarch64-darwin";
        modules = [
          ./macos.nix
          home-manager.darwinModules.home-manager
          {
            home-manager.useGlobalPkgs = true;
            home-manager.useUserPackages = false;
            home-manager.users.${user.username} = ./shared.nix;
            home-manager.extraSpecialArgs = {
              inherit user;
              fenix-pkgs = fenix.packages.aarch64-darwin;
            };
          }
        ];
        specialArgs = { inherit user; };
      };

      homeConfigurations.linux = home-manager.lib.homeManagerConfiguration {
        pkgs = nixpkgs.legacyPackages.aarch64-linux;
        modules = [ ./linux.nix ];
        extraSpecialArgs = {
          inherit user;
          fenix-pkgs = fenix.packages.aarch64-linux;
        };
      };
    };
}
