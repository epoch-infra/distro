# Distro module bundle.
#
# Single import that pulls in every NixOS module this distro provides.
# Builds on noctalia-bar (which includes noctalia-plugin, opencrow,
# llama-swap) and adds niri compositor + VM debug support.
{ inputs, ... }:
{
  imports = [
    (import ./noctalia-bar.nix { inherit inputs; })
    ./niri.nix
    ./vm-debug.nix
  ];
}