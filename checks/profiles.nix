{
  inputs,
  pkgs,
  system,
  ...
}:
let
  inherit (pkgs) lib;

  baseModule = {
    system.stateVersion = "26.05";
    fileSystems."/" = {
      device = "tmpfs";
      fsType = "tmpfs";
    };
    boot.loader.grub.enable = false;
    nixpkgs.config.allowUnfree = true;
    users.users.distro = {
      isNormalUser = true;
      password = "distro";
    };
  };

  evalProfile =
    name: modules:
    let
      sys = inputs.nixpkgs.lib.nixosSystem {
        inherit system;
        modules = modules ++ [ baseModule ];
      };
      inherit (sys.config.system.build.toplevel) drvPath;
    in
    builtins.seq drvPath "${name} ${builtins.unsafeDiscardStringContext drvPath}";

  profiles = [
    (evalProfile "desktop-zephyrus-g16-2025" [
      inputs.self.nixosModules.desktop
      inputs.self.nixosModules.hardware-asus-rog-zephyrus-g16-2025
    ])
    (evalProfile "desktop-flow-z13-2025" [
      inputs.self.nixosModules.desktop
      inputs.self.nixosModules.hardware-asus-rog-flow-z13-2025
    ])
    (evalProfile "server-dual-rtx5090" [
      inputs.self.nixosModules.server
      inputs.self.nixosModules.hardware-dual-rtx5090
    ])
  ];
in
if system == "x86_64-linux" then
  pkgs.writeText "profiles-eval" (lib.concatLines profiles)
else
  pkgs.writeText "profiles-eval-skipped" "hardware profiles target x86_64-linux\n"
