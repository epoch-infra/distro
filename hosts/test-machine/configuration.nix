# Minimal NixOS VM for testing distro modules.
{ config, ... }:
{
  imports = [
    ../../modules/nixos/niri.nix
    ../../modules/nixos/noctalia.nix
    ../../modules/nixos/vm-debug.nix
  ];

  nixpkgs.hostPlatform = "x86_64-linux";

  boot.loader.systemd-boot.enable = true;
  fileSystems."/" = {
    device = "/dev/vda1";
    fsType = "ext4";
  };

  networking.hostName = "test-machine";

  users.users.test = {
    isNormalUser = true;
    uid = 1000;
    initialPassword = "test";
    extraGroups = [ "wheel" ];
  };

  # Boot directly into a niri session — no greeter (per nixos wiki).
  services.greetd = {
    enable = true;
    settings.default_session = {
      command = "${config.programs.niri.package}/bin/niri-session";
      user = "test";
    };
  };

  system.stateVersion = "25.05";
}
