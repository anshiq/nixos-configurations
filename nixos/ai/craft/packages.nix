# Everything built from apps.nix:
#   apps.<name>.{gui,cli}   the desktop app and its CLI (package.nix)
#   live.<name>-live        start the app with its control server, so an agent
#                           can drive the open window (and you can watch)
#   mcpLive.<name>-mcp-live MCP server bridged to that window (used by ai/mcp.nix)
#
# Control tokens are secrets, so they are never in the Nix store. Apps with
# `token` below take one we create on first use in
# ${XDG_STATE_HOME:-~/.local/state}/craft/<name>.token (mode 600), shared by the
# launcher and the MCP bridge. The others write their own token when started
# with --control (e.g. /run/user/<uid>/gridcraft/, ~/.config/wordcraft/) and
# their CLIs find it. PdfCraft's control channel is a file holding its port
# and token.
{
  lib,
  callPackage,
  writeShellApplication,
  coreutils,
}:

let
  apps = import ./apps.nix;
  mk = callPackage ./package.nix { };
  built = lib.mapAttrs mk apps;

  gui = name: lib.getExe built.${name}.gui;
  cli = name: lib.getExe built.${name}.cli;
  port = name: toString apps.${name}.controlPort;

  # How each app's live mode works (checked against each release):
  #   token  null: the app makes its own; "file": a token file both sides are
  #          given ($tok); or an env var name both sides read (from $tok)
  #   gui    arguments for the app (after the binary)
  #   mcp    arguments for <name>-cli to serve MCP bridged to the window
  # Bridges marked "exits" fail at startup while the app isn't open; the MCP
  # client then lists that server as failed for the session.
  liveSpecs = {
    photocraft = {
      token = "file";
      gui = ''--new-instance --control ${port "photocraft"} --control-token-file "$tok" --automation-read-root "$HOME" --automation-write-root "$HOME"'';
      mcp = ''mcp --bridge ${port "photocraft"} --control-token-file "$tok"'';
    };
    filmcraft = {
      token = "FILMCRAFT_CONTROL_TOKEN";
      gui = "--control ${port "filmcraft"}";
      mcp = "--bridge 127.0.0.1:${port "filmcraft"} mcp";
    };
    gridcraft = {
      # exits
      gui = "--control ${port "gridcraft"}";
      mcp = "mcp --connect ${port "gridcraft"}";
    };
    wordcraft = {
      gui = "--control ${port "wordcraft"}";
      mcp = "mcp --connect 127.0.0.1:${port "wordcraft"}";
    };
    deckcraft = {
      # exits
      gui = "--control ${port "deckcraft"}";
      mcp = "mcp --connect ${port "deckcraft"}";
    };
    designcraft = {
      # exits
      gui = "--control ${port "designcraft"}";
      mcp = "mcp --connect ${port "designcraft"}";
    };
    effectcraft = {
      gui = "--control ${port "effectcraft"}";
      mcp = "mcp --bridge ${port "effectcraft"}";
    };
    lightcraft = {
      gui = "--control ${port "lightcraft"}";
      mcp = "mcp --connect 127.0.0.1:${port "lightcraft"} --compact"; # 632 tools otherwise
    };
    materialcraft = {
      token = "MATERIALCRAFT_CONTROL_TOKEN";
      gui = "--control ${port "materialcraft"}";
      mcp = "mcp --bridge ${port "materialcraft"}";
    };
    soundcraft = {
      gui = "--control ${port "soundcraft"}";
      mcp = "mcp --connect ${port "soundcraft"}";
    };
    texturecraft = {
      token = "TEXTURECRAFT_CONTROL_TOKEN";
      gui = "--control ${port "texturecraft"}";
      mcp = "mcp --bridge ${port "texturecraft"}";
    };
    vectorcraft = {
      # exits
      gui = "--control ${port "vectorcraft"}";
      mcp = "mcp --connect 127.0.0.1:${port "vectorcraft"}";
    };
  };

  stateDir = ''state="''${XDG_STATE_HOME:-$HOME/.local/state}/craft"; mkdir -p "$state"; chmod 700 "$state"'';

  # Sets $tok (creating a random token if missing) and exports it when the app
  # reads it from an environment variable.
  tokenSetup =
    name: token:
    lib.optionalString (token != null) (
      ''
        ${stateDir}
        tok="$state/${name}.token"
        if [ ! -s "$tok" ]; then
          (umask 077; { od -An -tx1 -N32 /dev/urandom | tr -d ' \n'; echo; } > "$tok")
        fi
        chmod 600 "$tok"
      ''
      + lib.optionalString (token != "file") ''
        ${token}="$(tr -d '\n' < "$tok")"
        export ${token}
      ''
    );

  script =
    name: text:
    writeShellApplication {
      inherit name text;
      runtimeInputs = [ coreutils ];
    };

  live =
    lib.mapAttrs' (
      name: s:
      lib.nameValuePair "${name}-live" (
        script "${name}-live" ''
          ${tokenSetup name (s.token or null)}
          exec ${gui name} ${s.gui} "$@"
        ''
      )
    ) liveSpecs
    // {
      pdfcraft-live = script "pdfcraft-live" ''
        ${stateDir}
        echo "PdfCraft control file: $state/pdfcraft.control (pdfcraft-cli ui --control FILE <method>)" >&2
        exec ${gui "pdfcraft"} --new-window --control "$state/pdfcraft.control" "$@"
      '';
    };

  mcpLive = lib.mapAttrs' (
    name: s:
    lib.nameValuePair "${name}-mcp-live" (
      script "${name}-mcp-live" ''
        ${tokenSetup name (s.token or null)}
        exec ${cli name} ${s.mcp}
      ''
    )
  ) liveSpecs;
in
{
  apps = built;
  inherit live mcpLive;
  all =
    lib.concatMap (a: [
      a.gui
      a.cli
    ]) (lib.attrValues built)
    ++ lib.attrValues live
    ++ lib.attrValues mcpLive;
}
