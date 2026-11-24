# One MCP server list for Claude Code, Codex and opencode.
#
# Each `home-manager switch` (i.e. every `nixos-rebuild switch`) merges the
# servers below into the tools' own config files:
#   Claude Code  ~/.claude.json                     .mcpServers
#   Codex        ~/.codex/config.toml               [mcp_servers.*]
#   opencode     ~/.config/opencode/opencode.jsonc  .mcp
#
# Those files are NOT symlinked into the store: Claude rewrites ~/.claude.json
# constantly and Codex writes project trust levels into config.toml, so they
# must stay writable. Only the servers named here are owned by Nix; anything
# else in those files (servers you add by hand, project-scoped servers, all
# other settings) is left alone. Removing a server from this list removes it
# from the configs on the next switch (tracked in
# ~/.local/state/nix-mcp/managed.json).
#
# Server fields:
#   command, args, env       how to start it (stdio)
#   harness = true           append `--harness <claude-code|codex|opencode>`
#   claude / codex / opencode  extra keys merged into that tool's entry only
#   enable = false           drop the server everywhere (removed on next switch)
#
# Every server adds its tools to each session's context, so switch off the
# ones you don't use with `enable = false`.
{
  config,
  lib,
  pkgs,
  ...
}:

let
  home = config.home.homeDirectory;
  craft = pkgs.callPackage ./craft/packages.nix { };
  craftMcp = name: args: {
    command = lib.getExe craft.apps.${name}.cli;
    inherit args;
  };
  homeRoots = [
    "--automation-read-root"
    home
    "--automation-write-root"
    home
  ];

  allServers = {
    codegraph = {
      command = "codegraph";
      args = [
        "serve"
        "--mcp"
      ];
    };

    rea = {
      command = "npx";
      args = [
        "-y"
        "rea-agents@6.7.0"
        "mcp"
      ];
      codex = {
        startup_timeout_sec = 30;
        tool_timeout_sec = 450;
      };
    };

    jack-ketch = {
      command = "${home}/.local/bin/jack-ketch";
      args = [ "serve" ];
      harness = true;
      claude.timeout = 660000;
      codex.startup_timeout_sec = 30;
      opencode.timeout = 30000;
    };

    # ---- ArtCraft apps (ai/craft). Headless servers work on files with no
    # window; the *-live ones (generated below from ai/craft/packages.nix)
    # drive the window opened by `<name>-live`.
    pdfcraft = craftMcp "pdfcraft" (
      [
        "mcp"
        "--compact"
      ]
      ++ homeRoots
    ); # 208 tools without --compact
    photocraft = craftMcp "photocraft" ([ "mcp" ] ++ homeRoots);
    wordcraft = craftMcp "wordcraft" ([ "mcp" ] ++ homeRoots);
    deckcraft = craftMcp "deckcraft" ([ "mcp" ] ++ homeRoots);
    designcraft = craftMcp "designcraft" ([ "mcp" ] ++ homeRoots);
    effectcraft = craftMcp "effectcraft" ([ "mcp" ] ++ homeRoots);
    materialcraft = craftMcp "materialcraft" ([ "mcp" ] ++ homeRoots);
    soundcraft = craftMcp "soundcraft" ([ "mcp" ] ++ homeRoots);
    texturecraft = craftMcp "texturecraft" ([ "mcp" ] ++ homeRoots);
    # Without --headless it would drive a VectorCraft window on port 7979 if one is open.
    vectorcraft = craftMcp "vectorcraft" (
      [
        "mcp"
        "--headless"
      ]
      ++ homeRoots
    );

    # These headless engines have no sandbox flag: they can read and write
    # anything you can.
    filmcraft = craftMcp "filmcraft" [ "mcp" ];
    gridcraft = craftMcp "gridcraft" [ "mcp" ];
    anicraft = craftMcp "anicraft" [ "mcp" ];
    lightcraft = craftMcp "lightcraft" [
      "mcp"
      "--compact"
    ];
    # Full mode (your choice): its tools can run code, change devices, open
    # websites and capture pages. For a safer default add "--restricted"
    # (then opt in with --allow-web / --allow-capture / --allow-run).
    craft-anything = craftMcp "craft-anything" [ "mcp" ];
  }
  // lib.mapAttrs' (
    bin: drv:
    lib.nameValuePair (lib.removeSuffix "-mcp-live" bin + "-live") { command = lib.getExe drv; }
  ) craft.mcpLive;

  servers = lib.filterAttrs (_: s: s.enable or true) allServers;

  argsFor =
    harnessId: s:
    (s.args or [ ])
    ++ lib.optionals (s.harness or false) [
      "--harness"
      harnessId
    ];
  envOf = s: s.env or { };
  withEnv = key: s: lib.optionalAttrs (envOf s != { }) { ${key} = envOf s; };

  rendered = {
    claude = lib.mapAttrs (
      _: s:
      {
        type = "stdio";
        command = s.command;
        args = argsFor "claude-code" s;
      }
      // withEnv "env" s
      // (s.claude or { })
    ) servers;

    codex = lib.mapAttrs (
      _: s:
      {
        command = s.command;
        args = argsFor "codex" s;
      }
      // withEnv "env" s
      // (s.codex or { })
    ) servers;

    opencode = lib.mapAttrs (
      _: s:
      {
        type = "local";
        command = [ s.command ] ++ argsFor "opencode" s;
        enabled = true;
      }
      // withEnv "environment" s
      // (s.opencode or { })
    ) servers;
  };

  renderedFile = pkgs.writeText "mcp-servers.json" (builtins.toJSON rendered);
  python = pkgs.python3.withPackages (p: [ p.tomli-w ]);
in
{
  home.activation.syncMcpServers = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
    run ${python}/bin/python3 -I ${./mcp-sync.py} ${renderedFile}
  '';
}
