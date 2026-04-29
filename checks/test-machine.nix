# NixOS VM test for the test-machine host.
#
# Headless verification of the wiring around niri. We cannot validate
# noctalia or any rendered output here because:
#   - niri rejects software EGL (hardcoded in src/backend/tty.rs)
#   - the nixos test runner has no GPU to pass through
#   - Qt/Quickshell (noctalia) requires a working OpenGL context
#
# What this test does verify:
#   - greetd starts and opens a PAM session for the test user
#   - the user manager (user@1000.service) comes up
#   - niri.service activates and exposes a Wayland socket
#
# Interactive validation of the shell happens in the GUI VM
# (`nix build .#test-vm && ./result/bin/run-test-machine-vm`).
{ pkgs, inputs, ... }:

pkgs.testers.nixosTest {
  name = "test-machine";

  nodes.test-machine =
    { lib, ... }:
    {
      _module.args = { inherit inputs; };
      imports = [ ../hosts/test-machine/configuration.nix ];

      # The host pins a real disk; the test framework provides its own.
      fileSystems = lib.mkForce { };
      boot.loader.systemd-boot.enable = lib.mkForce false;

      virtualisation = {
        memorySize = 2048;
        cores = 2;
      };
    };

  testScript =
    { nodes, ... }:
    let
      uid = toString nodes.test-machine.config.users.users.test.uid;
    in
    ''
      machine.wait_for_unit("multi-user.target")

      with subtest("greetd autostarts the niri session"):
          machine.wait_for_unit("greetd.service")
          # pam_systemd starts user@1000.service when greetd opens the session
          machine.wait_for_unit("user@${uid}.service")

      with subtest("niri.service starts under the user manager"):
          machine.wait_until_succeeds(
              "systemctl --user --machine=test@.host is-active niri.service",
              timeout=30,
          )

      with subtest("niri exposes its Wayland socket"):
          machine.wait_for_file("/run/user/${uid}/wayland-1", timeout=30)

      with subtest("niri spawned noctalia-shell"):
          # We can't verify quickshell renders (no GPU in the test runner),
          # but niri's spawn-at-startup must fire and create the systemd
          # transient scope. Quickshell also creates a runtime dir under
          # $XDG_RUNTIME_DIR/quickshell when it starts; that's enough to
          # prove the spawn happened and qs got far enough to initialize.
          machine.wait_until_succeeds(
              "test -d /run/user/${uid}/quickshell",
              timeout=30,
          )
          machine.wait_until_succeeds(
              "ls /sys/fs/cgroup/user.slice/user-${uid}.slice/"
              "user@${uid}.service/app.slice/ "
              "| grep -q 'app-niri-noctalia.*\\.scope'",
              timeout=30,
          )
    '';
}
