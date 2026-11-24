# Personal Claude Code skills, kept in the checkout and linked into
# ~/.claude/skills/ one folder each.
#
# Every directory under ./skills/ becomes ~/.claude/skills/<name>, a live
# link (like quickshell/): edits from either side land in ./skills/<name>/
# with no rebuild. Adding a skill = add its folder here, `git add` it (the
# flake only sees tracked files) and rebuild once to create the link.
#
# Not here, on purpose:
#   - ~/.claude/skills/{jack-ketch-*,reverse-engineer-anything,synced}: the
#     jack-ketch and REA tools and claude.ai sync install and update those.
#   - ~/.claude/settings.json: this repo is public and that file describes
#     other projects (auto-mode environment).
# ~/.claude/CLAUDE.md is linked from ../../home.nix.
{ config, lib, ... }:

let
  skills = lib.attrNames (lib.filterAttrs (_: type: type == "directory") (builtins.readDir ./skills));
in
{
  home.file = lib.listToAttrs (
    map (
      name:
      lib.nameValuePair ".claude/skills/${name}" {
        source = config.lib.file.mkOutOfStoreSymlink "/etc/nixos/ai/claude/skills/${name}";
      }
    ) skills
  );
}
