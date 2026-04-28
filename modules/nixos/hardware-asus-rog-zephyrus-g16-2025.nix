# ASUS ROG Zephyrus G16 2025 / GU605CW-class laptop.
#
# Target class for the Local AI OS desktop POC: Intel iGPU for display + NVIDIA
# Blackwell dGPU for CUDA/offload. The base quirks come from nixos-hardware;
# this module adds the AI-OS defaults that matter for local inference.
{ inputs, ... }:
{
  config,
  lib,
  pkgs,
  ...
}:
{
  imports = [ inputs.nixos-hardware.nixosModules.asus-zephyrus-gu605cw ];

  nixpkgs.hostPlatform = lib.mkDefault "x86_64-linux";
  nixpkgs.config.cudaCapabilities = lib.mkDefault [ "12.0" ];

  # Blackwell laptop enablement is still moving quickly; prefer the newest
  # kernel/driver pair unless the consuming host pins something more specific.
  boot.kernelPackages = lib.mkDefault pkgs.linuxPackages_latest;

  hardware.graphics.enable = lib.mkDefault true;
  hardware.nvidia = {
    package = lib.mkDefault config.boot.kernelPackages.nvidiaPackages.production;
    open = lib.mkDefault true;
    nvidiaSettings = lib.mkDefault false;
    powerManagement.enable = lib.mkDefault true;
  };

  hardware.nvidia-container-toolkit.enable = lib.mkDefault true;

  environment.systemPackages = [
    pkgs.nvtopPackages.nvidia
    pkgs.pciutils
  ];
}
