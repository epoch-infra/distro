# Release variant of `installer-iso`: same image, recompressed with xz
# at maximum settings for distribution. Slow to build (xz -e -T0 on a
# multi-GiB squashfs takes minutes), but produces the smallest artifact.
#
# Build with:
#   nix build .#installer-iso-release
#
# The dev variant (`installer-iso`) keeps zstd -5 for fast iteration —
# use that during development and this one for releases.
{ flake, ... }:
(flake.nixosConfigurations.installer.extendModules {
  modules = [
    (
      { lib, ... }:
      {
        # `xz -e` (extreme), `-T0` (all cores). `-Xbcj x86` lets squashfs's
        # x86 branch-call-jump filter run before xz, shaving another few %
        # on kernel/userland binaries. mkForce overrides the dev image's
        # zstd -5 setting from installer-iso.nix.
        isoImage.squashfsCompression = lib.mkForce "xz -Xdict-size 100% -Xbcj x86 -e -T0";
      }
    )
  ];
}).config.system.build.isoImage
