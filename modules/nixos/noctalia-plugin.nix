# Noctalia AI chat plugin.
#
# Base integration layer.  Single import for users who already run
# noctalia-shell.  Provides the opencrow-chat panel plugin, the opencrow
# agent backend, and llama-swap LLM serving.
{ inputs, ... }:
{
  imports = [
    inputs.opencrow.nixosModules.default
    (import ./opencrow.nix { inherit inputs; })
    ./llama-swap.nix
  ];
}