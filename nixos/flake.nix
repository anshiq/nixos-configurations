# /etc/nixos/flake.nix
{
  description = "My NixOS + Home Manager config";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    nixos-wsl.url = "github:nix-community/NixOS-WSL";
    home-manager = {
      url = "github:nix-community/home-manager";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs =
    {
      nixpkgs,
      nixos-wsl,
      home-manager,
      ...
    }:
    {
      nixosConfigurations.nixos = nixpkgs.lib.nixosSystem {
        system = "x86_64-linux";
        modules = [
          nixos-wsl.nixosModules.wsl
          ./configuration.nix
          home-manager.nixosModules.home-manager
          {
            home-manager.useGlobalPkgs = true;
            home-manager.useUserPackages = true;
            # A pre-existing file home-manager doesn't own would otherwise abort
            # the whole activation (checkLinkTargets) before anything is linked,
            # while `nixos-rebuild switch` still reports success. Back it up
            # instead so one stray file can't strand every other update.
            home-manager.backupFileExtension = "hm-bak";
            home-manager.users.nixos = import ./home.nix;
          }
        ];
      };
    };
}
