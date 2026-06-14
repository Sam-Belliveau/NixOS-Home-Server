# ╔══════════════════════════════════════════════════════════════════════════╗
# ║  OPTIONAL / ADOPT-AFTER-PROVEN-STABLE — DISABLED BY DEFAULT.              ║
# ║                                                                          ║
# ║  2TB NVMe (Samsung 970 EVO Plus 2TB, fw 2B2QEXM7) currently enumerates   ║
# ║  as state=dead / size=0. Leading theory: NVMe APST power-state drop       ║
# ║  (mitigated by nvme_core.default_ps_max_latency_us=0 in hardware.nix);    ║
# ║  secondary theory: a failing unit. Do NOT import this file in            ║
# ║  hosts/samb-tower/default.nix and do NOT flip the toggle until the drive  ║
# ║  has survived several cold/warm boots WITH the APST param applied.        ║
# ║                                                                          ║
# ║  Nothing irreplaceable lives here: build cache, extra Steam library,     ║
# ║  dataset scratch only. DESTRUCTIVE on enable.                            ║
# ╚══════════════════════════════════════════════════════════════════════════╝
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
