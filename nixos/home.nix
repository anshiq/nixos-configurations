# /etc/nixos/home.nix
{ config, lib, pkgs, ... }:
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
    kotlin-language-server

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
    # rust-analyzer already listed above under LSPs - not duplicated

    # Python
    python3
    python3Packages.pip
    python3Packages.virtualenv
    uv

    ############################
    ## Bun (installed via home.packages; BUN_INSTALL env var set below)
    ############################
    bun
  ];

  xdg.configFile."helix/config.toml".source = ./helix/config.toml;
  xdg.configFile."helix/languages.toml".source = ./helix/languages.toml;

  ############################################################
  ## Fish shell
  ############################################################
  # Migrated from config.fish. What moved where:
  #  - PATH additions      -> home.sessionPath (idiomatic, shell-agnostic)
  #  - BUN_INSTALL / GOPATH -> home.sessionVariables
  #  - aliases             -> programs.fish.shellAliases
  #  - functions (mkcd, gfile, y, dev) -> programs.fish.functions
  #  - zoxide integration  -> REMOVED. You asked to drop zoxide entirely
  #    during this migration - it is no longer installed or referenced
  #    anywhere in this config.
  #  - fzf integration     -> programs.fzf.enableFishIntegration (below),
  #    which generates the exact same `fzf --fish | source` for you.

  home.sessionVariables = {
    BUN_INSTALL = "$HOME/.bun";
    GOPATH = "$HOME/.go";
    GOROOT = "${pkgs.go}/share/go";

    JAVA_HOME = "${pkgs.jdk21}/lib/openjdk";
    NPM_CONFIG_PREFIX = "$HOME/.npm-global";

  # Rust doesn't need CARGO_HOME/RUSTUP_HOME unless you use rustup
  # (you're using pkgs.rustc/cargo directly, so this is optional)
    CARGO_HOME = "$HOME/.cargo";
  };

  home.sessionPath = [
    "$HOME/.npm-global/bin"
    "$HOME/.local/bin"
    "$HOME/.tmuxifier/bin"
    "$HOME/.go/bin"
  ];

