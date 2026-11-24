# ArtCraft desktop apps (https://github.com/storytold/<name>), pinned by version.
# Only text lives here: each AppImage is downloaded from its GitHub release into
# the Nix store at build time and checked against `hash`.
#
# To update an app: bump `version`, set `hash = "";`, rebuild, and paste the
# hash nix reports in the error.
#
# controlPort: the localhost port `<name>-live` opens the app's control server
# on, which the `<name>-live` MCP entry (ai/mcp.nix) connects to. PdfCraft's
# control channel is a file, not a port (see packages.nix).
{
  pdfcraft = {
    version = "0.21.1";
    hash = "sha256-cwJ2zamt2z1I8mxgJobRj8W8Dr42CmCi9SLXDP1CjSE=";
    description = "PDF reader and editor";
  };
  photocraft = {
    version = "0.23.1";
    hash = "sha256-BXR7PlJ+HgoMHeOZcDYc84yPyn6NPjYB7yCC+w5t0X8=";
    description = "Image editor";
    controlPort = 47321;
  };
  filmcraft = {
    version = "0.20.1";
    hash = "sha256-SiWuyy6UgbZec1NSi8qeSoxTiN1V8Uhv/mRQLgi9+gI=";
    description = "Video editor";
    controlPort = 47331;
  };
  gridcraft = {
    version = "0.19.1";
    hash = "sha256-WxzhCtbHotOJJJ39JZAQAUqF/OGqQsYn/EzaVxZx4iE=";
    description = "Spreadsheet";
    controlPort = 47341;
  };
  wordcraft = {
    version = "0.18.1";
    hash = "sha256-u8XBWwbUQDz9WllHW9+SZKScK88fktEjMRtQqdzjyIg=";
    description = "Word processor";
    controlPort = 47351;
  };
  deckcraft = {
    version = "0.18.1";
    hash = "sha256-aN+fBA0/bEzkqQSq3sYzlh+hmSSPChqjZvpkWXrgmGc=";
    description = "Presentation editor";
    controlPort = 47361;
  };
  designcraft = {
    version = "0.20.1";
    hash = "sha256-+db9a7GkIYUCQ8DUvkQjVxOp7Fsm+L8dW6h6/Pj5FTQ=";
    description = "Page layout";
    controlPort = 47371;
  };
  effectcraft = {
    version = "0.24.1";
    hash = "sha256-n4oWz3QUfJ4qw7ZfpvW+lqPhDq2S3fCNVE9dOZCtZNw=";
    description = "Motion graphics and VFX compositor";
    controlPort = 47381;
  };
  lightcraft = {
    version = "0.21.1";
    hash = "sha256-xCEtoid3oAANnrZshbeGXp6ZEfR6YCB9eFK3wGOtqKk=";
    description = "Photo library and raw developer";
    controlPort = 47391;
  };
  materialcraft = {
    version = "0.4.1";
    hash = "sha256-1R++QDSoIgR0UHIi9k2AHiZknIEzs+e0WPPpdYwItqE=";
    description = "Procedural PBR material designer";
    controlPort = 47401;
  };
  soundcraft = {
    version = "0.20.1";
    hash = "sha256-TbtAKkE+wqUxA7n6d9Y1bm/usIbZSXXJXmNcdLQ02vg=";
    description = "Digital audio workstation";
    controlPort = 47411;
  };
  texturecraft = {
    version = "0.6.1";
    hash = "sha256-kEdgAW/TdL8J/RtKPIQBy8fmvDy8DUQn43S5v4ExbKY=";
    description = "3D texture painter";
    controlPort = 47421;
  };
  vectorcraft = {
    version = "0.24.1";
    hash = "sha256-vc5+gumB+fTtC/JfpvJeb+T6sn6JZB5vlIiZ4BsTpRQ=";
    description = "Vector graphics editor";
    controlPort = 47431;
  };
  # No live control server in these two: headless MCP only.
  anicraft = {
    version = "0.2.1";
    hash = "sha256-NSRWOE0egvNz2DbcvNnxRzsWA8XJx7GF12MhhHAJGzE=";
    description = "2D vector animation studio";
  };
  craft-anything = {
    version = "0.6.1";
    hash = "sha256-fq3eHXSrQsyDiGL+P4MePPPJ+mul4r8E4oJLvEcUYTQ=";
    description = "Software explorer";
  };
}
