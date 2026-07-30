# /etc/nixos/home.nix
{ config, pkgs, ... }:
{
  home.stateVersion = "26.05";

  home.username = "nixos";
  home.homeDirectory = "/home/nixos";

  # Helix itself + the LSPs/formatters your languages.toml references
  home.packages = with pkgs; [
    helix

    # LSPs
    typescript-language-server
    vscode-langservers-extracted   # eslint, html, css, json servers
    tailwindcss-language-server
    yaml-language-server
    marksman
    taplo
    rust-analyzer
    gopls
    clang-tools                    # clangd
    jdt-language-server
    python3Packages.python-lsp-server
    python3Packages.flake8
    bash-language-server
    jdt-language-server

    # Formatters
    prettier
    black
    gotools                        # goimports
    shfmt

    # Used in your keybinds
    lazygit
    yazi



    ############################
    ## Dev Toolchains
    ############################

    # C / C++
    gcc          # includes g++ (gcc wrapper handles both)
    gnumake
    cmake
    pkg-config   # almost always needed alongside cmake/gcc for library detection

    # Java
    jdk21        # pin a specific LTS version rather than floating `jdk`

    # Node.js
    nodejs_22    # pin a version instead of floating `nodejs`

    # Go
    go

    # Rust
    rustc
    cargo
    rustfmt
    clippy
    rust-analyzer   # you likely already have this from the LSP list — don't duplicate

    # Python
    python3
    python3Packages.pip
    python3Packages.virtualenv
    
  ];

  xdg.configFile."helix/config.toml".source = ./helix/config.toml;
  xdg.configFile."helix/languages.toml".source = ./helix/languages.toml;
}