programs.fish = {
  enable = true;

  shellAliases = {
    glog = "git log --oneline --graph --decorate";
    reload = "source ~/.config/fish/config.fish";
    zjl = "zellij list-sessions";
    zja = "zellij attach";
  };

  interactiveShellInit = ''
    if type -q hx
        set -gx EDITOR hx
    else if type -q nvim
        set -gx EDITOR nvim
    else if type -q vi
        set -gx EDITOR vi
    end

    set -gx VISUAL $EDITOR
  '';

  functions = {
    mkcd = {
      description = "Create a directory and cd into it";
      body = ''
        if test (count $argv) -eq 0
            echo "Usage: mkcd <dir>"
            return 1
        end
        mkdir -p $argv[1]; and cd $argv[1]
      '';
    };

    gfile = {
      description = "Create one or more files along with parent directories";
      body = ''
        if test (count $argv) -eq 0
            echo "Usage: gfile ./path/to/file1.ext ./another/file2.ts ..."
            return 1
        end
        for filepath in $argv
            set dir (dirname $filepath)
            mkdir -p $dir
            if not test -e $filepath
                touch $filepath
                echo "Created: $filepath"
            else
                echo "Already exists: $filepath"
            end
        end
      '';
    };

    y = {
      description = "Open yazi and cd into last directory on exit";
      body = ''
        set tmp (mktemp -t "yazi-cwd.XXXXX")
        yazi $argv --cwd-file="$tmp"

        if set cwd (command cat -- "$tmp")
            and test -n "$cwd"
            and test "$cwd" != "$PWD"
            builtin cd -- "$cwd"
        end

        rm -f -- "$tmp"
      '';
    };

    dev = {
      description = "Launch Zellij with dev layout in current dir";
      body = ''
        zellij --layout ${config.xdg.configHome}/zellij/layouts/dev.kdl
      '';
    };
  };
};
  ############################################################
  ## fzf - fuzzy finder (kept; zoxide was dropped, fzf was not)
  ############################################################
  programs.fzf = {
    enable = true;
    enableFishIntegration = true;
  };

  ############################################################
  ## Zellij - terminal multiplexer
  ############################################################
  # NOTE: `zellij` did not exist anywhere in your original NixOS config
  # (not in configuration.nix systemPackages, not in home.nix) even
  # though config.kdl, dev.kdl, and your fish `dev`/`zjl`/`zja` all
  # depend on it. `programs.zellij.enable = true` below both installs
  # the package AND wires it up - this closes that gap.
  #
  # The keybinds block from config.kdl uses `clear-defaults=true` at
  # the top, which is verbatim KDL syntax rather than a structured
  # home-manager option, so it's passed through `extraConfig` unchanged
  # to guarantee byte-for-byte identical keybindings. Everything else
  # (theme, default_shell, mouse_mode, etc.) uses the structured
  # `settings` option, which is the idiomatic, type-checked path.
  programs.zellij = {
    enable = true;
    enableFishIntegration = false; # you launch zellij manually / via `dev`, not on every shell start

    settings = {
      theme = "catppuccin-mocha";
      default_shell = "fish";
      default_layout = "compact";
      mouse_mode = true;
      pane_frames = false;
      mirror_session = false;
      scroll_buffer_size = 10000;
      copy_on_select = true;
      show_startup_tips = false;

      plugins = {
        about.location = "zellij:about";
        compact-bar.location = "zellij:compact-bar";
        configuration.location = "zellij:configuration";
        filepicker = {
          location = "zellij:strider";
          cwd = "/";
        };
        plugin-manager.location = "zellij:plugin-manager";
        session-manager.location = "zellij:session-manager";
        status-bar.location = "zellij:status-bar";
        strider.location = "zellij:strider";
        tab-bar.location = "zellij:tab-bar";
        welcome-screen = {
          location = "zellij:session-manager";
          welcome_screen = true;
        };
      };

      load_plugins = [ "zellij:link" ];

      web_client.font = "monospace";
    };

    # Verbatim keybinds block from your original config.kdl, preserved
    # exactly (including `clear-defaults=true`) since this is raw KDL
    # syntax rather than something the `settings` attrset models 1:1.
            #  bind "Ctrl x" { CloseFocus; } # shit shortcout
    extraConfig = ''
      keybinds clear-defaults=true {
          normal {
              bind "Alt -" { Resize "Decrease"; }
              bind "Alt =" { Resize "Increase"; }
              bind "Ctrl f" { ToggleFloatingPanes; }
              bind "Ctrl g" { SwitchToMode "locked"; }
              bind "Ctrl h" { MoveFocus "left"; }
              bind "Ctrl j" { MoveFocus "down"; }
              bind "Ctrl k" { MoveFocus "up"; }
              bind "Ctrl l" { MoveFocus "right"; }
              bind "Ctrl n" { NewPane; }
              bind "Ctrl o" { SwitchToMode "session"; }
              bind "Ctrl p" { SwitchToMode "pane"; }
              bind "Ctrl s" { SwitchToMode "scroll"; }
              bind "Ctrl t" { SwitchToMode "tab"; }
          }
          locked {
              bind "Ctrl g" { SwitchToMode "normal"; }
          }
          pane {
              bind "f" { ToggleFocusFullscreen; SwitchToMode "normal"; }
              bind "h" { MoveFocus "left"; SwitchToMode "normal"; }
              bind "j" { MoveFocus "down"; SwitchToMode "normal"; }
              bind "k" { MoveFocus "up"; SwitchToMode "normal"; }
              bind "l" { MoveFocus "right"; SwitchToMode "normal"; }
              bind "n" { NewPane; SwitchToMode "normal"; }
              bind "r" { SwitchToMode "renamepane"; PaneNameInput 0; }
              bind "x" { CloseFocus; SwitchToMode "normal"; }
              bind "z" { TogglePaneFrames; SwitchToMode "normal"; }
          }
          tab {
              bind "1" { GoToTab 1; SwitchToMode "normal"; }
              bind "2" { GoToTab 2; SwitchToMode "normal"; }
              bind "3" { GoToTab 3; SwitchToMode "normal"; }
              bind "4" { GoToTab 4; SwitchToMode "normal"; }
              bind "h" { GoToPreviousTab; }
              bind "l" { GoToNextTab; }
              bind "n" { NewTab; SwitchToMode "normal"; }
              bind "r" { SwitchToMode "renametab"; TabNameInput 0; }
              bind "x" { CloseTab; SwitchToMode "normal"; }
          }
          scroll {
              bind "/" { SwitchToMode "entersearch"; SearchInput 0; }
              bind "G" { ScrollToBottom; SwitchToMode "normal"; }
              bind "d" { HalfPageScrollDown; }
              bind "j" { ScrollDown; }
              bind "k" { ScrollUp; }
              bind "u" { HalfPageScrollUp; }
          }
          search {
              bind "N" { Search "up"; }
              bind "n" { Search "down"; }
          }
      }
    '';

    # Your `dev` layout, referenced by the fish `dev` function above.
    # home-manager writes this to $XDG_CONFIG_HOME/zellij/layouts/dev.kdl
    layouts = {
      dev = ''
        layout {
            pane split_direction="vertical" {
                pane size="60%" focus=true {
                    command "hx"
                }
                pane split_direction="horizontal" {
                    pane size="60%" { command "fish"; }
                    pane { command "yazi"; }
                }
            }
            pane size=1 borderless=true {
                plugin location="zellij:compact-bar"
            }
        }
      '';
    };
  };

  ############################################################
  ## Yazi - terminal file manager
  ############################################################
  # settings/keymap/theme are imported from plain TOML files kept
  # alongside this config (./yazi/*.toml), per the pattern documented
  # on the NixOS wiki - this keeps the TOML portable/readable on its
  # own while still letting Nix manage placement + packages/plugins.
  #
  # Plugin deps from your old package.toml:
  #   yazi-rs/plugins:git            -> pkgs.yaziPlugins.git (packaged upstream)
  #   yazi-rs/plugins:jump-to-char   -> pkgs.yaziPlugins."jump-to-char" (packaged upstream)
  # Both are now maintained by nixpkgs directly, so the manual
  # rev/hash pins from package.toml are no longer needed.
  programs.yazi = {
    enable = true;
    enableFishIntegration = false; # you use the custom `y` function above instead

    settings = lib.importTOML ./yazi/yazi.toml;
    keymap = lib.importTOML ./yazi/keymap.toml;
    theme = lib.importTOML ./yazi/theme.toml;

    plugins = {
      git = pkgs.yaziPlugins.git;
      jump-to-char = pkgs.yaziPlugins."jump-to-char";
    };
  };
}
