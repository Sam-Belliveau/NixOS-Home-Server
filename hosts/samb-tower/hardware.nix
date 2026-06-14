{ config, lib, ... }:
{
  # Boot / initrd
  boot.initrd.availableKernelModules = [
    "nvme"
    "xhci_pci"
    "ahci"
    "usbhid"
    "usb_storage"
    "sd_mod"
  ];
  boot.kernelModules = [ "kvm-intel" ];

  # Disable deep NVMe APST, which drops the 2TB 970 EVO Plus to state=dead.
  boot.kernelParams = [ "nvme_core.default_ps_max_latency_us=0" ];

  # CPU microcode + firmware
  hardware.cpu.intel.updateMicrocode = lib.mkDefault true;
  hardware.enableRedistributableFirmware = true;
  services.fwupd.enable = true;
  powerManagement.cpuFreqGovernor = lib.mkDefault "performance";

  # Storage maintenance
  services.fstrim.enable = true;
  services.btrfs.autoScrub = {
    enable = true;
    interval = "monthly";
    fileSystems = [
      "/"
      "/home"
    ];
  };

  nixpkgs.hostPlatform = "x86_64-linux";
}
