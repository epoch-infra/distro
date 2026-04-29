# Noctalia Wayland desktop shell.
#
# Pulls noctalia-shell from the upstream flake. The upstream NixOS module
# only exposes a deprecated systemd-service path; per upstream docs the
# shell should be spawned by the compositor instead. We just install the
# package — the host wires the spawn into its compositor config.
{ inputs, pkgs, ... }:
{
  environment.systemPackages = [
    inputs.noctalia-shell.packages.${pkgs.system}.default
  ];
}
