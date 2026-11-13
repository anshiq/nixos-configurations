# /etc/nixos/flake.nix
{
  description = "My NixOS + Home Manager config";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    home-manager = {
      url = "github:nix-community/home-manager";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs =
    {
      nixpkgs,
      home-manager,
      ...
    }:
    let
      inherit (nixpkgs) lib;

      # modules/hardware/<name>.nix, handed to every host as `hardwareModules.<name>`
      # so a host's default.nix can opt into pieces without relative paths.
      hardwareModules = lib.mapAttrs' (
        file: _: lib.nameValuePair (lib.removeSuffix ".nix" file) (./modules/hardware + "/${file}")
      ) (builtins.readDir ./modules/hardware);

      # One system per hosts/<name>/ directory (default.nix + hardware-configuration.nix).
      # The CPU architecture comes from nixpkgs.hostPlatform in that host's
      # hardware-configuration.nix, so x86_64 and aarch64 machines sit side by side.
      # hosts/examples/ holds templates and is not built.
      hostNames = lib.attrNames (
        lib.filterAttrs (name: type: type == "directory" && name != "examples") (builtins.readDir ./hosts)
      );

      mkHost =
        hostDir:
        nixpkgs.lib.nixosSystem {
          specialArgs = { inherit hardwareModules; };
          modules = [
            hostDir
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

      hosts = lib.genAttrs hostNames (name: mkHost (./hosts + "/${name}"));
    in
    {
      # Exposed so a template under hosts/examples/ can be test-built:
      #   nix eval .#lib.mkHost ... (see hosts/README.md)
      lib.mkHost = mkHost;

      # `nixos` is the original machine's name, kept so
      # `nixos-rebuild --flake /etc/nixos#nixos` keeps working.
      nixosConfigurations = hosts // {
        nixos = hosts.laptop-amd;
      };
    };
}
