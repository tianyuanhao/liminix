{
  config
, pkgs
, lib
, ...
}:
let
#  inherit (lib) mkOption types concatStringsSep;
  inherit (pkgs) runCommand callPackage writeText;
in
{
  config = {
    kernel.config.BLK_DEV_INITRD = "y";

    outputs = {
      initramfs =
        let
          bb = pkgs.busybox.override {
            enableStatic = true;
            enableMinimal = true;
            enableAppletSymlinks  = false;
            extraConfig  = ''
              CONFIG_ASH y
              CONFIG_LS y
              CONFIG_LN y
              CONFIG_CAT y
              CONFIG_MOUNT y
              CONFIG_PRINTF y
              CONFIG_FEATURE_MOUNT_FLAGS y
              CONFIG_FEATURE_MOUNT_VERBOSE y
              CONFIG_ECHO y
              CONFIG_CHROOT y
              CONFIG_CHMOD y
              CONFIG_MKDIR y
              CONFIG_MKNOD y
              CONFIG_SH_IS_ASH y
              CONFIG_BASH_IS_NONE y
            '';
          };
          slashinit = pkgs.writeScript "init" ''
            #!/bin/sh
            exec >/dev/console
            echo IT MOVES
            mount -t proc none /proc
            mount -t jffs2 mtd0 /target/persist
            mount -o bind /target/persist/nix /target/nix
            sh /target/persist/activate /target
            cd /target
            mount -o bind /target /
            exec chroot . /bin/init "$@"
          '';
          refs = pkgs.writeReferencesToFile bb;
          gen_init_cpio = pkgs.pkgsBuildBuild.gen_init_cpio;
        in runCommand "initramfs" {} ''
          cat << SPECIALS | ${gen_init_cpio}/bin/gen_init_cpio /dev/stdin > $out
          dir /proc 0755 0 0
          dir /dev 0755 0 0
          nod /dev/mtdblock0 0600 0 0 b 31 0
          dir /target 0755 0 0
          dir /target/persist 0755 0 0
          dir /target/nix 0755 0 0
          nod /dev/console 0600 0 0 c 5 1
          dir /bin 0755 0 0
          file /bin/busybox ${bb}/bin/busybox 0755 0 0
          slink /bin/sh /bin/busybox 0755 0 0
          slink /bin/echo /bin/busybox 0755 0 0
          slink /bin/mount /bin/busybox 0755 0 0
          slink /bin/chroot /bin/busybox 0755 0 0
          slink /bin/chmod /bin/busybox 0755 0 0
          slink /bin/ln /bin/busybox 0755 0 0
          slink /bin/mkdir /bin/busybox 0755 0 0
          slink /bin/mknod /bin/busybox 0755 0 0
          slink /bin/printf /bin/busybox 0755 0 0
          file /init ${slashinit} 0755 0 0
          SPECIALS
        '';
    };
  };
}