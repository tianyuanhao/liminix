{ lib, pkgs, config, ...}:
let
  inherit (lib) mkEnableOption mkOption types isDerivation hasAttr ;
in {
  options = {
    boot = {
    };
    hardware = {
      dts = {
        src = mkOption { type = types.path; };
        includes = mkOption {
          default = [];
          type = types.listOf types.path;
        };
      };
      defaultOutput = mkOption {
        type = types.nonEmptyStr;
      };
      flash = {
        # start address and size of whichever partition (often
        # called "firmware") we're going to overwrite with our
        # kernel uimage and root fs. Not the entire flash, as
        # that often also contains the bootloader, data for
        # for wireless devices, etc
        address = mkOption { type = types.str; };
        size = mkOption { type = types.str; };
        eraseBlockSize = mkOption { type = types.str; };
      };
      loadAddress = mkOption { default = null; };
      entryPoint = mkOption { };
      radios = mkOption {
        type = types.listOf types.str;
        default = [];
        example = ["ath9k" "ath10k"];
      };
      rootDevice = mkOption { };
      networkInterfaces = mkOption {
        type = types.attrsOf types.anything;
      };
    };
  };
}
