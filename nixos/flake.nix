# /etc/nixos/flake.nix
{
  description = "My NixOS + Home Manager config";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    # WSL migration input kept as a reference only. Native NixOS must not load it.
    # nixos-wsl.url = "github:nix-community/NixOS-WSL";
    home-manager = {
      url = "github:nix-community/home-manager";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    # Ported Omarchy plugin lifecycle scripts (add/enable/disable/update/
    # remove/clone/list/catalog/validate + git-url-check), adapted to this
    # repo's Quickshell paths. Plain file repo, not a flake.
    omarchy-binaries = {
      url = "github:anshiq/omarchy-binaries-for-nixos";
      flake = false;
    };
  };

  outputs =
    inputs@{
      self,
      nixpkgs,
      home-manager,
      ...
    }:
    {
      nixosConfigurations.nixos = nixpkgs.lib.nixosSystem {
        system = "x86_64-linux";
        # Makes the ported plugin source tree visible to modules as
        # `omarchyBinaries` (dashes are illegal in Nix identifiers, hence
        # the rename from the input's `omarchy-binaries`).
        specialArgs = {
          omarchyBinaries = inputs."omarchy-binaries";
        };
        modules = [
          # nixos-wsl.nixosModules.wsl # Disabled: this host is native NixOS.
          ./configuration.nix
          home-manager.nixosModules.home-manager
          (
            { omarchyBinaries, ... }:
            {
              home-manager.useGlobalPkgs = true;
              home-manager.useUserPackages = true;
              # Forward the flake input to home-manager modules (home.nix
              # -> plugins/cli.nix) so the ported scripts can be packaged.
              home-manager.extraSpecialArgs = { inherit omarchyBinaries; };
              # Without this, a single pre-existing file in ~/.config that
              # home-manager doesn't own aborts the ENTIRE activation in
              # checkLinkTargets - before any file is linked - so *nothing*
            # under ~/.config gets updated while `nixos-rebuild switch`
            # still reports success for the system half. That silently
            # stranded every script/keybind fix for a full day of work
            # (a hand-made ~/.config/quickshell symlink was the trigger;
            # see desktop/home.nix). Backing the stray file up instead of
            # bailing keeps activation total: a mistake in one file can no
            # longer strand every other file.
            home-manager.backupFileExtension = "hm-bak";
            home-manager.users.nixos = import ./home.nix;
            }
          )
        ];
      };
    };
}
