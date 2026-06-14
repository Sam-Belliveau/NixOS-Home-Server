# DESTRUCTIVE on enable. Disabled and unimported by default. See HARVEST.md.
{ config, lib, ... }:
let
  cfg = config.samb.scratch;
  mountOpts = [
    "compress=zstd:1"
    "noatime"
    "ssd"
    "nofail"
  ];
in
{
  options.samb.scratch.enable =
    lib.mkEnableOption "the optional 2TB NVMe scratch disk (adopt only after proven stable)";

  config = lib.mkIf cfg.enable {
    disko.devices.disk.scratch = {
      type = "disk";
      device = "/dev/disk/by-id/nvme-Samsung_SSD_970_EVO_Plus_2TB_S59CNJ0N102070D";
      content = {
        type = "gpt";
        partitions.scratch = {
          size = "100%";
          content = {
            type = "btrfs";
            extraArgs = [
              "-f"
              "-L"
              "scratch"
            ];
            subvolumes = {
              "@cache" = {
                mountpoint = "/scratch/cache";
                mountOptions = mountOpts;
              };
              "@steam" = {
                mountpoint = "/scratch/steam";
                mountOptions = mountOpts;
              };
              "@dataset" = {
                mountpoint = "/scratch/dataset";
                mountOptions = mountOpts;
              };
            };
          };
        };
      };
    };
  };
}
