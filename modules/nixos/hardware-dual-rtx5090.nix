# Dual RTX 5090 / Blackwell inference workstation profile.
#
# Headless GPU server baseline for the Local AI OS POC. This is intentionally
# hardware-only: combine it with nixosModules.server for the llama-swap offload
# service and with a machine-local disk/network configuration.
{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.distro.hardware.dual-rtx5090;
in
{
  options.distro.hardware.dual-rtx5090 = {
    cudaCapabilities = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [ "12.0" ];
      description = "CUDA architectures to build for RTX 5090 / Blackwell GPUs.";
    };

    containerToolkit.enable = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = "Enable NVIDIA Container Toolkit/CDI for containerized GPU workloads.";
    };
  };

  config = {
    nixpkgs.hostPlatform = lib.mkDefault "x86_64-linux";
    nixpkgs.config.cudaCapabilities = lib.mkDefault cfg.cudaCapabilities;

    # Blackwell support depends on recent kernels and userspace drivers.
    boot.kernelPackages = lib.mkDefault pkgs.linuxPackages_latest;
    boot.blacklistedKernelModules = [ "nouveau" ];

    services.xserver.videoDrivers = lib.mkDefault [ "nvidia" ];
    hardware.graphics.enable = lib.mkDefault true;
    hardware.nvidia = {
      package = lib.mkDefault config.boot.kernelPackages.nvidiaPackages.production;
      open = lib.mkDefault true;
      modesetting.enable = lib.mkDefault true;
      nvidiaSettings = lib.mkDefault false;
      nvidiaPersistenced = lib.mkDefault true;
      powerManagement.enable = lib.mkDefault false;
    };

    hardware.nvidia-container-toolkit.enable = lib.mkDefault cfg.containerToolkit.enable;

    environment.systemPackages = [
      pkgs.nvtopPackages.nvidia
      pkgs.pciutils
    ];
  };
}
