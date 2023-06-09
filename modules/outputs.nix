{
  config
, pkgs
, lib
, ...
}:
let
  inherit (lib) mkOption types concatStringsSep;
  inherit (pkgs) liminix callPackage writeText;
in
{
  imports = [
    ./squashfs.nix
  ];
  options = {
    outputs = mkOption {
      type = types.attrsOf types.package;
      default = {};
    };
  };
  config = {
    outputs = rec {
      tftpd = pkgs.buildPackages.tufted;
      kernel = liminix.builders.kernel.override {
        inherit (config.kernel) config src extraPatchPhase;
      };
      dtb =  (callPackage ../kernel/dtb.nix {}) {
        inherit (config.boot) commandLine;
        dts = config.hardware.dts.src;
        includes = config.hardware.dts.includes ++ [
          "${kernel.headers}/include"
        ];
      };
      uimage = (callPackage ../kernel/uimage.nix {}) {
        commandLine = concatStringsSep " " config.boot.commandLine;
        inherit (config.hardware) loadAddress entryPoint;
        inherit kernel;
        inherit dtb;
      };
      vmroot = pkgs.runCommand "qemu" {} ''
        mkdir $out
        cd $out
        ln -s ${config.outputs.rootfs} rootfs
        ln -s ${kernel} vmlinux
        ln -s ${manifest} manifest
        ln -s ${kernel.headers} build
      '';

      # this exists so that you can run "nix-store -q --tree" on it and find
      # out what's in the image, which is nice if it's unexpectedly huge
      manifest = writeText "manifest.json" (builtins.toJSON config.filesystem.contents);
    };
  };
}
