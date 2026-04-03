{
  description = "Dotfiles flake with Home Manager";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";
    home-manager = {
      url = "github:nix-community/home-manager";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs = { self, nixpkgs, home-manager }:
    let
      system = "x86_64-linux";
      pkgs = nixpkgs.legacyPackages.${system};
      mkHomeConfig = username: hostname:
        home-manager.lib.homeManagerConfiguration {
          inherit pkgs;
          modules = [
            {
              _module.args.customUsername = username;
            }
            ./home-manager/home.nix
          ];
        };
    in
    {
      homeConfigurations = {
        # Replace 'user' and 'hostname' with your actual user and hostname
        # Usage: home-manager switch --flake .#user@hostname
        "user@hostname" = mkHomeConfig "user" "hostname";
      };
    };
}
