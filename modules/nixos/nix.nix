# Nix daemon defaults.
#
# Enables the `nix-command` and `flakes` experimental features so
# flake-based workflows work out of the box on any host that imports
# this module.
{ lib, ... }:
{
  nix.settings.experimental-features = lib.mkDefault [
    "nix-command"
    "flakes"
  ];
}
