# DESTRUCTIVE: disko wipes and repartitions the entire 1TB OS NVMe.
let
  mountOpts = [
    "compress=zstd:1"
    "noatime"
    "ssd"
    "space_cache=v2"
  ];
in
{
  disko.devices.disk.os = {
    type = "disk";
    device = "/dev/disk/by-id/nvme-Samsung_SSD_970_EVO_Plus_1TB_S59ANJ0N209883H";
    content = {
      type = "gpt";
      partitions = {
        ESP = {
          type = "EF00";
          size = "1G";
          content = {
            type = "filesystem";
            format = "vfat";
            mountpoint = "/boot";
            mountOptions = [ "umask=0077" ];
          };
        };

        root = {
          size = "100%";
          content = {
            type = "btrfs";
            extraArgs = [
              "-f"
              "-L"
              "os"
            ];
            subvolumes = {
              "@" = {
                mountpoint = "/";
                mountOptions = mountOpts;
              };
              "@nix" = {
                mountpoint = "/nix";
                mountOptions = mountOpts;
              };
              "@log" = {
                mountpoint = "/var/log";
                mountOptions = mountOpts;
              };
              "@snapshots" = {
                mountpoint = "/.snapshots";
                mountOptions = mountOpts;
              };

              # mkswapfile sets nodatacow and disables compression here.
              "@swap" = {
                mountpoint = "/swap";
                swap.swapfile = {
                  size = "16G";
                  priority = 10;
                };
              };
            };
          };
        };
      };
    };
  };
}
