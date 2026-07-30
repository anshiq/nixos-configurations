# /etc/nixos/configuration.nix

{ config, lib, pkgs, ... }:

{
  imports = [
   
  ];

  ############################
  ## WSL Configuration
  ############################

  wsl.enable = true;
  wsl.defaultUser = "nixos";
  wsl.interop.register= true;
  wsl.wslConf.interop.enabled = true;

  ############################
  ## Fish Shell
  ############################

  programs.fish.enable = true;

  users.users.nixos = {
    isNormalUser = true;
    description = "NixOS User";
    extraGroups = [ "wheel" ];
    shell = pkgs.fish;
  };

  ############################
  ## System Packages
  ############################
  #
  # NOTE ON MIGRATION: `zellij`, `yazi`, `lazygit`, and `fzf` are
  # intentionally NOT listed here. They are managed as Home Manager
  # *programs* in home.nix instead (programs.zellij / programs.yazi /
  # programs.fzf), which is the more "Nix-idiomatic" path: it installs
  # the package AND wires up its dotfiles/shell-integration from the
  # same declarative block, rather than splitting "package present"
  # (here) from "package configured" (home.nix) across two files.
  #
  # `zoxide` was on your old Ubuntu box (referenced in config.fish) but
  # you've asked to drop it entirely during this migration - it is not
  # installed anywhere in this config anymore.
  #
  # Alacritty was intentionally left out of this migration entirely:
  # since this NixOS runs under WSL, Alacritty is normally a
  # Windows-side GUI app rather than something the WSL Linux guest
  # manages, and you confirmed you don't need it here.

  environment.systemPackages = with pkgs; [
    # Shell
    fish
    starship

    # Editors
    neovim
    vim
    helix

    # Git & SSH
    git
    openssh
    gh

    # Networking
    curl
    wget

    # Modern CLI tools
    eza
    bat
    fd
    ripgrep
    fzf
    zoxide
    jq
    tree
    unzip
    zip

    # Monitoring
    btop
    htop

    # Utilities
    which
    file
    gnupg
  ];

  ############################
  ## Git
  ############################

  programs.git.enable = true;

  ############################
  ## SSH
  ############################

  services.openssh.enable = true;

  ############################
  ## Starship Prompt
  ############################

  programs.starship.enable = true;

  ############################
  ## Nix Settings
  ############################

  nix.settings.experimental-features = [
    "nix-command"
    "flakes"
  ];

  ############################
  ## Locale
  ############################

  time.timeZone = "Asia/Kolkata";

  i18n.defaultLocale = "en_US.UTF-8";

  ############################
  ## State Version
  ############################

  system.stateVersion = "26.05";
}
