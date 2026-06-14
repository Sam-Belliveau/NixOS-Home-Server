# ╔══════════════════════════════════════════════════════════════════════════╗
# ║  DESTRUCTIVE: disko wipes and repartitions the entire 4TB DATA SSD.       ║
# ║  Addressed by stable /dev/disk/by-id path — never /dev/sdX.               ║
# ╚══════════════════════════════════════════════════════════════════════════╝
let
  mountOpts = [
    "compress=zstd:2"
    "noatime"
    "ssd"
    "space_cache=v2"
  ];
in
{
  disko.devices.disk.data = {
    type = "disk";
    device = "/dev/disk/by-id/ata-Samsung_SSD_870_QVO_4TB_S5VYNG0NC01406M";
    content = {
      type = "gpt";
      partitions.data = {
        size = "100%";
        content = {
          type = "btrfs";
          extraArgs = [
            "-f"
            "-L"
            "data"
          ];
          subvolumes = {
            "@home" = {
              mountpoint = "/home";
              mountOptions = mountOpts;
            };
            "@games" = {
              mountpoint = "/games";
              mountOptions = mountOpts;
            };
            "@srv" = {
              mountpoint = "/srv";
              mountOptions = mountOpts;
            };
          };
        };
      };
    };
  };
}
