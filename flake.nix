{
  description = "eyelady_core NixOS configuration";

  inputs = {
    nixpkgs.url           = "github:nixos/nixpkgs/nixos-25.11";
    nixpkgs-unstable.url  = "github:nixos/nixpkgs/nixos-unstable";
    herdr.url             = "github:herdrdev/herdr/v0.8.2";
    zen-browser-flake.url = "github:youwen5/zen-browser-flake";
    rex.url               = "https://pkgs.superlogical.com/rex/nix/preview.tar.gz";
  };

  outputs = { self, nixpkgs, nixpkgs-unstable, ... } @ inputs:
  let
    system = "x86_64-linux";
    pkgs-unstable = import nixpkgs-unstable {
      inherit system;
      config.allowUnfree = true;
    };
  in
  {
    nixosConfigurations.eyelady_core = nixpkgs.lib.nixosSystem {
      inherit system;
      specialArgs = { inherit inputs pkgs-unstable; };
      modules = [
        ./nixos/configuration.nix
        inputs.rex.nixosModules.default
      ];
    };
  };
}
