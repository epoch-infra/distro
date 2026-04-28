# ASUS ROG Flow Z13 2025 / GZ302-class tablet laptop.
#
# Target class for the high-memory mobile desktop POC: AMD Strix Halo / Ryzen AI
# Max with a large unified-memory Radeon iGPU. No machine-specific
# nixos-hardware module exists yet, so this is a conservative common AMD laptop
# profile plus the kernel/graphics defaults needed by the platform.
{ inputs, ... }:
{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.distro.hardware.asus-rog-flow-z13-2025;
in
{
  imports = [
    inputs.nixos-hardware.nixosModules.common-cpu-amd
    inputs.nixos-hardware.nixosModules.common-cpu-amd-pstate
    inputs.nixos-hardware.nixosModules.common-gpu-amd
    inputs.nixos-hardware.nixosModules.common-pc-laptop-ssd
  ];

  options.distro.hardware.asus-rog-flow-z13-2025 = {
    rocmOpencl.enable = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = ''
        Enable ROCm OpenCL userspace. Kept off by default because Strix Halo
        support is moving quickly; llama.cpp/Vulkan is the primary local lane.
      '';
    };
  };

  config = {
    nixpkgs.hostPlatform = lib.mkDefault "x86_64-linux";

    # 6.14+ carries the baseline Strix Halo graphics support; keep following
    # latest until the hardware is boring in stable kernels.
    boot.kernelPackages = lib.mkIf (lib.versionOlder pkgs.linux.version "6.14") (
      lib.mkDefault pkgs.linuxPackages_latest
    );
    boot.kernelModules = [ "kvm-amd" ];
    boot.initrd.kernelModules = [ "amdgpu" ];
    boot.kernelParams = [ "amd_pstate=active" ];

    hardware.graphics = {
      enable = lib.mkDefault true;
      enable32Bit = lib.mkDefault true;
    };
    hardware.amdgpu = {
      initrd.enable = lib.mkDefault true;
      opencl.enable = lib.mkDefault cfg.rocmOpencl.enable;
    };

    # Flow devices are 2-in-1s; this gives Niri/desktop components rotation data.
    hardware.sensor.iio.enable = lib.mkDefault true;

    services.asusd.enable = lib.mkDefault true;
    services.power-profiles-daemon.enable = lib.mkDefault true;

    environment.systemPackages = [
      pkgs.nvtopPackages.amd
      pkgs.pciutils
      pkgs.usbutils
    ];
  };
}
