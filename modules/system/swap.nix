{ ... }:
{
  # Tier-1 swap; the tier-2 disk swapfile is declared in disko-os.nix.
  zramSwap = {
    enable = true;
    algorithm = "zstd";
    memoryPercent = 50;
    priority = 100;
  };
}
